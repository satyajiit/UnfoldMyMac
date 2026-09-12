"use client";
import Image from "next/image";
import { useEffect, useRef, useState } from "react";
import { Play, Pause } from "lucide-react";
import type { ShowcaseItem } from "@/lib/catalog";
export function MediaCard({ item, featured = false, previewLabel }: { item: ShowcaseItem; featured?: boolean; previewLabel?: string }) {
  const video = useRef<HTMLVideoElement>(null);
  const [playing, setPlaying] = useState(false);
  const [loaded, setLoaded] = useState(false);
  const [error, setError] = useState(false);
  useEffect(() => {
    const element = video.current;
    if (!element) return;
    const observer = new IntersectionObserver(([entry]) => { if (!entry.isIntersecting) element.pause(); }, { threshold: 0.1 });
    observer.observe(element);
    const onVisibility = () => { if (document.hidden) element.pause(); };
    const motion = matchMedia("(prefers-reduced-motion: reduce)");
    const onMotion = () => { if (motion.matches) element.pause(); };
    document.addEventListener("visibilitychange", onVisibility);
    motion.addEventListener("change", onMotion);
    return () => { observer.disconnect(); document.removeEventListener("visibilitychange", onVisibility); motion.removeEventListener("change", onMotion); };
  }, [loaded]);
  async function toggle() {
    if (!video.current) return;
    if (playing) { video.current.pause(); return; }
    if (error) video.current.load();
    setError(false);
    setLoaded(true);
    if (!video.current.getAttribute("src")) video.current.src = item.video!;
    try { await video.current.play(); } catch { setError(true); setLoaded(false); setPlaying(false); }
  }
  return <article className={`media-card${featured ? " featured-card" : ""}`} id={item.id}>
    <div className="media-frame">
      <Image src={item.poster} alt={`${item.name} ${item.kind === "effect" ? "effect over a demo Mac desktop" : "wallpaper with sample data"}`} fill sizes="(max-width: 700px) 92vw, (max-width: 1000px) 45vw, 380px" />
      {item.video && <><video ref={video} className={loaded ? "media-video loaded" : "media-video"} aria-label={`${item.name} app recording`} muted loop playsInline preload="none" onPlay={() => setPlaying(true)} onPause={() => setPlaying(false)} onError={() => { setError(true); setLoaded(false); setPlaying(false); }} />
        <button className="play-button" type="button" aria-label={`${playing ? "Pause" : "Play"} ${previewLabel ?? item.name} preview`} onClick={toggle}>{playing ? <Pause size={17} aria-hidden="true" /> : <Play size={17} aria-hidden="true" />}<span>{playing ? "Pause" : "Preview"}</span></button></>}
    </div><div className="media-caption"><span className="small muted">{item.category}</span><h3>{item.name}</h3><p>{item.description}</p><span className="media-note">App render · {item.sampleData ? "Sample data" : "Demo desktop"}</span>{error && <p role="status">Preview could not play. The artwork is still available above.</p>}</div>
  </article>;
}
