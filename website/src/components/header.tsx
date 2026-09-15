"use client";
import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import { Code2, Download, Menu, X } from "lucide-react";
import { libraryCollections } from "@/lib/catalog-routes";
import { navigation, site } from "@/lib/site";
import { ThemeControl } from "./theme";
import { Button } from "./ui/button";
export function Header() {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  return <header className="site-header">
    <div className="header-inner">
      <Link href="/" className="wordmark" onClick={() => setOpen(false)}><Image src="/media/logo.webp" width={36} height={36} alt="" priority />UnfoldMyMac</Link>
      <nav id="main-navigation" aria-label="Main navigation" className={open ? "main-nav is-open" : "main-nav"} onKeyDown={event => { if (event.key === "Escape") { setOpen(false); document.getElementById("menu-toggle")?.focus(); } }}>
        {navigation.map(item => <Link href={item.href} key={item.href} aria-current={pathname.startsWith(item.href) ? "page" : item.href === "/showcase/" && libraryCollections.some(collection => pathname.startsWith(`/${collection.slug}/`)) ? "location" : undefined} onClick={() => setOpen(false)}>{item.label}</Link>)}<a href={site.repo} className="nav-github">GitHub</a>
      </nav>
      <div className="header-actions"><a href={site.repo} className="header-github" aria-label="UnfoldMyMac on GitHub" title="UnfoldMyMac on GitHub"><Code2 size={17} aria-hidden="true" /></a><ThemeControl /><Button asChild size="small"><Link href="/download/" aria-label="Get the app"><Download size={15} aria-hidden="true" /><span>Get the app</span></Link></Button>
        <button id="menu-toggle" className="menu-toggle" type="button" aria-label={open ? "Close menu" : "Open menu"} aria-expanded={open} aria-controls="main-navigation" onClick={() => setOpen(!open)}>{open ? <X /> : <Menu />}</button>
      </div>
    </div>
  </header>;
}
