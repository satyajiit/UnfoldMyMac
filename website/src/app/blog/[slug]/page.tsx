import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";
import { getArticles, renderArticle } from "@/lib/content";
import { pageMetadata } from "@/lib/metadata";
import { site } from "@/lib/site";
import { JsonLd } from "@/components/shared";
export const dynamicParams = false;
export function generateStaticParams() { return getArticles().map(({ slug }) => ({ slug })); }
export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const article = getArticles().find(article => article.slug === slug);
  if (!article) notFound();
  const metadata = pageMetadata(`/blog/${slug}/`, article.title, article.description);
  return { ...metadata, openGraph: { ...metadata.openGraph, type: "article", publishedTime: article.date, authors: [article.author] } };
}
export default async function ArticlePage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const article = getArticles().find(article => article.slug === slug);
  if (!article) notFound();
  const Content = await renderArticle(article);
  return <div className="container article-page"><div className="page-intro"><Link className="back-link" href="/blog/">Field notes</Link><span className="intro-separator">/</span><span className="muted">{article.topic}</span><h1>{article.title}</h1><p className="lede">{article.description}</p><div className="article-meta"><span>{article.author}</span><time dateTime={article.date}>{new Date(`${article.date}T12:00:00Z`).toLocaleDateString("en-US", { year: "numeric", month: "long", day: "numeric", timeZone: "UTC" })}</time><span>{article.minutes} min read</span></div></div><Image className="article-cover" src={article.image} alt={`${article.topic} illustrated with UnfoldMyMac artwork`} width={1200} height={750} sizes="(max-width: 800px) 92vw, 900px" priority /><article className="prose"><Content /></article><div className="article-end"><Link href="/blog/">More field notes</Link><Link href="/download/">Get UnfoldMyMac</Link></div><JsonLd data={{ "@context": "https://schema.org", "@type": "Article", headline: article.title, description: article.description, datePublished: article.date, author: { "@type": "Organization", "@id": `${site.company}/#organization`, name: article.author, url: site.company }, publisher: { "@id": `${site.company}/#organization` }, image: `${site.url}${article.image}`, mainEntityOfPage: `${site.url}/blog/${slug}/` }} /></div>;
}
