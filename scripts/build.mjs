import { mkdir, rm, cp, readFile, writeFile, access } from "node:fs/promises";
import { validateRelease } from "../release.js";
const manifest = validateRelease(
  JSON.parse(await readFile("release.json", "utf8")),
);
if (manifest.core.available) await access("install.sh");
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
try {
  await access("install.sh");
  await cp("install.sh", "dist/install.sh");
} catch (error) {
  if (error.code !== "ENOENT") throw error;
}
await writeFile("dist/.nojekyll", "");
console.log("Static site built to dist/");
