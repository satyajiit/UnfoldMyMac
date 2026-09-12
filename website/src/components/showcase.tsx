"use client";
import { useState } from "react";
import { catalog } from "@/lib/catalog";
import { MediaCard } from "./media-card";
export function Showcase() {
  const [category, setCategory] = useState("All designs");
  const filters = ["All designs", "Motion & 3D", "Glass & Light", "Image Art", "Live wallpaper"];
  const items = category === "All designs" ? catalog : catalog.filter(item => item.category === category);
  return <><div className="filter-bar" role="group" aria-label="Filter showcase">{filters.map(filter => <button key={filter} type="button" aria-pressed={category === filter} onClick={() => setCategory(filter)}>{filter}</button>)}</div><p className="result-count small muted" aria-live="polite">{items.length} designs · Select Preview to play an app render.</p><div className="showcase-grid">{items.map(item => <MediaCard key={item.id} item={item} />)}</div></>;
}
