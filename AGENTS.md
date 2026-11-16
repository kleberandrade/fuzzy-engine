# fuzzy_engine contributor instructions

- Use semantic commits (feat:, fix:, docs:, chore:, etc.).
- Keep API changes documented in English and Portuguese, with meaningful tests.
- Every user-facing fix or feature must add a bullet under `## Unreleased` in
  CHANGELOG.md. Never edit the notes for an already published version.
- Before each release, bump pubspec.yaml and move Unreleased notes together using
  `dart run tool/bump_version.dart patch|minor|major`.
- Use patch for compatible fixes, minor for compatible features. During 0.x,
  document breaking changes and increment minor; after 1.0, breaking changes
  increment major. Discuss the 1.0 stability commitment before selecting major.
- Bump once per release, not once per commit. Do not republish an existing version.
- Run core tests, tool/test, analysis and the relevant Flutter/external checks.
- Commit reviewed release files, then use tag v<pubspec version> to trigger publish.
  The tag workflow must pass the full CI before publishing with temporary OIDC.
- Do not create a release tag merely to test automation or store Pub tokens in Git.
