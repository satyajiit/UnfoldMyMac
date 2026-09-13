"use client";

import { useEffect, useRef, useState } from "react";
import type { RealFootage } from "@/lib/real-footage";
import { youtubeEmbed } from "@/lib/youtube";
import { loadYouTubeAPI, type YouTubePlayer } from "./youtube-api";

/** Keep narration from overlapping when two film cards are visible. Every other player
 *  listens for this and pauses itself. */
export function pauseOtherFilms(activeId: string) {
  document.dispatchEvent(new CustomEvent("unfold-film-play", { detail: activeId }));
}

export function useYouTubePlayback(item: RealFootage) {
  const holder = useRef<HTMLDivElement>(null);
  const player = useRef<YouTubePlayer | null>(null);
  const seek = useRef(0);
  const paused = useRef(false);
  const [loaded, setLoaded] = useState(false);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    const container = holder.current;
    if (!loaded || !container) return;
    let disposed = false;
    let started = false;
    const captionsOff = () => {
      // Apply the initial preference only. Later CC choices and chapter seeks stay intact.
      try { player.current?.unloadModule?.("captions"); } catch { /* Optional API support must not prevent playback. */ }
    };
    const pause = () => { paused.current = true; player.current?.pauseVideo(); };
    const onVisibility = () => { if (document.hidden) pause(); };
    const onOtherFilm = (event: Event) => { if ((event as CustomEvent).detail !== item.id) pause(); };
    const motion = matchMedia("(prefers-reduced-motion: reduce)");
    const onMotion = () => { if (motion.matches) pause(); };
    const observer = new IntersectionObserver(([entry]) => { if (!entry.isIntersecting) pause(); }, { threshold: 0.1 });
    observer.observe(container);
    document.addEventListener("visibilitychange", onVisibility);
    document.addEventListener("unfold-film-play", onOtherFilm);
    motion.addEventListener("change", onMotion);
    const fail = () => { if (!disposed) { setFailed(true); setLoaded(false); } };

    void loadYouTubeAPI().then(api => {
      if (disposed) return;
      const frame = document.createElement("iframe");
      frame.src = youtubeEmbed(item.youtubeId, location.origin, seek.current);
      frame.title = `${item.title} on YouTube`;
      frame.allow = "autoplay; encrypted-media; picture-in-picture; fullscreen";
      frame.allowFullscreen = true;
      frame.referrerPolicy = "strict-origin-when-cross-origin";
      container.replaceChildren(frame);
      player.current = new api.Player(frame, { events: {
        onReady: () => {
          if (disposed) return;
          captionsOff();
          if (paused.current || document.hidden) player.current?.pauseVideo();
          else { player.current?.seekTo(seek.current, true); player.current?.playVideo(); }
        },
        onError: fail,
        onStateChange: event => {
          if (event.data !== 1 || disposed) return;
          if (!started) { started = true; captionsOff(); }
          pauseOtherFilms(item.id);
        },
      } });
    }).catch(fail);
    return () => {
      disposed = true;
      observer.disconnect();
      document.removeEventListener("visibilitychange", onVisibility);
      document.removeEventListener("unfold-film-play", onOtherFilm);
      motion.removeEventListener("change", onMotion);
      player.current?.destroy();
      player.current = null;
      container.replaceChildren();
    };
  }, [loaded, item.id, item.title, item.youtubeId]);

  function play(startAt = 0) {
    seek.current = startAt;
    paused.current = false;
    setFailed(false);
    pauseOtherFilms(item.id);
    setLoaded(true);
    if (player.current) { player.current.seekTo(startAt, true); player.current.playVideo(); }
  }
  return { holder, loaded, failed, play, format: loaded ? "YouTube" : null };
}
