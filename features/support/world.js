// One headless Chromium for the whole run; a fresh browser context and a
// fresh API request context per scenario. BASE_URL selects the target
// (default: the local static server from `yarn serve`).
import { After, AfterAll, Before, BeforeAll, setDefaultTimeout, setWorldConstructor, World } from "@cucumber/cucumber";
import { chromium, request } from "playwright";

export const baseURL = (process.env.BASE_URL || "http://localhost:3000").replace(/\/$/, "");

// Chromium cannot read NODE_EXTRA_CA_CERTS (it keeps its own trust store),
// so when a private CA is supplied - the vault-pki staging cert in CI - the
// browser context skips certificate checks. Node still verifies every
// request-level step against that CA, so the chain is checked on each run.
const privateCA = Boolean(process.env.NODE_EXTRA_CA_CERTS);

// Whole-page steps iterate every public route; prod answers from the edge.
setDefaultTimeout(120_000);

let browser;

export class SiteWorld extends World {
  constructor(options) {
    super(options);
    this.baseURL = baseURL;
    /** @type {import("playwright").BrowserContext | undefined} */
    this.context = undefined;
    /** @type {import("playwright").Page | undefined} */
    this.page = undefined;
    /** @type {import("playwright").APIRequestContext | undefined} */
    this.api = undefined;
    /** @type {import("playwright").APIResponse | undefined} */
    this.response = undefined;
    /** @type {import("playwright").Response | null | undefined} */
    this.pageResponse = undefined;
    this.viewport = { width: 1280, height: 800 };
  }

  // Every URL exactly as a visitor requests it: no cache-busting query,
  // no edge bypass. In CI the prod suite runs in the template's
  // verify-live job, AFTER cdn-purge (porter-valley-infra
  // ci-templates/product-deploy.yml, PLAT-766), so the edge already
  // serves the promoted build; a query here would hide a stale edge.
  url(path) {
    return /^https?:\/\//.test(path) ? path : `${this.baseURL}${path}`;
  }

  // Plain HTTP, no redirects followed: status and headers are the assertion.
  async get(path, options = {}) {
    this.response = await this.api.get(this.url(path), { maxRedirects: 0, ...options });
    return this.response;
  }

  async head(path) {
    this.response = await this.api.head(this.url(path), { maxRedirects: 0 });
    return this.response;
  }

  async ensurePage() {
    if (!this.page) {
      this.context = await browser.newContext({ baseURL: this.baseURL, viewport: this.viewport, ignoreHTTPSErrors: privateCA });
      this.page = await this.context.newPage();
    }
    return this.page;
  }

  // Browser navigation; the response is kept for status assertions.
  async open(path) {
    const page = await this.ensurePage();
    this.pageResponse = await page.goto(this.url(path), { waitUntil: "load" });
    return this.pageResponse;
  }
}

setWorldConstructor(SiteWorld);

BeforeAll(async () => {
  browser = await chromium.launch();
});

Before(async function () {
  this.api = await request.newContext({ baseURL: this.baseURL, ignoreHTTPSErrors: false });
});

After(async function () {
  await this.context?.close();
  await this.api?.dispose();
});

AfterAll(async () => {
  await browser?.close();
});
