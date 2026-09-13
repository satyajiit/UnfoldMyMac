import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { load } from "cheerio";
import type { AnyNode } from "domhandler";
import { getArticles } from "../src/lib/content";
import { pages, site } from "../src/lib/site";

import { libraryRoutes } from "../src/lib/design-content";

const routes = [...[...pages, ...libraryRoutes].map(page => ({ path: page.path, title: page.title })), ...getArticles().map(article => ({ path: `/blog/${article.slug}/`, title: article.title }))];
function markdown(node: AnyNode): string {
  if (node.type === "text") return node.data.replace(/\s+/g, " ");
  if (!("tagName" in node)) return "";
  const tag = node.tagName;
  if (tag === "table") {
    const $ = load(node);
    const rows = $("tr").toArray().map(row => `| ${$(row).children("th,td").toArray().map(cell =>
      cell.children.map(markdown).join(" ").trim().replace(/\s+/g, " ").replace(/\|/g, "\\|")
    ).join(" | ")} |`);
    const columns = $("tr").first().children("th,td").length;
    rows.splice(1, 0, `| ${Array(columns).fill("---").join(" | ")} |`);
    return `\n\n${$("caption").text()}\n\n${rows.join("\n")}\n\n`;
  }
  const content = node.children.map(markdown).join("").trim();
  if (/^h[1-6]$/.test(tag)) return `\n\n${"#".repeat(Number(tag[1]))} ${content}\n\n`;
  if (tag === "a") return `[${content}](${new URL(node.attribs.href || "/", site.url).href})`;
  if (tag === "dt") return `\n**${content}:** `;
  if (tag === "dd") return `${content}\n`;
  if (tag === "li") return `\n- ${content}\n`;
  if (tag === "br") return "\n";
  if (tag === "pre") return `\n\n\`\`\`\n${node.children.map(child => "children" in child ? child.children.map(grandchild => grandchild.type === "text" ? grandchild.data : "").join("") : "").join("")}\n\`\`\`\n\n`;
  if (tag === "code") return `\`${content}\``;
  if (tag === "img") return node.attribs.alt ? `\n![${node.attribs.alt}](${new URL(node.attribs.src, site.url).href})\n` : "";
  if (["p", "div", "section", "article", "aside", "details", "summary", "ul", "ol"].includes(tag)) return `\n\n${content}\n\n`;
  return content;
}
for (const route of routes) {
  const directory = path.join("out", route.path);
  const html = await readFile(path.join(directory, "index.html"), "utf8");
  const $ = load(html);
  $("script,style,button,input,video,[aria-hidden=true],.lid-demo,.media-details-link,.filter-bar,.result-count,.download-cta,.back-link,.intro-separator").remove();
  const content = $("main").toArray().map(markdown).join("").replace(/\n{3,}/g, "\n\n").trim();
  await mkdir(directory, { recursive: true });
  await writeFile(path.join(directory, "index.md"), `${content}\n\nCanonical: ${site.url}${route.path}\n`);
}
await writeFile("out/llms.txt", `# UnfoldMyMac\n\n> ${site.description}\n\nUnfoldMyMac has three collections: 13 Lid Effects, 20 Dynamic Wallpapers, and two Creative Scenes: Hinge Garden and The Workshop. Its redesigned library has category tabs, tag filters, grid/list browsing, feature badges, creator links, and full design detail pages. Hinge Garden reacts to lid movement and charger power, with optional motion and microphone input. The Workshop opens a miniature studio with the lid: open apps light its workbenches and items in an optional chosen folder become parcels. Counts stay local, file contents are not opened, and eight optional motivating lines rotate every forty-five seconds. It requires macOS 26 or later. Automatic lid effects require a readable MacBook lid-angle sensor; support varies by model. The website's interactive demo is a browser illustration. Wallpaper recordings use sample data. Grok and racing counters are playful session counters, not live service telemetry. Check the download page for current release availability.\n\n## Collections, designs, and guides\n\n${routes.map(route => `- [${route.title}](${site.url}${route.path}index.md)`).join("\n")}\n\n## Sources\n\n- [Source code and documentation](${site.repo})\n- [Matterward Labs](${site.company})\n`);
await writeFile("out/.nojekyll", "");
console.log(`Exported ${routes.length} Markdown mirrors and llms.txt.`);
