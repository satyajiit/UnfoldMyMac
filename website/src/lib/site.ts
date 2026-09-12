import releaseData from "./release.json";
export const site = {
  name: "UnfoldMyMac", url: "https://unfoldmymac.com",
  repo: "https://github.com/satyajiit/UnfoldMyMac",
  company: "https://matterwardlabs.com", author: "Matterward Labs",
  description: "Desktop effects that follow your MacBook lid. Live wallpapers with something going on. A native Mac app by Matterward Labs.",
};
export interface Release {
  status: "pending" | "available"; version: string | null; tag: string | null;
  assetUrl: string | null; sha256: string | null; architectures: string[];
  minimumMacOS: string; signing: "unverified" | "developer-id-notarized";
  verifiedAt: string | null;
}
export const release = releaseData as Release;
export const sources = {
  overview: `${site.repo}/blob/main/README.md`,
  app: `${site.repo}/blob/main/MacDuo/README.md`,
  developing: `${site.repo}/blob/main/MacDuo/DEVELOPING.md`,
  license: `${site.repo}/blob/main/LICENSE`,
  notices: `${site.repo}/blob/main/NOTICE`,
};
export const navigation = [
  { href: "/features/", label: "Features" }, { href: "/showcase/", label: "Showcase" },
  { href: "/story/", label: "The story" }, { href: "/blog/", label: "Field notes" },
];
export const pages = [
  { path: "/", title: "A little drama for your desktop", description: site.description },
  { path: "/features/", title: "Made for the way you open your Mac", description: "Explore lid-driven effects, custom image reveals, live wallpapers, and optional data connections in UnfoldMyMac." },
  { path: "/showcase/", title: "Pick your kind of desktop", description: "See all 13 effects and ten live wallpaper scenes, with previews rendered by UnfoldMyMac." },
  { path: "/story/", title: "Apparently, closing a laptop needed art direction", description: "How one lid effect grew into UnfoldMyMac, a native Mac app from Matterward Labs." },
  { path: "/download/", title: "Make yourself at home", description: "Get UnfoldMyMac for macOS 26 or later. Check release availability, hardware requirements, and installation instructions." },
  { path: "/blog/", title: "Notes from an open laptop", description: "Practical guides to UnfoldMyMac lid effects, live wallpapers, and local data connections." },
  { path: "/faq/", title: "A few things before you unfold", description: "Answers about supported Macs, lid sensors, Screen Recording, wallpapers, and your data." },
  { path: "/privacy/", title: "What stays on your Mac", description: "How UnfoldMyMac handles desktop capture, imported artwork, optional connections, and website preferences." },
];
