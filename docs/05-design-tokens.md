# Design tokens

One source of truth, five outputs. The Flutter app, the marketing site, a future
iOS widget and the Android native theme all draw the same orange.

## The pipeline

```
design/tokens/*.json                    ← you edit these
        │
        ▼  dart run tools/token_builder/bin/build_tokens.dart
        │
        ├── app/lib/design_system/tokens/design_tokens.g.dart   (Flutter)
        ├── design/build/tokens.css                             (web, docs, Figma)
        ├── design/build/Tokens.swift                           (iOS widgets, App Clip)
        ├── design/build/colors.xml                             (Android theme/splash)
        ├── design/build/dimens.xml                             (Android theme/splash)
        └── design/build/tokens.flat.json                       (anything else)
```

The generated files are committed: a fresh clone builds without running a
generator, and a token change shows up as a reviewable diff in every platform at
once.

## The format

W3C Design Tokens (DTCG draft): a node with `$value` is a token, anything else
is a group, `$type` is inherited, and `{a.b.c}` is an alias.

```jsonc
// design/tokens/semantic.dark.json
"accent": {
  "default": { "$value": "{palette.ember.500}" },
  "subtle":  { "$value": "#F56B2629", "$description": "16% ember — selected chips" }
}
```

## Two layers, and why it matters

| Layer | File | Example | May be used by |
| --- | --- | --- | --- |
| **Primitive** | `palette.json` | `palette.ember.500` = `#F56B26` | Semantic tokens only |
| **Semantic** | `semantic.dark.json` | `color.accent.default` | Everything |

Primitives answer "what colours exist". Semantics answer "what does this colour
mean". Reaching past a semantic token into the palette is how design systems
rot: `palette.ember.500` cannot be re-themed, `color.accent.default` can.

Geometry (`dimension.json`), type (`typography.json`) and motion
(`motion.json`) follow the same discipline — the mock-up's ad-hoc 6/10/13/18 px
values were snapped onto a 4 pt scale on the way in.

## Generated names

| Token path | Dart | CSS |
| --- | --- | --- |
| `color.background.canvas` | `NpColors.backgroundCanvas` | `--np-color-background-canvas` |
| `space.lg` | `NpSpace.lg` | `--np-space-lg` |
| `font.size.body` | `NpFontSize.body` | `--np-font-size-body` |
| `duration.base` | `NpDuration.base` | `--np-duration-base` |
| `easing.standard` | `NpEasing.standard` | `--np-easing-standard` |

## Changing a token

```bash
$EDITOR design/tokens/semantic.dark.json
dart run tools/token_builder/bin/build_tokens.dart
cd app && flutter analyze && flutter test
git add design app/lib/design_system/tokens
```

Commit the JSON and the generated files together. CI runs the generator with
`--check`, which fails the build if they have drifted:

```bash
dart run tools/token_builder/bin/build_tokens.dart --check
```

## Adding a second theme

The structure is already there: add `design/tokens/semantic.light.json` with the
same keys, teach the generator to emit one class per theme, and turn the static
`NpColors` references in the components into a `ThemeExtension` lookup. That is
a day of work, and it is deliberately not done yet — see
[adr/0002-design-tokens.md](adr/0002-design-tokens.md).
