# Ponos

Ponos is a personal work, focus, and consistency tracker. This repository is a
monorepo containing the Flutter client and, in future steps, its homelab API.

## Repository structure

```text
app/       # Flutter client for Android and Web
server/    # API and database
```

The client and server remain separate applications with independent
dependencies. Keeping them together allows UI, API contracts, and database
migrations to evolve in the same changeset.

## Flutter client

```shell
cd app
flutter pub get
flutter run -d android
flutter run -d chrome
```

See [app/README.md](app/README.md) for the client structure and design language.

Fixed cross-platform business requirements are documented under `docs/`,
including the [Focus Timer domain rules](docs/focus-timer-domain-rules.md) and
the [Manual Work Entries and Special Activities domain
rules](docs/manual-work-and-special-activities-domain-rules.md).

## Server

The self-hosted FastAPI and PostgreSQL stack lives under `server/` and is
orchestrated by the root `compose.yaml`. See [server/README.md](server/README.md)
for setup and health-check instructions. Database credentials, local environment
files, and database volumes must never be committed.
