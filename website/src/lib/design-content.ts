// Build-time only: share the app's editorial content without shipping native resources to the browser.
import { readFileSync } from "node:fs";
import path from "node:path";
import { catalog, type ShowcaseItem } from "./catalog";
import { categoryPath, collectionPath, designPath, libraryCategories, libraryCollections, type LibraryCollection, type LibraryCategory } from "./catalog-routes";

interface NativeDesign {
  id: string; title: string; detail?: string; category?: string; tags: string[];
  capabilities?: { requiresCapture?: boolean; continuousMotion?: boolean };
  parameters?: { title: string }[];
  metadata?: { overview: string; sections?: { title: string; body: string }[]; authors?: { name: string; role: string; url?: string }[] };
  author?: string; credit?: string;
}
export interface DesignContent {
  item: ShowcaseItem; category: LibraryCategory; overview: string;
  sections: { title: string; body: string }[]; tags: string[];
  authors: { name: string; role: string; url?: string }[]; credit?: string;
}
const resources = path.resolve(process.cwd(), "../UnfoldMyMac/Sources/UnfoldMyMacKit/Resources");
function readNative<T>(file: string): T { return JSON.parse(readFileSync(path.join(resources, file), "utf8")) as T; }
const effects = readNative<{ effects: NativeDesign[] }>("Effects/Effects.json").effects;
const artworks = readNative<NativeDesign[]>("Library/Artworks.json");

function loadDesign(item: ShowcaseItem): DesignContent {
  const native = item.kind === "effect"
    ? [...effects, ...artworks].find(entry => entry.id === item.id)
    : readNative<NativeDesign>(`Wallpapers/${item.id}/template.json`);
  if (!native) throw new Error(`Missing app content for ${item.id}`);
  const category = libraryCategories.find(category => category.id === (native.category ?? "image"));
  if (!category) throw new Error(`Missing category for ${item.id}`);
  const overview = native.metadata?.overview ?? native.detail;
  if (!overview) throw new Error(`Missing description for ${item.id}`);
  const sections = [...(native.metadata?.sections ?? [])];
  if (item.kind === "effect") {
    if (native.parameters?.length) sections.push({ title: "Find your setting", body: `Open Adjust to tune ${native.parameters.map(parameter => parameter.title.toLowerCase()).join(", ")}. Preview the result in the app before enabling the effect.` });
    sections.push({ title: "On your Mac", body: native.capabilities?.requiresCapture
      ? "Frost uses Screen Recording permission to blur a live view of your desktop. Enable it in macOS System Settings when the app asks. Desktop capture stays on your Mac."
      : "This effect does not need Screen Recording permission. It draws over your desktop as your MacBook lid moves." });
  }
  return { item, category, overview, sections, tags: native.tags,
    authors: native.metadata?.authors ?? [{ name: native.author ?? "UnfoldMyMac", role: "Design & development" }], credit: native.credit };
}
export const designs = catalog.map(loadDesign);
export function collectionDesigns(collection: LibraryCollection, category?: LibraryCategory) {
  return designs.filter(design => design.item.kind === collection.id && (!category || design.category.id === category.id));
}
export function collectionCategories(collection: LibraryCollection) {
  return libraryCategories.filter(category => collectionDesigns(collection, category).length > 0);
}
export const libraryRoutes = libraryCollections.flatMap(collection => [
  { path: collectionPath(collection), title: `${collection.name} for Mac`, description: collection.description },
  ...collectionCategories(collection).map(category => ({ path: categoryPath(collection, category), title: `${category.name} — ${collection.name}`, description: category.description })),
  ...collectionDesigns(collection).map(({ item }) => ({ path: designPath(item), title: `${item.name} — ${collection.name.slice(0, -1)} for Mac`, description: item.description })),
]);
