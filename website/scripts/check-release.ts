import { createHash } from "node:crypto";
import { release, site } from "../src/lib/site";
import { releaseProblems } from "../src/lib/release-validation";
const problems = releaseProblems(release);
if (problems.length) { console.error(problems.join("\n")); process.exit(1); }
const headers: Record<string, string> = { Accept: "application/vnd.github+json", "X-GitHub-Api-Version": "2026-03-10" };
if (process.env.GITHUB_TOKEN) headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
// Citations and source-build instructions must resolve when the site launches.
for (const file of ["README.md", "LICENSE", "NOTICE", "MacDuo/README.md", "MacDuo/DEVELOPING.md", "MacDuo/Sources/UnfoldMyMacCore/Effects/EffectManifest.swift", "MacDuo/Sources/UnfoldMyMacCore/Wallpaper/WallpaperPlayback.swift"]) {
  const source = await fetch(`https://api.github.com/repos/satyajiit/UnfoldMyMac/contents/${file}?ref=main`, { headers, signal: AbortSignal.timeout(30_000) });
  if (!source.ok) throw new Error(`Public source citation is unavailable: ${file} (${source.status})`);
}
const response = await fetch(`https://api.github.com/repos/satyajiit/UnfoldMyMac/releases/tags/${encodeURIComponent(release.tag!)}`, { headers, signal: AbortSignal.timeout(30_000) });
if (!response.ok) throw new Error(`Release lookup failed: ${response.status}`);
const record = await response.json() as { draft: boolean; prerelease: boolean; assets: { browser_download_url: string }[] };
if (record.draft || record.prerelease || !record.assets.some(asset => asset.browser_download_url === release.assetUrl)) throw new Error("Download is not an asset on a published stable release.");
const download = await fetch(release.assetUrl!, { signal: AbortSignal.timeout(120_000) });
if (!download.ok || !download.body) throw new Error(`Download failed: ${download.status}`);
const hash = createHash("sha256");
for await (const chunk of download.body) hash.update(chunk);
if (hash.digest("hex") !== release.sha256) throw new Error("Downloaded DMG checksum does not match the verified release.");
console.log(`Verified ${site.name} ${release.version} download and checksum. Signing attestation: ${release.verifiedAt}.`);
