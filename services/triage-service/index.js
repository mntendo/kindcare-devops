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
  database: process.env.DB_NAME || 'careops',
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

// ESI Triage Scoring Logic (ESI levels 1-5)
function calculateTriageLevel(data) {
  const {
    heartRate, bloodPressureSystolic, oxygenSaturation,
    temperature, chiefComplaint, consciousnessLevel, painLevel, respiratoryRate
  } = data;

  // Level 1 - Immediate: Life threatening
  if (
    consciousnessLevel === 'unresponsive' ||
    oxygenSaturation < 85 ||
    heartRate > 150 || heartRate < 40 ||
    bloodPressureSystolic < 70 ||
    respiratoryRate > 35 || respiratoryRate < 8 ||
    ['cardiac arrest', 'stroke', 'severe trauma', 'respiratory failure'].some(c =>
      chiefComplaint.toLowerCase().includes(c))
  ) {
    return {
      level: 1,
      label: 'CRITICAL',
      color: 'red',
      reason: 'Immediate life threat detected. Requires immediate physician intervention.',
      waitTime: 'Immediate'
    };
  }

  // Level 2 - Emergent: High risk situation
  if (
    oxygenSaturation < 92 ||
    heartRate > 130 || heartRate < 50 ||
    bloodPressureSystolic < 90 || bloodPressureSystolic > 200 ||
    temperature > 103 || temperature < 95 ||
    consciousnessLevel === 'confused' ||
    painLevel >= 9 ||
    ['chest pain', 'difficulty breathing', 'severe headache', 'altered mental', 'seizure', 'overdose'].some(c =>
      chiefComplaint.toLowerCase().includes(c))
  ) {
    return {
      level: 2,
      label: 'EMERGENT',
      color: 'orange',
      reason: 'High-risk situation. Should not wait. Requires rapid medical evaluation.',
      waitTime: '< 15 minutes'
    };
  }

  // Level 3 - Urgent: Stable but needs multiple resources
  if (
    heartRate > 110 ||
    bloodPressureSystolic > 160 ||
    temperature > 101 ||
    painLevel >= 7 ||
    ['fracture', 'abdominal pain', 'back pain', 'vomiting', 'dehydration', 'infection'].some(c =>
      chiefComplaint.toLowerCase().includes(c))
  ) {
    return {
      level: 3,
      label: 'URGENT',
      color: 'yellow',
      reason: 'Urgent condition requiring multiple resources. Stable but needs timely care.',
      waitTime: '30 minutes'
    };
  }

  // Level 4 - Less Urgent
  if (
    painLevel >= 4 ||
    ['sprain', 'minor laceration', 'ear pain', 'sore throat', 'rash', 'urinary'].some(c =>
      chiefComplaint.toLowerCase().includes(c))
  ) {
    return {
      level: 4,
      label: 'LESS URGENT',
      color: 'green',
      reason: 'Condition is stable. One resource required. Can wait for available provider.',
      waitTime: '60 minutes'
    };
  }

  // Level 5 - Non-Urgent
  return {
    level: 5,
    label: 'NON-URGENT',
    color: 'blue',
    reason: 'Non-urgent condition. Minimal resources needed.',
    waitTime: '120 minutes'
  };
}

// Init DB
async function initDB() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS patients (
      id SERIAL PRIMARY KEY,
      first_name VARCHAR(100) NOT NULL,
      last_name VARCHAR(100) NOT NULL,
      dob DATE,
      gender VARCHAR(20),
      chief_complaint TEXT,
      heart_rate INTEGER,
      blood_pressure_systolic INTEGER,
      blood_pressure_diastolic INTEGER,
      oxygen_saturation INTEGER,
      temperature DECIMAL(4,1),
      respiratory_rate INTEGER,
      pain_level INTEGER,
      consciousness_level VARCHAR(50),
      triage_level INTEGER,
      triage_label VARCHAR(50),
      triage_reason TEXT,
      wait_time VARCHAR(50),
      status VARCHAR(50) DEFAULT 'waiting',
      created_at TIMESTAMP DEFAULT NOW()
    )
  `);
  console.log('Triage DB initialized');
}

// Register + triage a new patient
app.post('/patients', async (req, res) => {
  try {
    const {
      firstName, lastName, dob, gender,
      chiefComplaint, heartRate, bloodPressureSystolic,
      bloodPressureDiastolic, oxygenSaturation, temperature,
      respiratoryRate, painLevel, consciousnessLevel
    } = req.body;

    const triage = calculateTriageLevel({
      heartRate, bloodPressureSystolic, oxygenSaturation,
      temperature, chiefComplaint, consciousnessLevel,
      painLevel, respiratoryRate
    });

    const result = await pool.query(
      `INSERT INTO patients
        (first_name, last_name, dob, gender, chief_complaint, heart_rate,
         blood_pressure_systolic, blood_pressure_diastolic, oxygen_saturation,
         temperature, respiratory_rate, pain_level, consciousness_level,
         triage_level, triage_label, triage_reason, wait_time)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)
       RETURNING *`,
      [firstName, lastName, dob, gender, chiefComplaint, heartRate,
       bloodPressureSystolic, bloodPressureDiastolic, oxygenSaturation,
       temperature, respiratoryRate, painLevel, consciousnessLevel,
       triage.level, triage.label, triage.reason, triage.waitTime]
    );

    res.status(201).json({ patient: result.rows[0], triage });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

// Search patients
app.get('/patients', async (req, res) => {
  try {
    const { search, status } = req.query;
    let query = 'SELECT * FROM patients WHERE 1=1';
    const params = [];

    if (search) {
      params.push(`%${search}%`);
      query += ` AND (first_name ILIKE $${params.length} OR last_name ILIKE $${params.length} OR CAST(id AS TEXT) LIKE $${params.length})`;
    }
    if (status) {
      params.push(status);
      query += ` AND status = $${params.length}`;
    }

    query += ' ORDER BY triage_level ASC, created_at ASC';
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get single patient
app.get('/patients/:id', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM patients WHERE id = $1', [req.params.id]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Patient not found' });
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Update patient status
app.patch('/patients/:id/status', async (req, res) => {
  try {
    const { status } = req.body;
    const result = await pool.query(
      'UPDATE patients SET status = $1 WHERE id = $2 RETURNING *',
      [status, req.params.id]
    );
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/health', (req, res) => res.json({ status: 'ok', service: 'triage-service' }));

initDB().then(() => {
  app.listen(3001, () => console.log('Triage service running on port 3001'));
});

// Update patient condition
app.patch('/patients/:id/condition', async (req, res) => {
  try {
    const { condition } = req.body;
    await pool.query('ALTER TABLE patients ADD COLUMN IF NOT EXISTS condition VARCHAR(50)');
    const result = await pool.query(
      'UPDATE patients SET condition = $1 WHERE id = $2 RETURNING *',
      [condition, req.params.id]
    );
    res.json(result.rows[0]);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// Update patient notes
app.patch('/patients/:id/notes', async (req, res) => {
  try {
    const { notes } = req.body;
    await pool.query('ALTER TABLE patients ADD COLUMN IF NOT EXISTS notes TEXT');
    const result = await pool.query(
      'UPDATE patients SET notes = $1 WHERE id = $2 RETURNING *',
      [notes, req.params.id]
    );
    res.json(result.rows[0]);
  } catch (err) { res.status(500).json({ error: err.message }); }
});
