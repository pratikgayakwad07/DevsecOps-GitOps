# Local Development (optional)

You can run the app on your laptop without AWS for quick testing.

## Backend

```bash
cd backend
npm install
# Make sure you have MySQL running locally
# Create database and table using database.sql
npm start
```

## Frontend

```bash
cd frontend
npm install
npm run start
```

Open http://localhost:5173 (Vite default).

> Note: For the full DevSecOps experience you should deploy to EKS.
