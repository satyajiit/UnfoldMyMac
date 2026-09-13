import { PageIntro, Sources, Breadcrumbs } from "@/components/shared";
import { pageMetadata } from "@/lib/metadata";
import { site } from "@/lib/site";
export const metadata = pageMetadata("/legal/");
export default function LegalPage() {
  return <div className="container">
    <PageIntro label="Legal" title="Whose artwork this is." description="Trademarks, game tributes, and how to have something taken down." />
    <article className="prose">
      <h2>Take something down</h2>
      <p>If you hold rights in anything UnfoldMyMac ships and you want it removed, email <a href="mailto:admin@matterwardlabs.com?subject=TAKEDOWN">admin@matterwardlabs.com</a> with <code>TAKEDOWN</code> in the subject. <strong>We aim to remove it within two hours of reading your message</strong>, and we will not ask you to argue the point first.</p>
      <p>A short email is enough: what the material is, who you act for, and where we can reply. A formal notice under 17 U.S.C. § 512(c)(3) is honoured the same way, and you can also go through <a href="https://docs.github.com/en/site-policy/content-removal-policies/dmca-takedown-policy">GitHub&rsquo;s DMCA process</a> — though writing to us directly is faster.</p>
      <p>We remove the material from the repository, ship a release without it, and leave it removed. Anyone running version 1.0.2 or later receives that release automatically through the in-app updater. The full policy is in <a href={`${site.repo}/blob/main/DMCA.md`}>DMCA.md</a>.</p>

      <h2>Game tributes</h2>
      <p>Ten wallpapers are tributes to games we admire. Each one ships three different things, from three different places, and we would rather be precise than wave at it with a disclaimer:</p>
      <ul>
        <li><strong>The game logo</strong> is the publisher&rsquo;s own logo, downloaded from Steam&rsquo;s CDN or from PlayStation. The bytes are unchanged.</li>
        <li><strong>The detail banner</strong> is the publisher&rsquo;s official promotional artwork, converted from JPEG to PNG and otherwise untouched.</li>
        <li><strong>The animated background</strong> is AI-generated fan art made for this project and upscaled locally. It is not the publisher&rsquo;s artwork.</li>
      </ul>
      <p>The scene itself — the Metal shaders that make it move and react to your Mac — is original work.</p>
      <p>Logos, promotional artwork, game names and character names belong to their owners. They are excluded from the project&rsquo;s Apache 2.0 licence, and nothing on this page or in the repository grants anyone any right to them. <a href={`${site.repo}/blob/main/NOTICE`}>NOTICE</a> names every file and its owner; <a href={`${site.repo}/blob/main/UnfoldMyMac/GAME_WALLPAPERS.md`}>GAME_WALLPAPERS.md</a> records the source URL and retrieval date for each.</p>

      <h2>No affiliation</h2>
      <p>UnfoldMyMac is <strong>not affiliated with, sponsored by, endorsed by or connected to</strong> any publisher, studio or rightsholder named anywhere in the app or on this site. Every game wallpaper is an independent tribute made by a fan. Use of a name does not imply any approval.</p>
      <p>Apple, Mac, MacBook, macOS, iPhone and iOS are trademarks of Apple Inc. UnfoldMyMac is an independent app from Matterward Labs and is not affiliated with Apple.</p>

      <h2>Why we think this is fair</h2>
      <p>These tributes exist to show what the wallpaper engine does with live system data, and because it is a pleasure to watch a game you love react to your Mac&rsquo;s battery or network traffic. The app is <strong>free</strong>, <strong>open source</strong> and <strong>not monetised</strong>: no purchase, no subscription, no advertising, no telemetry, nothing sold. No part of it competes with the games it references.</p>
      <p>We believe that is a fair, non-commercial and largely nominative use — you cannot refer to Elden Ring without saying &ldquo;Elden Ring&rdquo;. We would rather say plainly where the limits of that reasoning sit than hide behind it: a good-faith belief is not a licence, and &ldquo;educational&rdquo; or &ldquo;promotional&rdquo; is one factor among several, not a switch that settles the question. The two-hour takedown promise above exists precisely because being easy to correct matters more to us than being right.</p>

      <h2>Other material</h2>
      <p>Space Grotesk is used under the SIL Open Font License. Weather readings come from Open-Meteo under CC BY 4.0, with city data from GeoNames. Player counts and announcements come from the public Steam Web API. Full credits and sources are in <a href={`${site.repo}/blob/main/NOTICE`}>NOTICE</a>.</p>
      <p>The app&rsquo;s own code is licensed under <a href={`${site.repo}/blob/main/LICENSE`}>Apache 2.0</a>. Privacy is covered <a href="/privacy/">separately</a>.</p>
    </article>
    <Sources />
    <Breadcrumbs path="/legal/" title="Legal" />
  </div>;
}
