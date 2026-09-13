import Image from "next/image";
import Link from "next/link";
import { ArrowUpRight, GitPullRequest } from "lucide-react";
import { Button } from "@/components/ui/button";
import { site } from "@/lib/site";
import styles from "./wallpaper-workshop.module.css";

const engineGuide = `${site.repo}/blob/main/UnfoldMyMac/WALLPAPER_ENGINE.md`;
const ideaLink = `${site.repo}/issues/new?template=feature-request.yml&title=Wallpaper%20idea%3A%20`;

export function WallpaperConnections() {
  return (
    <section id="connected-wallpapers" className={styles.connections} aria-labelledby="connections-heading">
      <div className={styles.heading}>
        <span className="section-context">Hooks & live data</span>
        <h2 id="connections-heading">Give the scene something<br />to react to.</h2>
        <p>A coding session can change a character’s mood. A public forecast can change the sky. The engine feeds those inputs to the wallpaper’s motion, colours, and text.</p>
      </div>
      <div className={styles.connectionGrid}>
        <article className={styles.hooks}>
          <span className={styles.label}>Local events</span>
          <h3>See what Codex is waiting for.</h3>
          <p>Codex Mission Control follows lifecycle hooks: starting work, using tools, asking for approval, finishing a turn, or being interrupted. The robot’s expression and status follow along.</p>
          <table className={styles.events}>
            <caption className="sr-only">Codex events and wallpaper states</caption>
            <thead><tr><th scope="col">Codex event</th><th scope="col">Wallpaper state</th></tr></thead>
            <tbody>
              <tr><th scope="row">Submit a prompt or run a tool</th><td>Working</td></tr>
              <tr><th scope="row">Request permission</th><td>Needs you</td></tr>
              <tr><th scope="row">Complete a turn</th><td>Finished</td></tr>
              <tr><th scope="row">Interrupt the turn</th><td>Interrupted</td></tr>
            </tbody>
          </table>
          <p className={styles.note}>The active feed reads local hook records once a second. Records keep event metadata and counters; prompts, commands, and responses are discarded.</p>
          <Link className="text-link" href="/blog/connecting-your-data/#codex-hooks-drive-live-work-states">Set up Codex hooks <ArrowUpRight size={16} aria-hidden="true" /></Link>
        </article>
        <article className={styles.publicData}>
          <span className={styles.label}>Public APIs</span>
          <h3>Put a few live numbers to work.</h3>
          <div className={styles.feed}>
            <h4>Aurora Observatory · NOAA</h4>
            <p>Planetary Kp readings and the aurora forecast shape the curtains around Earth. The data comes from <a href="https://www.swpc.noaa.gov/products/aurora-30-minute-forecast">NOAA’s public space-weather feeds</a>.</p>
          </div>
          <div className={styles.feed}>
            <h4>GitHub After Hours · GitHub</h4>
            <p>Public repository and follower counts, plus recent public push events, give your profile a place in the city. Connect a username in the app.</p>
          </div>
          <p className={styles.note}>Both sources refresh every five minutes. GitHub can delay public events, so these are periodically updated stats. See <a href="https://docs.github.com/en/rest/activity/events">GitHub’s timing notes</a>.</p>
          <Link className="text-link" href="/blog/connecting-your-data/#public-api-data-needs-a-snapshot-adapter">Connect another data source <ArrowUpRight size={16} aria-hidden="true" /></Link>
        </article>
      </div>
      <div className={styles.adapter}>
        <h3>Your API can be next.</h3>
        <div>
          <p>A small adapter can turn a public API response into the engine’s JSON snapshot format. Supply an updating local file or an HTTPS snapshot endpoint, then bind its values to your template. A raw API URL needs that translation unless it already returns the snapshot format.</p>
          <p className={styles.note}>Local snapshot files are read once a second; the standard HTTPS connector polls every five seconds. Your adapter controls upstream refreshes and API rate limits.</p>
        </div>
      </div>
    </section>
  );
}

export function WallpaperWorkshop() {
  return (
    <section id="make-a-wallpaper" className={styles.workshop} aria-labelledby="workshop-heading">
      <div className={styles.workshopIntro}>
        <div className={styles.workshopCopy}>
          <span className="section-context">An open invitation</span>
          <h2 id="workshop-heading">We built the engine.<br />You bring the next scene.</h2>
          <p>The renderer, data connections, and template format are in place. Now I want to see the scenes other people would put on their desktops.</p>
          <p>Try a harbour that follows the tide, a greenhouse driven by weather data, or a character with its own reaction when Codex finishes a turn. These are ideas to build on.</p>
          <p>Pitch something stranger, too. Share a sketch, the data it would use, and what should move. A rough drawing is enough to start a conversation.</p>
          <div className={styles.actions}>
            <Button asChild><a href={ideaLink}>Share a wallpaper idea <ArrowUpRight size={16} aria-hidden="true" /></a></Button>
            <a className="text-link" href={engineGuide}>Build a wallpaper <GitPullRequest size={16} aria-hidden="true" /></a>
          </div>
        </div>
        <figure className={styles.illustration}>
          <Image src="/media/wallpaper-workshop.webp" alt="A wallpaper workshop with a laptop, a small robot, an aurora model, and a hand sketching the next landscape" width={1536} height={1024} sizes="(max-width: 800px) 100vw, 650px" />
          <figcaption>A few directions to explore · Concept illustration</figcaption>
        </figure>
      </div>
      <div className={styles.contributionPaths}>
        <div><h3>Remix a template</h3><p>Use an installed scene and change its colours, text layers, or data bindings in JSON. Import the template to try it on your Mac.</p></div>
        <div><h3>Draw a new scene</h3><p>Contribute a template folder with its own Metal shader to the repo. The engine supplies timing, data, and display handling.</p></div>
        <div><h3>Bring a useful feed</h3><p>Write an adapter or a native provider for another data source. Include sample data so people can try the scene before connecting it.</p></div>
      </div>
      <p className={styles.sources}>Implementation and setup details are in the <a href={engineGuide}>wallpaper engine guide</a>. Start with an idea in the <a href={`${site.repo}/issues`}>issue tracker</a>, or send a pull request with a working scene.</p>
    </section>
  );
}
