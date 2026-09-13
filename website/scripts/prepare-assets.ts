import sharp from "sharp";
import { mkdir, copyFile } from "node:fs/promises";
import path from "node:path";
import { heroCovers } from "../src/lib/hero-demo";
const root = path.resolve("..");
const resources = path.join(root, "UnfoldMyMac/Sources/UnfoldMyMacKit/Resources");
await mkdir("public/media", { recursive: true });
await mkdir("public/artwork", { recursive: true });
await mkdir("public/artwork/thumbs", { recursive: true });
await mkdir("public/fonts", { recursive: true });
const assets = [
  ["Covers/Curtains.png", "curtains"], ["Covers/Peekaboo.png", "peekaboo"], ["Covers/Current.png", "current"],
  ["Covers/Frost.png", "frost"], ["Covers/Veil.png", "veil"], ["Covers/Fade.png", "fade"],
  ["Artwork/Reverie.png", "reverie"], ["Artwork/NeonCoast.png", "neon-coast"], ["Artwork/Rise.png", "rise"],
  ["Artwork/TabGoblin.png", "tab-goblin"], ["Artwork/FCUKIt.png", "fcuk-it"],
  ["Artwork/CodexAfterDark.png", "codex-after-dark"], ["Artwork/ClaudeHasNotes.png", "claude-has-notes"],
];
for (const [source, name] of assets) await sharp(path.join(resources, source)).resize({ width: 1200, withoutEnlargement: true }).webp({ quality: 85 }).toFile(`public/artwork/${name}.webp`);
for (const [source, name] of assets.filter(([, name]) => heroCovers.some(cover => cover.id === name))) await sharp(path.join(resources, source)).resize(220, 138, { fit: "cover" }).webp({ quality: 80 }).toFile(`public/artwork/thumbs/${name}.webp`);
await sharp(path.join(root, ".github/media/origin-comic.png")).resize({ width: 1400 }).webp({ quality: 85 }).toFile("public/media/origin-comic.webp");
await sharp(path.join(resources, "Brand/UnfoldMyMacLogo.png")).resize(128).webp({ quality: 90 }).toFile("public/media/logo.webp");
await sharp(path.join(resources, "Brand/UnfoldMyMacLogo.png")).resize(48).png().toFile("public/media/icon.png");
await sharp(path.join(resources, "Brand/UnfoldMyMacLogo.png")).resize(180).png().toFile("public/media/apple-icon.png");
await sharp("assets/social/featured-original.png").resize(1200, 630, { fit: "cover", position: "centre" }).png({ compressionLevel: 9 }).toFile("public/media/featured.png");
for (const file of ["SpaceGrotesk-Regular.ttf", "SpaceGrotesk-Medium.ttf", "SpaceGrotesk-Bold.ttf", "OFL.txt"]) await copyFile(path.join(resources, "Fonts", file), path.join("public/fonts", file));
console.log("Prepared app artwork, branding, and licensed fonts.");
