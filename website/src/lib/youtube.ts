/** Accept a YouTube ID or a link supplied after upload. Reject unrelated URLs. */
export function youtubeId(value: string | null | undefined): string | null {
  if (!value) return null;
  if (/^[\w-]{11}$/.test(value)) return value;
  try {
    const url = new URL(value);
    if (url.protocol !== "https:" || url.username || url.password || url.port) return null;
    const host = url.hostname.toLowerCase();
    const candidate = host === "youtu.be" ? url.pathname.slice(1) :
      ["youtube.com", "www.youtube.com", "m.youtube.com", "www.youtube-nocookie.com"].includes(host) ?
        url.pathname === "/watch" ? url.searchParams.get("v") : /^\/(embed|shorts)\/([\w-]{11})\/?$/.exec(url.pathname)?.[2] : null;
    return candidate && /^[\w-]{11}$/.test(candidate) ? candidate : null;
  } catch { return null; }
}

export function youtubeEmbed(id: string, origin: string, start = 0): string {
  if (!/^[\w-]{11}$/.test(id)) throw new Error("Invalid YouTube video ID");
  const params = new URLSearchParams({ autoplay: "1", playsinline: "1", enablejsapi: "1", rel: "0", cc_load_policy: "0", origin });
  if (start > 0) params.set("start", String(Math.floor(start)));
  return `https://www.youtube-nocookie.com/embed/${id}?${params}`;
}
