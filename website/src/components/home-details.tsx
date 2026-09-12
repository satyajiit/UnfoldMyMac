import Link from "next/link";
import { ArrowUpRight } from "lucide-react";
import { site, sources } from "@/lib/site";
import styles from "./home-details.module.css";

export function LidSetupSection() {
  return (
    <section className={styles.setup} aria-labelledby="lid-setup-heading">
      <div className={styles.intro}>
        <span className="section-context">From the hinge to the screen</span>
        <h2 id="lid-setup-heading">Your lid sets the pace.</h2>
        <p>Close a little and the effect moves a little. Open back up and it reverses. On a MacBook with a readable lid-angle sensor, the position of the lid controls how far the effect has progressed.</p>
        <Link href="/blog/lid-effects/" className="text-link">How lid control works <ArrowUpRight size={16} aria-hidden="true" /></Link>
      </div>
      <ol className={styles.steps}>
        <li><h3>Find your closing scene</h3><p>Choose an effect and scrub through its preview. Try the curtains halfway closed, or see where a character first peeks into view.</p></li>
        <li><h3>Set the angles</h3><p>Choose where the effect starts and where it finishes. Adjust the range until the movement feels right for the way you close your Mac.</p></li>
        <li><h3>Turn it on when you’re ready</h3><p>Effects start disabled. Enable your choice from the app; the overlay lets clicks through, and the menu-bar controls stay within reach.</p></li>
      </ol>
    </section>
  );
}

export function NativeMacSection() {
  return (
    <section id="built-for-mac" className={styles.native} aria-labelledby="native-mac-heading">
      <div className={styles.nativeHeading}>
        <span className="section-context">Under the hood</span>
        <h2 id="native-mac-heading">Swift for the app.<br />Metal for the motion.</h2>
        <p>UnfoldMyMac is written in Swift 6 for macOS 26 and later. SwiftUI handles the interface, AppKit places the desktop windows, and Metal renders the live wallpapers and shader effects on the GPU.</p>
      </div>
      <div className={styles.engineGrid}>
        <div className={styles.engineNotes}>
          <div>
            <h3>Work shared across the renderer</h3>
            <p>Metal scenes use one GPU device and command queue. Shader libraries and render pipelines are cached across the app, so changing a scene can reuse work already done. The renderer prefers precompiled shaders when they’re available.</p>
          </div>
          <div>
            <h3>Frames timed to the display</h3>
            <p>The wallpaper renderer uses Apple’s <code>CAMetalDisplayLink</code> to schedule frames for presentation. Choose a 30 or 60 fps limit; macOS power and accessibility settings can lower it automatically.</p>
          </div>
          <div>
            <h3>A limit on the pixels, too</h3>
            <p>Wallpaper rendering is capped at 1,920 pixels on the longest edge before scaling to the display. Each Metal surface allows at most three frames in flight, keeping queued GPU work bounded.</p>
          </div>
        </div>
        <div className={styles.playback}>
          <table>
            <caption>Wallpaper frame limits</caption>
            <thead><tr><th scope="col">Mac state</th><th scope="col">Frame limit</th></tr></thead>
            <tbody>
              <tr><th scope="row">Normal playback<span>Your choice in settings</span></th><td>30 or 60<small>fps</small></td></tr>
              <tr><th scope="row">Low Power Mode<span>Also during serious or critical thermal pressure</span></th><td>30<small>fps maximum</small></td></tr>
              <tr><th scope="row">Reduce Motion<span>Continuous animation is still</span></th><td>1<small>update / second</small></td></tr>
              <tr><th scope="row">Mac or display asleep<span>Rendering and data sampling stop</span></th><td className={styles.paused}>Paused</td></tr>
            </tbody>
          </table>
          <p className={styles.playbackNote}>Playback also pauses when you switch to another user’s session.</p>
        </div>
      </div>
      <div className={styles.captureNote}>
        <div><span className={styles.noteLabel}>The Frost effect</span><h3>Your desktop becomes the texture.</h3></div>
        <p>Frost uses ScreenCaptureKit to receive desktop frames in memory. Core Video exposes those frames as Metal textures without copying the pixels. Screen Recording permission is needed for Frost; the other lid effects work without it.</p>
      </div>
      <p className={styles.references}>Read the <a href={`${site.repo}/tree/main/MacDuo/Sources/UnfoldMyMacKit/Rendering`}>rendering code</a>, the <a href={`${site.repo}/blob/main/MacDuo/Sources/UnfoldMyMacCore/Wallpaper/WallpaperPlayback.swift`}>wallpaper playback policy</a>, or <a href="https://developer.apple.com/metal/">Apple’s Metal overview</a>.</p>
    </section>
  );
}

export function HomeQuestions() {
  return (
    <section className={styles.questions} aria-labelledby="home-questions-heading">
      <div className={styles.intro}>
        <span className="section-context">Before you try it</span>
        <h2 id="home-questions-heading">A few practical details.</h2>
        <Link href="/faq/" className="text-link">Read all the answers <ArrowUpRight size={16} aria-hidden="true" /></Link>
      </div>
      <div className={styles.answers}>
        <div><h3>Will my Mac’s lid work?</h3><p>Lid control needs a readable angle sensor, and support varies by MacBook model. The app requires macOS 26 or later. Check the <Link href="/download/">requirements</Link> before installing.</p></div>
        <div><h3>What about an external display?</h3><p>Lid effects stay on the MacBook’s built-in display. Live wallpapers can run across your displays, including external monitors.</p></div>
        <div><h3>Can I add my own artwork?</h3><p>Import an image and try the Sculpted, Diagonal, Slide, or Burst reveal. The app keeps a local copy. You can also build a wallpaper template using the <a href={sources.developing}>extension guide</a>.</p></div>
      </div>
    </section>
  );
}
