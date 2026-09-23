#!/usr/bin/env python3
"""Can Google read Sudanese Arabic mixed with English?

This is the test docs/solution.md says comes before any more building. If the
text that comes back is unreadable, the product changes shape — so it is worth
half an hour now rather than a month later.

    python3 jota/tools/stt_test.py my-recording.ogg

Takes WAV or Ogg Opus — a phone recording is usually the latter.

Needs GOOGLE_STT_KEY in the environment (a Speech-to-Text API key from Google
Cloud, with billing enabled on the project).

It runs the SAME request the app makes — see
app/lib/transcribe/google_stt_transcriber.dart — so a result here is a result
in the product, not an approximation of one.

It tries several language settings against the same audio and prints them side
by side, because "Sudanese Arabic" has no code of its own at Google and which
neighbour reads it best is exactly the unknown.
"""

import argparse
import base64
import json
import os
import pathlib
import sys
import urllib.error
import urllib.request
import wave

ENDPOINT = "https://speech.googleapis.com/v1/speech:recognize"

# Sudanese has no code of its own. These are the candidates worth trying, and
# the point of the test is which one comes back readable.
ATTEMPTS = [
    ("Egyptian + English", "ar-EG", ["en-US"]),
    ("Egyptian only", "ar-EG", []),
    ("Modern Standard + English", "ar-SA", ["en-US"]),
    ("Gulf + English", "ar-AE", ["en-US"]),
    ("English + Egyptian", "en-US", ["ar-EG"]),
]


def probe(path: str) -> dict:
    """Work out what this file is, and refuse what the endpoint will refuse.

    Google can infer WAV from its header, but NOT Ogg Opus — that one has to be
    declared, with its sample rate, or the request comes back complaining about
    a bad encoding. Phone recordings are usually Opus, so this is the common
    case, not the exotic one.
    """
    head = open(path, "rb").read(4)

    if head == b"RIFF":
        with wave.open(path, "rb") as w:
            frames, rate, ch = w.getnframes(), w.getframerate(), w.getnchannels()
        secs = frames / float(rate)
        cfg = {"encoding": "LINEAR16", "sampleRateHertz": rate}
        kind = "WAV"

    elif head == b"OggS":
        # Opus is always decoded at 48 kHz regardless of what it was captured
        # at, and that is the number Google wants here.
        rate, ch = 48000, 1
        secs = _ogg_seconds(path) or 0.0
        cfg = {"encoding": "OGG_OPUS", "sampleRateHertz": rate}
        kind = "Ogg Opus"

    else:
        sys.exit(f"unrecognised audio: {head!r}\n"
                 "Convert first:  ffmpeg -i in.xxx -ac 1 -ar 16000 out.wav")

    size = os.path.getsize(path)
    dur = f"{secs:.1f}s" if secs else "unknown length"
    print(f"audio      {kind}, {dur}, {rate} Hz, {ch} channel(s), {size/1024:.0f} KB")

    if ch != 1:
        print("  ! not mono — Google will only transcribe the first channel")
    # The synchronous endpoint stops at about a minute. Longer needs
    # longrunningrecognize, which wants the audio in Cloud Storage first.
    if secs > 58:
        sys.exit(f"  ! {secs:.0f}s is past the ~60s limit of this endpoint.\n"
                 f"    Trim it for the test:  ffmpeg -i {path} -t 55 short.ogg")
    if size > 10 * 1024 * 1024:
        sys.exit("  ! over 10 MB, which this endpoint refuses")
    return cfg


def _ogg_seconds(path: str) -> float:
    """Length from the last Ogg page's granule position, at 48 kHz.

    Avoids depending on ffprobe just to print one number — and the length only
    matters here for the 60-second limit.
    """
    with open(path, "rb") as f:
        f.seek(0, os.SEEK_END)
        tail_at = max(0, f.tell() - 65536)
        f.seek(tail_at)
        tail = f.read()
    i = tail.rfind(b"OggS")
    if i < 0 or i + 14 > len(tail):
        return 0.0
    granule = int.from_bytes(tail[i + 6:i + 14], "little")
    return granule / 48000.0


