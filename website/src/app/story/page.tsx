import Image from "next/image";
import Link from "next/link";
import { ArrowDown, ArrowUpRight, Download, Play } from "lucide-react";
import { Breadcrumbs, JsonLd } from "@/components/shared";
import { MediaCard } from "@/components/media-card";
import { RealFootagePlayer } from "@/components/real-footage-player";
import { catalog } from "@/lib/catalog";
import { realLifeReel } from "@/lib/real-footage";
import { pageMetadata } from "@/lib/metadata";
import { site, sources } from "@/lib/site";
import styles from "./story.module.css";

export const metadata = pageMetadata("/story/");
const wallpapers = ["lights-out", "github-after-hours", "codex-foundry"].map(id => catalog.find(item => item.id === id)!);
const effectCount = catalog.filter(item => item.kind === "effect").length;
const wallpaperCount = catalog.filter(item => item.kind === "wallpaper").length;
const storyFilm = { ...realLifeReel, title: "Give Your Mac a New Look", poster: "/media/story/film-cover.webp", posterAlt: "UnfoldMyMac film: a race-car wallpaper, a miniature city, and a curtain effect. Your Mac. More fun." };

function StoryOrigin() {
  return (
    <header className={styles.hero} id="the-spark">
      <div className={styles.heroCopy}>
        <h1>I only meant to make one effect.</h1>
        <p className={styles.lede}>It started with an animation on a folding phone. It became UnfoldMyMac: live wallpapers and playful desktop effects for your Mac.</p>
        <p>Watching the iPhone Duo open gave me an idea. My MacBook had a hinge, too. What could happen on its screen when I moved it?</p>
        <a className={styles.sourceLink} href="https://www.apple.com/newsroom/2026/09/apple-unveils-iphone-duo/">The iPhone Duo inspiration <ArrowUpRight size={15} aria-hidden="true" /></a>
        <a href="#the-film" className={styles.filmLink}><span><Play size={17} aria-hidden="true" /></span>Watch the story <small>2:30</small></a>
      </div>
      <figure className={styles.art + " " + styles.cover}>
        <Image src="/media/story/the-spark.webp" alt="Comic illustration: a maker looks from a phone to his MacBook as an idea takes shape." width={1672} height={941} sizes="(max-width: 760px) 92vw, 58vw" priority />
        <figcaption><span>The spark</span>What if my Mac did that?</figcaption>
      </figure>
    </header>
  );
}

