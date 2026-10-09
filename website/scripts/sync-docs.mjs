// Copies the public guides from ../docs into the Starlight content folder,
// adding frontmatter and rewriting links, so docs/ stays the single source.
import { mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const src = join(root, '..', 'docs');
const out = join(root, 'src', 'content', 'docs', 'docs');
const repo = 'https://github.com/AbhijithKonnayil/dartlane/blob/dev';

const pages = [
  ['quick-start', 'Quick start'],
  ['writing-lanes-and-actions', 'Writing lanes and actions'],
  ['ci', 'Running lanes on CI'],
  ['releasing', 'Releasing'],
];

rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });

for (const [slug, title] of pages) {
  let body = readFileSync(join(src, `${slug}.md`), 'utf8');
  // Drop the leading H1 and use its text as the description source.
  body = body.replace(/^# .*\n+/, '');
  const description = (body.split('\n\n')[0] ?? '').replace(/\s+/g, ' ').replace(/[*_`[\]]/g, '').replace(/\(.*?\)/g, '').slice(0, 160).trim();
  // Page links -> site routes; example files -> GitHub.
  body = body.replace(/\]\((?:\.\/)?examples\/([^)]+)\)/g, `](${repo}/docs/examples/$1)`);
  body = body.replace(/\]\((?:\.\/)?([a-z-]+)\.md(#[^)]*)?\)/g, '](/docs/$1/$2)');
  const fm = `---\ntitle: ${JSON.stringify(title)}\ndescription: ${JSON.stringify(description)}\n---\n\n`;
  writeFileSync(join(out, `${slug}.md`), fm + body);
}
console.log(`Synced ${pages.length} docs pages.`);
