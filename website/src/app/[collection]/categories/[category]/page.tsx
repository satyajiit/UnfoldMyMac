import { notFound } from "next/navigation";
import { libraryCollections, categoryPath } from "@/lib/catalog-routes";
import { collectionCategories } from "@/lib/design-content";
import { CollectionPage } from "@/components/library-pages";
import { pageMetadata } from "@/lib/metadata";

export const dynamicParams = false;
export function generateStaticParams() {
  return libraryCollections.flatMap(collection => collectionCategories(collection).map(category => ({ collection: collection.slug, category: category.slug })));
}
type Props = { params: Promise<{ collection: string; category: string }> };
async function resolveCategory({ params }: Props) {
  const slugs = await params;
  const collection = libraryCollections.find(collection => collection.slug === slugs.collection) ?? notFound();
  const category = collectionCategories(collection).find(category => category.slug === slugs.category) ?? notFound();
  return { collection, category };
}
export async function generateMetadata(props: Props) {
  const { collection, category } = await resolveCategory(props);
  return pageMetadata(categoryPath(collection, category), `${category.name} — ${collection.name}`, category.description);
}
export default async function Page(props: Props) { return <CollectionPage {...await resolveCategory(props)} />; }
