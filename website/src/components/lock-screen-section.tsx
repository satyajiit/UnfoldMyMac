import Image from "next/image";
import Link from "next/link";
import { ArrowUpRight } from "lucide-react";

export const lockScreenGuide = "/blog/live-wallpapers/#put-it-on-the-lock-screen";

export function LockScreenSection() {
  return <section id="lock-screen" className="lock-screen-section" aria-labelledby="lock-screen-heading">
    <div className="lock-screen-copy">
      <span className="section-context">Lock screen</span>
      <h2 id="lock-screen-heading">Lock it.{" "}<br />It keeps going.</h2>
      <p>On macOS 26, UnfoldMyMac is a wallpaper provider. Every bundled Dynamic Wallpaper and Creative Scene appears in System Settings under Wallpaper and Screen Saver, each with a rendered thumbnail, in the same panes as Apple’s own.</p>
      <p>Choose a scene under Screen Saver and it plays on your lock screen: the same Metal scene, the same live readouts while the app is running, at up to 60 fps. Lid, sound, and pointer reactions stay with the app’s own desktop window. The app shows whether a scene is on your desktop only or on your desktop and lock screen, and Add to Lock Screen… in the menu bar opens the right pane.</p>
      <Link href={lockScreenGuide} className="text-link">How the lock screen works <ArrowUpRight size={16} aria-hidden="true" /></Link>
    </div>
    <figure className="lock-screen-figure">
      <Image src="/media/lock-screen.webp" alt="A macOS lock screen showing the time over the Ghost of Tsushima — Scarlet Wind wallpaper, with maple leaves blowing across a moonlit valley" width={1920} height={1200} sizes="(max-width: 800px) 90vw, 620px" />
      <figcaption>Illustration: Ghost of Tsushima — Scarlet Wind behind a macOS lock screen layout. Sample data. Official logo © Sucker Punch Productions / Sony Interactive Entertainment.</figcaption>
    </figure>
  </section>;
}
