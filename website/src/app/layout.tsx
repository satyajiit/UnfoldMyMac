import type { Metadata } from "next";
import localFont from "next/font/local";
import { Header } from "@/components/header";
import { Footer, JsonLd } from "@/components/shared";
import { Theme } from "@/components/theme";
import { site } from "@/lib/site";
import "./globals.css";
const space = localFont({ src: [
  { path: "../../public/fonts/SpaceGrotesk-Regular.ttf", weight: "400", style: "normal" },
  { path: "../../public/fonts/SpaceGrotesk-Medium.ttf", weight: "500", style: "normal" },
  { path: "../../public/fonts/SpaceGrotesk-Bold.ttf", weight: "700", style: "normal" },
], display: "swap", variable: "--font-space" });
export const metadata: Metadata = {
  metadataBase: new URL(site.url), title: { default: site.name, template: "%s | UnfoldMyMac" },
  description: site.description, icons: { icon: "/media/icon.png", apple: "/media/apple-icon.png" },
  robots: { index: true, follow: true, googleBot: { index: true, follow: true, "max-image-preview": "large", "max-snippet": -1, "max-video-preview": -1 } },
};
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en" suppressHydrationWarning className={space.variable}><head><link rel="describedby" href="/llms.txt" type="text/plain" /></head><body><Theme>
    <a className="skip-link" href="#main">Skip to content</a><Header /><main id="main">{children}</main><Footer />
    <JsonLd data={{ "@context": "https://schema.org", "@type": "Organization", "@id": `${site.company}/#organization`, name: "Matterward Labs Private Limited", url: site.company, logo: `${site.url}/brand/matterward/organization-logo-512.png` }} />
  </Theme></body></html>;
}
