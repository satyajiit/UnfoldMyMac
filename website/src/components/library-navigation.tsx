import Link from "next/link";
import { catalog } from "@/lib/catalog";
import { libraryCollections, collectionPath, categoryPath, type LibraryCollection, type LibraryCategory } from "@/lib/catalog-routes";
import { JsonLd } from "./shared";
import { site } from "@/lib/site";
import styles from "./library.module.css";

export function LibraryNavigation({ collection, categories = [], category }: { collection?: LibraryCollection; categories?: LibraryCategory[]; category?: LibraryCategory }) {
  return <div className={styles.navigation}>
    <nav className={styles.collections} aria-label="Design collections">
      <Link href="/showcase/" aria-current={!collection ? "page" : undefined}>All designs <span>{catalog.length}</span></Link>
      {libraryCollections.map(entry => <Link key={entry.id} href={collectionPath(entry)} aria-current={entry.id === collection?.id ? "page" : undefined}>{entry.name}<span>{catalog.filter(item => item.kind === entry.id).length}</span></Link>)}
    </nav>
    {collection && <nav className={styles.categories} aria-label={`${collection.name} categories`}>
      <Link href={collectionPath(collection)} aria-current={!category ? "page" : undefined}>All categories</Link>
      {categories.map(entry => <Link key={entry.id} href={categoryPath(collection, entry)} aria-current={entry.id === category?.id ? "page" : undefined}>{entry.name}</Link>)}
    </nav>}
  </div>;
}

export function LibraryBreadcrumbs({ trail }: { trail: { title: string; path: string }[] }) {
  const crumbs = [{ title: "Home", path: "/" }, { title: "Showcase", path: "/showcase/" }, ...trail];
  return <><nav className={styles.breadcrumbs} aria-label="Breadcrumb"><ol>{crumbs.map((crumb, index) => <li key={crumb.path}>{index === crumbs.length - 1 ? <span aria-current="page">{crumb.title}</span> : <Link href={crumb.path}>{crumb.title}</Link>}</li>)}</ol></nav>
    <JsonLd data={{ "@context": "https://schema.org", "@type": "BreadcrumbList", itemListElement: crumbs.map((crumb, index) => ({ "@type": "ListItem", position: index + 1, name: crumb.title, item: `${site.url}${crumb.path}` })) }} />
  </>;
}
