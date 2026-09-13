export const interactiveScenes = ["hinge-garden", "the-workshop"] as const;
export type InteractiveScene = (typeof interactiveScenes)[number];
export type SceneClip = "idle" | "connect" | "disconnect" | "lid";
export const sceneLidAngles = { min: 8, max: 125 };
export function isInteractiveScene(id: string): id is InteractiveScene { return interactiveScenes.some(scene => scene === id); }
export function sceneClipURL(scene: InteractiveScene, clip: SceneClip, charging: boolean) {
  const name = clip === "idle" || clip === "lid" ? `${clip}-${charging ? "charging" : "battery"}` : clip;
  return `/media/interactive/${scene}-${name}.mp4`;
}
export function scenePosterURL(scene: InteractiveScene, charging: boolean, closed = false) {
  return `/media/interactive/${scene}-${closed ? "closed" : "open"}-${charging ? "charging" : "battery"}.webp`;
}
// The seekable native clip has one independent frame for each degree from 8° to 110°.
export function sceneLidTime(angle: number) { return Math.max(0, Math.min(102, angle - 8)) / 60; }
