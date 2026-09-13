"use client";
import Image from "next/image";
import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { Play, Pause } from "lucide-react";
import type { ShowcaseItem } from "@/lib/catalog";
import { designPath } from "@/lib/catalog-routes";
import { isInteractiveScene } from "@/lib/scene-preview";
import { ScenePreview } from "./scene-preview";

type MediaCardProps = { item: ShowcaseItem; featured?: boolean; previewLabel?: string; detailsHref?: string; previewOnly?: boolean; id?: string };
export function MediaCard(props: MediaCardProps) {
  const { item, featured, previewLabel, previewOnly = false, detailsHref = designPath(item), id = item.id } = props;
  if (item.kind === "scene" && isInteractiveScene(item.id)) return <article className={`media-card${featured ? " featured-card" : ""}`} id={id}>
    <ScenePreview scene={item.id} name={item.name} previewLabel={previewLabel} priority={previewOnly} />
    {!previewOnly && <MediaCaption item={item} previewOnly={false} detailsHref={detailsHref} error={false} />}
  </article>;
  return <RecordedMediaCard {...props} />;
}
function RecordedMediaCard({ item, featured = false, previewLabel, detailsHref = designPath(item), previewOnly = false, id = item.id }: MediaCardProps) {
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
  return <article className={`media-card${featured ? " featured-card" : ""}`} id={id}>
    <div className="media-frame">
      <Image src={item.poster} alt={`${item.name} ${item.kind === "effect" ? "effect over a demo Mac desktop" : item.kind === "scene" ? "creative scene with representative inputs" : "dynamic wallpaper with sample data"}`} fill sizes={previewOnly ? "(max-width: 900px) 92vw, 760px" : "(max-width: 700px) 92vw, (max-width: 1000px) 45vw, 380px"} priority={previewOnly} />
      {!previewOnly && <Link className="media-details-link" href={detailsHref} aria-label={`Explore ${item.name}`} />}
      {item.video && <><video ref={video} className={loaded ? "media-video loaded" : "media-video"} aria-label={`${item.name} app recording`} muted loop playsInline preload="none" onPlay={() => setPlaying(true)} onPause={() => setPlaying(false)} onError={() => { setError(true); setLoaded(false); setPlaying(false); }} />
        <button className="play-button" type="button" aria-label={`${playing ? "Pause" : "Play"} ${previewLabel ?? item.name} preview`} onClick={toggle}>{playing ? <Pause size={17} aria-hidden="true" /> : <Play size={17} aria-hidden="true" />}<span>{playing ? "Pause" : "Preview"}</span></button></>}
    </div><MediaCaption item={item} previewOnly={previewOnly} detailsHref={detailsHref} error={error} />
  </article>;
}

function MediaCaption({ item, previewOnly, detailsHref, error }: { item: ShowcaseItem; previewOnly: boolean; detailsHref: string; error: boolean }) {
  return <div className="media-caption">{!previewOnly && <><span className="small muted">{item.category}</span><h3><Link href={detailsHref}>{item.name}</Link></h3><p>{item.description}</p>{item.kind === "scene" && <Link className="scene-details-link" href={detailsHref} aria-label={`Explore ${item.name}`}>Explore design →</Link>}</>}{item.kind !== "scene" && <span className="media-note">App render · {item.sampleData ? "Sample data" : "Demo desktop"}</span>}{item.credit && <p className="media-note">{item.credit} AI-generated fan environment; independent tribute.</p>}{error && <p role="status">Preview could not play. The artwork is still available above.</p>}</div>;
}
