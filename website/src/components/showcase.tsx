"use client";
import { useState } from "react";
import { catalog, collections } from "@/lib/catalog";
import { MediaCard } from "./media-card";
export function Showcase() {
  const [collection, setCollection] = useState("all");
  const [category, setCategory] = useState("All styles");
  const items = catalog.filter(item => (collection === "all" || item.kind === collection) && (collection !== "effect" || category === "All styles" || item.category === category));
  return <section className="showcase-library" aria-label="Design library">
    <div className="filter-bar" role="group" aria-label="Filter showcase">
      {[{ id: "all", name: "All designs" }, ...collections].map(filter => <button key={filter.id} type="button" aria-pressed={collection === filter.id} onClick={() => { setCollection(filter.id); setCategory("All styles"); }}>{filter.name}{filter.id === "scene" && <span className="new-badge">New</span>}</button>)}
    </div>
    {collection === "effect" && <div className="filter-bar" role="group" aria-label="Filter lid effect styles">{["All styles", "Motion & 3D", "Glass & Light", "Image Art"].map(style => <button key={style} type="button" aria-pressed={category === style} onClick={() => setCategory(style)}>{style}</button>)}</div>}
    <p className="result-count small muted" aria-live="polite">{items.length} {items.length === 1 ? "design" : "designs"} · Native app renders. Select Preview where a recording is available.</p>
    <div className="showcase-grid">{items.map(item => <MediaCard key={item.id} item={item} />)}</div>
  </section>;
}
