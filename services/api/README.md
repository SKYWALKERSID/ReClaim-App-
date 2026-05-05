# ReClaim API

## Quick start

1. Copy `.env.example` to `.env` and update `DATABASE_URL`.
2. Run `npm install`.
3. Run migration: `npm run migrate`.
4. Run API: `npm run dev`.

## Endpoints

- `POST /v1/commitments`
- `GET /v1/commitments/:userId`
- `POST /v1/analytics/events`
- `GET /v1/analytics/daily/:userId?date=YYYY-MM-DD&timeZone=Asia/Kolkata`
- `GET /v1/policy/:userId?date=YYYY-MM-DD&timeZone=Asia/Kolkata`
- `GET /v1/rewards/:userId?date=YYYY-MM-DD`

