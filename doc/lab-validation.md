# Flutter laboratory validation and action log

## Visual editor and dark theme revision · November 17, 2026

Added a visual draft editor without changing the pure Dart API. The home scenarios
can be edited in place and opened in the workbench for exact configuration export.
The multi-output climate surface opens an independent editable workbench copy.
Workbench edits become a standalone model, retaining its settings and metadata.

Validation for this revision:

- 450 core tests, 4 tool tests and 29 Flutter tests passed; Dart/Flutter analysis
  found no issues. The Web release build passed with the existing Pages base path
  and bundled web resources. The toolchain remains Flutter 3.50.0 / Dart 3.14.0.
- New tests cover isolated drafts, all eleven membership defaults, automatic term
  reference updates, nested conditions/hedges, invalid references/numbers, apply,
  cancellation, adding/deleting a composed rule, edited range switching/export,
  dark/light theme switching, 150% text at 390 × 844 and a 390 × 640 viewport with
  280 pixels reserved for the virtual keyboard.
- The pre-implementation draft test failed because VisualDraft did not yet exist.
  The keyboard regression test then exposed a 26-pixel overflow; moving the status
  header into each scrolling form fixed the cause. The older workbench test was
  adjusted to reveal the JSON button after the extra editor button changed wrapping.
- Actual Chrome checks: dark default, light toggle retaining applied values,
  triangle low.c 25 → 30 producing midpoint 49.35, invalid c = −1 disabling Apply,
  AND construction with two operand editors, application to the scenario and
  cancellation back to the previous configuration. Weight 0.5 after the endpoint
  edit produced preview 49.83. The editor was also inspected at 390 × 844.
- Fresh real captures: [curves](screenshots/visual-membership-dark.jpg),
  [rules](screenshots/visual-rules-dark.jpg),
  [mobile editor](screenshots/visual-editor-mobile.jpg). Comparison/import captures
  were refreshed for the dark theme. These are running app screenshots, not mockups.

Action log: inspected the clean checkout/instructions; wrote failing draft tests;
kept all inference in the existing codec/engines; built isolated forms and recursive
condition controls; restricted Tsukamoto output shapes to the core inverse contract;
added dark/light themes and accessible contextual parameter labels; fixed the
keyboard layout and edited scenario midpoint; connected exact scenario export;
ran the required checks; inspected the real UI; updated both READMEs and the guide,
retaining exactly five final exercises. No shared SDK, third-party project, core
public API, package version or release tag was changed.