def transcribe(key: str, audio_b64: str, lang: str, alts: list[str],
               audio_cfg: dict) -> str:
    config: dict = {
        "languageCode": lang,
        "enableAutomaticPunctuation": True,
        "model": "latest_long",
        **audio_cfg,
    }
    if alts:
        config["alternativeLanguageCodes"] = alts

    body = json.dumps({"config": config, "audio": {"content": audio_b64}})
    req = urllib.request.Request(
        f"{ENDPOINT}?key={key}",
        data=body.encode(),
        headers={"Content-Type": "application/json; charset=utf-8"},
    )
    try:
        with urllib.request.urlopen(req, timeout=180) as res:
            payload = json.load(res)
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        try:
            detail = json.loads(detail)["error"]["message"]
        except Exception:
            pass
        return f"[HTTP {e.code}] {detail}"
    except urllib.error.URLError as e:
        return f"[network] {e.reason}"

    # An empty `results` on a 200 means silence, or audio the endpoint would
    # not process — not "you said nothing".
    parts = [
        alt["transcript"].strip()
        for r in payload.get("results", [])
        for alt in r.get("alternatives", [])[:1]
        if alt.get("transcript", "").strip()
    ]
    return " ".join(parts) if parts else "[nothing came back]"



# ---- Gemini ---------------------------------------------------------------
# The v1 Speech API cannot do this job. Every dialect code (ar-SD included)
# falls back to the same Modern Standard model, `alternativeLanguageCodes`
# changes the output by not one byte, and 43 seconds of speech comes back as
# 23-35 words. Code-switching is the product, so that is disqualifying.
#
# Chirp 2 would be the fix inside Speech-to-Text, but the v2 API refuses API
# keys — it wants a service account. Gemini takes the SAME key this file
# already uses, and reads dialect and code-switching natively.

GEMINI_PROMPT = (
    "Transcribe this audio exactly as spoken. It is Sudanese Arabic mixed with "
    "English. Keep English words in Latin script and Arabic words in Arabic "
    "script - never translate one into the other. Transcribe every sentence, "
    "including quiet or unclear speech; mark anything genuinely inaudible as "
    "[...]. Output only the transcript."
)


def gemini_key() -> str:
    """Gemini's own key, falling back to the Speech one.

    They are usually the same key, but not always: a Speech-to-Text key often
    carries an API restriction that blocks Generative Language, and the quickest
    way out is a second key from aistudio.google.com/apikey rather than a fight
    with the restriction UI. GEMINI_KEY wins when it is set.
    """
    k = (os.environ.get("GEMINI_KEY") or os.environ.get("GOOGLE_STT_KEY") or "").strip()
    if not k:
        sys.exit("set GEMINI_KEY (or GOOGLE_STT_KEY) first")
    return k


def gemini(key: str, path: str, model: str) -> str:
    mime = "audio/ogg" if open(path, "rb").read(4) == b"OggS" else "audio/wav"
    with open(path, "rb") as f:
        blob = base64.b64encode(f.read()).decode()
    body = json.dumps({
        "contents": [{"parts": [
            {"text": GEMINI_PROMPT},
            {"inline_data": {"mime_type": mime, "data": blob}},
        ]}],
        # Transcription is not a creative task; drifting off the audio is the
        # one failure mode that matters here.
        "generationConfig": {"temperature": 0.0},
    })
    req = urllib.request.Request(
        f"https://generativelanguage.googleapis.com/v1beta/models/"
        f"{model}:generateContent?key={key}",
        data=body.encode(),
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=300) as res:
            j = json.load(res)
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        try:
            detail = json.loads(detail)["error"]["message"]
        except Exception:
            pass
        return f"[HTTP {e.code}] {detail}"
    except urllib.error.URLError as e:
        return f"[network] {e.reason}"
    try:
        return j["candidates"][0]["content"]["parts"][0]["text"].strip()
    except (KeyError, IndexError):
        return f"[no transcript] {json.dumps(j)[:300]}"


