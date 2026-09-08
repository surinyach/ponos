# Ponos server

Self-hosted FastAPI service for Ponos. PostgreSQL is the source of truth and
Alembic owns all schema changes.

## Current scope

- Environment-based configuration
- Async SQLAlchemy session management
- Alembic migration foundation
- Database-aware `GET /health`
- Docker Compose deployment with private PostgreSQL networking
- Basic API test
- Focus Area, weekday target, and timer execution schema
- Database-enforced non-overlapping target periods
- PostgreSQL-backed, versioned Focus Areas API under `/api/v1/focus-areas`

Authentication and Flutter integration remain outside the current scope.

## Run with Docker

From the repository root:

```shell
cp .env.example .env
docker compose up --build
```

The API is available at `http://localhost:8000`. PostgreSQL is not published to
the host. The API container waits for PostgreSQL, runs `alembic upgrade head`,
and then starts FastAPI.

Run the complete backend test suite against an isolated, temporary PostgreSQL instance:

```shell
docker compose -f compose.test.yaml up --build --abort-on-container-exit --exit-code-from api-test
```

Check readiness:

```shell
curl http://localhost:8000/health
```

Expected response:

```json
{"status":"ok","database":"ok"}
```

## Development without Docker

Python 3.12 and a reachable PostgreSQL instance are required.

```shell
cd server
python -m venv .venv
.venv/Scripts/activate
pip install -e ".[dev]"
alembic upgrade head
uvicorn app.main:app --reload
pytest
```

Set the `PONOS_DATABASE_HOST`, `PONOS_DATABASE_PORT`, `PONOS_DATABASE_NAME`,
`PONOS_DATABASE_USER`, and `PONOS_DATABASE_PASSWORD` environment variables when
the defaults are not appropriate.
