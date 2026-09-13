"use client";

import Image from "next/image";
import { useState } from "react";
import { ArrowLeft, ArrowRight, Layers } from "lucide-react";
import { catalog } from "@/lib/catalog";
import { MediaCard } from "@/components/media-card";

export function CollectionCarousel() {
  const [index, setIndex] = useState(0);
  const item = catalog[index];
  function select(next: number) {
    const selected = (next + catalog.length) % catalog.length;
    setIndex(selected);
    document.getElementById(`collection-tab-${catalog[selected].id}`)?.scrollIntoView({ block: "nearest", inline: "nearest", behavior: "instant" });
  }
  return <section id="every-preview" className="collection-carousel" aria-labelledby="collection-title" aria-roledescription="carousel">
    <div className="section-heading"><div>
      <span className="real-life-eyebrow"><Layers size={16} aria-hidden="true" />The whole collection</span>
      <h2 id="collection-title">Every mood. Every preview.</h2>
      <p>All {catalog.filter(item => item.kind === "effect").length} lid effects and {catalog.filter(item => item.kind === "wallpaper").length} dynamic wallpapers, plus Hinge Garden in Creative Scenes. Find your desktop personality.</p>
    </div><div className="collection-controls">
      <button type="button" aria-label="Previous animation" onClick={() => select(index - 1)}><ArrowLeft size={20} aria-hidden="true" /></button>
      <span aria-live="polite" aria-atomic="true">{String(index + 1).padStart(2, "0")} / {catalog.length}</span>
      <button type="button" aria-label="Next animation" onClick={() => select(index + 1)}><ArrowRight size={20} aria-hidden="true" /></button>
    </div></div>
    <div className="collection-stage" role="group" aria-roledescription="slide" aria-label={`${index + 1} of ${catalog.length}: ${item.name}`}>
      <MediaCard key={item.id} item={{ ...item, id: `collection-preview-${item.id}` }} previewLabel={`${item.name} collection`} featured />
    </div>
    <div className="collection-rail" aria-label="Choose an animation">
      {catalog.map((preview, position) => <button type="button" id={`collection-tab-${preview.id}`} key={preview.id} aria-label={`Show ${preview.name}`} aria-pressed={position === index} onClick={() => select(position)}>
        <Image src={preview.poster} alt="" width={120} height={75} sizes="120px" />
        <span>{preview.name}</span>
      </button>)}
    </div>
    <p className="collection-note">Choose a design. Where a recording is available, press Preview to play. Wallpapers and Hinge Garden show representative data.</p>
  </section>;
}
