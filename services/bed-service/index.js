const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'kindcare',
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

async function initDB() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS beds (
      id SERIAL PRIMARY KEY,
      bed_number VARCHAR(20) UNIQUE NOT NULL,
      ward VARCHAR(50) NOT NULL,
      status VARCHAR(20) DEFAULT 'available',
      patient_id INTEGER,
      patient_name VARCHAR(200),
      triage_level INTEGER,
      assigned_at TIMESTAMP,
      updated_at TIMESTAMP DEFAULT NOW()
    )
  `);

  // Seed beds if empty
  const count = await pool.query('SELECT COUNT(*) FROM beds');
  if (parseInt(count.rows[0].count) === 0) {
    const wards = [
      { ward: 'ICU', prefix: 'ICU', count: 8 },
      { ward: 'Emergency', prefix: 'ER', count: 15 },
      { ward: 'General', prefix: 'GEN', count: 20 },
      { ward: 'Pediatric', prefix: 'PED', count: 10 },
    ];
    for (const w of wards) {
      for (let i = 1; i <= w.count; i++) {
        await pool.query(
          'INSERT INTO beds (bed_number, ward) VALUES ($1, $2) ON CONFLICT DO NOTHING',
          [`${w.prefix}-${String(i).padStart(2, '0')}`, w.ward]
        );
      }
    }
    console.log('Beds seeded');
  }
  console.log('Bed DB initialized');
}

// Get all beds, optionally filtered by ward or status
app.get('/beds', async (req, res) => {
  try {
    const { ward, status } = req.query;
    let query = 'SELECT * FROM beds WHERE 1=1';
    const params = [];

    if (ward) { params.push(ward); query += ` AND ward = $${params.length}`; }
    if (status) { params.push(status); query += ` AND status = $${params.length}`; }

    query += ' ORDER BY ward, bed_number';
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get bed summary stats
app.get('/beds/summary', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT ward,
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE status = 'available') as available,
        COUNT(*) FILTER (WHERE status = 'occupied') as occupied,
        COUNT(*) FILTER (WHERE status = 'cleaning') as cleaning
      FROM beds
      GROUP BY ward
      ORDER BY ward
    `);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Assign a bed to a patient
app.post('/beds/assign', async (req, res) => {
  try {
    const { patientId, patientName, triageLevel, ward } = req.body;

    // Find best available bed — prefer ward matching triage level
    let preferredWard = ward;
    if (!preferredWard) {
      if (triageLevel === 1) preferredWard = 'ICU';
      else if (triageLevel === 2) preferredWard = 'Emergency';
      else preferredWard = 'General';
    }

    let bed = await pool.query(
      `SELECT * FROM beds WHERE status = 'available' AND ward = $1 LIMIT 1`,
      [preferredWard]
    );

    // Fallback to any available bed
    if (bed.rows.length === 0) {
      bed = await pool.query(`SELECT * FROM beds WHERE status = 'available' LIMIT 1`);
    }

    if (bed.rows.length === 0) {
      return res.status(409).json({ error: 'No beds available' });
    }

    const result = await pool.query(
      `UPDATE beds SET status = 'occupied', patient_id = $1, patient_name = $2,
       triage_level = $3, assigned_at = NOW(), updated_at = NOW()
       WHERE id = $4 RETURNING *`,
      [patientId, patientName, triageLevel, bed.rows[0].id]
    );

    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Release a bed
app.patch('/beds/:id/release', async (req, res) => {
  try {
    const result = await pool.query(
      `UPDATE beds SET status = 'cleaning', patient_id = NULL, patient_name = NULL,
       triage_level = NULL, assigned_at = NULL, updated_at = NOW()
       WHERE id = $1 RETURNING *`,
      [req.params.id]
    );
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Mark bed as available after cleaning
app.patch('/beds/:id/ready', async (req, res) => {
  try {
    const result = await pool.query(
      `UPDATE beds SET status = 'available', updated_at = NOW() WHERE id = $1 RETURNING *`,
      [req.params.id]
    );
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/health', (req, res) => res.json({ status: 'ok', service: 'bed-service' }));

initDB().then(() => {
  app.listen(3002, () => console.log('Bed service running on port 3002'));
});
