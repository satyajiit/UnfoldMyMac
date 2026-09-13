import Link from "next/link";
import { ArrowUpRight, Camera } from "lucide-react";
import { realLifeClips, realLifeReel } from "@/lib/real-footage";
import { RealFootagePlayer } from "@/components/real-footage-player";

export function RealLifeSection({ collection = false }: { collection?: boolean }) {
  return <section className="real-life-section" id="in-real-life" aria-labelledby="real-life-heading">
    <div className="real-life-heading"><div>
      <span className="real-life-eyebrow"><Camera size={16} aria-hidden="true" />UnfoldMyMac, in the wild</span>
      <h2 id="real-life-heading">A real MacBook.<br />A little desktop theatre.</h2>
      <p>Filmed at a café. Close the lid, change the scene.<br className="desktop-break" /> See the effects and wallpapers out in the world.</p>
    </div>{!collection && <Link className="text-link" href="/showcase/#in-real-life">Watch all five clips <ArrowUpRight size={17} aria-hidden="true" /></Link>}</div>
    <RealFootagePlayer item={realLifeReel} featured />
    {collection && <div className="real-life-grid">{realLifeClips.map(item => <RealFootagePlayer key={item.id} item={item} />)}</div>}
    <p className="real-life-note">The full film plays the complete recordings at 1.5×. Individual clips play at their original speed. Press play for sound; the films stream from YouTube in 4K, with HDR on compatible screens.</p>
  </section>;
}
