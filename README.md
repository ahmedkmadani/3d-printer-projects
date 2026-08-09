# 3D-print workspace

A workspace for parametric, CAD-kernel (build123d / OpenCASCADE) 3D-print
projects. Each project lives in its own subfolder; shared tooling stays here at
the root.

## Projects

- **[jota/](jota/)** — a pocket voice-note device: press a button, speak, and
  the transcript lands on your phone. Three parts, each with its own README:

  | | | |
  |---|---|---|
  | [`jota/`](jota/README.md) | enclosure | parametric snap-fit case, validated and print-ready |
  | [`jota/firmware/`](jota/firmware/README.md) | device | ESP32-S3, e-paper UI, BLE link |
  | [`jota/app/`](jota/app/README.md) | phone | Flutter companion — pulls notes over BLE, transcribes them |

  It has no WiFi and no server: the phone does the transcription with its own
  internet, so no credentials or API keys live on the device.

## Shared (root level)

- `.venv/` — one virtual environment for the CAD work
- `requirements.txt` — shared Python dependencies (build123d, trimesh, …)
- `.gitignore`

The firmware and app carry their own toolchains (PlatformIO and Flutter); only
the CAD side uses the shared venv.

## Setup (once)

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
```

Then run a project's scripts by path, e.g. `python jota/src/validate.py`.
Each script writes its outputs inside its own project folder.

`requirements.txt` needs Python 3.10+. `numpy` is left as a range rather than
pinned because the pinned version required 3.12.

## Adding a project

Create a new folder alongside `jota/` (e.g. `holder/`) with the same shape —
`src/ models/ renders/ docs/`. Scripts resolve their output dirs relative to
their own location, so the pattern copies cleanly.
