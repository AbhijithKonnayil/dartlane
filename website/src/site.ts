import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const repo = "AbhijithKonnayil/dartlane";

/** Facts shown on the landing page. Version and stars are read at build time. */
export const site = {
  repoUrl: `https://github.com/${repo}`,
  license: "BSD-3-Clause",
  installCommand: "dart pub global activate dartlane",
};

/** Hide the star count until it is big enough to be worth showing. */
const minStarsToShow = 10;

/** The version in packages/dartlane/pubspec.yaml, or null if unreadable. */
export function readVersion(): string | null {
  try {
    const pubspec = readFileSync(
      resolve(process.cwd(), "../packages/dartlane/pubspec.yaml"),
      "utf8",
    );
    return pubspec.match(/^version:\s*(\S+)/m)?.[1] ?? null;
  } catch {
    return null;
  }
}

/** A short star count such as "842" or "2.4k", or null to hide it. */
export async function readStars(): Promise<string | null> {
  try {
    const token = process.env.GITHUB_TOKEN;
    const res = await fetch(`https://api.github.com/repos/${repo}`, {
      headers: {
        accept: "application/vnd.github+json",
        ...(token ? { authorization: `Bearer ${token}` } : {}),
      },
      signal: AbortSignal.timeout(5000),
    });
    if (!res.ok) return null;
    const count = ((await res.json()) as { stargazers_count?: number })
      .stargazers_count;
    if (typeof count !== "number" || count < minStarsToShow) return null;
    return count >= 1000
      ? `${(count / 1000).toFixed(1).replace(/\.0$/, "")}k`
      : String(count);
  } catch {
    return null;
  }
}
