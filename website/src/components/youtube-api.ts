export interface YouTubePlayer {
  playVideo(): void;
  pauseVideo(): void;
  seekTo(seconds: number, allowSeekAhead: boolean): void;
  destroy(): void;
  // Available in the current iframe API; feature-detect because it is not documented.
  unloadModule?(module: "captions"): void;
}
interface PlayerOptions {
  events: { onReady(): void; onError(): void; onStateChange(event: { data: number }): void };
}
interface YouTubeAPI { Player: new (element: HTMLIFrameElement, options: PlayerOptions) => YouTubePlayer }
declare global { interface Window { YT?: YouTubeAPI; onYouTubeIframeAPIReady?: () => void } }

let pending: Promise<YouTubeAPI> | null = null;

/** Called only after the visitor chooses to play a YouTube film. */
export function loadYouTubeAPI(): Promise<YouTubeAPI> {
  if (window.YT?.Player) return Promise.resolve(window.YT);
  if (pending) return pending;
  pending = new Promise<YouTubeAPI>((resolve, reject) => {
    const previous = window.onYouTubeIframeAPIReady;
    const script = document.createElement("script");
    const timeout = window.setTimeout(() => fail(), 15000);
    function fail() {
      window.clearTimeout(timeout);
      script.remove();
      window.onYouTubeIframeAPIReady = previous;
      pending = null;
      reject(new Error("YouTube could not load"));
    }
    window.onYouTubeIframeAPIReady = () => {
      window.clearTimeout(timeout);
      previous?.();
      if (window.YT?.Player) resolve(window.YT);
      else fail();
    };
    script.src = "https://www.youtube.com/iframe_api";
    script.async = true;
    script.onerror = fail;
    document.head.append(script);
  });
  return pending;
}
