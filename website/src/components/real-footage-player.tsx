"use client";

import Image from "next/image";
import { pauseOtherFilms, useFilmPlayback } from "@/components/use-film-playback";
import { useYouTubePlayback } from "@/components/use-youtube-playback";
import { Download, Play, RotateCcw } from "lucide-react";
import { formatFilmTime, type RealFootage } from "@/lib/real-footage";

export function RealFootagePlayer({ item, featured = false }: { item: RealFootage; featured?: boolean }) {
  const { video, onError, loaded: fileLoaded, failed: fileFailed, format: fileFormat, play: playFile } = useFilmPlayback(item);
  const { holder, loaded: youtubeLoaded, failed: youtubeFailed, format: youtubeFormat, play: playYouTube } = useYouTubePlayback(item);
  const { loaded, failed, format, play } = item.youtubeId
    ? { loaded: youtubeLoaded, failed: youtubeFailed, format: youtubeFormat, play: playYouTube }
    : { loaded: fileLoaded, failed: fileFailed, format: fileFormat, play: playFile };
  return <article id={item.id} className={`real-film${featured ? " real-film-featured" : ""}`} data-provider={item.youtubeId ? "youtube" : "file"}>
    <div className={`real-film-frame${item.youtubeId ? " has-youtube" : ""}`}>
      <Image src={item.poster} alt={item.posterAlt ?? (featured ? "Watch the lid: an illustrated MacBook opening and closing" : `${item.title}, filmed on a real MacBook in a café`)} fill sizes={featured ? "(max-width: 800px) 92vw, 1160px" : "(max-width: 700px) 92vw, 560px"} />
      {item.youtubeId ? <div ref={holder} className={loaded ? "real-film-video is-loaded real-film-youtube" : "real-film-video"} /> : <video ref={video} controls={loaded} playsInline preload="none" tabIndex={loaded ? 0 : -1}
        aria-label={`${item.title} real-life video`} aria-describedby={`${item.id}-description`}
        className={loaded ? "real-film-video is-loaded" : "real-film-video"}
        onPlay={event => pauseOtherFilms(event.currentTarget)} onError={onError} />}
      {!loaded && <FilmPlayButton item={item} failed={failed} play={play} />}
    </div>
    <FilmDetails item={item} format={format} />
    {featured && <FilmChapters item={item} play={play} />}
    {failed && <p className="real-film-error" role="status">The film couldn’t load. {item.youtubeId ? "Try again or open it on YouTube." : "Try again or download the MP4."}</p>}
  </article>;
}

function FilmPlayButton({ item, failed, play }: { item: RealFootage; failed: boolean; play(startAt?: number): void }) {
  return <><button type="button" className="real-film-play" onClick={() => void play()} aria-label={`${failed ? "Retry" : "Play"} ${item.title} real-life video`}>
    {failed ? <RotateCcw size={26} aria-hidden="true" /> : <Play size={26} aria-hidden="true" />}<span>{failed ? "Try again" : "Play film"}</span>
  </button><span className="real-film-duration">{formatFilmTime(Math.round(item.duration))} · Sound on</span></>;
}

function FilmDetails({ item, format }: { item: RealFootage; format: string | null }) {
  const status = format ? ` · Playing in ${format}` : item.youtubeId ? " · 4K on YouTube" : " · HDR available";
  return <div className="real-film-caption"><div>
    <span className="real-film-category">{item.category} <span aria-hidden="true">/</span> Real footage{status}</span>
    <h3>{item.title}</h3><p id={`${item.id}-description`}>{item.description}</p>
  </div><div className="real-film-downloads">{item.youtubeId ? <a className="real-film-download" href={`https://www.youtube.com/watch?v=${item.youtubeId}`}>Watch on YouTube ↗</a> : <>
    <a className="real-film-download" href={item.hdrVideo} download aria-label={`Download ${item.title} HDR video`}><Download size={17} aria-hidden="true" /><span>HDR</span></a>
    <a className="real-film-download" href={item.video} download aria-label={`Download ${item.title} video`}><span>SDR MP4</span></a>
  </>}</div></div>;
}

function FilmChapters({ item, play }: { item: RealFootage; play(startAt?: number): void }) {
  return <div className="film-chapters" aria-label="Film chapters"><span>Jump to</span>{item.chapters?.map(chapter => <button key={chapter.start} type="button" onClick={() => void play(chapter.start)}>{formatFilmTime(chapter.start)} · {chapter.label}</button>)}<a href="/media/real-life/reel-transcript.txt">Read transcript</a></div>;
}
