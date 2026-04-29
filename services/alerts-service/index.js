const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

const pool = new Pool({
  ssl: { rejectUnauthorized: false },
  host: process.env.DB_HOST,
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'kindcare',
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

async function initDB() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS alerts (
      id SERIAL PRIMARY KEY,
      type VARCHAR(50) NOT NULL,
      severity VARCHAR(20) NOT NULL,
      title VARCHAR(200) NOT NULL,
      message TEXT NOT NULL,
      patient_id INTEGER,
      patient_name VARCHAR(200),
      acknowledged BOOLEAN DEFAULT FALSE,
      acknowledged_by VARCHAR(100),
      created_at TIMESTAMP DEFAULT NOW(),
      updated_at TIMESTAMP DEFAULT NOW()
    )
  `);
  console.log('Alerts DB initialized');
}

// Get all active alerts
app.get('/alerts', async (req, res) => {
  try {
    const { acknowledged, severity } = req.query;
    let query = 'SELECT * FROM alerts WHERE 1=1';
    const params = [];

    if (acknowledged !== undefined) {
      params.push(acknowledged === 'true');
      query += ` AND acknowledged = $${params.length}`;
    }
    if (severity) {
      params.push(severity);
      query += ` AND severity = $${params.length}`;
    }

    query += ' ORDER BY CASE severity WHEN \'critical\' THEN 1 WHEN \'high\' THEN 2 WHEN \'medium\' THEN 3 ELSE 4 END, created_at DESC';
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Create an alert
app.post('/alerts', async (req, res) => {
  try {
    const { type, severity, title, message, patientId, patientName } = req.body;
    const result = await pool.query(
      `INSERT INTO alerts (type, severity, title, message, patient_id, patient_name)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [type, severity, title, message, patientId || null, patientName || null]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Acknowledge an alert
app.patch('/alerts/:id/acknowledge', async (req, res) => {
  try {
    const { acknowledgedBy } = req.body;
    const result = await pool.query(
      `UPDATE alerts SET acknowledged = TRUE, acknowledged_by = $1, updated_at = NOW()
       WHERE id = $2 RETURNING *`,
      [acknowledgedBy || 'Staff', req.params.id]
    );
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Auto-generate system alerts based on conditions
app.post('/alerts/check', async (req, res) => {
  try {
    const { criticalWaiting, bedAvailabilityPct, level1WaitMinutes, patientId, patientName } = req.body;
    const generated = [];

    if (level1WaitMinutes > 2) {
      const a = await pool.query(
        `INSERT INTO alerts (type, severity, title, message, patient_id, patient_name)
         VALUES ('wait_time', 'critical', 'CRITICAL: Level 1 Patient Waiting', $1, $2, $3)
         RETURNING *`,
        [`Level 1 Critical patient ${patientName} has been waiting ${level1WaitMinutes} minutes. Immediate intervention required.`, patientId, patientName]
      );
      generated.push(a.rows[0]);
    }

    if (bedAvailabilityPct < 10) {
      const a = await pool.query(
        `INSERT INTO alerts (type, severity, title, message)
         VALUES ('capacity', 'critical', 'ER AT CRITICAL CAPACITY', $1)
         RETURNING *`,
        [`Bed availability has dropped to ${bedAvailabilityPct.toFixed(1)}%. Activate surge protocol immediately.`]
      );
      generated.push(a.rows[0]);
    } else if (bedAvailabilityPct < 20) {
      const a = await pool.query(
        `INSERT INTO alerts (type, severity, title, message)
         VALUES ('capacity', 'high', 'Low Bed Availability Warning', $1)
         RETURNING *`,
        [`Bed availability is at ${bedAvailabilityPct.toFixed(1)}%. Consider diverting non-critical patients.`]
      );
      generated.push(a.rows[0]);
    }

    if (criticalWaiting > 3) {
      const a = await pool.query(
        `INSERT INTO alerts (type, severity, title, message)
         VALUES ('queue', 'high', 'High Volume Critical Patients', $1)
         RETURNING *`,
        [`${criticalWaiting} Level 1-2 patients currently waiting. Additional staff may be required.`]
      );
      generated.push(a.rows[0]);
    }

    res.json({ generated, count: generated.length });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Alert stats
app.get('/alerts/stats', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        COUNT(*) FILTER (WHERE NOT acknowledged) as active,
        COUNT(*) FILTER (WHERE severity = 'critical' AND NOT acknowledged) as critical,
        COUNT(*) FILTER (WHERE severity = 'high' AND NOT acknowledged) as high,
        COUNT(*) FILTER (WHERE acknowledged) as resolved
      FROM alerts
    `);
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/health', (req, res) => res.json({ status: 'ok', service: 'alerts-service' }));

initDB().then(() => {
  app.listen(3003, () => console.log('Alerts service running on port 3003'));
});
