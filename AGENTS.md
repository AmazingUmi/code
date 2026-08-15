# AGENTS.md

Personal research codebase ("Umi的代码库") for underwater-acoustic signal simulation. Docs, comments, and commit messages are in Chinese — match that in commits. No CI, linters, or test infrastructure; verify changes by running the specific script/module affected.

## Layout & authority

- `matlab/UASignalAugmentor/` — **the authoritative, complete pipeline** (A1–A5). Python is a partial port; when behavior conflicts, MATLAB wins.
- `py/UASignalAugmentor/` — in-progress Python partial port. Only `modules/A1_SignalAnalyzer.py`, `A2_EnvGenerator.py`, `B1_DataPreprocess.py` + `utils/` exist; run via `examples/*.py` (no `main.py`, no tests, no CLI). **Its README describes an aspirational structure that doesn't match reality** — trust the files. `config/*.json` still contain stale Windows `G:/` paths; fix/override them rather than trusting defaults. Note: `A2_EnvGenerator.py` was ported from the OLD `matlab/arr_test` scripts (`A22origin_ENVmake.m` / `A3envfilmade.m`), not from the current `A2ENVmaker.m` / `A3ENVDuplicator.m` — it is **not behaviorally aligned** with the current MATLAB pipeline (e.g. per-frequency reflection-coefficient recalculation is missing).
- `py/EnvProcess/` — standalone ETOPO2022/WOA23 netCDF → `.mat`/`.npz` extractors (deps: numpy, scipy, netCDF4, tqdm). Docstring paths like `D:\database\...` are stale Windows defaults; the real database location must be passed in.
- `py/old/` — legacy PyTorch classifier training (DenseNet/ResNet/ConvNext) with committed training logs and `model.pth`. Not part of the main pipeline; don't modernize unprompted.
- `matlab/arr_test/` — **historical predecessor** of `UASignalAugmentor` (older A1–D2 script names). Superseded by UASA; don't develop here. Contains `项目总结与Python转码计划.md`, the original blueprint of the Python port.
- `cpp/` — old Windows Visual Studio experiments with committed build artifacts (`.exe`, `.obj`, `.vs/`), incl. `sspmake/`, `fbnq/`, `test/`, `learn_0630/`, `arrtest/`. Mostly superseded; the live C++ code is in `matlab/UASignalAugmentor/CallBell/`.
- `matlab/underwateracoustic/` (incl. large WOA18/ETOPO `.mat` libraries), `matlab/特性分析/`, `matlab/NoiseGenerate/`, `matlab/CyxReverberation/`, `matlab/不同海洋环境聚类/` (clustering analysis + its own large `.mat` data), `matlab/env_data_read/` (ADCP/OBS/typhoon data readers), `matlab/basic_module/` (minimal script template using the same active-editor init) — auxiliary standalone code, no code-level coupling with the main pipeline.
- `doc/` — reference papers (PDF/docx/xlsx), not code.

## Main pipeline (MATLAB, order matters)

`ConfigMaker.m` (writes `Config{Shallow|Transition|Deep}.mat` into `data/OriginEnvPack/`) → `A1WavTransformer.m` → `A2ENVmaker.m` → `A3ENVDuplicator.m` (writes `.env` files + `env_files_list.txt`) → **run BELLHOP via CallBell binary** → `A4ArrProcessor.m` (parses `.arr`) → `A5RecSigSynthesizer.m`.

Eddy variant: `Eddy/EXTRA_EddyConfigMaker.m` → `EXTRA_EddyAnalyzer.m` / `EddyComparison.m`.

Config tracking status (2026-08 audit): `data/OriginEnvPack/ConfigDeep.mat` **is tracked in git**; `ConfigShallow/Transition.mat` are not in the tree. Whether a config file is present is a fact of the git tree, not a policy — check `git ls-files` before assuming.

### Gotchas

- The A-scripts and Eddy scripts open with `matlab.desktop.editor.getActive` and `cd` to the active editor file's dir — **they must be run as the active file in the MATLAB desktop editor**, not via `matlab -batch` from an arbitrary cwd. This block also performs `addpath(function/)`; do not remove it without a compatible replacement.
- BELLHOP parallel run (see `CallBell/命令.txt`):
  ```
  ./BellParallelMac <abs path to dir containing env_files_list.txt>
  ```
  Run from `CallBell/mac/` (or `win/`, `lin/`): the binary locates `bellhop.exe` **next to itself via its own cwd**, then chdirs into the target dir. The executable is named `bellhop.exe` even on macOS/Linux.
- Rebuild command for `BellParallelMac` is embedded as a comment on line 9 of `BellParallelMac.cpp` (clang++ + miniconda3 OpenMP paths).
- Committed binaries (`bellhop.exe`, `BellParallelMac*`) and VS build artifacts are intentional runtime dependencies / deliberately retained history — the root `.gitignore` (added 2026-08) only ignores OS/cache temp files (`.DS_Store`, `__pycache__/`, `*.py[cod]`, `*.asv`). Don't clean, gitignore, or delete binaries/data unprompted.

## Data conventions

- `matlab/UASignalAugmentor/data/OceanData/`: `ETOPO2022.mat` + `woa23_00..16.mat`. WOA23 file index mapping (see `function/load_data.m`): files `01–12` = months, `13–16` = seasons, `00` = annual; loaded as indices 1–12 (months), 13–16 (seasons), 17 (annual).
- `data/OriginEnvPack/{Shallow,Transition,Deep}/ENVn/Rrn/EnvTemplate/` describes the **runtime-generated layout** produced by A2/A3 — one `EnvTemplate` dir per (site, range), each holding a batch of `.env` files plus `env_files_list.txt` for the CallBell binary. The repo does **not** necessarily retain full generated batches; the current tree keeps only `ConfigDeep.mat` there, full packs are regenerated by the pipeline.
- `data/raw/Class {A..E}/*.wav` are pipeline inputs (one sample per class is committed); `data/processed/` holds A1/A5 outputs (e.g. `Analy_freq_all.mat`). Treat everything under `data/` as large/expensive — never delete or regenerate wholesale without being asked.

## Key docs

- `matlab/UASignalAugmentor/README.md` — UASA entry point & run order (start here for the MATLAB pipeline).
- Root `README.md` — repo navigation and status; `readme.txt` — original historical log (kept as-is).
- `matlab/UASignalAugmentor/doc/项目说明文档.md` — full pipeline + data layout (best single reference).
- `matlab/UASignalAugmentor/doc/接口文档.md` — function interfaces.
- `matlab/UASignalAugmentor/doc/BEHAVIOR_BASELINE.md` + `baseline/` — behavioral baseline & regression harness (run after any MATLAB change).
- `matlab/UASignalAugmentor/doc/FUNCTION_MAP.md`, `doc/FUNCTION_ARCHITECTURE.md`, `doc/CONFIGURATION_MAP.md` — function classification, dependency audit, parameter map.
- `py/UASignalAugmentor/docs/PROJECT_STATUS.md`, `docs/CONFIG_DESIGN.md`, `modules/COMPLETION_SUMMARY.md` — port status snapshots (historical/stale in parts; verify against code).

## Modernization rules

- Preserve numerical and scientific behavior unless a behavior change is explicitly requested.
- Never fix suspected scientific/algorithmic bugs as part of an unrelated refactor.
- Separate behavior changes from refactors into different commits.
- Prefer characterization/baseline tests before restructuring legacy scientific code.
- Do not rewrite Git history unless explicitly requested.
- Do not remove tracked binaries solely because they are binaries.
- MATLAB authoritative behavior takes precedence over incomplete Python ports.
