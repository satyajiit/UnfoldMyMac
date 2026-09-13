import Link from "next/link";
import { ArrowUpRight, Download } from "lucide-react";
import { collectionCategories, collectionDesigns, type DesignContent } from "@/lib/design-content";
import { collectionPath, collectionFor, categoryPath, designPath, type LibraryCollection, type LibraryCategory } from "@/lib/catalog-routes";
import { site } from "@/lib/site";
import { MediaCard } from "./media-card";
import { DownloadCTA, JsonLd } from "./shared";
import { LibraryNavigation, LibraryBreadcrumbs } from "./library-navigation";
import { Button } from "./ui/button";
import styles from "./library.module.css";

const collectionGuides = {
  effect: { title: "Made for the moment you close your Mac.", body: "Lid Effects appear over your desktop as your MacBook opens and closes. Choose a design, try the preview, and tune its settings in Adjust. Automatic movement needs a readable lid-angle sensor; support varies by MacBook model.", href: "/blog/lid-effects/", link: "Read the Lid Effects guide" },
  wallpaper: { title: "A desktop with something to do.", body: "Dynamic Wallpapers live behind your windows. Some use readings from your Mac; others connect to local coding tools, a public profile, or a weather service. Each design explains what it reads and which connections you can choose.", href: "/blog/connecting-your-data/", link: "Learn about data connections" },
  scene: { title: "Small worlds, at home on your Mac.", body: "Creative Scenes turn your desktop into an interactive place. Your lid and charger shape the atmosphere, with optional inputs and customization for each world. Open a design to explore how it moves and what brings it to life.", href: "/blog/live-wallpapers/", link: "Read the desktop setup guide" },
};

export function CollectionPage({ collection, category }: { collection: LibraryCollection; category?: LibraryCategory }) {
  const entries = collectionDesigns(collection, category);
  const url = category ? categoryPath(collection, category) : collectionPath(collection);
  const title = category?.name ?? collection.name;
  const description = category?.description ?? collection.description;
  const guide = collectionGuides[collection.id];
  const trail = [{ title: collection.name, path: collectionPath(collection) }, ...(category ? [{ title: category.name, path: url }] : [])];
  return <div className="container">
    <LibraryBreadcrumbs trail={trail} />
    <div className={styles.intro}><h1>{title}</h1><p>{description}</p></div>
    <LibraryNavigation collection={collection} categories={collectionCategories(collection)} category={category} />
    <section aria-label="Design library"><h2 className="sr-only">{title} designs</h2><p className={styles.count}>{entries.length} {entries.length === 1 ? "design" : "designs"} · Preview the motion, or open a design to explore.</p>
      <div className={`showcase-grid ${entries.length === 1 ? styles.singleGrid : entries.length === 2 ? styles.smallGrid : ""}`}>{entries.map(({ item }) => <MediaCard key={item.id} item={item} />)}</div>
    </section>
    <section className={styles.guide}><h2>{guide.title}</h2><div><p>{guide.body}</p><p><Link href={guide.href}>{guide.link} →</Link></p></div></section>
    <DownloadCTA />
    <JsonLd data={{ "@context": "https://schema.org", "@type": "CollectionPage", name: title, description, url: `${site.url}${url}`, mainEntity: { "@type": "ItemList", numberOfItems: entries.length, itemListElement: entries.map(({ item }, index) => ({ "@type": "ListItem", position: index + 1, url: `${site.url}${designPath(item)}`, name: item.name })) } }} />
  </div>;
}

// Native descriptions use paragraphs, bold emphasis, and links. React escapes all text.
function Description({ text }: { text: string }) {
  return text.split(/\n\s*\n/).map((paragraph, index) => <p key={index}>{paragraph.split(/(\*\*[^*]+\*\*|\[[^\]]+\]\(https?:\/\/[^)]+\))/g).map((part, index) => {
    if (part.startsWith("**")) return <strong key={index}>{part.slice(2, -2)}</strong>;
    const link = part.match(/^\[([^\]]+)\]\((https?:\/\/[^)]+)\)$/);
    return link ? <a key={index} href={link[2]}>{link[1]}</a> : part;
  })}</p>);
}

