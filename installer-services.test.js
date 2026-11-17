import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync, mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const read = (name) => readFileSync(new URL(name, import.meta.url), "utf8");
const fn = (source, name) => {
  const match = source.match(new RegExp(`^${name}\\(\\) \\{[\\s\\S]*?^\\}`, "m"));
  assert.ok(match, `Missing installer function ${name}`);
  return match[0];
};

for (const platform of ["macos", "linux"]) {
  test(`${platform} waits for exact target and both independent services`, () => {
    const directory = mkdtempSync(join(tmpdir(), "wand-installer-status-"));
    try {
      const source = read(`./install-${platform}.sh`);
      const reader = join(directory, "json-reader.cjs");
      writeFileSync(reader, "const v=JSON.parse(require('fs').readFileSync(process.argv[3],'utf8'))[process.argv[2]];if(v===undefined)process.exit(1);process.stdout.write(String(v));");
      const parser = platform === "linux" ? fn(source, "json_field") : 'json() { "$NODE_EXE" "$JSON_READER" "$1" "$2"; }';
      const transport = platform === "linux" ? 'curl() { printf \'%s\' "$HELLO_JSON"; }' : 'hello() { printf \'%s\' "$HELLO_JSON" > "$TEMP/hello.json"; }';
      const script = [parser, transport, fn(source, "on_build"), "on_build"].join("\n");
      const base = { version: "0.5.10", build: 42, restartPending: false, agentRestartPending: false };
      const cases = [
        { name: "all current", info: base, ok: true },
        { name: "agent still old", info: { ...base, agentRestartPending: true }, ok: false },
        { name: "terminal still old", info: { ...base, restartPending: true }, ok: false },
        { name: "wrong build", info: { ...base, build: 41 }, ok: false },
        { name: "wrong version", info: { ...base, version: "0.5.9" }, ok: false },
        { name: "missing agent evidence", info: { ...base, agentRestartPending: undefined }, ok: false },
        { name: "legacy terminal scope", scope: "terminal", info: { ...base, agentRestartPending: undefined }, ok: true },
        { name: "failed restoration while processes current", info: base, record: "failed", ok: false },
        { name: "operation still running", info: base, record: "running", ok: false },
      ];
      for (const item of cases) {
        const record = join(directory, "restart-services");
        rmSync(record, { force: true });
        if (item.record) writeFileSync(record, JSON.stringify({ status: item.record }));
        const result = spawnSync("sh", ["-c", script], {
          encoding: "utf8",
          env: { ...process.env, NODE_EXE: process.execPath, JSON_READER: reader, HELLO_JSON: JSON.stringify(item.info),
            TEMP: directory, RECORD: record, RESTART_SCOPE: item.scope ?? "services", LISTEN: "3210",
            VERSION: "0.5.10", CORE_VERSION: "0.5.10", BUILD: "42", CORE_BUILD: "42" },
        });
        assert.equal(result.status === 0, item.ok, `${item.name}: ${result.stderr}`);
      }
    } finally { rmSync(directory, { recursive: true, force: true }); }
  });
}

test("Linux chooses dual-service consent only when the bundle explicitly supports it", () => {
  const directory = mkdtempSync(join(tmpdir(), "wand-installer-scope-"));
  try {
    const source = read("./install-linux.sh");
    const selection = source.match(/^RESTART_SCOPE=none\n[\s\S]*?^fi$/m)?.[0];
    assert.ok(selection);
    for (const [flags, expected] of [
      ["--restart-terminal)\n--restart-services)", "services\n--restart-services"],
      ["--restart-terminal)", "terminal\n--restart-terminal"],
      ["", "none"],
    ]) {
      writeFileSync(join(directory, "install.sh"), flags);
      const result = spawnSync("sh", ["-c", `${selection}\nprintf '%s\\n' "$RESTART_SCOPE" "$@"`], {
        encoding: "utf8", env: { ...process.env, BUNDLE: directory },
      });
      assert.equal(result.status, 0, result.stderr);
      assert.equal(result.stdout.trim(), expected);
    }
  } finally { rmSync(directory, { recursive: true, force: true }); }
});

test("Linux reports a failed durable operation before later successful result statuses", () => {
  const parser = fn(read("./install-linux.sh"), "json_field");
  const record = { status: "failed", results: { agentd: { status: "failed" }, sessiond: { status: "restarted" } } };
  const result = spawnSync("sh", ["-c", `${parser}\njson_field "$RECORD_JSON" status first_string`], {
    encoding: "utf8", env: { ...process.env, RECORD_JSON: JSON.stringify(record) },
  });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout.trim(), "failed");
});
