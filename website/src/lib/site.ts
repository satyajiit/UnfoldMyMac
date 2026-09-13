import releaseData from "./release.json";
export const site = {
  name: "UnfoldMyMac", url: "https://unfoldmymac.com",
  repo: "https://github.com/satyajiit/UnfoldMyMac",
  company: "https://matterwardlabs.com", author: "Matterward Labs",
  description: "Lid Effects, Dynamic Wallpapers, and Creative Scenes. A redesigned native Mac app with reactive worlds, design previews, and optional data connections.",
  keywords: [
    "MacBook lid effects", "lid angle sensor", "macOS desktop effects", "live wallpaper for Mac",
    "dynamic wallpaper macOS", "Creative Scenes", "Hinge Garden", "The Workshop", "iPhone Duo", "iOS Duo", "iPhone Duo effect on Mac",
    "Metal shaders macOS", "native Mac app", "menu bar app", "Apple silicon",
  ],
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
  app: `${site.repo}/blob/main/UnfoldMyMac/README.md`,
  developing: `${site.repo}/blob/main/UnfoldMyMac/DEVELOPING.md`,
  license: `${site.repo}/blob/main/LICENSE`,
  notices: `${site.repo}/blob/main/NOTICE`,
};
export const navigation = [
  { href: "/features/", label: "Features" }, { href: "/showcase/", label: "Showcase" },
  { href: "/story/", label: "The story" }, { href: "/blog/", label: "Field notes" },
];
export const pages = [
  { path: "/", title: "A little more life on your Mac", description: "Explore Lid Effects, Dynamic Wallpapers, and Creative Scenes in a redesigned native Mac app. Meet The Workshop and Hinge Garden, browse by category, and preview each design." },
  { path: "/features/", title: "Made for the way you open your Mac", description: "Explore Lid Effects, Dynamic Wallpapers, and Creative Scenes: custom image reveals, The Workshop and Hinge Garden, and optional data connections." },
  { path: "/showcase/", title: "Pick your kind of desktop", description: "Browse 13 Lid Effects, 20 Dynamic Wallpapers, and two Creative Scenes, with native app renders of The Workshop and Hinge Garden." },
  { path: "/story/", title: "I only meant to make one effect", description: "The illustrated story of UnfoldMyMac: how an iPhone Duo animation inspired a MacBook experiment, desktop effects, and a collection of live wallpapers." },
  { path: "/download/", title: "Make yourself at home", description: "Get UnfoldMyMac for macOS 26 or later. Check release availability, hardware requirements, and installation instructions." },
  { path: "/blog/", title: "Notes from an open laptop", description: "Practical guides to Lid Effects, Dynamic Wallpapers, Creative Scenes, and local data connections." },
  { path: "/faq/", title: "A few things before you unfold", description: "Answers about supported Macs, lid sensors, Screen Recording, live wallpapers, the iPhone Duo effect on macOS, and your data." },
  { path: "/privacy/", title: "What stays on your Mac", description: "How UnfoldMyMac handles desktop capture, imported artwork, optional connections, and website preferences." },
];
