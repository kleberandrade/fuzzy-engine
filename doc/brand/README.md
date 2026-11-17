# Fuzzy Engine identity

The original mark combines two overlapping membership peaks, their common area
and one crisp decision point. Teal and amber remain visible against the lab's
navy background. The compact circular-square mark is used by the mobile navbar
and as the SVG favicon; the wordmark variant includes the project name.

- `fuzzy-mark.svg`: standalone compact mark; matches `example/web/favicon.svg`.
- `fuzzy-wordmark.svg`: horizontal brand variant.
- `language-br.svg`, `language-uk.svg`: original vector renditions of the Brazilian
  and United Kingdom national-flag motifs, clipped to circles. The equivalent
  local Flutter painters power the 48 × 48 language buttons. The selected language
  has an outline and an accessibility selected state; both buttons have native
  language-name tooltips and keyboard focus.

These assets and their Flutter painting code were drawn for this project and are
covered by the repository's MIT license. No third-party logo, flag image, emoji,
web font or remote image request is needed to render them. The flag motifs identify the two supported interface languages.

Maintain the compact mark, favicon and wordmark geometry together. Semantic labels
name Fuzzy Engine and the language even when the compact navbar hides text.
