"use client";
import Image from "next/image";
import type { RefObject } from "react";
import { ArrowDown, ArrowUp, Check, MoveHorizontal, RotateCcw } from "lucide-react";
import type { useLidGestures } from "./use-lid-gestures";
import { heroCovers, lidAngles } from "@/lib/hero-demo";
import styles from "./lid-demo.module.css";

export function HeroCoverControls({ selected, onSelect, onAngle, slider, output, holdEvents }: {
  selected: number;
  onSelect: (index: number) => void;
  onAngle: (angle: number, animate: boolean) => void;
  slider: RefObject<HTMLInputElement | null>;
  output: RefObject<HTMLOutputElement | null>;
  holdEvents: ReturnType<typeof useLidGestures>["holdEvents"];
}) {
  return <div className={styles.controls}>
    <div className={styles.controlHeading}><h2>Try a lid effect</h2><p>Choose a cover. It closes fully at 30°.</p></div>
    <div className={styles.coverGrid} role="group" aria-label="Demo effect">
      {heroCovers.map((item, index) => <button key={item.id} type="button" aria-pressed={selected === index} onClick={() => { onSelect(index); onAngle(75, true); }}>
        <span className={styles.coverThumbnail}><Image src={`/artwork/thumbs/${item.id}.webp`} alt="" width={220} height={138} sizes="110px" loading="eager" />{selected === index && <span className={styles.selected}><Check size={11} aria-hidden="true" /></span>}</span><span>{item.name}</span>
      </button>)}
    </div>
    <div className={styles.angleControl}>
      <div className={styles.angleLabel}><label htmlFor="lid-angle"><MoveHorizontal size={15} aria-hidden="true" />Lid angle</label><output htmlFor="lid-angle" ref={output}>125°</output></div>
      <input id="lid-angle" ref={slider} type="range" min={lidAngles.min} max={lidAngles.max} defaultValue={lidAngles.max} onInput={event => onAngle(Number(event.currentTarget.value), false)} aria-describedby="gesture-hint" aria-valuetext="125 degrees" />
      <div className={styles.angleEnds} aria-hidden="true"><span>Covered · 30°</span><span>Open</span></div>
      <div className={styles.holdControls}><button type="button" {...holdEvents(-1)}><ArrowDown size={13} aria-hidden="true" />Hold to close</button><button type="button" {...holdEvents(1)}><ArrowUp size={13} aria-hidden="true" />Hold to open</button></div>
      <button type="button" className={styles.reset} aria-label="Reset lid angle" onClick={event => onAngle(125, event.detail !== 0)}><RotateCcw size={14} aria-hidden="true" />Open the lid</button>
    </div>
  </div>;
}
