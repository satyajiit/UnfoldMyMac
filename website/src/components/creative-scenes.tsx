import { MediaCard } from "./media-card";
import { catalog } from "@/lib/catalog";
import Link from "next/link";
import { site } from "@/lib/site";

export function CreativeScenesSection() {
  return <section id="creative-scenes" className="feature-story">
    <MediaCard item={{ ...catalog.find(item => item.id === "hinge-garden")!, id: "featured-hinge-garden" }} previewLabel="Hinge Garden featured" />
    <div>
      <span className="section-context">Creative Scenes <span className="new-badge">New</span></span>
      <h2>A small world.<br />A real connection.</h2>
      <p>Creative Scenes is home to experiments that respond to your Mac. First up: <strong>Hinge Garden</strong>, a glass snail tending a miniature greenhouse.</p>
      <p>Open the lid and the garden wakes. Close it and the snail retreats. Connect your charger and a pulse travels through the water and roots, up the shell, and into the greenhouse lantern; a gentle glow remains while power is connected.</p>
      <p>Battery, daylight, and system activity shape the atmosphere. Enable pointer response, supported motion sensors, or microphone input in Customize. A breath can stir petals and pollen. Sound and motion sensing are optional; microphone processing stays on your Mac.</p>
      <p>Optional one-liners add a quiet thought to the scene. Reduce Motion keeps the garden still.</p>
      <p className="small muted">Created by <a href={site.company}>Matterward Labs</a>. App render with representative inputs.</p>
      <Link href="/showcase/#hinge-garden" className="text-link">See Hinge Garden</Link>
    </div>
  </section>;
}
