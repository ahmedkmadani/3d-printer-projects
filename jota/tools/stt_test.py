#!/usr/bin/env python3
"""Can Google read Sudanese Arabic mixed with English?

This is the test docs/solution.md says comes before any more building. If the
text that comes back is unreadable, the product changes shape — so it is worth
half an hour now rather than a month later.

    python3 jota/tools/stt_test.py my-recording.wav

Needs GOOGLE_STT_KEY in the environment (a Speech-to-Text API key from Google
Cloud, with billing enabled on the project).

It runs the SAME request the app makes — see
app/lib/transcribe/google_stt_transcriber.dart — so a result here is a result
in the product, not an approximation of one.

It tries several language settings against the same audio and prints them side
by side, because "Sudanese Arabic" has no code of its own at Google and which
neighbour reads it best is exactly the unknown.
"""

import base64
import json
import os
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


def check_audio(path: str) -> float:
    """Refuse audio the endpoint will refuse, with a reason you can act on."""
    try:
        with wave.open(path, "rb") as w:
            frames, rate, ch = w.getnframes(), w.getframerate(), w.getnchannels()
    except wave.Error as e:
        sys.exit(f"not a WAV file this can read: {e}\n"
                 "Convert first:  ffmpeg -i in.m4a -ac 1 -ar 16000 out.wav")

    secs = frames / float(rate)
    print(f"audio      {secs:.1f}s, {rate} Hz, {ch} channel(s)")

    if ch != 1:
        print("  ! not mono — Google will only transcribe the first channel")
    # The synchronous endpoint stops at about a minute. Longer needs
    # longrunningrecognize, which wants the audio in Cloud Storage first.
    if secs > 58:
        sys.exit(f"  ! {secs:.0f}s is past the ~60s limit of this endpoint.\n"
                 "    Trim it for the test:  ffmpeg -i in.wav -t 55 short.wav")
    if os.path.getsize(path) > 10 * 1024 * 1024:
        sys.exit("  ! over 10 MB, which this endpoint refuses")
    return secs


def transcribe(key: str, audio_b64: str, lang: str, alts: list[str]) -> str:
    config: dict = {
        "languageCode": lang,
        "enableAutomaticPunctuation": True,
        "model": "latest_long",
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


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    path = sys.argv[1]
    key = os.environ.get("GOOGLE_STT_KEY", "").strip()
    if not key:
        sys.exit("set GOOGLE_STT_KEY first:\n  export GOOGLE_STT_KEY=AIza...")

    check_audio(path)
    with open(path, "rb") as f:
        audio_b64 = base64.b64encode(f.read()).decode()

    print()
    for name, lang, alts in ATTEMPTS:
        print(f"── {name}  ({lang}{' + ' + ', '.join(alts) if alts else ''})")
        print(transcribe(key, audio_b64, lang, alts))
        print()

    print("Read them, do not score them. The question is not whether the words")
    print("are right — it is whether you could work out what you meant from")
    print("this a week later. That is the whole product.")


if __name__ == "__main__":
    main()
