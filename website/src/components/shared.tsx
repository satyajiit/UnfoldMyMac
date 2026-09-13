import Link from "next/link";
import Image from "next/image";
import { Download, Code2 } from "lucide-react";
import { site, sources } from "@/lib/site";
import { Button } from "./ui/button";
export function JsonLd({ data }: { data: Record<string, unknown> }) {
  return <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(data).replace(/</g, "\\u003c") }} />;
}
export function PageIntro({ title, description, label }: { title: string; description: string; label: string }) {
  return <div className="page-intro"><Link href="/" className="back-link">UnfoldMyMac</Link><span className="intro-separator">/</span><span className="muted">{label}</span><h1>{title}</h1><p className="lede">{description}</p></div>;
}
export function Breadcrumbs({ title, path }: { title: string; path: string }) {
  return <JsonLd data={{ "@context": "https://schema.org", "@type": "BreadcrumbList", itemListElement: [
    { "@type": "ListItem", position: 1, name: "UnfoldMyMac", item: site.url },
    { "@type": "ListItem", position: 2, name: title, item: `${site.url}${path}` },
  ] }} />;
}
export function Sources({ children }: { children?: React.ReactNode }) {
  return <aside className="sources" aria-label="Sources"><h2>Sources & further reading</h2>{children ?? <p>Product details come from the <a href={sources.overview}>project README</a> and <a href={sources.app}>app documentation</a>. The code and documentation are open for inspection.</p>}</aside>;
}
export function DownloadCTA() {
  return <section className="download-cta"><div><Image src="/media/logo.webp" width={68} height={68} alt="" /><h2>Your Mac has a dramatic side.</h2><p>Give it a curtain call. Or a very small robot.</p></div><div className="cta-actions"><Button asChild><Link href="/download/"><Download size={18} aria-hidden="true" />Get UnfoldMyMac</Link></Button><span className="muted small">For macOS 26 and later</span></div></section>;
}
export function Footer() {
  return <footer className="site-footer"><div className="footer-main"><div><Link href="/" className="wordmark"><Image src="/media/logo.webp" width={30} height={30} alt="" />UnfoldMyMac</Link><p>A little more life on your desktop.</p><div className="footer-studio"><span>Made by</span><a href={site.company} className="matterward-logo" aria-label="Matterward Labs"><Image className="matterward-logo-light" src="/brand/matterward/lockup-c-horizontal-on-light.svg" width={160} height={40} alt="" /><Image className="matterward-logo-dark" src="/brand/matterward/lockup-c-horizontal-on-dark.svg" width={160} height={40} alt="" /></a></div></div>
    <nav aria-label="Footer navigation"><Link href="/lid-effects/">Lid Effects</Link><Link href="/dynamic-wallpapers/">Dynamic Wallpapers</Link><Link href="/creative-scenes/">Creative Scenes</Link><Link href="/download/">Get the app</Link><Link href="/faq/">FAQ</Link><Link href="/privacy/">Privacy</Link><Link href="/legal/">Legal</Link><a href="/sitemap.xml">Sitemap</a><a href={site.repo}><Code2 size={16} aria-hidden="true" /> GitHub</a></nav></div>
    <div className="footer-bottom"><span>© 2026 <a href={site.company}>Matterward Labs Private Limited</a></span><span><a href={sources.license}>Apache 2.0</a><span aria-hidden="true"> · </span><a href={sources.notices}>Credits & notices</a></span></div>
  </footer>;
}
