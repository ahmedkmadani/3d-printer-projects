# Injects the build identity: -DJOTA_GIT_REV="<short-sha>" and
# -DJOTA_BUILD_DATE="<yyyy-mm-dd>". A "+" on the sha means the tree was
# dirty, so a binary can never claim to BE a commit it only resembles.
# Outside a git checkout both fall back, and diag.cpp's defaults ("dev")
# still compile.
import datetime
import subprocess

Import("env")  # noqa: F821 — provided by SCons


def _git(args, fallback=""):
    try:
        return (
            subprocess.check_output(
                ["git"] + args,
                cwd=env["PROJECT_DIR"],  # noqa: F821
                text=True,
                stderr=subprocess.DEVNULL,
            ).strip()
            or fallback
        )
    except Exception:
        return fallback


rev = _git(["rev-parse", "--short", "HEAD"], "dev")
if rev != "dev" and _git(["status", "--porcelain", "--untracked-files=no"]):
    rev += "+"

env.Append(  # noqa: F821
    CPPDEFINES=[
        ("JOTA_GIT_REV", env.StringifyMacro(rev)),  # noqa: F821
        ("JOTA_BUILD_DATE", env.StringifyMacro(datetime.date.today().isoformat())),  # noqa: F821
    ]
)
