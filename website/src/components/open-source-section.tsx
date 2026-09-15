import { ArrowUpRight, Code2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { site, sources } from "@/lib/site";
import styles from "./open-source-section.module.css";

export function OpenSourceSection() {
  return (
    <section id="open-source" className={styles.section} aria-labelledby="open-source-heading">
      <div className={styles.intro}>
        <span className="section-context">Open source</span>
        <h2 id="open-source-heading">Every line is public.</h2>
      </div>
      <div className={styles.body}>
        <p>UnfoldMyMac is open source under the Apache 2.0 license. The Swift app, its Metal shaders, and this website live in one public repository. Read the code, report a bug, or build a scene with the extension guide.</p>
        <div className={styles.actions}>
          <Button asChild><a href={site.repo}><Code2 size={17} aria-hidden="true" />View on GitHub</a></Button>
          <Button asChild variant="secondary"><a href={sources.developing}>Extension guide <ArrowUpRight size={16} aria-hidden="true" /></a></Button>
        </div>
        <p className={styles.meta}><a href={sources.license}>Apache 2.0</a><span aria-hidden="true"> · </span><a href={sources.notices}>Credits & notices</a></p>
      </div>
    </section>
  );
}
