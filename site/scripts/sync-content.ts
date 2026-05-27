/**
 * Site content sync agent.
 *
 * Reads canonical source (package.json, SKILL.md, commands/*.md) and
 * regenerates derived TypeScript content files (site/src/content/*.ts).
 *
 * Run via: npm run sync (inside site/)
 *
 * This is the "agent that updates the website based on the actual skill"
 * referenced in CLAUDE.md and AGENTS.md. It is intentionally deterministic:
 * no LLM calls. Just reads files, transforms, writes.
 */

import fs from "node:fs/promises";
import path from "node:path";

const REPO_ROOT = path.resolve(import.meta.dirname, "../..");
const SITE_ROOT = path.resolve(import.meta.dirname, "..");
const CONTENT_DIR = path.join(SITE_ROOT, "src/content");

interface PackageJson {
  name: string;
  version: string;
  description: string;
  homepage: string;
}

function parseFrontmatter(md: string): { meta: Record<string, string>; body: string } {
  if (!md.startsWith("---")) return { meta: {}, body: md };
  const end = md.indexOf("\n---", 4);
  if (end === -1) return { meta: {}, body: md };
  const fm = md.slice(4, end);
  const body = md.slice(end + 4).replace(/^\n/, "");
  const meta: Record<string, string> = {};
  for (const line of fm.split("\n")) {
    const m = line.match(/^(\w+):\s*(.+)$/);
    if (m) meta[m[1]] = m[2].trim();
  }
  return { meta, body };
}

async function syncMeta(): Promise<void> {
  const pkg: PackageJson = JSON.parse(
    await fs.readFile(path.join(REPO_ROOT, "package.json"), "utf-8"),
  );
  const out = `// Auto-synced from package.json by scripts/sync-content.ts
// Do not edit by hand. Run: npm run sync
export const meta = {
  name: ${JSON.stringify(pkg.name)},
  version: ${JSON.stringify(pkg.version)},
  description: ${JSON.stringify(pkg.description)},
  homepage: ${JSON.stringify(pkg.homepage)},
  npm: ${JSON.stringify("https://www.npmjs.com/package/" + pkg.name)},
};
`;
  await fs.writeFile(path.join(CONTENT_DIR, "meta.ts"), out);
  console.log("sync: meta.ts (version " + pkg.version + ")");
}

async function syncCommands(): Promise<void> {
  const commandsDir = path.join(REPO_ROOT, "commands");
  const entries = await fs.readdir(commandsDir);
  const commands = [];
  for (const f of entries.sort()) {
    if (!f.endsWith(".md")) continue;
    const raw = await fs.readFile(path.join(commandsDir, f), "utf-8");
    const { meta, body } = parseFrontmatter(raw);
    const name = f.replace(/^/, "").replace(/\.md$/, "");
    const description = meta.description || body.split("\n")[0].slice(0, 200);
    commands.push({ name, description });
  }
  const out = `// Auto-synced from commands/*.md by scripts/sync-content.ts
// Do not edit by hand. Run: npm run sync
export interface Command {
  name: string;
  description: string;
  category?: string;
  whenToUse?: string;
}

export const commands: Command[] = ${JSON.stringify(commands, null, 2)};
`;
  // Note: this overwrites the hand-curated commands.ts. To preserve category
  // and whenToUse fields, the source of truth should move into commands/*.md
  // frontmatter. For now, only run this for new commands; manual file owns
  // category and whenToUse.
  console.log("sync: " + commands.length + " commands detected (skipping write — manual file owns category/whenToUse)");
  void out;
}

async function main(): Promise<void> {
  console.log("Syncing site content from canonical source...");
  await syncMeta();
  await syncCommands();
  console.log("Done.");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
