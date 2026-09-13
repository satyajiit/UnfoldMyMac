"use client";

import Image from "next/image";
import Link from "next/link";
import { useState } from "react";
import { libraryCollections as collections, collectionPath } from "@/lib/catalog-routes";
import styles from "./app-discovery.module.css";

const screens = { effect: "effects", wallpaper: "wallpaper", scene: "scenes" };

export function AppDiscovery() {
  const [selected, setSelected] = useState<(typeof collections)[number]>(collections[0]);
  return <section id="discover" className={styles.discovery} aria-labelledby="discovery-heading">
    <div className={styles.heading}>
      <h2 id="discovery-heading">Three ways to<br />make it yours.</h2>
      <p>A new home for the whole collection. Find a design by category, tag, creator, or the things it reacts to. Take a closer look before bringing it to your desktop.</p>
    </div>
    <div className={styles.tabs} role="group" aria-label="Explore app collections">
      {collections.map(collection => <button type="button" key={collection.id} aria-pressed={selected.id === collection.id} aria-controls="collection-screen" onClick={() => setSelected(collection)}>
        {collection.name}{collection.id === "scene" && <span className={styles.badge}>New</span>}
      </button>)}
    </div>
    <figure id="collection-screen" className={styles.screen}>
      <Image className={styles.light} src={`/media/discovery/${screens[selected.id]}-light.webp`} alt={`${selected.name} in the redesigned UnfoldMyMac app, light appearance`} width={2240} height={1560} sizes="(max-width: 800px) 94vw, 1160px" />
      <Image className={styles.dark} src={`/media/discovery/${screens[selected.id]}-dark.webp`} alt={`${selected.name} in the redesigned UnfoldMyMac app, dark appearance`} width={2240} height={1560} sizes="(max-width: 800px) 94vw, 1160px" />
      <figcaption aria-live="polite"><span>{selected.description}</span><Link href={collectionPath(selected)}>Explore {selected.name}</Link></figcaption>
    </figure>
    <div className={styles.details}>
      <div className={styles.detailScreen}>
        <Image className={styles.light} src="/media/discovery/detail-light.webp" alt="Claude Current details, with the title and Claude usage above the actual design preview and actions below it" width={1680} height={2000} sizes="(max-width: 700px) 90vw, 500px" />
        <Image className={styles.dark} src="/media/discovery/detail-dark.webp" alt="Claude Current design details in dark appearance" width={1680} height={2000} sizes="(max-width: 700px) 90vw, 500px" />
      </div>
      <div className={styles.detailCopy}>
        <h3>Know the design.<br />Then make it yours.</h3>
        <p>Every wallpaper and creative scene has a page of its own: the real design preview, a full description, features, and linked creator credits.</p>
        <p>Brand marks and feature badges show what’s involved—Claude, Codex, a public API, your lid sensor, or an optional microphone. Preview, apply, and customize from below the main preview.</p>
        <p>Browse in a grid or list. Keep your place with a title that stays in the toolbar as you scroll. Switch between light and dark, just like the rest of your Mac.</p>
      </div>
    </div>
  </section>;
}