export function DesignPage({ design }: { design: DesignContent }) {
  const { item, category } = design;
  const collection = collectionFor(item);
  const related = collectionDesigns(collection).filter(entry => entry.item.id !== item.id)
    .sort((a, b) => Number(b.category.id === category.id) - Number(a.category.id === category.id)).slice(0, 3);
  const trail = [{ title: collection.name, path: collectionPath(collection) }, { title: category.name, path: categoryPath(collection, category) }, { title: item.name, path: designPath(item) }];
  return <div className="container">
    <LibraryBreadcrumbs trail={trail} />
    <LibraryNavigation collection={collection} categories={collectionCategories(collection)} category={category} />
    <div className={styles.hero}>
      <MediaCard item={item} previewOnly />
      <div className={styles.heroCopy}>
        <Link href={categoryPath(collection, category)} className={styles.eyebrow}>{category.name} / {collection.name}</Link>
        <h1>{item.name}</h1><p>{item.description}</p>
        <div className={styles.actions}><Button asChild><Link href="/download/"><Download size={17} aria-hidden="true" />Get UnfoldMyMac</Link></Button></div>
        <p className={styles.requirement}>Included in UnfoldMyMac · macOS 26 or later</p>
      </div>
    </div>
    <div className={styles.content}>
      <article className={styles.copy}><h2>Inside {item.name}</h2><Description text={design.overview} />
        {design.sections.map(section => <section key={section.title}><h3>{section.title}</h3><Description text={section.body} /></section>)}
      </article>
      <aside className={styles.details} aria-label="Design details">
        <h2>Bring it to your desktop.</h2>
        <ol><li>Get UnfoldMyMac and open <strong>{collection.name}</strong>.</li><li>Choose <strong>{item.name}</strong> and try the preview.</li><li>{item.kind === "effect" ? "Tune the design in Adjust, then enable the effect. Automatic lid response requires a supported MacBook sensor." : "Choose Use to apply it. Open Customize for available options and connections, then Show Desktop to see it behind your windows."}</li></ol>
        <dl className={styles.facts}><div><dt>Collection</dt><dd><Link href={collectionPath(collection)}>{collection.name}</Link></dd></div><div><dt>Category</dt><dd><Link href={categoryPath(collection, category)}>{category.name}</Link></dd></div><div><dt>Platform</dt><dd>macOS 26+</dd></div>
          {design.authors.map(author => <div key={`${author.name}-${author.role}`}><dt>{author.role}</dt><dd>{author.url ? <a href={author.url}>{author.name}</a> : author.name}</dd></div>)}
        </dl>
        <ul className={styles.tags} aria-label="Design features">{design.tags.map(tag => <li key={tag}>{tag}</li>)}</ul>
        {design.credit && <p className="small muted">{design.credit}</p>}
        <p className="small"><Link href={collectionGuides[item.kind].href}>Setup guide</Link><span aria-hidden="true"> · </span><Link href="/privacy/">About your data</Link></p>
      </aside>
    </div>
    {related.length > 0 && <section className={styles.related} aria-labelledby="related-designs"><div><h2 id="related-designs">More {collection.name.toLowerCase()}.</h2><Link href={collectionPath(collection)}>Explore the collection <ArrowUpRight size={16} aria-hidden="true" style={{ display: "inline" }} /></Link></div><div className="showcase-grid">{related.map(({ item }) => <MediaCard key={item.id} item={item} />)}</div></section>}
    <JsonLd data={{ "@context": "https://schema.org", "@type": "CreativeWork", "@id": `${site.url}${designPath(item)}#design`, name: item.name, description: item.description, url: `${site.url}${designPath(item)}`, image: `${site.url}${item.poster}`, genre: category.name, keywords: design.tags.join(", "), isPartOf: { "@type": "CreativeWork", name: collection.name, url: `${site.url}${collectionPath(collection)}` }, mainEntityOfPage: `${site.url}${designPath(item)}` }} />
  </div>;
}
