# Cap parallel compile jobs to keep clean builds deterministic.
# With 8 jobs on this machine, a compile process occasionally gets killed
# mid-build, leaving `ar` with a missing .o ("No such file or directory").
# 4 jobs is still fast but avoids the race. Applies to CLI and the VS Code
# PlatformIO extension alike (both go through SCons).
Import("env")
env.SetOption("num_jobs", 4)
