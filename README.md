## Wholesale Business Management & Accounting System

### Structure
- **`backend/`**: Node.js (Express) API + Prisma (PostgreSQL)
- **`mobile/`**: Flutter app

### Quick start (Backend)
Database options:
- If you have Docker installed, you can use `docker compose up -d` (see `docker-compose.yml`).
- If you don't have Docker, use Prisma's local dev database:

```bash
cd backend
npx prisma dev
```

Run API:

```bash
cd backend
npm install
cp .env.example .env
npm run prisma:generate
npm run prisma:push
npm run prisma:seed
npm run dev
```

Health check: `http://localhost:4000/health`

Seeded login:
- **username**: `admin`
- **password**: `Admin12345!`