export default function StoryPage() {
  return <div className={styles.story}>
    <div className={styles.inner}>
      <nav className={styles.breadcrumb} aria-label="Breadcrumb"><Link href="/">UnfoldMyMac</Link><span aria-hidden="true">/</span><span>The story</span></nav>
      <StoryOrigin />
      <nav className={styles.chapters} aria-label="Story chapters">
        <span>Follow the idea <ArrowDown size={16} aria-hidden="true" /></span>
        <a href="#the-experiment">The experiment</a>
        <a href="#a-bigger-idea">A bigger idea</a>
        <a href="#the-film">See it in action</a>
      </nav>
      <section className={styles.chapter + " " + styles.experiment} id="the-experiment" aria-labelledby="experiment-heading">
        <figure className={styles.art}>
          <Image src="/media/story/the-experiment.webp" alt="Comic illustration: the maker lowers his MacBook lid, and purple curtains move across the desktop." width={1672} height={941} sizes="(max-width: 760px) 92vw, 55vw" />
          <figcaption><span>The experiment</span>Move the lid. The desktop follows.</figcaption>
        </figure>
        <div className={styles.chapterCopy}>
          <span className={styles.chapterNumber} aria-hidden="true">01</span>
          <h2 id="experiment-heading">So I tried it on my MacBook.</h2>
          <p>The first experiment was blur: the iPhone Duo frost, redrawn in Metal for a laptop hinge. Lower the lid and the desktop blurs. Lift it and everything comes back. Stop halfway, and the effect stops with you.</p>
          <p>Then came curtains, flowing ribbons, artwork, and characters peeking over my windows. One effect had become a collection.</p>
          <Link className={styles.inlineLink} href="/showcase/#curtains">Meet the {effectCount} lid effects <ArrowUpRight size={18} aria-hidden="true" /></Link>
        </div>
      </section>
      <section className={styles.chapter + " " + styles.worlds} id="a-bigger-idea" aria-labelledby="worlds-heading">
        <div className={styles.chapterCopy}>
          <span className={styles.chapterNumber} aria-hidden="true">02</span>
          <h2 id="worlds-heading">Then I left the lid open.</h2>
          <p>I started making scenes that could keep moving while I worked. A race circuit behind my windows. A little city built from a GitHub profile. A factory that follows coding activity.</p>
          <p>That became the live wallpaper collection. Choose a scene, leave it running, and get on with your day.</p>
          <span className={styles.annotation}>The desktop had plans of its own.</span>
        </div>
        <figure className={styles.art}>
          <Image src="/media/story/a-bigger-idea.webp" alt="Comic illustration: race cars, curtains, windows, and a mischievous character spill from the maker's growing collection of ideas." width={1672} height={941} sizes="(max-width: 760px) 92vw, 55vw" />
          <figcaption><span>A bigger idea</span>Okay, a few more.</figcaption>
        </figure>
      </section>
      <section className={styles.previewSection} aria-labelledby="wallpaper-heading">
        <div className={styles.previewHeading}><div><h2 id="wallpaper-heading">A few things now living on my desktop.</h2><p>These are previews from the app. Pick one to see it move.</p></div><Link className={styles.inlineLink} href="/showcase/#pulse">Explore all {wallpaperCount} wallpapers <ArrowUpRight size={18} aria-hidden="true" /></Link></div>
        <div className={styles.previewGrid}>{wallpapers.map(item => <MediaCard key={item.id} item={item} />)}</div>
      </section>
      <section className={styles.filmSection} id="the-film" aria-labelledby="film-heading">
        <div className={styles.filmHeading}><div><span className={styles.chapterNumber} aria-hidden="true">03</span><h2 id="film-heading">Here’s what that became.</h2><p>The whole story, the collection, and five demos filmed on a real MacBook.</p></div><p className={styles.collectionNote}><strong>{catalog.length} ways to change the scene.</strong><span>{effectCount} lid effects. {wallpaperCount} live wallpapers.</span></p></div>
        <RealFootagePlayer featured item={storyFilm} />
      </section>
      <section className={styles.invitation} aria-labelledby="invitation-heading">
        <Image src="/media/logo.webp" alt="" width={76} height={76} />
        <div><h2 id="invitation-heading">Find your kind of desktop.</h2><p>Start with a look you like. Change it when you feel like it.</p></div>
        <div className={styles.actions}><Link className="button button-primary" href="/download/"><Download size={18} aria-hidden="true" />Get the Mac app</Link><Link href="/showcase/">Browse the collection</Link></div>
      </section>
      <aside className={styles.afterword} aria-label="About this story">
        <div><h2>Have an idea for the next scene?</h2><p>UnfoldMyMac is open source. Share an idea, report a bug, or make something of your own.</p><p><a href={site.repo + "/issues/new/choose"}>Share it on GitHub</a><span aria-hidden="true"> · </span><a href={sources.developing}>Guide for contributors</a></p></div>
        <div><h2>From the sketchbook</h2><p>The three comic scenes were created for the UnfoldMyMac film. The wallpaper previews are rendered by the app with sample data.</p><p><a href={sources.overview}>Read the original story</a><span aria-hidden="true"> · </span><a href={sources.notices}>Artwork & credits</a></p><p><small>iPhone, iOS and Mac are trademarks of Apple Inc. UnfoldMyMac is an independent app from Matterward Labs, not affiliated with, endorsed by, or sponsored by Apple.</small></p></div>
      </aside>
      <JsonLd data={{ "@context": "https://schema.org", "@type": "AboutPage", "@id": `${site.url}/story/#about`, name: "The story behind UnfoldMyMac", description: "How an iPhone Duo animation led to a lid-driven blur on a MacBook, then to a collection of desktop effects and live wallpapers.", url: `${site.url}/story/`, isPartOf: { "@id": `${site.url}/#app` }, about: { "@id": `${site.url}/#app` }, publisher: { "@id": `${site.company}/#organization` } }} />
      <Breadcrumbs path="/story/" title="The story" />
    </div>
  </div>;
}
