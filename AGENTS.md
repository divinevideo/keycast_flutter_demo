# Repository Guidelines

## Project Structure & Module Organization
- App code lives in `lib/`.
- Workspace packages live in `packages/`.
- Platform-specific Flutter targets live under `android/`, `ios/`, `linux/`, `macos/`, `web/`, and `windows/`.
- Tests live in `test/`, and supporting docs live in `docs/`.

## Build, Test, and Development Commands
- `flutter pub get`: install dependencies.
- `flutter analyze`: run static analysis.
- `flutter test`: run the test suite.
- `flutter run`: launch the demo locally.
- If you change auth flow behavior or package APIs, update the README and docs in the same change.

## Coding Style & Naming Conventions
- Use idiomatic Dart and Flutter patterns with focused widgets and clear auth-flow boundaries.
- Prefer small package-level changes over broad cross-platform churn unless the change truly spans all targets.
- Keep PRs tightly scoped. Do not mix unrelated cleanup, formatting churn, or speculative refactors into the same change.
- Temporary or transitional code must include `TODO(#issue):` with the tracking issue for removal.

## Pull Request Guardrails
- PR titles must use Conventional Commit format: `type(scope): summary` or `type: summary`.
- Set the correct PR title when opening the PR. Do not rely on fixing it afterward.
- If a PR title changes after opening, verify that the semantic PR title check reruns successfully.
- PR descriptions must include a short summary, motivation, linked issue, and manual test plan.
- Changes to OAuth, PKCE, BYOK, or deep-link flows should include representative screenshots or flow notes when helpful.

## Sensitive Information
- Do not commit secrets, live tokens, private keys, or sensitive user data.
- Public issues, PRs, branch names, screenshots, and descriptions must not mention corporate partners, customers, brands, campaign names, or other sensitive external identities unless a maintainer explicitly approves it. Use generic descriptors instead.
