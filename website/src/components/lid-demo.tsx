"use client";
import { useState } from "react";
import { Hand, Keyboard, Pause, Play } from "lucide-react";
import { HeroCoverControls } from "./hero-cover-controls";
import { HeroMac } from "./hero-mac";
import { useLidMotion } from "./use-lid-motion";
import { useLidGestures } from "./use-lid-gestures";
import { heroCovers, heroWallpapers, lidAngles } from "@/lib/hero-demo";
import { useHeroPlayback } from "./use-hero-playback";
import styles from "./lid-demo.module.css";

export function LidDemo() {
  const [coverIndex, setCoverIndex] = useState(0);
  const cover = heroCovers[coverIndex];
  const { viewport, videos, index: wallpaperIndex, playing, ready, failed, select, toggle, onReady, onError } = useHeroPlayback();
  const wallpaper = heroWallpapers[wallpaperIndex];
  const { lid, left, right, glass, surface, slider, output, move, getAngle } = useLidMotion(coverIndex);
  const { gestureEvents, holdEvents } = useLidGestures(move, getAngle);

  return (
    <div className={`lid-demo ${styles.demo}`} aria-label="Interactive Mac preview" data-wallpaper={wallpaper.id} data-effect={cover.id} data-playing={playing}>
      <div className={styles.workspace}>
        <div className={styles.preview}>
          <div className={styles.nowShowing}>
            <div><span className={styles.wallpaperLabel}>Live wallpaper</span><span className={styles.wallpaperName}>{wallpaper.name}</span></div>
            <button type="button" className={styles.playbackButton} onClick={toggle} aria-label={`${playing ? "Pause" : "Play"} wallpaper loop`}>
              {playing ? <Pause size={15} aria-hidden="true" /> : <Play size={15} aria-hidden="true" />}<span>{playing ? "Pause" : "Play"}</span>
            </button>
          </div>
          <div className={styles.viewport} ref={viewport}>
            <div className={styles.gestureSurface} ref={surface} role="slider" tabIndex={0} aria-label="MacBook lid gesture" aria-valuemin={lidAngles.min} aria-valuemax={lidAngles.max} aria-valuenow={lidAngles.max} aria-valuetext="125 degrees open" aria-orientation="vertical" aria-describedby="gesture-hint" {...gestureEvents}>
              <HeroMac cover={cover} wallpaperIndex={wallpaperIndex} ready={ready} videos={videos} lid={lid} left={left} right={right} glass={glass} onReady={onReady} onError={onError} />
            </div>
          </div>
          <p id="gesture-hint" className={styles.gestureHint}><span className={styles.pointerHint}><Hand size={13} aria-hidden="true" />Drag or swipe down to close. Up to open.</span><span className={styles.keyboardHint}><Keyboard size={14} aria-hidden="true" />Use ↑ ↓ to move. Home / End for limits.</span></p>
          <div className={styles.wallpaperPicker} role="group" aria-label="Preview wallpapers">
            {heroWallpapers.map((item, index) => <button key={item.id} type="button" aria-label={`Show ${item.label} wallpaper`} aria-pressed={wallpaperIndex === index} onClick={() => select(index)}>
              <span className={styles.sceneNumber} aria-hidden="true">0{index + 1}</span>{item.label}<span className={styles.progress} aria-hidden="true" />
            </button>)}
          </div>
          <p className={styles.sceneDetail}>{wallpaper.detail}</p>
          {failed && <p role="status" className={styles.mediaError}>The recording couldn’t play. Its still preview is shown. Press play to try again.</p>}
        </div>
        <HeroCoverControls selected={coverIndex} onSelect={setCoverIndex} onAngle={move} slider={slider} output={output} holdEvents={holdEvents} />
      </div>
      <p id="simulation-note" className={styles.caption}>Native wallpaper recordings with sample data. Lid movement and covers are an interactive illustration.</p>
    </div>
  );
}