def write_report(path: str, audio: str, results: list[tuple[str, str, str]]) -> str:
    """Write the transcripts to a file that renders right-to-left properly.

    A terminal puts Arabic through bidi reordering that ranges from imperfect
    to unreadable, which makes the one judgement this test exists for — "could
    I work out what I meant from this?" — impossible to make. The answer has to
    be read somewhere that sets direction:rtl and uses a real Arabic face.
    """
    out = pathlib.Path(path)
    rows = []
    for name, lang, text in results:
        rows.append(
            f'<section>\n'
            f'  <h2>{name}</h2>\n'
            f'  <p class="code">{lang}</p>\n'
            f'  <p class="t" dir="auto">{text}</p>\n'
            f'</section>'
        )
    out.write_text(f"""<!doctype html>
<html lang="ar" dir="rtl"><head><meta charset="utf-8">
<title>Jota — transcript test</title>
<style>
  :root {{ color-scheme: light dark; }}
  body {{ margin:0 auto; padding:40px 24px; max-width:44rem;
         background:#F6F1E8; color:#23201C;
         font-family:"IBM Plex Sans Arabic","Noto Sans Arabic",system-ui,sans-serif; }}
  @media (prefers-color-scheme: dark) {{ body {{ background:#23201C; color:#F6F1E8; }} }}
  header {{ direction:ltr; text-align:left; border-bottom:1px solid #8B817755;
            padding-bottom:16px; margin-bottom:8px; }}
  h1 {{ font-size:1.4rem; margin:0 0 4px; }}
  header p {{ margin:0; color:#8B8177; font-size:.85rem;
              font-family:ui-monospace,monospace; }}
  section {{ padding:22px 0; border-bottom:1px solid #8B817733; }}
  h2 {{ direction:ltr; text-align:left; font-size:.95rem; margin:0 0 2px; }}
  .code {{ direction:ltr; text-align:left; margin:0 0 14px; color:#8B8177;
           font-family:ui-monospace,monospace; font-size:.8rem; }}
  .t {{ margin:0; font-size:1.45rem; line-height:2; }}
  footer {{ direction:ltr; text-align:left; color:#8B8177; font-size:.9rem;
            padding-top:22px; line-height:1.6; }}
</style></head><body>
<header>
  <h1>Can Google read Sudanese Arabic?</h1>
  <p>{audio}</p>
</header>
{chr(10).join(rows)}
<footer>
  Read them, do not score them. The question is not whether the words are
  right &mdash; it is whether you could work out what you meant from this a
  week later. That is the whole product.
</footer>
</body></html>
""", encoding="utf-8")

    # A plain-text copy too, for grep and for diffing between runs.
    txt = out.with_suffix(".txt")
    txt.write_text(
        f"{audio}\n\n" + "\n\n".join(
            f"== {n}  ({l})\n{t}" for n, l, t in results
        ) + "\n", encoding="utf-8")
    return str(txt)


def main() -> None:
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("audio", help="a WAV or Ogg Opus recording")
    ap.add_argument("--out", help="where to write the report (default: "
                                  "alongside the audio)")
    ap.add_argument("--gemini", action="store_true",
                    help="use Gemini instead of Speech-to-Text (handles "
                         "dialect and code-switching; same API key)")
    a = ap.parse_args()
    path = a.audio
    key = os.environ.get("GOOGLE_STT_KEY", "").strip()
    if not key:
        sys.exit("set GOOGLE_STT_KEY first:\n  export GOOGLE_STT_KEY=AIza...")

    audio_cfg = probe(path)
    with open(path, "rb") as f:
        audio_b64 = base64.b64encode(f.read()).decode()

    results: list[tuple[str, str, str]] = []
    print()

    if a.gemini:
        key = gemini_key()
        for model in ("gemini-3.1-pro-preview", "gemini-3.6-flash"):
            print(f"── {model}", flush=True)
            text = gemini(key, path, model)
            print(text)
            print()
            results.append((model, "gemini", text))
        report = a.out or str(pathlib.Path(path).with_suffix("")) + "-gemini.html"
        txt = write_report(report, os.path.basename(path), results)
        print(f"written    {report}")
        print(f"           {txt}")
        return

    for name, lang, alts in ATTEMPTS:
        label = f"{lang}{' + ' + ', '.join(alts) if alts else ''}"
        print(f"── {name}  ({label})", flush=True)
        text = transcribe(key, audio_b64, lang, alts, audio_cfg)
        print(text)
        print()
        results.append((name, label, text))

    report = a.out or str(pathlib.Path(path).with_suffix("")) + "-transcript.html"
    txt = write_report(report, os.path.basename(path), results)
    print(f"written    {report}")
    print(f"           {txt}")
    print()

    print("Read them, do not score them. The question is not whether the words")
    print("are right — it is whether you could work out what you meant from")
    print("this a week later. That is the whole product.")


if __name__ == "__main__":
    main()