The same gated Pages workflow validates the revision before publication. Its
[CI executions](https://github.com/kleberandrade/fuzzy-engine/actions/workflows/ci.yml)
and [deployment executions](https://github.com/kleberandrade/fuzzy-engine/actions/workflows/pages.yml)
provide the commit-specific remote record. Earlier release evidence follows.

## Original laboratory delivery

Date: November 17, 2026. Checkout: `kleberandrade/fuzzy-engine`, branch `main`.
This record distinguishes local checks from the deployment result recorded below.

## Implemented scope

Preserved the three original home scenarios and the multi-output climate/FIS
surface. Added a separate comparison/configuration page backed by the existing
pure Dart engines and codec. No core public API, release version, release tag or
pub.dev publication was changed. No shared Flutter SDK or steering-engine files
were edited. The existing MIT license and authorship were preserved.

## Local evidence

- Pure Dart tests: 450 passed; tool tests: 4 passed; Dart analysis: no issues.
- Flutter tests: 17 passed, including the existing surface/scenario tests, codec
  round-trips for all three families, no-decision semantics, method selection,
  invalid/valid import, cancel, restore, reset and overflow recovery.
- Flutter analysis: no issues. Dart formatting and `git diff --check` passed.
- Flutter Web release build: passed with `/fuzzy-engine/` base href and
  `--no-web-resources-cdn`. Wasm compatibility dry run passed; a standalone Wasm
  deployment was not tested.
- Independent FIS comparison: 234 scikit-fuzzy/NumPy cases passed; maximum crisp
  difference 0.0000166666664. The Python 3.9 attempt could not load the existing
  Python 3.13 native packages; rerunning with Python 3.13 passed.
- jFuzzyLogic FCL comparison: 72 cases passed; maximum mapped crisp difference
  9.77 × 10⁻¹⁴. Eight default sampling differences are explicitly mapped by the
  existing comparator (maximum raw difference 11.0).
- Chrome: inspected actual Web build at desktop size and 390 × 844. Tested
  language switch, keyboard slider adjustment (50 → 40), JSON rejection and
  cancellation, midpoint reset (40 → 50), stacked cards and scrolling to rules.
  The preserved climate surface was inspected at phone width, including keyboard
  input (20 → 24 °C) and switching to the heating surface.
  Real captures are in [screenshots](screenshots/).
- Accessibility: numeric memberships supplement colors, output and activation
  values are textual, sliders/buttons expose semantics; widget test uses 150%
  text scale on a 390 × 844 viewport. No full assistive-technology audit claimed.

## Toolchain and dependency limits

Validation used a private temporary copy of Flutter 3.50.0, framework commit
`ab2912035e160d9cad6306df307576da6128ebdb`, Dart 3.14.0. The official Flutter Git
repository's `3.50.0` tag was checked and matched this commit. CI's Flutter jobs
are pinned to 3.50.0. The pure Dart CI retains its 3.3.4/stable matrix.

Resolved current compatible root development dependencies: test 1.33.0 and lints
6.1.0; `dart pub outdated` reported none outdated after upgrade. The Flutter SDK
pins material_color_utilities 0.13.0 and test_api 0.7.14; newer catalog versions
were incompatible with those SDK constraints and were not forced by overrides.
As an existing package convention, dependency lockfiles remain untracked.

The named crapper, dryer and mutator executables were not available in this
session; no result from those tools is claimed. Behavioral tests, analysis,
manual source review and visual inspection were used. Initial test attempts
were blocked by dependency access/local socket permissions, so they do not
constitute a valid pre-implementation failing-test run. An incorrect expected
Tsukamoto output (37.5 instead of 25) was corrected from the ramp inverses.

## Action log and reasons

1. Read root/project instructions, modernization standard and requested ub-mode;
   checked status/remotes. The checkout was clean but one README-only commit
   behind; fast-forwarded it to preserve the existing badge improvements.
2. Read existing Dart/Flutter sources and tests; read steering-engine as a
   reference only. Kept the working scenarios and cached surface intact.
3. Copied the installed newer Flutter SDK to a task-specific temporary directory
   to avoid changing SDK state used by other work. Resolved compatible dependencies.
4. Added behavior tests and a small pure Dart view adapter; all inference and JSON
   validation continue to call the package's production engines/codec.
5. Added comparison, defuzzification, rules, output curves and transactional JSON
   editing. Bounded browser imports and added recoverable numerical error handling.
6. Reused the existing membership painter in its own UI file, removing a circular
   import. Added numeric input degrees and a visible workbench entry point.
7. Ran core/tool/Flutter checks and independent interoperability comparisons;
   corrected test expectations and ensured reset assertions inspect actual values.
8. Inspected the Web build in Chrome; recorded original screenshots and narrow
   screen behavior. Documented scenarios, exact semantics, limits and five exercises.
9. Prepared GitHub Pages artifact/deployment in the existing CI, with correct
   base path and all CI jobs required before deployment. Pages was initially disabled.
10. Reviewed changes and sent semantic commits to main. The final extraction of
    the painter left an unused home-page import; Flutter analysis detected it and
    commit `e721253` removed it. Repeated analysis, 17 tests and Web build passed.
11. Enabled GitHub Actions as the Pages source. Updated About to name all three
    families, selected the GitHub-provided Pages URL, and verified eight relevant topics.
12. Observed successful full CI and Pages deployment, opened the public app and
    reproduced demand 40 outputs (44.95 / 44.00 / 40.00). Saved its real screenshot,
    then added the verified online links to the English/Portuguese READMEs.

No related Medium URL or editable lesson was supplied or linked by this project;
no Medium page was modified or claimed published. The concrete teaching revision
is [the scenario guide](lab-guide.md), ending in exactly five practical exercises.

## Remote verification

- Implemented source: `a9f2041`; workflow/guide: `da3bdc8`; final import cleanup:
  `e72125344ecb2d2362cbfd2d0e46c045483550ef`.
- The initial CI for `da3bdc8` failed its Flutter analysis because of the unused
  import. Its Pages run was correctly skipped: no failed artifact was published.
- [Full CI #19](https://github.com/kleberandrade/fuzzy-engine/actions/runs/44169463100)
  passed all six jobs for `e721253`, including Dart 3.3.4/stable, Flutter 3.50.0,
  FIS/FCL runtime comparisons and the package quality check.
- [Pages deploy #2](https://github.com/kleberandrade/fuzzy-engine/actions/runs/44169828935)
  downloaded that successful run's artifact and completed successfully.
- Public application verified in Chrome:
  [Fuzzy Lab](https://kleberandrade.github.io/fuzzy-engine/). The language switch,
  workbench navigation and keyboard slider were exercised on the public build.
  Demand 40 yielded Mamdani 44.95, Sugeno 44.00 and Tsukamoto 40.00.
- About was verified with eight topics: dart, dart-package, flutter,
  fuzzy-inference, fuzzy-logic, mamdani, sugeno, tsukamoto. The existing Dart/MIT
  badge claims match the manifest/license; the CI badge links to the verified workflow.
- [Pages source evidence](screenshots/pages-source.jpg),
  [About evidence](screenshots/github-about.jpg),
  [public UI capture](screenshots/inference-desktop.jpg).
- The follow-up documentation commit adds the now-verified links and evidence;
  it does not alter the tested Dart/Flutter implementation.
