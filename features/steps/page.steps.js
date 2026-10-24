// Browser steps: pages opened in headless Chromium.
import assert from "node:assert/strict";
import { Given, Then, When } from "@cucumber/cucumber";
import { contentPages, home, navigation, productionOrigin, sectionPages, siteDescription, siteTitle, titleOf } from "../support/content.js";

When("I open {string}", async function (path) {
  await this.open(path);
});

When("I open the home page", async function () {
  await this.open(home.path);
});

Then("the page answers {int}", function (status) {
  assert.equal(this.pageResponse?.status(), status, `${this.page.url()} answered ${this.pageResponse?.status()}`);
});

Then("the page has exactly one main heading", async function () {
  const h1 = this.page.locator("h1");
  assert.equal(await h1.count(), 1, `${this.page.url()} has ${await h1.count()} main headings, expected one`);
  assert.ok((await h1.first().innerText()).trim(), `${this.page.url()} has an empty main heading`);
});

Then("the page title is the site title and the home page's title", async function () {
  assert.equal(await this.page.title(), titleOf(home));
});

// The old verify-staging body check (curl | grep "William Poynter"): proves
// the real Hugo site rendered with its config, not an nginx default page or
// the near-blank page a build without the theme submodule produces.
Then("the page carries the site description from config.toml", async function () {
  const content = await this.page.locator("meta[name='description']").getAttribute("content");
  assert.equal(content, siteDescription);
});

// A page "renders" when it answers 200, has a heading (list pages and the
// home page carry one h1; publication and project pages head their article
// with an h2, the theme's single-page layout) and no more than one h1, and
// its <title> is "<site title> | <front matter title>" (baseof.html).
async function checkRendered(page, expected) {
  const headings = (await page.locator("h1, h2").allInnerTexts()).map(t => t.trim()).filter(Boolean);
  assert.ok(headings.length > 0, `${page.url()} has no heading`);
  const h1 = await page.locator("h1").count();
  assert.ok(h1 <= 1, `${page.url()} has ${h1} main headings, expected at most one`);
  assert.equal(await page.title(), titleOf(expected), `${page.url()} has the wrong title`);
}

// One step per derived list: every path is visited and every failure is
// reported together, so one broken page does not hide the next.
async function eachRenders(world, pages) {
  assert.ok(pages.length > 0, "content/ lists no pages for this step");
  const failures = [];
  for (const expected of pages) {
    try {
      const response = await world.open(expected.path);
      assert.equal(response?.status(), 200, `${expected.path} answered ${response?.status()}`);
      await checkRendered(world.page, expected);
    } catch (error) {
      failures.push(error.message);
    }
  }
  assert.equal(failures.length, 0, `${failures.length} of ${pages.length} pages failed:\n${failures.join("\n")}`);
}

Then("every section page from the content renders with a heading and a title", async function () {
  await eachRenders(this, sectionPages);
});

Then("every published content page renders with a heading and a title", async function () {
  await eachRenders(this, contentPages);
});

async function links(page, selector) {
  return page.locator(selector).evaluateAll(as => as.map(a => ({ href: a.getAttribute("href"), label: a.textContent.trim() })));
}

// Ours: a root-relative href, or an absolute one on the production origin
// (Hugo bakes baseURL into many links), checked by path on the host under
// test. mailto: and other hosts are not ours to assert on.
function ownPath(href) {
  if (!href) return undefined;
  if (href.startsWith("/") && !href.startsWith("//")) return href;
  if (href.startsWith(`${productionOrigin}/`)) return href.slice(productionOrigin.length);
  return undefined;
}

// A link resolves when its page answers 200, directly or through one
// redirect that stays on this origin (the theme's tag links have no
// trailing slash), and its fragment, if any, names an element on that page.
async function resolves(world, href) {
  const url = new URL(href, world.baseURL);
  let response = await world.api.get(world.url(url.pathname), { maxRedirects: 0 });
  if ([301, 302, 307, 308].includes(response.status())) {
    const next = new URL(response.headers().location || "", url);
    if (next.origin !== url.origin) return `${href} redirected off the origin to ${response.headers().location}`;
    response = await world.api.get(world.url(next.href), { maxRedirects: 0 });
  }
  if (response.status() !== 200) return `${href} answered ${response.status()}`;
  const id = decodeURIComponent(url.hash.slice(1));
  if (id) {
    const escaped = id.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    if (!new RegExp(`\\sid=["']?${escaped}(["'\\s>])`).test(await response.text())) return `${href} names no element with id '${id}'`;
  }
  return undefined;
}

async function eachResolves(world, hrefs) {
  const failures = [];
  for (const href of hrefs) {
    const failure = await resolves(world, href);
    if (failure) failures.push(failure);
  }
  assert.equal(failures.length, 0, `${failures.length} of ${hrefs.length} links failed:\n${failures.join("\n")}`);
}

const navLinks = "#sideNav .navbar-nav a";

Then("the header navigation lists the sections config.toml turns on", async function () {
  const found = await links(this.page, navLinks);
  assert.deepEqual(found, navigation);
});

Then("every header navigation link resolves", async function () {
  const found = await links(this.page, `#sideNav a`);
  await eachResolves(this, found.map(l => l.href));
});

