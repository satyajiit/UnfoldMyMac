import Link from "next/link";
import Image from "next/image";
import { PageIntro, Breadcrumbs } from "@/components/shared";
import { getArticles } from "@/lib/content";
import { pageMetadata } from "@/lib/metadata";
export const metadata = pageMetadata("/blog/");
export default function BlogPage() { return <div className="container"><PageIntro label="Field notes" title="Notes from an open laptop." description="A closer look at the effects, the wallpaper engine, and the data behind those little worlds." /><div className="article-grid">{getArticles().map(article => <article className="article-card" key={article.slug}><Link href={`/blog/${article.slug}/`}><Image src={article.image} alt="" width={1000} height={625} sizes="(max-width: 700px) 90vw, 380px" /><span className="small muted">{article.topic} · {article.minutes} min read</span><h2>{article.title}</h2><p>{article.description}</p><span className="article-byline">{article.author}</span></Link></article>)}</div><Breadcrumbs path="/blog/" title="Field notes" /></div>; }
