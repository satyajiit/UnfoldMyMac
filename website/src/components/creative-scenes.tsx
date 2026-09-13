import { MediaCard } from "./media-card";
import { catalog } from "@/lib/catalog";
import Link from "next/link";
import { site } from "@/lib/site";

export function CreativeScenesSection() {
  return <div id="creative-scenes">
  <section className="feature-story" aria-labelledby="scene-workshop-heading">
    <MediaCard item={catalog.find(item => item.id === "the-workshop")!} id="featured-the-workshop" previewLabel="The Workshop featured" />
    <div>
      <span className="section-context">Creative Scenes <span className="new-badge">New</span></span>
      <h2 id="scene-workshop-heading">A little room<br />to make things.</h2>
      <p><strong>The Workshop</strong> turns your everyday Mac into a tiny maker’s studio. Open the lid and a wooden case unfolds, task lamps rise, and a little wind-up maker gets to work.</p>
      <p>Your open apps light the benches. Connect your Desktop, or another folder you choose, and its items become parcels on the shelves. Up to twelve stations and twenty-four parcels appear; the optional caption keeps the full counts.</p>
      <p>Small tools move gently, daylight warms the room, and connecting your charger sends a glow around the brass rail. Eight motivating lines fade into one another every forty-five seconds.</p>
      <p>Customize the lines, counts, pointer parallax, and mirrored view. Folder access is optional, and files are counted without opening their contents. Reduce Motion holds a complete, still workshop.</p>
      <p className="small muted">Created by <a href={site.company}>Matterward Labs</a>. Native app render with sample counts and optional text hidden.</p>
      <Link href="/creative-scenes/the-workshop/" className="text-link">See The Workshop</Link>
    </div>
  </section>
  <section className="feature-story" aria-labelledby="scene-garden-heading">
    <MediaCard item={catalog.find(item => item.id === "hinge-garden")!} id="featured-hinge-garden" previewLabel="Hinge Garden featured" />
    <div>
      <span className="section-context">Creative Scenes <span className="new-badge">New</span></span>
      <h2 id="scene-garden-heading">A small world.<br />A real connection.</h2>
      <p>Meet <strong>Hinge Garden</strong>, a glass snail tending a miniature greenhouse. Another little world in Creative Scenes, shaped by your Mac.</p>
      <p>Open the lid and the garden wakes. Close it and the snail retreats. Connect your charger and a pulse travels through the water and roots, up the shell, and into the greenhouse lantern; a gentle glow remains while power is connected.</p>
      <p>Battery, daylight, and system activity shape the atmosphere. Enable pointer response, supported motion sensors, or microphone input in Customize. A breath can stir petals and pollen. Sound and motion sensing are optional; microphone processing stays on your Mac.</p>
      <p>Optional one-liners add a quiet thought to the scene. Reduce Motion keeps the garden still.</p>
      <p className="small muted">Created by <a href={site.company}>Matterward Labs</a>. App render with representative inputs.</p>
      <Link href="/creative-scenes/hinge-garden/" className="text-link">See Hinge Garden</Link>
    </div>
  </section>
  </div>;
}
