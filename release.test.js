import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import {
  channels,
  copyCommand,
  installCommand,
  betaInstallCommand,
  betaDownloadURL,
  downloadURL,
  releasesURL,
} from "./release.js";
const read = (file) => readFile(new URL(file, import.meta.url), "utf8");

test("the download button points at the latest release asset and needs no per-release edit", async () => {
  const html = await read("./index.html");
  assert.equal(
    downloadURL,
    "https://github.com/wandapp/app/releases/latest/download/Wand-macOS-arm64.dmg",
  );
  assert.match(html, new RegExp(`id="download"[^>]*\\s+href="${downloadURL}"`.replace(/\./g, "\\.")));
  assert.match(releasesURL, /^https:\/\/github\.com\/wandapp\/app\/releases$/);
  for (const file of ["./index.html", "./main.js", "./release.js"]) {
    const text = await read(file);
    assert.doesNotMatch(text, /wandapp\.github\.io\/releases|macos-v\d|release\.json/);
  }
});

test("the page does not depend on the legacy feeds", async () => {
  const text = (await read("./main.js")) + (await read("./index.html"));
  assert.doesNotMatch(text, /fetch\(/);
});

test("copy succeeds only after the clipboard accepts the exact text", async () => {
  let copied;
  await copyCommand(installCommand, {
    writeText: async (value) => {
      copied = value;
    },
  });
  assert.equal(copied, installCommand);
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
  const html = await read("./index.html");
  assert.equal(html.split(installCommand).length - 1, 1);
  assert.doesNotMatch(html, /wand-core start|install-app\.sh|先安装 Core|不会自动打开/);
});

test("the Beta channel runs the same installer with --beta and offers the Beta dmg", () => {
  assert.equal(betaInstallCommand, `${installCommand.replace(/\| sh$/, "| sh -s -- --beta")}`);
  assert.equal(betaDownloadURL, "https://github.com/wandapp/app/releases/download/beta/Wand-macOS-arm64.dmg");
  assert.deepEqual(Object.keys(channels), ["stable", "beta"]);
  assert.equal(channels.stable.command, installCommand);
  assert.equal(channels.beta.command, betaInstallCommand);
});

test("every installer accepts --beta and passes it on", async () => {
  assert.match(await read("./install.sh"), /sh "\$script" "\$@"/);
  for (const file of ["./install-macos.sh", "./install-linux.sh"]) {
    const text = await read(file);
    assert.match(text, /--beta\) CHANNEL=beta/);
    assert.match(text, /releases\/download\/beta\/manifest\.json/);
  }
});
