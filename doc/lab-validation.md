# Flutter laboratory validation and action log

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
  round-trips for all three families, no-decision semantics, five-method selection,
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
10. Reviewed changes and recorded the resulting commit/deployment verification below.

No related Medium URL or editable lesson was supplied or linked by this project;
no Medium page was modified or claimed published. The concrete teaching revision
is [the scenario guide](lab-guide.md), ending in exactly five practical exercises.

## Remote verification

Pending verification after the reviewed commits are pushed. A Pages URL is not
reported as live until deployment and the running public application are observed.
