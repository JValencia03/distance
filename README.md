# Distance — Frontend

**Turn intentions into shared experiences.**

Distance is a mobile-first application designed to help people discover, create, and join nearby plans around shared activities. Instead of browsing people nearby, users discover **plans**: things they can actually do together.

> **Project status:** Early development. The features described below represent the planned MVP, not necessarily implemented functionality.

## Planned MVP

- Choose an activity of interest.
- Discover nearby plans related to that activity.
- View plan details, including location and time.
- Create a plan when there isn't a suitable one.
- Join plans created by other users.

## Tech stack

- **Flutter** — cross-platform UI framework.
- **Dart** — application language.
- **Android** — initial development target.
- **Go REST API** — separate backend service.

The frontend is developed on **Windows**, using VS Code, Flutter, and the Android SDK. The backend is maintained in a separate repository and developed in WSL2.

## Responsibilities

The mobile client is responsible for the user interface, navigation, application state, API integration, and device location permissions. Business rules and persistent data are handled by the backend.

Location features will be designed with privacy in mind, including appropriate permissions and avoiding unnecessary exposure of precise user locations.

## Getting started

### Prerequisites

- Flutter SDK installed and available on `PATH`.
- Android SDK and an Android emulator or physical Android device.
- VS Code with Flutter and Dart extensions (recommended).

### Run locally

```bash
flutter doctor
flutter pub get
flutter run
```

These commands assume the Flutter project has been initialized and you're running them from its root directory. API configuration may be required once backend integration is implemented.

## Development principles

- Keep the application modular without premature abstraction.
- Separate UI, state, and data access where useful.
- Introduce dependencies only when they solve a concrete problem.
- Build and validate features incrementally.
- Treat location permissions and user privacy as core requirements.

## Related repository

**Backend:** `distance-backend` — Go API and persistence layer. Add the GitHub repository link once confirmed.

## Roadmap

The initial focus is establishing the Flutter foundation and connecting it to the Go API. Activity selection, nearby plan discovery, plan creation, and participation will follow incrementally.

## License

No license has been specified yet. See the repository for any future licensing terms.
