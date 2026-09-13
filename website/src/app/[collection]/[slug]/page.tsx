import { notFound } from "next/navigation";
import { collectionFor, designPath } from "@/lib/catalog-routes";
import { designs } from "@/lib/design-content";
import { DesignPage } from "@/components/library-pages";
import { pageMetadata } from "@/lib/metadata";

export const dynamicParams = false;
export function generateStaticParams() { return designs.map(({ item }) => ({ collection: collectionFor(item).slug, slug: item.id })); }
type Props = { params: Promise<{ collection: string; slug: string }> };
async function resolveDesign({ params }: Props) {
  const { collection, slug } = await params;
  return designs.find(({ item }) => item.id === slug && collectionFor(item).slug === collection) ?? notFound();
}
export async function generateMetadata(props: Props) {
  const { item } = await resolveDesign(props);
  return pageMetadata(designPath(item), `${item.name} — ${collectionFor(item).name.slice(0, -1)} for Mac`, item.description, { url: item.poster, alt: `${item.name} in UnfoldMyMac` });
}
export default async function Page(props: Props) { return <DesignPage design={await resolveDesign(props)} />; }
