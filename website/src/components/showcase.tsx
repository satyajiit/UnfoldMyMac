import { catalog } from "@/lib/catalog";
import { MediaCard } from "./media-card";
import { LibraryNavigation } from "./library-navigation";
export function Showcase() {
  return <section className="showcase-library" aria-label="Design library">
    <h2 className="sr-only">Browse all designs</h2>
    <LibraryNavigation />
    <p className="result-count small muted">{catalog.length} designs · Preview the motion, or open a design to explore.</p>
    <div className="showcase-grid">{catalog.map(item => <MediaCard key={item.id} item={item} />)}</div>
  </section>;
}
