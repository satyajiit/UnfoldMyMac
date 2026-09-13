import type { MetadataRoute } from "next";
import { pages, site } from "@/lib/site";
import { getArticles } from "@/lib/content";
import { libraryRoutes } from "@/lib/design-content";
export const dynamic = "force-static";
export default function sitemap(): MetadataRoute.Sitemap {
  return [...[...pages, ...libraryRoutes].map(page => ({ url: `${site.url}${page.path}` })), ...getArticles().map(article => ({ url: `${site.url}/blog/${article.slug}/`, lastModified: article.date }))];
}
