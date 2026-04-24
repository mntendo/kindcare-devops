# KindCare — Smart ER Triage System

A real-time hospital operations platform for emergency room triage, bed management, and clinical alerts.

## Architecture

- **Frontend** — ER Command Center dashboard (Nginx + HTML/JS)
- **Triage Service** (Port 3001) — Patient intake with automatic ESI Level scoring
- **Bed Service** (Port 3002) — Real-time bed availability across ICU, ER, General, Pediatric wards
- **Alerts Service** (Port 3003) — Clinical alerts with severity levels and acknowledgement

## Run Locally

```bash
docker compose up --build
```

Open http://localhost:8080

## Services

| Service | Port | Description |
|---|---|---|
| Frontend | 8080 | ER Dashboard |
| Triage | 3001 | Patient intake + ESI scoring |
| Bed Management | 3002 | Bed tracking + assignment |
| Alerts | 3003 | Clinical alert management |

## ESI Triage Levels

| Level | Label | Wait Time |
|---|---|---|
| 1 | Critical | Immediate |
| 2 | Emergent | < 15 min |
| 3 | Urgent | 30 min |
| 4 | Less Urgent | 60 min |
| 5 | Non-Urgent | 120 min |
