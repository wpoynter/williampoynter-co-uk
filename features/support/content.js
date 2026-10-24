// What the suite expects, derived from config.toml and content/ - the same
// files Hugo builds the site from - so a new publication, project or section
// is covered without editing a feature, and copy changes never break a step.
// Only structure is read here (paths, titles, the [params] switches); never
// page copy. The readers below understand the subset of TOML and front
// matter this repo uses (flat `key = value` / `key: value` lines), which
// keeps the suite free of parser dependencies.
import { readdirSync, readFileSync } from "node:fs";
import { join, relative, sep } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../../", import.meta.url));

function scalar(raw) {
  const v = raw.trim();
  if (/^".*"$/.test(v)) return JSON.parse(v);
  if (/^'.*'$/.test(v)) return v.slice(1, -1).replace(/''/g, "'");
  const bare = v.replace(/\s+#.*$/, "");
  if (bare === "true") return true;
  if (bare === "false") return false;
  return bare;
}

// config.toml: top-level keys plus the tables named in square brackets
// ([params] and friends). Arrays of tables ([[...]]) are not needed here.
function readConfig() {
  const config = {};
  let table = config;
  for (const line of readFileSync(join(root, "config.toml"), "utf8").split(/\r?\n/)) {
    const header = line.match(/^\s*\[([^[\]]+)\]\s*$/);
    if (header) {
      table = config;
      for (const part of header[1].trim().split(".")) table = table[part] ??= {};
      continue;
    }
    if (/^\s*\[\[/.test(line)) { table = {}; continue; }
    const kv = line.match(/^\s*([A-Za-z0-9_]+)\s*=\s*(.+)$/);
    if (kv) table[kv[1]] = scalar(kv[2]);
  }
  return config;
}

// Front matter between --- (YAML) or +++ (TOML) fences.
function frontMatter(file) {
  const lines = readFileSync(file, "utf8").split(/\r?\n/);
  const fence = lines[0].trim();
  const fields = {};
  if (fence !== "---" && fence !== "+++") return fields;
  for (const line of lines.slice(1)) {
    if (line.trim() === fence) break;
    const kv = line.match(/^([A-Za-z0-9_]+)\s*[:=]\s*(.+)$/);
    if (kv) fields[kv[1]] = scalar(kv[2]);
  }
  return fields;
}

function walk(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap(e =>
    e.isDirectory() ? walk(join(dir, e.name)) : e.name.endsWith(".md") ? [join(dir, e.name)] : []);
}

// Hugo's rules for a default build: drafts, future-dated and expired pages
// are not published (buildDrafts/buildFuture/buildExpired all false).
const now = Date.now();
function published(fm) {
  if (fm.draft === true) return false;
  const pub = fm.publishDate || fm.date;
  if (pub && Date.parse(pub) > now) return false;
  if (fm.expiryDate && Date.parse(fm.expiryDate) <= now) return false;
  return true;
}

// Hugo's default paths: lower-cased, one directory per page, trailing
// slash; `url` replaces the path, `slug` the last segment.
function pathOf(file, fm) {
  if (fm.url) return fm.url.endsWith("/") ? fm.url : `${fm.url}/`;
  const rel = relative(join(root, "content"), file).split(sep);
  const name = rel.pop().replace(/\.md$/, "");
  const segments = name === "_index" ? rel : [...rel, fm.slug || name];
  const path = segments.map(s => s.toLowerCase().replace(/\s+/g, "-")).join("/");
  return path ? `/${path}/` : "/";
}

const config = readConfig();
const params = config.params || {};

export const siteTitle = config.title;
export const siteDescription = params.description;
// The production origin Hugo bakes into absolute links (baseURL).
export const productionOrigin = new URL(config.baseURL).origin;

const pages = walk(join(root, "content"))
  .map(file => ({ file, fm: frontMatter(file) }))
  .filter(p => published(p.fm))
  .map(p => ({
    path: pathOf(p.file, p.fm),
    title: p.fm.title,
    section: p.file.endsWith(`${sep}_index.md`),
  }));

export const home = pages.find(p => p.path === "/");
// List pages: one per content directory with an _index.md.
export const sectionPages = pages.filter(p => p.section && p.path !== "/");
// Single pages: every published publication, project and standalone page.
export const contentPages = pages.filter(p => !p.section);
export const allPages = [home, ...sectionPages, ...contentPages].filter(Boolean);

// Every page's <title>, per layouts/_default/baseof.html.
export const titleOf = page => `${siteTitle} | ${page.title}`;

// Mirrors layouts/partials/nav.html: About always, then one link per
// homepage section its [params] show* switch turns on, in that order.
const publications = params.publicationsAlternateName || "Publications";
export const navigation = [
  { href: "/#about", label: "About" },
  ...[
    ["showProjects", "/#projects", "Projects"],
    ["showOpenSource", "/#open", "Open Source"],
    ["showPublications", `/#${publications}`, publications],
    ["showExperience", "/#experience", "Experience"],
    ["showSkills", "/#skills", "Skills"],
    ["showEducation", "/#education", "Education"],
    ["showTutorials", "/#tutorials", "Tutorials"],
  ].filter(([flag]) => params[flag] === true).map(([, href, label]) => ({ href, label })),
];