Then("every internal link on the page resolves", async function () {
  const found = await links(this.page, "a[href]");
  const hrefs = [...new Set(found.map(l => ownPath(l.href)).filter(Boolean))];
  assert.ok(hrefs.length > 0, "no internal links found");
  // Fragments are checked once per page, not once per anchor.
  await eachResolves(this, hrefs);
});

Then("the page links back to the home page", async function () {
  const found = await links(this.page, "a[href]");
  const home = found.filter(l => { const p = ownPath(l.href); return p && new URL(p, this.baseURL).pathname === "/"; });
  assert.ok(home.length >= 1, `${this.page.url()} has no link to /`);
});

// Browser hygiene: listeners go on before navigation so nothing is missed.
When("I open the home page and watch the browser console and network", async function () {
  const page = await this.ensurePage();
  this.consoleErrors = [];
  this.failedRequests = [];
  this.requestUrls = [];
  // Only the host under test is counted: the CDN stylesheets and scripts,
  // the analytics script and the production-origin assets Hugo bakes into
  // absolute URLs are someone else's (or another environment's) outage.
  const origin = new URL(this.baseURL).origin;
  const ours = r => { try { return new URL(r.url()).origin === origin; } catch { return false; } };
  page.on("console", m => { if (m.type() === "error") this.consoleErrors.push(m.text()); });
  page.on("pageerror", e => this.consoleErrors.push(`pageerror: ${e.message}`));
  page.on("requestfailed", r => { if (ours(r) && r.failure()?.errorText !== "net::ERR_ABORTED") this.failedRequests.push(`${r.url()} (${r.failure()?.errorText})`); });
  page.on("request", r => { if (ours(r)) this.requestUrls.push(r.url()); });
  await this.open(home.path);
  await page.waitForLoadState("networkidle");
});

Then("no console errors were logged", function () {
  assert.deepEqual(this.consoleErrors, []);
});

Then("none of the site's own requests failed", function () {
  assert.deepEqual(this.failedRequests, []);
});

// Mixed content: on an HTTPS target nothing may be fetched over plain HTTP.
// On the local http server the check has nothing to say.
Then("nothing of the site's own was loaded over plain HTTP when the site is on HTTPS", function () {
  if (!this.baseURL.startsWith("https://")) return;
  const insecure = this.requestUrls.filter(u => u.startsWith("http://"));
  assert.deepEqual(insecure, [], "mixed content");
});

// Responsive: the theme's side navigation is a Bootstrap navbar-expand-lg,
// so below 992px it collapses behind the toggler button.
Given("a phone-sized viewport", function () {
  this.viewport = { width: 390, height: 844 };
});

const menuButton = page => page.locator("#sideNav button.navbar-toggler");
const menu = page => page.locator("#navbarSupportedContent");

Then("the menu button is shown and the navigation is hidden", async function () {
  assert.ok(await menuButton(this.page).isVisible(), "menu button not visible");
  assert.equal(await menuButton(this.page).getAttribute("aria-expanded"), "false");
  assert.equal(await menu(this.page).isVisible(), false, "navigation should start hidden");
});

When("I press the menu button", async function () {
  await menuButton(this.page).click();
  // Wait for Bootstrap's open transition to finish: a collapse('hide')
  // issued while the menu is still `collapsing` is ignored, so a link
  // followed too early leaves the menu open for good.
  await this.page.waitForFunction(() => {
    const c = document.getElementById("navbarSupportedContent")?.classList;
    return c && c.contains("show") && !c.contains("collapsing");
  });
});

Then("the navigation is shown with the sections config.toml turns on", async function () {
  assert.equal(await menuButton(this.page).getAttribute("aria-expanded"), "true");
  const anchors = this.page.locator(navLinks);
  assert.equal(await anchors.count(), navigation.length);
  for (let i = 0; i < navigation.length; i++) {
    assert.ok(await anchors.nth(i).isVisible(), `${navigation[i].href} is not visible in the open menu`);
  }
  assert.deepEqual(await links(this.page, navLinks), navigation);
});

// The last link points furthest down the page, so arriving there proves the
// link scrolled (resume.js animates the scroll and closes the menu).
When("I follow the last navigation link", async function () {
  this.followed = navigation[navigation.length - 1];
  await this.page.locator(navLinks).last().click();
});

Then("the menu closes and that section is in view", async function () {
  await menu(this.page).waitFor({ state: "hidden" });
  const id = this.followed.href.split("#")[1];
  await this.page.waitForFunction(target => {
    const el = document.getElementById(target);
    if (!el) return false;
    // In view = on screen once the scroll settles. Not "top at the top":
    // resume.js measures the target while the open menu still pushes the
    // page down, so it lands one menu-height past the section's start.
    const { top, bottom } = el.getBoundingClientRect();
    return top < window.innerHeight && bottom > 0 && window.scrollY > 0;
  }, id, { timeout: 10_000 });
});

Then("the page title starts with the site title", async function () {
  const title = await this.page.title();
  assert.ok(title.startsWith(siteTitle), `${this.page.url()} title '${title}' does not start with '${siteTitle}'`);
});
