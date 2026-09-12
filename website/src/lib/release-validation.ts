import type { Release } from "./site";
export function releaseProblems(value: Release): string[] {
  const issues: string[] = [];
  if (value.status !== "available") issues.push("No verified downloadable release is available.");
  if (!value.version?.trim() || !value.tag?.trim()) issues.push("Release version and GitHub tag are required.");
  if (!value.architectures.length || value.architectures.some(arch => !["arm64", "x86_64"].includes(arch))) issues.push("Declare verified architectures (arm64 and/or x86_64).");
  if (value.signing !== "developer-id-notarized") issues.push("Developer ID signing and Apple notarization must be verified.");
  if (!value.verifiedAt || Number.isNaN(Date.parse(value.verifiedAt)) || Date.parse(value.verifiedAt) > Date.now()) issues.push("A valid, nonfuture verification date is required.");
  if (!value.sha256 || !/^[a-f0-9]{64}$/.test(value.sha256)) issues.push("A SHA-256 checksum is required.");
  try {
    const url = new URL(value.assetUrl ?? "");
    const prefix = `/satyajiit/UnfoldMyMac/releases/download/${encodeURIComponent(value.tag ?? "")}/`;
    if (url.origin !== "https://github.com" || !url.pathname.startsWith(prefix) || !url.pathname.endsWith(".dmg") || url.search || url.hash) issues.push("The download must be a DMG asset on the configured GitHub release.");
  } catch { issues.push("A verified download URL is required."); }
  return issues;
}
