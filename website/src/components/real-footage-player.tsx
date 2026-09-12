"use client";

import Image from "next/image";
import { useEffect, useRef, useState } from "react";
import { Download, Play, RotateCcw } from "lucide-react";
import type { RealFootage } from "@/lib/real-footage";

export function RealFootagePlayer({ item, featured = false }: { item: RealFootage; featured?: boolean }) {
  const video = useRef<HTMLVideoElement>(null);
  const [loaded, setLoaded] = useState(false);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    const element = video.current;
    if (!element) return;
    const observer = new IntersectionObserver(([entry]) => {
      if (!entry.isIntersecting) element.pause();
    }, { threshold: 0.1 });
    const motion = matchMedia("(prefers-reduced-motion: reduce)");
    const onVisibility = () => { if (document.hidden) element.pause(); };
    const onMotion = () => { if (motion.matches) element.pause(); };
    observer.observe(element);
    document.addEventListener("visibilitychange", onVisibility);
    motion.addEventListener("change", onMotion);
    return () => {
      observer.disconnect();
      document.removeEventListener("visibilitychange", onVisibility);
      motion.removeEventListener("change", onMotion);
    };
  }, []);

  async function play() {
    const element = video.current;
    if (!element) return;
    setFailed(false);
    setLoaded(true);
    if (!element.getAttribute("src")) element.src = item.video;
    else if (failed) element.load();
    try {
      await element.play();
      element.focus();
    } catch {
      setFailed(true);
      setLoaded(false);
    }
  }

  return <article id={item.id} className={`real-film${featured ? " real-film-featured" : ""}`}>
    <div className="real-film-frame">
      <Image src={item.poster} alt={`${item.title}, filmed on a real MacBook in a café`} fill sizes={featured ? "(max-width: 800px) 92vw, 1160px" : "(max-width: 700px) 92vw, 560px"} />
      <video ref={video} controls={loaded} muted playsInline preload="none" tabIndex={loaded ? 0 : -1}
        aria-label={`${item.title} real-life video`} aria-describedby={`${item.id}-description`}
        className={loaded ? "real-film-video is-loaded" : "real-film-video"}
        onError={() => { setFailed(true); setLoaded(false); }} />
      {!loaded && <button type="button" className="real-film-play" onClick={play} aria-label={`${failed ? "Retry" : "Play"} ${item.title} real-life video`}>
        {failed ? <RotateCcw size={23} aria-hidden="true" /> : <Play size={23} aria-hidden="true" />}<span>{failed ? "Try again" : "Watch film"}</span>
      </button>}
      {!loaded && <span className="real-film-duration">{item.duration}s</span>}
    </div>
    <div className="real-film-caption"><div>
      <span className="real-film-category">{item.category} <span aria-hidden="true">/</span> Real footage</span>
      <h3>{item.title}</h3><p id={`${item.id}-description`}>{item.description}</p>
    </div><a className="real-film-download" href={item.video} download aria-label={`Download ${item.title} video`}><Download size={19} aria-hidden="true" /><span>MP4</span></a></div>
    {failed && <p className="real-film-error" role="status">The film couldn’t load. Try again or download the MP4.</p>}
  </article>;
}
