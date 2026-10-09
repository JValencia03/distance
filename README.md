# Distance

**Turn intentions into shared experiences.**

Distance is a mobile-first application designed to help people discover, create, and join nearby plans around shared activities. Instead of browsing people nearby, users discover **plans**: things they can actually do together.

> **Project status:** Early development. Activity selection, nearby plan discovery, and plan creation work end to end against a local API. Joining plans, authentication, and persistent storage are not implemented yet.

## MVP

| Feature | Status |
| --- | --- |
| Choose an activity from a predefined catalog | Implemented |
| Discover upcoming plans near a reference zone, filtered by activity | Implemented |
| View plan details: activity, meeting point, date and time, participants | Implemented |
| Create a plan when there isn't a suitable one | Implemented |
| Join plans created by other users | Planned |

## Repository structure

```text
distance/
├── backend/    Go HTTP API (net/http, standard library only)
├── frontend/   Flutter mobile app
├── CLAUDE.md   Shared project rules
└── CHANGELOG.md
```

Both modules live in this single repository. Run each module's commands from its own directory.

## Tech stack

- **Flutter / Dart:** mobile client. Android is the initial development target.
- **Go:** REST API built on `net/http`.
- **`http` package:** the app's only third-party runtime dependency.

The current backend stores plans **in memory**, so data is lost when the server restarts. PostgreSQL/PostGIS will be added when a feature needs persistence.

## Responsibilities

- **Frontend:** user interface, navigation, UI state, and HTTP requests to the API.
- **Backend:** HTTP API, business rules such as validation, discovery ordering, and participant limits, and data storage.

### Location and privacy

Location is handled with privacy in mind. For now the app uses **predefined zones** instead of device GPS:

- Users pick a zone to search from and a zone for each plan's meeting point.
- Zone coordinates stay on the server. The app only receives a rounded distance between zones.
- A plan's location is a meeting point, never a participant's live position.

## Getting started

### Prerequisites

- Go (see `backend/go.mod` for the version).
- Flutter SDK available on `PATH`.
- Android SDK and an Android emulator or physical device.
- VS Code with the Go, Flutter, and Dart extensions (recommended).

### Run the backend

```bash
cd backend
go run .
```

The API listens on port `8080`. Check it with `curl http://localhost:8080/health`.

### Run the app

```bash
cd frontend
flutter pub get
flutter run
```

The API base URL depends on where the app runs:

| Target | Default URL |
| --- | --- |
| Android emulator | `http://10.0.2.2:8080` |
| iOS simulator / desktop | `http://localhost:8080` |
| Physical device | Pass the URL explicitly (see below) |

On a physical device, pass your computer's LAN IP:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8080
```

Debug Android builds allow plain HTTP so they can reach the local API.

### Development identity

There is no authentication yet. The app sends a development user id in the `X-User-Id` header when creating plans; it defaults to `demo-user`. To simulate another user, run:

```bash
flutter run --dart-define=DEV_USER_ID=another-user
```

**This header is not a security mechanism.**

## API overview

| Method | Path | Description |
| --- | --- | --- |
| `GET` | `/health` | Liveness check |
| `GET` | `/activities` | Activity catalog |
| `GET` | `/zones` | Reference zones (names only) |
| `GET` | `/plans?zone=<id>[&activity=<id>]` | Upcoming plans near a zone. Available plans come first, then nearest, then soonest. |
| `GET` | `/plans/{id}` | Plan details |
| `POST` | `/plans` | Create a plan. Requires `X-User-Id`. |

Dates are ISO 8601 in UTC. The full request and response contract, including error format and status codes, is documented in [CHANGELOG.md](CHANGELOG.md).

## Testing

```bash
# Backend
cd backend
gofmt -l .
go test ./...

# Frontend
cd frontend
dart format lib test
flutter analyze
flutter test
```

On Windows, Smart App Control may block Go test binaries built in `%TEMP%`. Setting `GOTMPDIR` to another directory works around it.

## Development principles

- Keep the application modular without premature abstraction.
- Separate UI, state, and data access where useful.
- Introduce dependencies only when they solve a concrete problem.
- Build and validate features incrementally, with tests proportional to risk.
- Treat location permissions and user privacy as core requirements.

## Roadmap

1. Join a plan, respecting participant limits.
2. Persistent storage (PostgreSQL/PostGIS).
3. Authentication to replace the development identity.
4. Device location, only if it adds clear value over zones.

## License

No license has been specified yet.
