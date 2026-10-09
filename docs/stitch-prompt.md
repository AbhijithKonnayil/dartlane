# Google Stitch prompt: Dartlane landing page

Paste the prompt below into Google Stitch. Logo: `assets/dartlane.png` (upload it as a reference image if Stitch allows).

## Brand palette (sampled from the logo)

| Role | Color | Hex (approx.) |
| --- | --- | --- |
| Primary (dart cyan) | Bright teal-cyan | `#00C6CF` |
| Secondary (dart blue) | Strong blue | `#0060C0` |
| Deep (dart navy) | Dark navy | `#062B6B` |
| Accent (speed trails) | Vivid orange | `#FF5C00` |
| Background (dark) | Near-black navy | `#060D1F` |
| Surface (dark) | Raised navy | `#0D1A38` |
| Text | White / slate | `#F5F8FF` / `#9FB0CC` |

Use cyan to blue as the gradient for headlines and highlights. Use orange sparingly, for the primary CTA and small accents only.

## Prompt

```
Design a responsive, dark-theme landing page for "Dartlane", an open-source
release automation tool for Flutter and Dart apps, written in Dart. It is a
CLI that lets developers define "lanes" (ordered release workflows) made of
reusable "actions" (build, test, version bump, publish, deploy to Firebase,
and so on). Think of it as a Dart-native alternative to Fastlane. The
audience is Flutter and Dart developers. The tone is modern, fast, precise
and developer-friendly.

BRAND
- Logo: a dart flying diagonally, with cyan, blue and navy fletching,
  followed by two orange speed streaks. It suggests speed, precision and
  hitting the target. Place the logo and the wordmark "Dartlane" in the
  navbar.
- Palette:
  - Background #060D1F, with surfaces and cards at #0D1A38
  - Primary cyan #00C6CF
  - Secondary blue #0060C0
  - Deep navy #062B6B
  - Accent orange #FF5C00, used only for the main CTA button and small
    highlights
  - Text: #F5F8FF headings, #9FB0CC body
- Gradient: cyan #00C6CF to blue #0060C0 for the hero headline highlight and
  key icons. Add a subtle glow behind the hero, and faint diagonal orange
  streak motifs echoing the logo.
- Typography: Inter or Plus Jakarta Sans for UI, and JetBrains Mono for
  code and the terminal.
- Style: clean, generous spacing, rounded corners (12px), thin 1px borders
  in rgba cyan at low opacity, and no stock photos.

PAGE SECTIONS
1. Navbar: logo + "Dartlane", links (Docs, Examples, Changelog), a GitHub
   star button, and an orange "Get started" button.
2. Hero: headline "Ship Flutter and Dart apps faster, with lanes written
   in Dart." Subheadline: "Release automation for Flutter and Dart. Define
   lanes, compose actions, run anywhere: locally or in CI." Two buttons:
   orange "Get started" and outlined "View on GitHub". Beside or below
   them, a terminal window mockup showing
   `dart pub global activate dartlane` followed by
   `dartlane run beta`, with colored step output (build, test, upload)
   ending in a green success line.
3. Install strip: a copyable one-line install command in a code block, plus
   badges for pub.dev version, license and CI status.
4. Features: a 3 to 4 card grid. Each card has a gradient icon, a title and
   one line of copy:
   - Lanes: ordered release workflows in plain Dart
   - Actions: reusable steps for build, test, version and publish
   - Firebase and stores: deploy to Firebase App Distribution and more
   - CI-ready: the same lane runs locally and on GitHub Actions
5. Code showcase: a two-column section. The left column has a short
   explanation. The right column is a syntax-highlighted Dart snippet
   defining a lane, shown as an editor window with a tab.
6. How it works: three numbered steps (Install, Define a lane, Run it),
   connected by a thin line with an orange dot, like a speed streak.
7. CI section: a GitHub Actions YAML snippet showing the one-line lane
   run, with a small "Works with GitHub Actions" label.
8. Final CTA: a full-width band with a navy-to-blue gradient, the headline
   "Hit your release target every time.", and an orange "Read the docs"
   button.
9. Footer: logo, Docs / GitHub / pub.dev / License links, and "Made with
   Dart".

DESIGN NOTES
- Desktop first at 1440px, with a mobile layout that stacks the sections
  and collapses the nav into a hamburger menu.
- Keep text contrast at WCAG AA or better.
- Use subtle hover states: cyan glow on cards, brightened orange on the CTA.
- Keep it minimal and fast-feeling. No more than one orange element per
  viewport section.
```

## After generating

- Export the HTML/CSS or take screenshots and save them to `website/design/`.
- Check the exported colors against the table above, and replace any off-palette values with the tokens.
- Ask Stitch for variants if the hero feels busy: "simpler hero, terminal only" or "light theme version".
