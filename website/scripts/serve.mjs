import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import path from "node:path";
const root = path.resolve("out");
const types = { ".html": "text/html; charset=utf-8", ".css": "text/css", ".js": "text/javascript", ".json": "application/json", ".txt": "text/plain; charset=utf-8", ".md": "text/markdown; charset=utf-8", ".xml": "application/xml", ".webp": "image/webp", ".png": "image/png", ".svg": "image/svg+xml", ".mp4": "video/mp4", ".woff2": "font/woff2", ".ttf": "font/ttf" };
createServer(async (req, res) => {
  try {
    const url = new URL(req.url, "http://localhost");
    let filename = path.resolve(root, `.${decodeURIComponent(url.pathname)}`);
    if (!filename.startsWith(`${root}${path.sep}`) && filename !== root) { res.writeHead(403).end(); return; }
    if ((await stat(filename)).isDirectory()) filename = path.join(filename, "index.html");
    const bytes = await readFile(filename);
    const range = req.headers.range?.match(/^bytes=(\d+)-(\d*)$/);
    const headers = { "Content-Type": types[path.extname(filename)] || "application/octet-stream", "Accept-Ranges": "bytes" };
    if (range) {
      const start = Number(range[1]), end = range[2] ? Math.min(Number(range[2]), bytes.length - 1) : bytes.length - 1;
      if (start > end || start >= bytes.length) { res.writeHead(416, { "Content-Range": `bytes */${bytes.length}` }).end(); return; }
      res.writeHead(206, { ...headers, "Content-Range": `bytes ${start}-${end}/${bytes.length}`, "Content-Length": end - start + 1 });
      res.end(req.method === "HEAD" ? undefined : bytes.subarray(start, end + 1));
    } else { res.writeHead(200, { ...headers, "Content-Length": bytes.length }); res.end(req.method === "HEAD" ? undefined : bytes); }
  } catch {
    res.writeHead(404, { "Content-Type": "text/html; charset=utf-8" });
    res.end(await readFile(path.join(root, "404.html")).catch(() => "Not found"));
  }
}).listen(Number(process.env.PORT || 4173), "127.0.0.1", () => console.log("Static site: http://127.0.0.1:4173"));
