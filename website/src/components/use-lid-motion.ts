"use client";
import { useCallback, useEffect, useLayoutEffect, useRef } from "react";
import { animate, type AnimationPlaybackControls } from "motion";
import { lidAngles } from "@/lib/hero-demo";

export function useLidMotion(coverIndex: number, onAngle?: (angle: number) => void, range: { min: number; max: number } = lidAngles) {
  const lid = useRef<HTMLDivElement>(null);
  const left = useRef<HTMLDivElement>(null);
  const right = useRef<HTMLDivElement>(null);
  const glass = useRef<HTMLDivElement>(null);
  const surface = useRef<HTMLDivElement>(null);
  const slider = useRef<HTMLInputElement>(null);
  const output = useRef<HTMLOutputElement>(null);
  const angle = useRef<number>(range.max);
  const animation = useRef<AnimationPlaybackControls | null>(null);

  const paint = useCallback((value: number) => {
    angle.current = Math.max(range.min, Math.min(range.max, value));
    const opening = Math.max(0, Math.min(1, (angle.current - lidAngles.coverClosed) / (lidAngles.coverOpen - lidAngles.coverClosed)));
    const degrees = String(Math.round(angle.current));
    // The base sits at 70° to the viewing plane. Both halves share one hinge.
    if (lid.current) lid.current.style.transform = `rotateX(${angle.current - 110}deg)`;
    if (left.current) left.current.style.transform = `translateX(${-opening * 52}%)`;
    if (right.current) right.current.style.transform = `translateX(${opening * 52}%)`;
    if (glass.current) glass.current.style.opacity = String(1 - opening);
    if (slider.current) { slider.current.value = degrees; slider.current.setAttribute("aria-valuetext", `${degrees} degrees`); }
    if (output.current) output.current.value = `${degrees}°`;
    surface.current?.setAttribute("aria-valuenow", degrees);
    surface.current?.setAttribute("aria-valuetext", `${degrees} degrees open`);
    onAngle?.(angle.current);
  }, [onAngle, range.min, range.max]);

  function move(target: number, animated = false) {
    animation.current?.stop();
    const bounded = Math.max(range.min, Math.min(range.max, target));
    if (!animated || matchMedia("(prefers-reduced-motion: reduce)").matches) { paint(bounded); return; }
    animation.current = animate(angle.current, bounded, { type: "spring", duration: 0.5, bounce: 0.1, onUpdate: paint });
  }

  useLayoutEffect(() => { paint(angle.current); }, [coverIndex, paint]);
  useEffect(() => {
    const stop = () => animation.current?.stop();
    const preference = matchMedia("(prefers-reduced-motion: reduce)");
    preference.addEventListener("change", stop);
    window.addEventListener("blur", stop);
    return () => { stop(); preference.removeEventListener("change", stop); window.removeEventListener("blur", stop); };
  }, []);

  return { lid, left, right, glass, surface, slider, output, move, getAngle: () => angle.current };
}
