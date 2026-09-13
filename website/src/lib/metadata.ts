import type { Metadata } from "next";
import { pages, site } from "./site";
export function pageMetadata(path: string, title?: string, description?: string, image?: { url: string; alt: string }): Metadata {
  const page = pages.find(page => page.path === path);
  const resolvedTitle = title ?? page?.title ?? site.name;
  const resolvedDescription = description ?? page?.description ?? site.description;
  const socialImage = image ? { ...image, type: "image/webp" } : { url: "/media/featured.png", width: 1200, height: 630, type: "image/png", alt: "UnfoldMyMac — Lid down. Drama up. A MacBook with theatre curtains and curious characters." };
  return {
    title: { absolute: `${resolvedTitle} | UnfoldMyMac` }, description: resolvedDescription,
    alternates: { canonical: path, types: { "text/markdown": `${path}index.md` } },
    openGraph: { title: resolvedTitle, description: resolvedDescription, url: path, siteName: site.name, locale: "en_US", type: "website", images: [socialImage] },
    twitter: { card: "summary_large_image", title: resolvedTitle, description: resolvedDescription, images: [socialImage] },
  };
}
