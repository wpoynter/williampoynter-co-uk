// Request-level steps: status codes, headers and bodies, no browser.
import assert from "node:assert/strict";
import { Then, When } from "@cucumber/cucumber";
import { sectionPages } from "../support/content.js";

When("I request {string}", async function (path) {
  await this.get(path);
});

Then("the response status is {int}", function (status) {
  assert.equal(this.response.status(), status, `${this.response.url()} answered ${this.response.status()}`);
});

// Content types compare on their prefix, so "text/plain" accepts an added
// charset.
Then("the response is served as {string}", function (type) {
  const actual = (this.response.headers()["content-type"] || "").toLowerCase();
  assert.ok(actual.startsWith(type.toLowerCase()), `${this.response.url()} is served as '${actual}', expected '${type}'`);
});

// nginx says text/xml, other static servers application/xml: both are XML.
Then("the response is XML", function () {
  const actual = (this.response.headers()["content-type"] || "").toLowerCase();
  assert.match(actual, /^(text|application)\/xml\b/, `${this.response.url()} is served as '${actual}'`);
});

Then("the response body is {string}", async function (body) {
  assert.equal((await this.response.text()).trim(), body);
});

Then("the response body contains {string}", async function (needle) {
  assert.ok((await this.response.text()).includes(needle), `${this.response.url()} does not contain '${needle}'`);
});

Then("the response body has a line starting {string}", async function (prefix) {
  const lines = (await this.response.text()).split(/\r?\n/);
  assert.ok(lines.some(l => l.startsWith(prefix)), `${this.response.url()} has no line starting '${prefix}'`);
});

// The build sentinel the Dockerfile bakes: one token, nothing else.
Then("the response body is a single build tag", async function () {
  const text = await this.response.text();
  assert.match(text.trim(), /^[A-Za-z0-9._-]+$/, `unexpected build tag body: ${JSON.stringify(text)}`);
});

// verify-staging exports TAG (the build job's dotenv artifact) and
// verify-live PROMOTED_TAG (the promote job's); a run with neither, such
// as the prod probe or a local run, only checks the shape.
Then("the build tag matches the one CI expects, if any", async function () {
  const expected = process.env.PROMOTED_TAG || process.env.TAG;
  if (!expected) return;
  assert.equal((await this.response.text()).trim(), expected);
});

// Redirects must stay on the public origin: a relative Location, or an
// absolute one on the same origin. Never another host, port or scheme
// (nginx listens on 8080 behind the edge, hence absolute_redirect off in
// docker/nginx.conf; without it every slashless URL sent visitors to
// http://<host>:8080/..., which nothing answers).
function assertRedirectOnOrigin(world, response, target) {
  assert.ok([301, 308].includes(response.status()), `${response.url()} answered ${response.status()}, expected a permanent redirect`);
  const location = response.headers().location;
  assert.ok(location, `${response.url()} redirected without a Location header`);
  const resolved = new URL(location, world.baseURL);
  assert.equal(resolved.origin, new URL(world.baseURL).origin, `${response.url()} redirect left the origin: ${location}`);
  assert.equal(resolved.pathname, target, `${response.url()} redirected to ${location}, expected ${target}`);
}

Then("every section page requested without its trailing slash redirects on this origin to the page", async function () {
  assert.ok(sectionPages.length > 0, "content/ lists no section pages");
  const failures = [];
  for (const { path } of sectionPages) {
    try {
      assertRedirectOnOrigin(this, await this.get(path.replace(/\/$/, "")), path);
    } catch (error) {
      failures.push(error.message);
    }
  }
  assert.equal(failures.length, 0, `${failures.length} of ${sectionPages.length} redirects failed:\n${failures.join("\n")}`);
});
