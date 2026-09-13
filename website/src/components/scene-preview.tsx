"use client";
import Image from "next/image";
import { useId } from "react";
import { Battery, Laptop, Pause, Play, PlugZap, RotateCcw } from "lucide-react";
import { sceneLidAngles, scenePosterURL, type InteractiveScene } from "@/lib/scene-preview";
import { MacBookFrame } from "./macbook-frame";
import { useLidMotion } from "./use-lid-motion";
import { useLidGestures } from "./use-lid-gestures";
import { useScenePreview } from "./use-scene-preview";
import styles from "./scene-preview.module.css";

export function ScenePreview({ scene, name, previewLabel = name, priority = false }: { scene: InteractiveScene; name: string; previewLabel?: string; priority?: boolean }) {
  const inputID = useId();
  const { viewport, video, still, request, ready, failed, playing, reduced, onAngle, connect, beginLid, toggle: togglePlayback, ended, reset: resetPlayback, retry } = useScenePreview(scene);
  const { lid, surface, slider, output, move: moveModel, getAngle } = useLidMotion(0, onAngle, sceneLidAngles);
  function move(angle: number, animated = false) { beginLid(); moveModel(angle, animated); }
  const { gestureEvents } = useLidGestures(move, getAngle, sceneLidAngles);
  const charging = request.charging;
  function toggle() { if (getAngle() < 110) moveModel(125); togglePlayback(); }
  function reset() { resetPlayback(); moveModel(125); }

  return <div className={styles.preview} ref={viewport} data-scene-preview={scene} data-charging={charging} data-response={request.clip}>
    <div className={styles.topline}><span>Try it on a Mac</span><span role="status">{charging ? <PlugZap size={13} aria-hidden="true" /> : <Battery size={13} aria-hidden="true" />}{charging ? "Charger connected" : "On battery"}</span></div>
    <div className={styles.gesture} ref={surface} role="slider" tabIndex={0} aria-label={`${name} MacBook lid`} aria-orientation="vertical" aria-valuemin={8} aria-valuemax={125} aria-valuenow={125} aria-valuetext="125 degrees open" aria-describedby={`${inputID}-hint`} {...gestureEvents}>
      <MacBookFrame lid={lid} charging={charging}>
        <Image src={scenePosterURL(scene, charging)} alt={`${name} on a MacBook desktop`} fill sizes="(max-width: 700px) 80vw, 650px" priority={priority} className={styles.poster} />
        <canvas className={styles.freeze} ref={still} aria-hidden="true" />
        <video ref={video} className={styles.video} data-ready={ready && !failed} aria-label={`${name} interactive native scene`} muted playsInline preload="none" loop={request.clip === "idle"} onEnded={ended} />
      </MacBookFrame>
    </div>
    <p id={`${inputID}-hint`} className="sr-only">Drag down to close the lid, or up to open. Use arrow keys when focused. Charger controls are below.</p>
    <div className={styles.actions} role="group" aria-label={`${name} preview events`}>
      <button type="button" className={styles.charger} onClick={connect} aria-pressed={charging}><PlugZap size={16} aria-hidden="true" />{charging ? "Disconnect charger" : "Connect charger"}</button>
      <button type="button" onClick={toggle} aria-label={`${playing ? "Pause" : "Play"} ${previewLabel} preview`}>{playing ? <Pause size={15} aria-hidden="true" /> : <Play size={15} aria-hidden="true" />}{playing ? "Pause" : "Play"}</button>
      <button type="button" onClick={reset} aria-label={`Reset ${name} preview`} title="Reset preview"><RotateCcw size={15} aria-hidden="true" /></button>
    </div>
    <div className={styles.angleRow}><label htmlFor={inputID}><Laptop size={14} aria-hidden="true" />Lid</label><input className={styles.slider} id={inputID} ref={slider} type="range" min={8} max={125} defaultValue={125} aria-label={`${name} lid angle`} onChange={event => move(Number(event.target.value))} /><output ref={output} htmlFor={inputID}>125°</output></div>
    <div className={styles.lidButtons}><button type="button" onClick={() => move(8, true)}>Close lid</button><button type="button" onClick={() => move(125, true)}>Open lid</button></div>
    <p className={styles.response}>{scene === "hinge-garden" ? charging ? "Follow the light through the roots, shell, and lantern." : "Unplugged, the garden settles into a quieter glow." : charging ? "A warm light travels around the brass rail." : "Eight open apps. Eighteen parcels. A little room to work."}</p>
    {failed && <p className={styles.error} role="alert">This response couldn’t load. The still scene is available.<button type="button" onClick={retry}>Try again</button></p>}
    {request.sequence > 0 && !ready && !failed && <p className={styles.loading} role="status">Loading scene response…</p>}
    <p className={styles.note}>{reduced ? "Reduced Motion: events use still poses. Play opts into motion." : "Native scene renders with sample inputs."} Your device isn’t read.</p>
  </div>;
}
