import type { ReactNode, RefObject } from "react";
import { MacDesktopChrome } from "./mac-desktop-chrome";
import { MacKeyboard } from "./mac-keyboard";
import { MacStickers } from "./mac-stickers";
import styles from "./lid-demo.module.css";

export function MacBookFrame({ children, overlay, lid, charging }: { children: ReactNode; overlay?: ReactNode; lid?: RefObject<HTMLDivElement | null>; charging?: boolean }) {
  return <div className={styles.stage}><div className={styles.model}>
    <div className={styles.screen} ref={lid} data-mac-lid="true">
      <div className={styles.screenFront}><span className={styles.camera} /><div className={styles.screenContent}>
        {children}<MacDesktopChrome charging={charging} />{overlay}
      </div></div>
      <div className={styles.screenBack} aria-hidden="true"><span>◈</span></div>
    </div>
    <div className={styles.deck} data-mac-base="true" aria-hidden="true"><MacKeyboard /><div className={styles.trackpad} /><MacStickers /><span className={styles.fingerNotch} /></div>
    <div className={styles.hinge} aria-hidden="true" />
    {charging !== undefined && <svg className={styles.powerCable} data-connected={charging} viewBox="0 0 120 30" aria-hidden="true"><path d="M0 28 H62 Q78 28 78 15 H103" /><rect x="100" y="8" width="18" height="14" rx="3" /><path className={styles.powerLight} d="M107 12 h5" /></svg>}
  </div></div>;
}
