import { collections, type ShowcaseItem } from "./catalog";

export const libraryCollections = collections.map(collection => ({
  ...collection,
  slug: collection.id === "wallpaper" ? "dynamic-wallpapers" : collection.anchor,
}));
export type LibraryCollection = (typeof libraryCollections)[number];
export interface LibraryCategory {
  id: string; slug: string; name: string; description: string;
}
export const libraryCategories: LibraryCategory[] = [
  { id: "motion", slug: "motion-3d", name: "Motion & 3D", description: "Velvet curtains, curious faces, and luminous ribbons. These MacBook lid effects give opening and closing a little character." },
  { id: "glass", slug: "glass-light", name: "Glass & Light", description: "A live desktop blur, translucent material, or a gentle fade. Explore three quieter ways to close your MacBook." },
  { id: "image", slug: "image-art", name: "Image Art", description: "Paper worlds, pixel art, and posters with opinions. Illustrated lid effects part to reveal your Mac desktop." },
  { id: "mac", slug: "your-mac", name: "Your Mac", description: "Let your desktop show how your Mac is doing. Local CPU, memory, and battery readings give these wallpapers their rhythm." },
  { id: "ai", slug: "ai-companions", name: "AI companions", description: "Robots, sculptures, and a playful black hole for your coding desk. Explore local Claude and Codex activity, plus a Grok-themed tribute." },
  { id: "code", slug: "code-community", name: "Code & community", description: "Give the work you share a place on your desktop. Public GitHub profiles become a city of repositories, followers, and activity." },
  { id: "art", slug: "art-image", name: "Art & image", description: "A moving composition with room for your own image. Make a personal desktop from artwork, glass, and a little typography." },
  { id: "play", slug: "games-sport", name: "Games & sport", description: "Return to a favorite world between tasks. Explore game-inspired Mac wallpapers with useful live features, racing atmosphere, and a GTA VI countdown." },
  { id: "space", slug: "space-science", name: "Space & science", description: "A small observatory behind your windows. NOAA space weather and NASA Earth imagery inspire a moving view of our planet." },
  { id: "work", slug: "work-play", name: "Work & play", description: "Make room for a little encouragement. A miniature workshop turns open apps into lit benches and your chosen folder’s items into parcels." },
  { id: "nature", slug: "nature-atmosphere", name: "Nature & atmosphere", description: "A small living world for your Mac. Explore a greenhouse that wakes with your lid, follows the light, and responds to optional sound." },
];
export function collectionPath(collection: LibraryCollection) { return `/${collection.slug}/`; }
export function categoryPath(collection: LibraryCollection, category: LibraryCategory) {
  return `${collectionPath(collection)}categories/${category.slug}/`;
}
export function collectionFor(item: ShowcaseItem) { return libraryCollections.find(collection => collection.id === item.kind)!; }
export function designPath(item: ShowcaseItem) { return `${collectionPath(collectionFor(item))}${item.id}/`; }
