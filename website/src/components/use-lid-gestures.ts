"use client";
import { useEffect, useRef, type KeyboardEvent, type PointerEvent } from "react";
import { lidAngles } from "@/lib/hero-demo";

type Drag = { id: number; y: number; angle: number; at: number; travel: number; element: HTMLDivElement };

export function useLidGestures(move: (angle: number, animated?: boolean) => void, getAngle: () => number, range: { min: number; max: number } = lidAngles) {
  const drag = useRef<Drag | null>(null);
  const holdFrame = useRef(0);

  function stop() {
    cancelAnimationFrame(holdFrame.current);
    if (drag.current) drag.current.element.dataset.dragging = "false";
    drag.current = null;
  }

  useEffect(() => {
    window.addEventListener("blur", stop);
    document.addEventListener("visibilitychange", stop);
    return () => { stop(); window.removeEventListener("blur", stop); document.removeEventListener("visibilitychange", stop); };
  }, []);

  function onPointerDown(event: PointerEvent<HTMLDivElement>) {
    if (!event.isPrimary || event.button !== 0) return;
    stop(); move(getAngle());
    event.currentTarget.dataset.input = "pointer";
    event.currentTarget.focus({ preventScroll: true });
    event.currentTarget.setPointerCapture(event.pointerId);
    event.currentTarget.dataset.dragging = "true";
    drag.current = { id: event.pointerId, y: event.clientY, angle: getAngle(), at: event.timeStamp, travel: Math.max(120, event.currentTarget.clientHeight * 0.55), element: event.currentTarget };
  }
  function onPointerMove(event: PointerEvent<HTMLDivElement>) {
    const start = drag.current;
    if (start?.id === event.pointerId) move(start.angle - (event.clientY - start.y) * (range.max - range.min) / start.travel);
  }
  function onPointerUp(event: PointerEvent<HTMLDivElement>) {
    const start = drag.current;
    if (!start || start.id !== event.pointerId) return;
    const distance = event.clientY - start.y;
    const duration = event.timeStamp - start.at;
    stop();
    if (Math.abs(distance) > 28 && duration < 260 && Math.abs(distance) / Math.max(1, duration) > 0.45) move(distance > 0 ? range.min : range.max, true);
    if (event.currentTarget.hasPointerCapture(event.pointerId)) event.currentTarget.releasePointerCapture(event.pointerId);
  }
  function onKeyDown(event: KeyboardEvent<HTMLDivElement>) {
    event.currentTarget.dataset.input = "keyboard";
    const target = { ArrowUp: getAngle() + 5, ArrowRight: getAngle() + 5, ArrowDown: getAngle() - 5, ArrowLeft: getAngle() - 5, Home: range.min, End: range.max }[event.key];
    if (target === undefined) return;
    event.preventDefault(); stop(); move(target);
  }
  function hold(event: PointerEvent<HTMLButtonElement>, direction: number) {
    if (!event.isPrimary || event.button !== 0) return;
    stop(); event.currentTarget.setPointerCapture(event.pointerId);
    move(getAngle() + direction * 5);
    const start = performance.now(), from = getAngle();
    const tick = (now: number) => {
      // Elapsed time since the press, not a per-frame delta clamped to 32ms: a page that only
      // gets a frame every 140ms would otherwise move the lid at a fifth of 75 degrees a second.
      move(from + direction * (now - start) * 0.075);
      if (getAngle() > range.min && getAngle() < range.max) holdFrame.current = requestAnimationFrame(tick);
    };
    holdFrame.current = requestAnimationFrame(tick);
  }

  return {
    gestureEvents: { onPointerDown, onPointerMove, onPointerUp, onPointerCancel: stop, onLostPointerCapture: stop, onKeyDown, onBlur: (event: React.FocusEvent<HTMLDivElement>) => { delete event.currentTarget.dataset.input; stop(); } },
    holdEvents: (direction: number) => ({
      onPointerDown: (event: PointerEvent<HTMLButtonElement>) => hold(event, direction),
      onPointerUp: stop, onPointerCancel: stop, onLostPointerCapture: stop, onBlur: stop,
      onClick: (event: React.MouseEvent<HTMLButtonElement>) => { if (event.detail === 0) { stop(); move(direction > 0 ? range.max : range.min); } },
    }),
  };
}
