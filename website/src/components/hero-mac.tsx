import Image from "next/image";
import type { RefObject } from "react";
import { heroWallpapers, type heroCovers } from "@/lib/hero-demo";
import { MacBookFrame } from "./macbook-frame";
import styles from "./lid-demo.module.css";

export function HeroMac({ cover, wallpaperIndex, ready, videos, lid, left, right, glass, onReady, onError }: {
  cover: typeof heroCovers[number]; wallpaperIndex: number; ready: Record<number, boolean>;
  videos: RefObject<(HTMLVideoElement | null)[]>;
  lid: RefObject<HTMLDivElement | null>; left: RefObject<HTMLDivElement | null>;
  right: RefObject<HTMLDivElement | null>; glass: RefObject<HTMLDivElement | null>;
  onReady: (index: number) => void; onError: (index: number) => void;
}) {
  const overlay = <div className={styles.cover} data-treatment={cover.treatment} aria-hidden="true">
    {cover.treatment === "split" ? <>
      <div ref={left} className={`${styles.half} ${styles.left}`}><Image src={`/artwork/${cover.id}.webp`} alt="" fill sizes="(max-width: 700px) 80vw, 760px" /></div>
      <div ref={right} className={`${styles.half} ${styles.right}`}><Image src={`/artwork/${cover.id}.webp`} alt="" fill sizes="(max-width: 700px) 80vw, 760px" /></div>
    </> : <div ref={glass} className={styles.glass} />}
  </div>;
  return <MacBookFrame lid={lid} overlay={overlay}>
    {heroWallpapers.map((item, index) => <div key={item.id} className={styles.wallpaper} data-scene={item.id} data-active={index === wallpaperIndex} aria-hidden="true">
      <Image src={`/media/${item.id}.webp`} alt="" fill sizes="(max-width: 700px) 80vw, 760px" priority={index === 0} />
      <video ref={element => { videos.current[index] = element; }} className={styles.video} data-ready={!!ready[index]} muted loop playsInline preload="none" onPlaying={() => onReady(index)} onError={() => onError(index)} />
    </div>)}
  </MacBookFrame>;
}
