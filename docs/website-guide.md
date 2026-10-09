# Building the Dartlane website (Astro + Starlight)

Goal: one project in `website/` with a custom landing page at `/` and the docs at `/docs/`, deployed to Firebase Hosting.

Prerequisites: Node 20 or later (`node -v`) and npm.

---

## 1. Scaffold the project

From the repo root:

```sh
npm create astro@latest website -- --template starlight --no-git --install
cd website
npm run dev
```

Open `http://localhost:4321` to check that the starter docs site loads. The repo root has no `package.json`, so `website/` stays separate from the melos and pub workspace.

Add to the root `.gitignore`:

```
website/node_modules/
website/dist/
website/.astro/
```

## 2. Configure the site

Edit `website/astro.config.mjs`:

```js
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  site: 'https://dartlane.aioncw.com',
  integrations: [
    starlight({
      title: 'Dartlane',
      logo: { src: './src/assets/logo.png' },
      social: [
        { icon: 'github', label: 'GitHub', href: 'https://github.com/AbhijithKonnayil/dartlane' },
      ],
      customCss: ['./src/styles/theme.css'],
      sidebar: [
        { label: 'Start here', items: ['docs/quick-start'] },
        { label: 'Guides', items: ['docs/writing-lanes-and-actions', 'docs/ci', 'docs/releasing'] },
      ],
    }),
  ],
});
```

Notes:
- The site is served from the root of `dartlane.aioncw.com`, so no `base` is needed and links like `/docs/quick-start/` work as written.
- The sidebar entries are slugs of files under `src/content/docs/`.
- Check the exact config keys against the Starlight docs for the installed version (`social` changed shape between versions).

## 3. Add the brand theme

Copy the logo: `cp ../assets/dartlane.png src/assets/logo.png`. Make a transparent-background version for the dark theme.

Create `website/src/styles/theme.css`:

```css
:root {
  --dl-cyan: #00c6cf;
  --dl-blue: #0060c0;
  --dl-navy: #062b6b;
  --dl-orange: #ff5c00;
  --dl-bg: #060d1f;
  --dl-surface: #0d1a38;
  --dl-text: #f5f8ff;
  --dl-muted: #9fb0cc;
}

/* Starlight dark theme */
:root[data-theme='dark'] {
  --sl-color-accent-low: var(--dl-navy);
  --sl-color-accent: var(--dl-blue);
  --sl-color-accent-high: var(--dl-cyan);
  --sl-color-bg: var(--dl-bg);
  --sl-color-bg-nav: var(--dl-bg);
  --sl-color-bg-sidebar: var(--dl-bg);
  --sl-color-bg-inline-code: var(--dl-surface);
  --sl-color-white: var(--dl-text);
  --sl-color-gray-2: var(--dl-muted);
  --sl-font: 'Inter', system-ui, sans-serif;
  --sl-font-mono: 'JetBrains Mono', ui-monospace, monospace;
}

/* Starlight light theme */
:root[data-theme='light'] {
  --sl-color-accent-low: #d6f6f8;
  --sl-color-accent: var(--dl-blue);
  --sl-color-accent-high: var(--dl-navy);
}
```

Self-host the fonts with `npm i @fontsource-variable/inter @fontsource/jetbrains-mono` and import them in `theme.css`. This is better than loading from the Google Fonts CDN.

## 4. Move the docs in

Public guides move into the content folder under a `docs/` subfolder, so they are served at `/docs/...`:

```
website/src/content/docs/docs/
  quick-start.md
  writing-lanes-and-actions.md
  ci.md
  releasing.md
  examples/...
```

Each file needs frontmatter:

```md
---
title: Quick start
description: Install Dartlane and run your first lane.
---
```

Then:
- Delete the page's leading `# Title` heading, because Starlight renders the title.
- Fix links between pages to absolute paths such as `/docs/ci/`.
- Leave `PRD.md` and `github-plan.md` out of the site.
- In the repo's `docs/` folder, keep only internal docs, so there's one source of truth.

