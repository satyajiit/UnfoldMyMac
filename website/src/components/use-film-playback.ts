"use client";

import { useEffect, useRef, useState } from "react";
import { HDR_MEDIA_TYPE, type RealFootage } from "@/lib/real-footage";

/** Keep narration from overlapping when two film cards are visible. */
export function pauseOtherFilms(active: HTMLVideoElement | string) {
  const activeId = typeof active === "string" ? active : active.closest(".real-film")?.id;
  document.querySelectorAll<HTMLVideoElement>(".real-film video").forEach(element => {
    if (element.closest(".real-film")?.id !== activeId) element.pause();
  });
  document.dispatchEvent(new CustomEvent("unfold-film-play", { detail: activeId }));
}

/** Owns opt-in playback, HDR recovery, and offscreen/reduced-motion pausing. */
export function useFilmPlayback(item: RealFootage) {
  const video = useRef<HTMLVideoElement>(null);
  const [loaded, setLoaded] = useState(false);
  const [failed, setFailed] = useState(false);
  const [format, setFormat] = useState<"HDR" | "SDR" | null>(null);
  const starting = useRef(false);
  const activeHDR = useRef(false);

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

  async function play(startAt = 0, forceSDR = false) {
    const element = video.current;
    if (!element) return;
    setFailed(false);
    setLoaded(true);
    starting.current = true;
    const hdr = !forceSDR && matchMedia("(dynamic-range: high)").matches && !!element.canPlayType(HDR_MEDIA_TYPE);
    activeHDR.current = hdr;
    const source = hdr ? item.hdrVideo : item.video;
    if (element.getAttribute("src") !== source) element.src = source;
    else if (failed) element.load();
    try {
      await element.play();
      element.currentTime = startAt;
      setFormat(hdr ? "HDR" : "SDR");
      element.focus();
    } catch (error) {
      // A user or the visibility observer can pause while play() is still pending.
      if (error instanceof DOMException && error.name === "AbortError") return;
      if (hdr) {
        await play(startAt, true);
      } else {
        setFailed(true);
        setLoaded(false);
      }
    } finally {
      starting.current = false;
    }
  }

  function onError() {
    if (starting.current) return;
    if (activeHDR.current) void play(video.current?.currentTime ?? 0, true);
    else { setFailed(true); setLoaded(false); }
  }
  return { video, loaded, failed, format, play, onError };
}
