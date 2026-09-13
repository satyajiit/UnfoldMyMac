import { notFound } from "next/navigation";
import { libraryCollections, collectionPath } from "@/lib/catalog-routes";
import { CollectionPage } from "@/components/library-pages";
import { pageMetadata } from "@/lib/metadata";

export const dynamicParams = false;
export function generateStaticParams() { return libraryCollections.map(({ slug }) => ({ collection: slug })); }
type Props = { params: Promise<{ collection: string }> };
async function resolveCollection({ params }: Props) {
  const { collection: slug } = await params;
  return libraryCollections.find(collection => collection.slug === slug) ?? notFound();
}
export async function generateMetadata(props: Props) {
  const collection = await resolveCollection(props);
  return pageMetadata(collectionPath(collection), `${collection.name} for Mac`, collection.description);
}
export default async function Page(props: Props) { return <CollectionPage collection={await resolveCollection(props)} />; }
