import { RealLifeSection } from "@/components/real-life-section";
import { CollectionCarousel } from "@/components/collection-carousel";
import { PageIntro, DownloadCTA, Sources, Breadcrumbs } from "@/components/shared";
import { Showcase } from "@/components/showcase";
import { pageMetadata } from "@/lib/metadata";
import { sources } from "@/lib/site";
export const metadata = pageMetadata("/showcase/");
export default function ShowcasePage() { return <div className="container"><PageIntro label="Showcase" title="Pick your kind of desktop." description="Thirteen effects for closing time. Ten worlds for everything in between. All part of UnfoldMyMac." /><RealLifeSection collection /><CollectionCarousel /><Showcase /><Sources><p>Product details come from the <a href={sources.overview}>project README</a> and <a href={sources.app}>app documentation</a>.</p><p>GTA VI artwork © <a href="https://www.rockstargames.com/VI">Rockstar Games</a>. Aurora Observatory uses <a href="https://www.swpc.noaa.gov/products/aurora-30-minute-forecast">NOAA OVATION forecasts</a> and <a href="https://science.nasa.gov/earth/earth-observatory/blue-marble-next-generation/">NASA Earth Observatory imagery</a>. Its auroras are an artistic interpretation; these recordings use sample data.</p></Sources><DownloadCTA /><Breadcrumbs path="/showcase/" title="Showcase" /></div>; }
