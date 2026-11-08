import { mkdir, rm, cp, readFile, writeFile, access } from "node:fs/promises";
import { validateRelease } from "../release.js";
const manifest = validateRelease(
  JSON.parse(await readFile("release.json", "utf8")),
);
if (manifest.installer.available) await access("install.sh");
await rm("dist", { recursive: true, force: true });
await mkdir("dist", { recursive: true });
for (const file of [
  "index.html",
  "styles.css",
  "main.js",
  "release.js",
  "release.json",
  "assets",
])
  await cp(file, `dist/${file}`, { recursive: true });
for (const installer of ["install.sh", "install-macos.sh", "install-linux.sh"]) {
  try {
    await access(installer);
    await cp(installer, `dist/${installer}`);
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }
}
await writeFile("dist/.nojekyll", "");
console.log("Static site built to dist/");
