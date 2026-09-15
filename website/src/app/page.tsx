import { AppDiscovery } from "@/components/app-discovery";
import { CreativeScenesSection } from "@/components/creative-scenes";
import { GamingFilmSection } from "@/components/gaming-film";
import { LockScreenSection } from "@/components/lock-screen-section";
import { OpenSourceSection } from "@/components/open-source-section";
import Link from "next/link";
import Image from "next/image";
import { Download, ArrowUpRight, SlidersHorizontal, Laptop, Sparkles, Code2 } from "lucide-react";
import { RealLifeSection } from "@/components/real-life-section";
import { CollectionCarousel } from "@/components/collection-carousel";
import { HomeQuestions, LidSetupSection, NativeMacSection } from "@/components/home-details";
import { WallpaperConnections, WallpaperWorkshop } from "@/components/wallpaper-workshop";
import { LidDemo } from "@/components/lid-demo";
import { MediaCard } from "@/components/media-card";
import { Button } from "@/components/ui/button";
import { DownloadCTA, JsonLd } from "@/components/shared";
import { featured, catalog } from "@/lib/catalog";
import { pageMetadata } from "@/lib/metadata";
import { site, release } from "@/lib/site";
import heroStyles from "./home-hero.module.css";
export const metadata = pageMetadata("/");
export default function Home() {
  return <div className="container"><section className={heroStyles.hero} aria-labelledby="hero-heading">
    <div className={heroStyles.intro}>
      <div className={heroStyles.title}><p className={heroStyles.eyebrow}>UnfoldMyMac for macOS</p><h1 id="hero-heading">A little more life<br />on your Mac.</h1></div>
      <div className={heroStyles.copy}><p>Lid Effects that follow your MacBook. Dynamic Wallpapers that react to your work. Creative Scenes that respond to your world. All in one native Mac app.</p>
        <div className={heroStyles.actions}><Button asChild><Link href="/download/"><Download size={17} aria-hidden="true" />Get UnfoldMyMac</Link></Button><Button asChild variant="secondary"><Link href="/showcase/">Explore the collection <ArrowUpRight size={16} aria-hidden="true" /></Link></Button></div>
        <span className={heroStyles.footnote}>macOS 26+ · <a href={site.repo}>Open source</a> · Made by <a href={site.company}>Matterward Labs</a></span>
      </div>
    </div><LidDemo />
    </section>
    <div className="feature-strip"><span><Laptop aria-hidden="true" />Follows your MacBook lid</span><span><Sparkles aria-hidden="true" />Three collections. {catalog.length} designs.</span><span><SlidersHorizontal aria-hidden="true" />Make it your own</span><span><Code2 aria-hidden="true" />Open source · SwiftUI, AppKit & Metal</span></div>
    <AppDiscovery />
    <LidSetupSection />
    <RealLifeSection />
    <CollectionCarousel />
    <section className="section"><div className="section-heading"><div><h2>Closing time has character.</h2><p>Curtains, curious faces, and a little moonlit escape.<br />Choose what happens when your lid comes down.</p></div><Link className="text-link" href="/lid-effects/">See every effect <ArrowUpRight size={16} aria-hidden="true" /></Link></div><div className="featured-grid">{featured.map(item => <MediaCard key={item.id} item={item} featured />)}</div></section>
    <section className="wallpaper-section"><div className="wallpaper-copy"><span className="section-context">Dynamic Wallpapers</span><h2>Leave it open.{" "}<br />There’s a whole{" "}<br />world in there.</h2><p>A sculpture moves with your Mac’s workload. A robot follows your coding sessions. Your GitHub profile becomes a city.</p><p>Twenty wallpapers, including ten game worlds with useful live features. Track your battery with Wolverine, focus at a Site of Grace, or follow the wind through Tsushima.</p><Link href="/dynamic-wallpapers/" className="text-link">Meet your next wallpaper <ArrowUpRight size={16} aria-hidden="true" /></Link></div><div className="wallpaper-preview"><MediaCard item={catalog.find(item => item.id === "codex-mission-control")!} /></div></section>
    <GamingFilmSection />
    <LockScreenSection />
    <CreativeScenesSection />
    <WallpaperConnections />
    <NativeMacSection />
    <OpenSourceSection />
    <section className="story-teaser"><div><span className="section-context">The story behind the app</span><h2>It was supposed to be<br />one effect.</h2><p>Then came curtains. Then characters. Then a small robot had opinions about a coding session. This is what happens when a side project finds the lid sensor.</p><Link href="/story/" className="text-link">Read how it started <ArrowUpRight size={16} aria-hidden="true" /></Link></div><Image src="/media/origin-comic.webp" alt="A comic showing one lid effect growing into a collection of effects and live wallpapers" width={1400} height={467} sizes="(max-width: 800px) 90vw, 600px" /></section>
    <WallpaperWorkshop />
    <HomeQuestions />
    <DownloadCTA /><JsonLd data={{ "@context": "https://schema.org", "@type": "SoftwareApplication", "@id": `${site.url}/#app`, name: site.name, description: site.description, url: site.url, operatingSystem: "macOS 26 or later", applicationCategory: "DesktopEnhancementApplication", author: { "@type": "Organization", "@id": `${site.company}/#organization`, name: site.author, url: site.company }, publisher: { "@id": `${site.company}/#organization` }, sameAs: [site.repo], license: "https://www.apache.org/licenses/LICENSE-2.0", alternateName: "Unfold My Mac", keywords: site.keywords.join(", "), isAccessibleForFree: true, softwareRequirements: "macOS 26 or later on Apple silicon", featureList: ["Lid Effects that follow the MacBook lid angle", "Dynamic Wallpapers and Creative Scenes on the desktop", "Wallpaper provider extension for the macOS 26 lock screen and screen saver", "Optional local and public data connections"], ...(release.status === "available" && release.version ? { softwareVersion: release.version, offers: { "@type": "Offer", price: "0", priceCurrency: "USD", availability: "https://schema.org/InStock", url: `${site.url}/download/` } } : {}) }} /><JsonLd data={{ "@context": "https://schema.org", "@type": "SoftwareSourceCode", "@id": `${site.url}/#source`, name: "UnfoldMyMac source code", description: "Swift 6 sources, Metal shaders, and documentation for UnfoldMyMac, published under the Apache 2.0 license.", codeRepository: site.repo, programmingLanguage: "Swift", runtimePlatform: "macOS 26", license: "https://www.apache.org/licenses/LICENSE-2.0", targetProduct: { "@id": `${site.url}/#app` }, author: { "@id": `${site.company}/#organization` }, publisher: { "@id": `${site.company}/#organization` } }} />
  </div>;
}
