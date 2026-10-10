# Distance

**Turn intentions into shared experiences.**

Distance is a mobile-first application designed to help people discover, create, and join nearby plans around shared activities. Instead of browsing people nearby, users discover **plans**: things they can actually do together.

> **Project status:** Early development. The MVP flow works end to end: choose an activity, discover nearby plans, create a plan, and join one. Authentication is not implemented yet.

## MVP

| Feature | Status |
| --- | --- |
| Choose an activity from a predefined catalog | Implemented |
| Discover upcoming plans near a reference zone, filtered by activity | Implemented |
| View plan details: activity, meeting point, date and time, participants | Implemented |
| Create a plan when there isn't a suitable one | Implemented |
| Join plans created by other users, respecting participant limits | Implemented |
| Join plans while they are ongoing | Implemented |
| Customizable character for each user | Implemented (basic skin) |
| 3D map of the real city with the characters of the people taking part in each plan, in the zone each one chose | Implemented |

## Repository structure

```text
distance/
├── backend/      Go HTTP API (net/http)
├── frontend/     Flutter mobile app
├── compose.yaml  Local PostgreSQL for development
├── CLAUDE.md     Shared project rules
└── CHANGELOG.md
```

Both modules live in this single repository. Run each module's commands from its own directory.

## Tech stack

- **Flutter / Dart:** mobile client. Android is the initial development target.
- **Go:** REST API built on `net/http`.
- **PostgreSQL:** persistent storage, accessed with `pgx`. Schema migrations are plain SQL files embedded in the binary and applied on startup.
- **App packages:** `http` for API requests, `flutter_localizations` + `intl` for translations and locale formats, and `shared_preferences` to remember theme and language.

Without a database configured, the backend falls back to **in-memory** storage, and data is lost when the server restarts. PostGIS will be added when plans need real coordinates.

## Theme and language

The app has light and dark themes and is available in Spanish and English. Both follow the device by default and can be changed in **Settings** (gear icon on the home screen). The choice is saved on the device.

- App texts live in `frontend/lib/l10n/app_es.arb` (template) and `app_en.arb`. Classes are generated on build; run `flutter gen-l10n` to regenerate them manually.
- The app sends its language in `Accept-Language`, and the API answers activity names and error messages in that language. Spanish is the default. Plan titles and descriptions are written by users and are not translated.

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
- Docker, to run PostgreSQL locally. Optional: without it the API uses in-memory storage.
- Flutter SDK available on `PATH`.
- Android SDK and an Android emulator or physical device.
- VS Code with the Go, Flutter, and Dart extensions (recommended).

### Run the backend

Start PostgreSQL and point the API at it:

```bash
docker compose up -d
cd backend
DATABASE_URL="postgres://distance:distance@localhost:5432/distance?sslmode=disable" go run .
```

In PowerShell, set the variable first with `$env:DATABASE_URL = "..."`. Pending migrations are applied on startup.

Without `DATABASE_URL`, `go run .` uses in-memory storage.

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

The plans map shows the real shape of Bogotá (districts, avenues, parks, rivers and landmarks) in the app's pastel style. The city is built offline from OpenStreetMap data (© OpenStreetMap contributors, ODbL) into `assets/map/bogota.bin`; the app needs no map service or API key. To rebuild it, for example after changing zones in `backend/internal/plans/catalog.go`:

```bash
cd frontend
dart run tool/build_city_map.dart            # uses the cached download
dart run tool/build_city_map.dart --refresh  # downloads fresh data
```

The plans map and the character preview render in 3D with [flutter_scene](https://pub.dev/packages/flutter_scene), which draws through Flutter GPU. Flutter GPU is already enabled for Android (`AndroidManifest.xml`) and iOS (`Info.plist`), so `flutter run` needs no extra flags. The first build takes longer while flutter_scene compiles its shaders. On devices that cannot render 3D, both screens show a flat 2D version instead.

### Development identity

There is no authentication yet. The app sends a development user id in the `X-User-Id` header with plan requests; it defaults to `demo-user`. The API uses it to record who creates or joins a plan and to tell the app whether the user already participates. To try joining as a different user, run:

```bash
flutter run --dart-define=DEV_USER_ID=another-user
```

**This header is not a security mechanism.**

## API overview

| Method | Path | Description |
| --- | --- | --- |
| `GET` | `/health` | Liveness check |
| `GET` | `/activities` | Activity catalog, named in the `Accept-Language` language |
| `GET` | `/zones` | Reference zones (names only) |
| `GET` | `/plans?zone=<id>[&activity=<id>]` | Upcoming and ongoing plans near a zone. Available plans come first, then nearest, then soonest. |
| `GET` | `/plans/{id}` | Plan details |
| `POST` | `/plans` | Create a plan. Requires `X-User-Id`. |
| `POST` | `/plans/{id}/participants` | Join a plan until it ends, choosing the zone shown to others. Requires `X-User-Id`. |
| `GET` | `/avatar-options` | Values each avatar field accepts |
| `GET` / `PUT` | `/me/avatar` | Read or save your character. Requires `X-User-Id`. |
| `GET` | `/map[?activity=<id>]` | Zone layout plus upcoming and ongoing plans with their participants' avatars and chosen zones |

Every endpoint accepts `Accept-Language` (`es` or `en`; Spanish by default) for activity names and error messages. Dates are ISO 8601 in UTC. The full request and response contract, including error format and status codes, is documented in [CHANGELOG.md](CHANGELOG.md).

## Testing

```bash
# Backend
cd backend
gofmt -l .
go test ./...

# Backend integration tests against PostgreSQL (wipes plan data)
DISTANCE_TEST_DATABASE_URL="postgres://.../distance_test?sslmode=disable" go test ./...

# Frontend
cd frontend
dart format lib test
flutter analyze
flutter test
```

PostgreSQL store tests are skipped unless `DISTANCE_TEST_DATABASE_URL` is set. They verify that concurrent joins never exceed a plan's limit. Point the variable at a disposable database, because the tests delete all plans.

On Windows, Smart App Control may block Go test binaries built in `%TEMP%`. Setting `GOTMPDIR` to another directory works around it.

## Development principles

- Keep the application modular without premature abstraction.
- Separate UI, state, and data access where useful.
- Introduce dependencies only when they solve a concrete problem.
- Build and validate features incrementally, with tests proportional to risk.
- Treat location permissions and user privacy as core requirements.

## Roadmap

1. Authentication to replace the development identity, then plan cancellation and leaving a plan.
2. Device location and PostGIS, only if they add clear value over zones.

## License

No license has been specified yet.
