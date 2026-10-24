// The sitemap names the production host (Hugo bakes baseURL in at build
// time), so its URLs are compared and fetched by path on whichever host is
// under test.
import assert from "node:assert/strict";
import { Then } from "@cucumber/cucumber";
import { allPages } from "../support/content.js";

async function sitemapPaths(world) {
  const response = await world.get("/sitemap.xml");
  assert.equal(response.status(), 200, `/sitemap.xml answered ${response.status()}`);
  const xml = await response.text();
  const paths = [...xml.matchAll(/<loc>([^<]+)<\/loc>/g)].map(m => new URL(m[1].trim()).pathname);
  assert.ok(paths.length > 0, "the sitemap lists no URLs");
  return paths;
}

Then("the sitemap lists the home page, every section page and every published content page", async function () {
  const listed = new Set(await sitemapPaths(this));
  const missing = allPages.map(p => p.path).filter(p => !listed.has(p));
  assert.deepEqual(missing, [], "pages missing from the sitemap");
});

// Tag pages are in the sitemap too; Hugo generates them from front matter,
// so this is where they are checked.
Then("every page in the sitemap answers 200 on this host", async function () {
  const failures = [];
  for (const path of await sitemapPaths(this)) {
    const response = await this.api.get(this.url(path), { maxRedirects: 0 });
    if (response.status() !== 200) failures.push(`${path} answered ${response.status()}`);
  }
  assert.deepEqual(failures, []);
});
