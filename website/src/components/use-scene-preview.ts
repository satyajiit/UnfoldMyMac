"use client";
import { useCallback, useEffect, useRef, useState } from "react";
import { sceneClipURL, sceneLidTime, type InteractiveScene, type SceneClip } from "@/lib/scene-preview";

interface Request { clip: SceneClip; charging: boolean; sequence: number }

export function useScenePreview(scene: InteractiveScene) {
  const viewport = useRef<HTMLDivElement>(null);
  const video = useRef<HTMLVideoElement>(null);
  const still = useRef<HTMLCanvasElement>(null);
  const angle = useRef(125);
  const current = useRef<Request>({ clip: "idle", charging: false, sequence: 0 });
  const [request, setRequest] = useState<Request>({ clip: "idle", charging: false, sequence: 0 });
  const [intent, setIntent] = useState(false);
  const [ready, setReady] = useState(-1);
  const [failed, setFailed] = useState(false);
  const [environment, setEnvironment] = useState({ visible: false, reduced: false });
  const wantsPlayback = intent && request.clip !== "lid";
  const playing = wantsPlayback && environment.visible && !failed;
  const src = sceneClipURL(scene, request.clip, request.charging);

  // Keep the displayed native frame while the next response is loading.
  const capture = useCallback(() => {
    const element = video.current, canvas = still.current;
    if (!element || !canvas || element.readyState < 2) return;
    canvas.width = element.videoWidth; canvas.height = element.videoHeight;
    canvas.getContext("2d")?.drawImage(element, 0, 0);
  }, []);

  function select(clip: SceneClip, charging: boolean, motion: boolean) {
    capture();
    video.current?.pause();
    const next = { clip, charging, sequence: current.current.sequence + 1 };
    current.current = next;
    setRequest(next); setIntent(motion); setFailed(false);
  }

  const seek = useCallback(() => {
    const element = video.current;
    if (!element || current.current.clip !== "lid" || element.readyState < 1 || element.seeking) return;
    const target = sceneLidTime(angle.current);
    if (Math.abs(element.currentTime - target) > 1 / 120) element.currentTime = target;
  }, []);
  const onAngle = useCallback((value: number) => { angle.current = value; seek(); }, [seek]);

  useEffect(() => {
    const element = viewport.current;
    if (!element) return;
    const motion = matchMedia("(prefers-reduced-motion: reduce)");
    let visible = false;
    const update = () => setEnvironment({ visible: visible && !document.hidden, reduced: motion.matches });
    const onMotion = () => { if (motion.matches) setIntent(false); update(); };
    const observer = new IntersectionObserver(([entry]) => { visible = entry.isIntersecting; update(); }, { threshold: 0.15 });
    observer.observe(element);
    document.addEventListener("visibilitychange", update); motion.addEventListener("change", onMotion);
    return () => { observer.disconnect(); document.removeEventListener("visibilitychange", update); motion.removeEventListener("change", onMotion); };
  }, []);

  useEffect(() => {
    const element = video.current;
    if (!element || request.sequence === 0) return;
    let cancelled = false;
    const commit = () => {
      if (cancelled) return;
      if (request.clip === "lid") {
        seek();
        if (element.seeking) return;
      }
      setReady(request.sequence);
    };
    const onSeeked = () => { seek(); commit(); };
    const error = () => { if (!cancelled) setFailed(true); };
    element.addEventListener("loadeddata", commit);
    element.addEventListener("seeked", onSeeked);
    element.addEventListener("error", error);
    element.src = src;
    element.load();
    return () => { cancelled = true; element.pause(); element.removeEventListener("loadeddata", commit); element.removeEventListener("seeked", onSeeked); element.removeEventListener("error", error); };
  }, [src, request.sequence, request.clip, seek]);

  useEffect(() => {
    const element = video.current;
    if (!element || ready !== request.sequence) return;
    if (!playing) { element.pause(); return; }
    let cancelled = false;
    void element.play().catch(error => { if (!cancelled && error.name !== "AbortError") setFailed(true); });
    return () => { cancelled = true; element.pause(); };
  }, [playing, ready, request.sequence]);

  function connect() {
    const charging = !current.current.charging;
    if (angle.current < 110) { select("lid", charging, false); return; }
    select(environment.reduced ? "idle" : charging ? "connect" : "disconnect", charging, !environment.reduced);
  }
  function beginLid() {
    if (current.current.clip !== "lid") select("lid", current.current.charging, false);
  }
  function toggle() {
    if (intent && !failed) { setIntent(false); return; }
    if (current.current.sequence > 0 && current.current.clip !== "lid" && !failed) { setIntent(true); return; }
    select(angle.current < 110 ? "lid" : "idle", current.current.charging, true);
  }
  function ended() { select("idle", current.current.charging, intent); }
  function reset() { angle.current = 125; select("idle", false, false); }

  return { viewport, video, still, request, ready: ready === request.sequence, failed, playing,
    reduced: environment.reduced, connect, beginLid, onAngle, toggle, ended, reset,
    retry: () => select(current.current.clip, current.current.charging, intent) };
}