## 5. Build the landing page

Starlight owns `/` by default. Put your own page at `src/pages/index.astro`, which takes priority over the docs index. If a `src/content/docs/index.mdx` exists, delete it.

Structure the page from the Stitch design as components:

```
website/src/
  pages/index.astro
  components/landing/
    Navbar.astro
    Hero.astro
    InstallStrip.astro
    Features.astro
    CodeShowcase.astro
    HowItWorks.astro
    CiSection.astro
    FinalCta.astro
    Footer.astro
  layouts/Landing.astro
  styles/landing.css
```

`index.astro`:

```astro
---
import Landing from '../layouts/Landing.astro';
import Hero from '../components/landing/Hero.astro';
import Features from '../components/landing/Features.astro';
// ...the rest
---
<Landing title="Dartlane - release automation for Flutter and Dart">
  <Hero />
  <Features />
</Landing>
```

`layouts/Landing.astro` is a plain HTML shell. It imports `theme.css` and `landing.css`, sets the `<title>`, description and Open Graph tags, and renders `<slot />`. Include `<html lang="en" data-theme="dark">`.

Porting the Stitch export:
1. Open the exported HTML in `website/design/` next to the editor.
2. Copy one section at a time into its component.
3. Replace inline styles and hard-coded hex values with the CSS variables from `theme.css`.
4. Replace absolute-positioned layouts with flexbox or grid, and add responsive breakpoints.
5. Link the buttons: "Get started" goes to `/docs/quick-start/`, and "GitHub" goes to the repo.
6. Add alt text to images and use real `<button>` and `<a>` elements.

For the code and terminal blocks, either use Astro's built-in `<Code lang="dart" code={...} />` component or the `expressive-code` that Starlight ships.

## 6. Add SEO and polish

- A favicon at `public/favicon.svg`, generated from the dart in the logo.
- An Open Graph image at `public/og.png` (1200x630), and the `og:` and `twitter:` meta tags in the layout.
- `@astrojs/sitemap`: `npx astro add sitemap` (needs `site` set).
- Starlight's search is built in (Pagefind) and works after `npm run build`.
- Run Lighthouse on the built site, and aim for 95 or higher in each category.

## 7. Deploy to Firebase Hosting

`website/firebase.json` serves `dist/`, and `.github/workflows/website.yaml` builds the site and deploys it. A push to `dev` (and the weekly schedule) deploys to the live site. Pull requests from this repo get a preview URL, posted as a comment.

One-time setup:

1. Link the repo: from `website/`, run `firebase use <project-id>` (or add the project in the Firebase console and enable Hosting).
2. Create a service account with the *Firebase Hosting Admin* role, or run `firebase init hosting:github` to create it for you. Save its JSON key as the repository secret `FIREBASE_SERVICE_ACCOUNT`.
3. Add the repository variable `FIREBASE_PROJECT_ID` (Settings > Secrets and variables > Actions > Variables).
4. Add the custom domain in the Firebase console (Hosting > Add custom domain > `dartlane.aioncw.com`) and create the DNS records it shows (usually a TXT record for verification, then an A record or a CNAME).

Use `https://` everywhere (canonical URL, Open Graph tags, README links). Firebase provisions the certificate once DNS verifies.

## 8. Final checklist

- [ ] `npm run build` passes with no broken links
- [ ] Landing page matches the Stitch design on desktop and mobile
- [ ] Docs sidebar, search and dark and light themes all work
- [ ] All CTAs and nav links resolve
- [ ] The logo, favicon and OG image are in place
- [ ] The README links to the live site
- [ ] The deploy workflow has run once successfully
- [ ] DNS resolves and HTTPS works on `dartlane.aioncw.com`

## Suggested order of work

1. Scaffold, config and theme (steps 1 to 3). One session.
2. Move the docs and fix the sidebar (step 4).
3. Deploy early (step 7), with the default landing page, to confirm the pipeline works.
4. Build the landing page from the Stitch design, one component at a time (step 5).
5. SEO and polish (step 6), then the checklist.
