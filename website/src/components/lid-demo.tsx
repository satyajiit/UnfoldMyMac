"use client";
import Image from "next/image";
import { useRef, useState } from "react";
import { RotateCcw, MoveHorizontal } from "lucide-react";
const designs = [{ id: "peekaboo", name: "Peekaboo" }, { id: "curtains", name: "Curtains" }, { id: "reverie", name: "Reverie" }];
export function LidDemo() {
  const [design, setDesign] = useState("peekaboo");
  const stage = useRef<HTMLDivElement>(null);
  const slider = useRef<HTMLInputElement>(null);
  const output = useRef<HTMLOutputElement>(null);
  function move(angle: number) {
    const opening = Math.max(0, Math.min(1, (angle - 25) / 100));
    stage.current?.style.setProperty("--opening", String(opening));
    stage.current?.style.setProperty("--lid-rotation", `${(125 - angle) * 0.17}deg`);
    if (output.current) output.current.value = `${angle}°`;
  }
  return <div className="lid-demo">
    <div className="demo-toolbar"><span><span className="live-dot" />Try a lid effect</span><span className="demo-toolbar-note">Made for MacBook</span></div>
    <div className="demo-stage" ref={stage} style={{ "--opening": 0.2, "--lid-rotation": "13.6deg" } as React.CSSProperties}>
      <div className="laptop">
        <div className="laptop-screen"><div className="camera" /><div className="screen-content">
          <div className="demo-desktop"><Image src="/media/demo-desktop.webp" alt="" fill sizes="(max-width: 700px) 90vw, 750px" priority /></div>
          <div className="effect-half effect-left"><Image src={`/artwork/${design}.webp`} alt="" fill sizes="(max-width: 700px) 90vw, 750px" priority /></div>
          <div className="effect-half effect-right"><Image src={`/artwork/${design}.webp`} alt="" fill sizes="(max-width: 700px) 90vw, 750px" priority /></div>
        </div><span className="laptop-wordmark">MacBook</span></div><div className="laptop-base"><span /></div>
      </div>
    </div>
    <div className="demo-controls"><div className="design-picker" role="group" aria-label="Demo effect">{designs.map(item => <button type="button" aria-pressed={design === item.id} key={item.id} onClick={() => setDesign(item.id)}>{item.name}</button>)}</div>
      <div className="angle-control"><label htmlFor="lid-angle"><MoveHorizontal size={17} aria-hidden="true" /><span>Drag to open</span></label><input id="lid-angle" ref={slider} type="range" min="25" max="125" defaultValue="45" onInput={event => move(Number(event.currentTarget.value))} aria-describedby="simulation-note" /><output htmlFor="lid-angle" ref={output}>45°</output><button type="button" className="reset-demo" aria-label="Reset lid angle" onClick={() => { if (slider.current) slider.current.value = "45"; move(45); }}><RotateCcw size={15} /></button></div>
    </div><p id="simulation-note" className="demo-disclaimer">Interactive illustration using app artwork. Real app recordings are in the showcase.</p>
  </div>;
}
