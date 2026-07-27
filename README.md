# 3D-print workspace

A workspace for parametric, CAD-kernel (build123d / OpenCASCADE) 3D-print
projects. Each project lives in its own subfolder; shared tooling stays here at
the root.

## Projects

- **[note/](note/)** — Pala-style pocket voice-note enclosure for the Waveshare
  ESP32-S3 1.54" e-Paper board + 503035 LiPo. Two-part snap-fit case, validated
  and print-ready. See [note/README.md](note/README.md).

## Shared (root level)

- `.venv/` — one virtual environment for all projects
- `requirements.txt` — shared Python dependencies (build123d, trimesh, …)
- `.gitignore`

## Setup (once)

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
```

Then run a project's scripts by path, e.g. `python note/src/validate.py`.
Each script writes its outputs inside its own project folder.

## Adding a project

Create a new folder alongside `note/` (e.g. `holder/`) with the same shape —
`src/ models/ renders/ docs/`. Scripts resolve their output dirs relative to
their own location, so the pattern copies cleanly.
