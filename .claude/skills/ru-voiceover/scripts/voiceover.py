#!/usr/bin/env python3
"""Накладывает озвучку (Microsoft Edge TTS, по умолчанию ru-RU-DmitryNeural) на видео.

Примеры:
  python3 voiceover.py video.mp4 --text "Привет! Это наш новый продукт." -o out.mp4
  python3 voiceover.py video.mp4 --text-file script.txt -o out.mp4 --keep-audio 0.2
  python3 voiceover.py video.mp4 --audio voice.mp3 -o out.mp4      # без TTS, готовый звук

Рядом с результатом пишется .srt с субтитрами по фразам (если озвучка шла через TTS).
Нужны: pip install edge-tts, ffmpeg/ffprobe в PATH, доступ к speech.platform.bing.com.
"""
import argparse
import asyncio
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

DEFAULT_VOICE = "ru-RU-DmitryNeural"


def log(msg):
    print(msg, file=sys.stderr)


def probe(path):
    """Длительность файла и наличие аудиодорожки."""
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration:stream=codec_type",
         "-of", "json", str(path)],
        check=True, capture_output=True, text=True,
    ).stdout
    info = json.loads(out)
    duration = float(info["format"]["duration"])
    has_audio = any(s.get("codec_type") == "audio" for s in info.get("streams", []))
    return duration, has_audio


async def synthesize(text, voice, rate, volume, pitch, audio_path, srt_path):
    import edge_tts

    proxy = os.environ.get("HTTPS_PROXY") or os.environ.get("https_proxy") or None
    communicate = edge_tts.Communicate(text, voice, rate=rate, volume=volume, pitch=pitch, proxy=proxy)
    submaker = edge_tts.SubMaker()
    with open(audio_path, "wb") as f:
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                f.write(chunk["data"])
            elif chunk["type"] in ("WordBoundary", "SentenceBoundary"):
                submaker.feed(chunk)
    if srt_path:
        Path(srt_path).write_text(submaker.get_srt(), encoding="utf-8")


def build_ffmpeg_cmd(video, voice_audio, output, *, video_dur, video_has_audio, voice_dur,
                     delay, keep_audio, voice_volume, fit):
    voice_end = delay + voice_dur
    extend = fit == "extend" and voice_end > video_dur
    final_dur = voice_end if extend else video_dur

    filters = []
    if extend:
        # Замораживаем последний кадр, пока не закончится озвучка.
        filters.append(f"[0:v]tpad=stop_mode=clone:stop_duration={voice_end - video_dur + 0.1:.3f}[v]")
        video_map, video_codec = "[v]", ["-c:v", "libx264", "-preset", "veryfast", "-crf", "18", "-pix_fmt", "yuv420p"]
    else:
        video_map, video_codec = "0:v:0", ["-c:v", "copy"]

    delay_ms = int(delay * 1000)
    filters.append(f"[1:a]adelay={delay_ms}|{delay_ms},volume={voice_volume},apad[voice]")
    if keep_audio > 0 and video_has_audio:
        filters.append(f"[0:a]volume={keep_audio},apad[bg]")
        filters.append("[voice][bg]amix=inputs=2:duration=longest:dropout_transition=0:normalize=0[a]")
        audio_map = "[a]"
    else:
        audio_map = "[voice]"

    return [
        "ffmpeg", "-y", "-v", "error", "-i", str(video), "-i", str(voice_audio),
        "-filter_complex", ";".join(filters),
        "-map", video_map, "-map", audio_map,
        *video_codec, "-c:a", "aac", "-b:a", "192k",
        "-t", f"{final_dur:.3f}", "-movflags", "+faststart", str(output),
    ], final_dur


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("video", help="исходное видео")
    src = p.add_mutually_exclusive_group(required=True)
    src.add_argument("--text", help="текст озвучки")
    src.add_argument("--text-file", help="файл с текстом озвучки (UTF-8)")
    src.add_argument("--audio", help="готовый аудиофайл вместо TTS")
    p.add_argument("-o", "--output", help="куда сохранить (по умолчанию <video>_voiced.mp4)")
    p.add_argument("--voice", default=DEFAULT_VOICE, help=f"голос edge-tts (по умолчанию {DEFAULT_VOICE})")
    p.add_argument("--rate", default="+0%", help="скорость речи, напр. +10%% или -15%%")
    p.add_argument("--volume", default="+0%", help="громкость TTS, напр. +20%%")
    p.add_argument("--pitch", default="+0Hz", help="высота голоса, напр. -5Hz")
    p.add_argument("--delay", type=float, default=0.0, help="задержка начала озвучки, сек")
    p.add_argument("--voice-volume", type=float, default=1.0, help="множитель громкости озвучки при сведении")
    p.add_argument("--keep-audio", type=float, default=0.0,
                   help="оставить исходный звук видео с этой громкостью (0 — убрать, 0.2 — тихий фон)")
    p.add_argument("--fit", choices=["extend", "cut"], default="extend",
                   help="если озвучка длиннее видео: extend — заморозить последний кадр, cut — обрезать озвучку")
    p.add_argument("--no-srt", action="store_true", help="не сохранять субтитры .srt")
    args = p.parse_args()

    video = Path(args.video)
    output = Path(args.output) if args.output else video.with_name(video.stem + "_voiced.mp4")
    srt_path = None if (args.no_srt or args.audio) else output.with_suffix(".srt")

    with tempfile.TemporaryDirectory() as tmp:
        if args.audio:
            voice_audio = Path(args.audio)
        else:
            text = args.text if args.text is not None else Path(args.text_file).read_text(encoding="utf-8")
            if not text.strip():
                sys.exit("Пустой текст озвучки")
            voice_audio = Path(tmp) / "voice.mp3"
            log(f"Озвучка голосом {args.voice}…")
            try:
                asyncio.run(synthesize(text, args.voice, args.rate, args.volume, args.pitch, voice_audio, srt_path))
            except Exception as e:  # noqa: BLE001 — показываем понятную причину вместо трейсбека
                sys.exit(f"Не удалось получить озвучку от Edge TTS ({type(e).__name__}: {e}).\n"
                         "Проверьте доступ к speech.platform.bing.com в настройках сети.")

        video_dur, video_has_audio = probe(video)
        voice_dur, _ = probe(voice_audio)
        cmd, final_dur = build_ffmpeg_cmd(
            video, voice_audio, output, video_dur=video_dur, video_has_audio=video_has_audio,
            voice_dur=voice_dur, delay=args.delay, keep_audio=args.keep_audio,
            voice_volume=args.voice_volume, fit=args.fit,
        )
        subprocess.run(cmd, check=True)

    log(f"Видео {video_dur:.1f} c, озвучка {voice_dur:.1f} c, результат {final_dur:.1f} c")
    if args.fit == "cut" and args.delay + voice_dur > video_dur:
        log("Внимание: озвучка длиннее видео и обрезана (--fit cut)")
    print(output)
    if srt_path:
        print(srt_path)


if __name__ == "__main__":
    main()
