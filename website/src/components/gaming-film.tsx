"use client";

import { useSyncExternalStore } from "react";
import Image from "next/image";
import Link from "next/link";
import { ArrowUpRight, Play, RotateCcw } from "lucide-react";
import { useYouTubePlayback } from "@/components/use-youtube-playback";
import type { RealFootage } from "@/lib/real-footage";
import styles from "./gaming-film.module.css";

const portraitQuery = "(max-width: 700px)";
const film = {
  id: "gaming-launch", title: "Gaming wallpapers for Mac", category: "Gaming wallpapers",
  description: "Ten game worlds with moving scenery and useful live readings on your Mac.",
  duration: 100,
};
const films: Record<"portrait" | "landscape", RealFootage> = {
  portrait: { ...film, youtubeId: "2Sx3D9i8-Ew", poster: "/media/gaming/launch-portrait.webp" },
  landscape: { ...film, youtubeId: "eYLM1soTuVs", poster: "/media/gaming/launch-landscape.webp" },
};

function subscribeToViewport(onChange: () => void) {
  const query = window.matchMedia(portraitQuery);
  query.addEventListener("change", onChange);
  return () => query.removeEventListener("change", onChange);
}
const isPortrait = () => window.matchMedia(portraitQuery).matches;
const serverPortrait = () => false;

export function GamingFilmSection() {
  const portrait = useSyncExternalStore(subscribeToViewport, isPortrait, serverPortrait);
  const format = portrait ? "portrait" : "landscape";
  return <section id="gaming-wallpapers" className={styles.section} aria-labelledby="gaming-heading">
    <div className={styles.heading}>
      <h2 id="gaming-heading">Game’s closed.<br />World’s still on.</h2>
      <div><p>Ten live wallpapers for gamers, on Mac. Charge up with Wolverine, focus at a Site of Grace, and let Night City follow your downloads.</p>
        <Link className="text-link" href="/dynamic-wallpapers/">Explore the wallpapers <ArrowUpRight size={16} aria-hidden="true" /></Link>
      </div>
    </div>
    {/* A format change destroys the old player and returns to the matching poster. */}
    <GamingFilmPlayer key={format} item={films[format]} format={format} />
  </section>;
}

function GamingFilmPlayer({ item, format }: { item: RealFootage; format: "portrait" | "landscape" }) {
  const { holder, loaded, failed, play } = useYouTubePlayback(item);
  return <div data-gaming-film data-format={format}>
    <div className={styles.frame}>
      <picture>
        <source media={portraitQuery} srcSet={films.portrait.poster} />
        <Image src={films.landscape.poster} alt="UnfoldMyMac gaming wallpapers playing on a MacBook against a blue stage" fill sizes="(max-width: 700px) 400px, (max-width: 1224px) 94vw, 1160px" />
      </picture>
      <div ref={holder} className={`${styles.player}${loaded ? ` ${styles.loaded}` : ""}`} />
      {!loaded && <button className={styles.play} type="button" onClick={() => play()} aria-label={`${failed ? "Retry" : "Play"} gaming wallpapers film`}>
        {failed ? <RotateCcw size={22} aria-hidden="true" /> : <Play size={22} aria-hidden="true" />}
        {failed ? "Try again" : "Watch the film"}
      </button>}
    </div>
    <div className={styles.details}><span>1:40 · 4K · Sound on</span><a className="text-link" href={`https://www.youtube.com/watch?v=${item.youtubeId}`}>Watch on YouTube <ArrowUpRight size={15} aria-hidden="true" /></a></div>
    {failed && <p className={styles.error} role="status">The film couldn’t load. Try again or open it on YouTube.</p>}
  </div>;
}
