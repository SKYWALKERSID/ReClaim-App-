# API Documentation - ReClaim

## Base URL
`http://localhost:3000/api`

## Authentication
All protected routes require a Bearer token in the `Authorization` header.

## Endpoints

### Auth
- `POST /auth/register`: Create a new user.
- `POST /auth/login`: Login and receive tokens.
- `POST /auth/refresh`: Refresh the access token.
- `POST /auth/logout`: Invalidate the current session.

### Focus / Insights
- `GET /drift/stats`: Get cognitive drift metrics.
- `GET /reflection/prompts`: Fetch daily reflection prompts.
- `POST /reflection/submit`: Submit a reflection response.

### Notifications
- `POST /notifications/token`: Register FCM device token.
