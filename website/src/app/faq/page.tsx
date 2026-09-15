import { ChevronDown } from "lucide-react";
import { PageIntro, Sources, DownloadCTA, Breadcrumbs, JsonLd } from "@/components/shared";
import { pageMetadata } from "@/lib/metadata";
import { faqs } from "@/lib/faq";
export const metadata = pageMetadata("/faq/");
export default function FAQPage() { return <div className="container"><PageIntro label="FAQ" title="A few things before you unfold." description="Mac requirements, permissions, the lock screen, and what those little wallpaper counters are actually counting." /><div className="faq-list">{faqs.map((faq, index) => <details key={faq.question} open={index === 0}><summary>{faq.question}<ChevronDown size={20} aria-hidden="true" /></summary><p>{faq.answer}</p></details>)}</div><Sources /><DownloadCTA /><JsonLd data={{ "@context": "https://schema.org", "@type": "FAQPage", mainEntity: faqs.map(faq => ({ "@type": "Question", name: faq.question, acceptedAnswer: { "@type": "Answer", text: faq.answer } })) }} /><Breadcrumbs path="/faq/" title="FAQ" /></div>; }
