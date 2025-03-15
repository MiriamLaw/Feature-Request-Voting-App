# Docker Setup for Feature Voting App

This document provides instructions on how to run the Feature Voting application using Docker.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)

## Getting Started

### Using Docker Compose (Recommended)

1. Clone the repository and navigate to the project directory:

```bash
git clone <repository-url>
cd feature-voting
```

2. Start the application and database using Docker Compose:

```bash
docker-compose up -d
```

This will:
- Build the application image
- Start a MySQL database container
- Start the application container
- Connect the application to the database

3. Access the application at [http://localhost:3000](http://localhost:3000)

4. To stop the containers:

```bash
docker-compose down
```

### Using Docker Only

1. Build the Docker image:

```bash
docker build -t feature-voting-app .
```

2. Run the container:

```bash
docker run -p 3000:3000 -e DATABASE_URL=<your-database-url> -e NEXTAUTH_SECRET=<your-secret> -e NEXTAUTH_URL=<your-url> feature-voting-app
```

Replace the environment variables with your actual values.

## Environment Variables

The following environment variables are required:

- `DATABASE_URL`: MySQL connection string
- `NEXTAUTH_SECRET`: Secret for NextAuth.js
- `NEXTAUTH_URL`: URL where the application is hosted

For Google OAuth (optional):
- `GOOGLE_ID`: Google OAuth client ID
- `GOOGLE_SECRET`: Google OAuth client secret

## Database Migrations

When running the application for the first time, you need to run database migrations:

```bash
# Using Docker Compose
docker-compose exec app npx prisma migrate deploy

# Using Docker only
docker exec -it <container-id> npx prisma migrate deploy
```

## Troubleshooting

### Database Connection Issues

If the application cannot connect to the database, ensure:

1. The database container is running:
```bash
docker-compose ps
```

2. The DATABASE_URL environment variable is correctly set:
```bash
docker-compose exec app printenv DATABASE_URL
```

3. You can manually connect to the database:
```bash
docker-compose exec db mysql -u root -p
```

### Prisma Client Generation

If you encounter Prisma-related errors, you may need to regenerate the Prisma client:

```bash
docker-compose exec app npx prisma generate
``` 