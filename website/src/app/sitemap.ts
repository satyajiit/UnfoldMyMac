import type { MetadataRoute } from "next";
import { pages, site } from "@/lib/site";
import { getArticles } from "@/lib/content";
export const dynamic = "force-static";
export default function sitemap(): MetadataRoute.Sitemap {
  return [...pages.map(page => ({ url: `${site.url}${page.path}` })), ...getArticles().map(article => ({ url: `${site.url}/blog/${article.slug}/`, lastModified: article.date }))];
}
