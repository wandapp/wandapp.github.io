import { mkdir, rm, cp, writeFile, access } from "node:fs/promises";
await access("install.sh");
await rm("dist", { recursive: true, force: true });
await mkdir("dist", { recursive: true });
for (const file of [
  "index.html",
  "styles.css",
  "main.js",
  "release.js",
  "assets",
])
  await cp(file, `dist/${file}`, { recursive: true });
// Legacy bridges, still read by already-installed 0.4.x apps (release.json) and hosts (core/<channel>/):
// kept byte for byte, nothing on the page uses them.
await cp("release.json", "dist/release.json");
try {
  await access("core");
  await cp("core", "dist/core", { recursive: true });
} catch (error) {
  if (error.code !== "ENOENT") throw error;
}
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
