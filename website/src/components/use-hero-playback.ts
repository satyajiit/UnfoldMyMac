"use client";
import { useEffect, useRef, useState } from "react";
import { heroWallpapers, wallpaperInterval } from "@/lib/hero-demo";

export function useHeroPlayback() {
  const viewport = useRef<HTMLDivElement>(null);
  const videos = useRef<(HTMLVideoElement | null)[]>([]);
  const [index, setIndex] = useState(0);
  const [intent, setIntent] = useState<"auto" | "play" | "pause">("auto");
  const [environment, setEnvironment] = useState({ visible: false, reduced: false });
  const [ready, setReady] = useState<Record<number, boolean>>({});
  const [failed, setFailed] = useState(false);
  const playing = environment.visible && !failed && (intent === "play" || (intent === "auto" && !environment.reduced));

  useEffect(() => {
    const element = viewport.current;
    if (!element) return;
    const motion = matchMedia("(prefers-reduced-motion: reduce)");
    let visible = false;
    const update = () => setEnvironment({ visible: visible && !document.hidden, reduced: motion.matches });
    const onMotion = () => { if (motion.matches) setIntent("auto"); update(); };
    const observer = new IntersectionObserver(([entry]) => { visible = entry.isIntersecting; update(); }, { threshold: 0.15 });
    observer.observe(element);
    document.addEventListener("visibilitychange", update);
    motion.addEventListener("change", onMotion);
    return () => { observer.disconnect(); document.removeEventListener("visibilitychange", update); motion.removeEventListener("change", onMotion); };
  }, []);

  useEffect(() => {
    const video = videos.current[index];
    if (!video || !playing) return;
    let cancelled = false;
    video.muted = true;
    if (!video.getAttribute("src")) video.src = `/media/${heroWallpapers[index].id}.mp4`;
    void video.play().catch(error => {
      if (!cancelled && error.name !== "AbortError") setFailed(true);
    });
    const timer = setTimeout(() => setIndex(current => (current + 1) % heroWallpapers.length), wallpaperInterval);
    return () => { cancelled = true; clearTimeout(timer); video.pause(); };
  }, [index, playing]);

  function select(next: number) { setIndex(next); setFailed(false); }
  function toggle() {
    if (failed) videos.current[index]?.load();
    setFailed(false);
    setIntent(playing ? "pause" : "play");
  }
  function onReady(next: number) { setReady(current => ({ ...current, [next]: true })); }
  function onError(next: number) {
    setReady(current => ({ ...current, [next]: false }));
    if (next === index) setFailed(true);
  }

  return { viewport, videos, index, playing, ready, failed, select, toggle, onReady, onError };
}
