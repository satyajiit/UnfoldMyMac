import { readFileSync, readdirSync } from "node:fs";
import path from "node:path";
import matter from "gray-matter";
import { evaluate } from "@mdx-js/mdx";
import * as runtime from "react/jsx-runtime";

export interface Article {
  slug: string; title: string; description: string; author: string; date: string;
  image: string; topic: string; minutes: number; content: string;
}
const directory = path.join(process.cwd(), "content/blog");
export function getArticles(): Article[] {
  return readdirSync(directory).filter(file => file.endsWith(".mdx")).map(file => {
    const { data, content } = matter(readFileSync(path.join(directory, file), "utf8"));
    for (const key of ["title", "description", "author", "date", "image", "topic"]) {
      if (typeof data[key] !== "string") throw new Error(`Missing ${key} in ${file}`);
    }
    return { ...data, slug: file.replace(/\.mdx$/, ""), content, minutes: Math.max(1, Math.ceil(content.split(/\s+/).length / 200)) } as Article;
  }).sort((a, b) => b.date.localeCompare(a.date) || a.title.localeCompare(b.title));
}
export async function renderArticle(article: Article) {
  // Only repository-owned MDX is evaluated, at build time. No user or remote input.
  const { default: Content } = await evaluate(article.content, { ...runtime });
  return Content;
}
