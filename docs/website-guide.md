# Working on the website

The site at <https://dartlane.aioncw.com> is one Astro Starlight project in
`website/`: a custom landing page at `/` and the docs at `/docs/`. It is
separate from the pub workspace and Melos (the repo root has no `package.json`).

Needs Node 22 (what CI uses) and npm.

```sh
cd website
npm ci
npm run dev       # http://localhost:4321
npm run build     # output in website/dist
```

## Where things live

| What | Where |
|---|---|
| Landing page | `website/src/pages/index.astro`, layout `src/layouts/Landing.astro`, styles `src/styles/landing.css` |
| Brand colors and Starlight theme | `website/src/styles/theme.css` (the palette is sampled from `assets/dartlane.png`) |
| Site-wide strings and links | `website/src/site.ts` |
| Docs pages | `docs/*.md` at the repo root, the single source |
| Sidebar and Starlight config | `website/astro.config.mjs` |

## Docs are synced, not copied

`npm run dev` and `npm run build` first run `scripts/sync-docs.mjs`. It copies
the guides listed in its `pages` array (quick start, writing lanes and actions,
CI, releasing) from `docs/` into `website/src/content/docs/docs/`, adds the
frontmatter, drops the leading `# Title` and rewrites links between pages. The
synced folder is generated, so never edit it.

To add a guide: write `docs/<slug>.md`, add `['<slug>', 'Title']` to `pages`,
and add `docs/<slug>` to the sidebar in `astro.config.mjs`. Link to other
guides as `other-guide.md` and to example files as `examples/<file>`; the script
rewrites both. `PRD.md` and `github-plan.md` are internal and stay off the site.

## Deploying

`.github/workflows/website.yaml` builds the site and deploys it to Firebase
Hosting (`website/firebase.json` serves `dist/`). A push to `dev` that touches
`website/` or `docs/`, a manual run, and a weekly schedule deploy to the live
site. Pull requests get a preview URL.

One-time setup, already done for the live site:

1. A Firebase project with Hosting, linked in `website/.firebaserc`.
2. A service account with the *Firebase Hosting Admin* role, saved as the
   repository secret `FIREBASE_SERVICE_ACCOUNT`.
3. The custom domain `dartlane.aioncw.com` added in Hosting, with its DNS
   records.

Use `https://dartlane.aioncw.com` everywhere (canonical URL, README, package
`homepage`).
