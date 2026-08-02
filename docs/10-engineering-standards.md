# Engineering standards

## Branches and commits

- `main` is always releasable.
- Branch names: `feat/check-in-sheet`, `fix/fog-mask-on-pan`,
  `chore/bump-flutter`.
- Commit subjects say what changed in the product, in the imperative, under 60
  characters: *"Show the check-in sheet above the navigation bar"*. The body
  explains **why**, not what — the diff already says what.
- One logical change per commit. A commit that touches tokens, l10n and three
  screens should have been three commits.

## Before you push

```bash
cd app
dart format lib test
flutter analyze          # must be clean
flutter test             # must be green
```

`analysis_options.yaml` is stricter than `flutter_lints` on purpose: strict
casts, strict inference, `unawaited_futures`, `prefer_const_*`,
`require_trailing_commas`. CI treats infos as failures. If a lint is wrong for a
specific line, `// ignore:` it **with the reason on the line above** — an
unexplained ignore is a review comment.

## Code style

- Files: `snake_case.dart`. Design-system widgets: `Np` prefix. Private widgets
  in a screen file: `_LeadingUnderscore`.
- Doc comments say **why this exists and when to use it**. A comment that
  restates the code is noise; a comment that explains a decision (why the fog
  mask uses `dstOut`, why sheets use the root navigator) is the reason the next
  person does not undo your work.
- Widgets stay under ~150 lines. Past that, extract a private widget — not a
  `Widget _buildFoo()` method, which defeats const-ness and rebuild scoping.
- No `print`. No `TODO` without a line in [backlog.md](backlog.md).

## Review checklist

- [ ] Does it use design-system components, or did it invent a colour?
- [ ] Are all new strings in both ARB files, with descriptions?
- [ ] Does it work at 1.3× text scale on a 360 dp-wide screen?
- [ ] Is the state in the right place ([08](08-state-management.md))?
- [ ] Are the layering rules intact — does any feature import `data/fake/`?
- [ ] Is there a test that would fail if the change were reverted?

## Generated code

Committed, never hand-edited:

- `app/lib/design_system/tokens/design_tokens.g.dart`
- `app/lib/l10n/generated/**`

Regenerate, then commit source and output together.

## CI (to configure)

The pipeline the repo is written for — worth wiring up as soon as there is more
than one contributor:

```yaml
- flutter pub get
- dart run tools/token_builder/bin/build_tokens.dart --check   # tokens in sync
- dart format --set-exit-if-changed lib test
- flutter analyze --fatal-infos
- flutter test --coverage
- flutter build apk --debug        # and `flutter build ios --no-codesign`
```

## Versioning and release

`pubspec.yaml` holds `version: <marketing>+<build>`. The build number is bumped
by CI; never by hand on a feature branch. Android `applicationId` and the iOS
bundle identifier are both `site.lya3hc.noplace`.
