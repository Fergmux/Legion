---
name: publish-release
description: "Upload Legion to GitHub (github.com/Fergmux/Legion, public): sync the source, then release the latest exported Windows playtest, Windows dev and macOS builds as v<version>. Use when the owner asks to upload, publish or release a build."
argument-hint: "[sync | release | release --clobber] [--notes \"text\"]"
user-invocable: true
allowed-tools: Read, Bash, PowerShell
---

# Publish to GitHub

The owner authorised (2026-11-04) uploading the project and its builds to
**github.com/Fergmux/Legion**. That repo is **PUBLIC**: anyone can read the source and download the
releases. All the work is in `tools/publish_github.py`; this skill only adds the checks around it.

## 1. Before anything goes up

1. `gh` must be logged in: `"C:\Program Files\GitHub CLI\gh.exe" auth status`. If not, ask the owner to
   run `gh auth login -h github.com -p https -w` in their own terminal. Never ask for or store a token.
2. Commit what should be public first. `sync` uploads only **committed** history of `main` and
   `build/legion-game`; it never pushes the working tree or the `worktree-agent-*` branches.
3. Scan the commits being added for secrets (service-account JSON, private keys, refresh tokens, API keys
   other than the Firebase web key in `legion/data/telemetry_config.json`, which ships in every build).
   On any hit: stop and tell the owner. Standing rule: no credentials in checked-in files.
4. For `release`, the builds must already be exported (`build/windows`, `build/windows-dev`,
   `build/macos/Legion-macos.zip`), and `config/version` in `legion/project.godot` bumped if this is a new
   release (also bump `application/short_version` and `application/version` of the "macOS" preset in
   `legion/export_presets.cfg`, which show in the .app's Info.plist). The publish script never exports.
   To export everything, run `python -I -X utf8 tools/export_all.py` (see "Exporting" below).

## Exporting (all three builds)

`tools/export_all.py` imports, then exports Windows playtest + dev (`Windows Desktop` preset, the
`legion_export` plugin writes `build/windows-dev`) and macOS (`macOS` preset), in one command:

```
python -I -X utf8 tools/export_all.py                  # everything
python -I -X utf8 tools/export_all.py --only macos     # or --only windows
python -I -X utf8 tools/export_all.py --check          # just test whether an export is allowed
python -I -X utf8 tools/export_all.py --godot <path-to-console-exe> --build-dir <dir>
```

- It **refuses to run** (exit 1, nothing written) while any `Legion*` process is running, or if the process
  list cannot be read. It never kills a process. Close the game yourself.
- Godot comes from `--godot`, then `$GODOT`, then the Downloads path in the script. It needs Godot 4.7.2 and
  the 4.7.2 export templates including `macos.zip` (`%APPDATA%\Godot\export_templates\4.7.2.stable`).
- The macOS zip is exported to a scratch folder, checked, then moved to `build/macos/Legion-macos.zip`; a bad
  export never replaces a good zip. Checks: all `.app` members and the signature present, a universal
  (2-architecture) binary, no `tests/`, `gdUnit4`, `legion_export` or `reports/` in the pck, and both S3TC
  and ASTC textures packed. The Windows step checks both folders were rewritten.
- After a Windows export it always rebuilds `build/Legion-friends.zip` and `build/Legion-dev.zip` (owner,
  17 Nov: the friends zip must never be older than the build) and prints each zip's size and pck time.
- The summary prints `OK`, `FAILED` or `NOT RUN` for every platform; any failure exits 1. Do not release
  after a FAILED line.
- In a git worktree the default `--build-dir` is that worktree's `build/`; pass the main tree's
  `build/` if the release is published from there.
- The first export after changing `textures/vram_compression/*` or pulling new art reimports textures
  (minutes). Run the import before the export, as the script does.

## 2. Run it

From the repo root:

```
python -I -X utf8 tools/publish_github.py sync                # source only
python -I -X utf8 tools/publish_github.py release             # sync + new release v<version>
python -I -X utf8 tools/publish_github.py release --clobber   # same version: replace its zips and notes
python -I -X utf8 tools/publish_github.py release --notes "What changed for testers"
```

Run it in the background (the filter and upload take a few minutes). What it does:
- `sync`:
  - takes a throwaway hardlinked clone in `..\.legion-github-mirror`;
  - strips `production/qa/evidence/` from all history (5.9 GB of screenshots that would break GitHub's
    limits) and pushes `main` + `build/legion-game`;
  - never force-pushes. A refused push means GitHub has commits this PC lacks: stop and ask.
  - Hashes on GitHub differ from the local ones.
- `release`:
  - zips `build/windows` -> `build/Legion-friends.zip` (playtest) and `build/windows-dev` ->
    `build/Legion-dev.zip` (dev), and uploads `build/macos/Legion-macos.zip` (already a zip) as the third asset;
  - warns if a build (including the macOS zip) is older than the last commit to `legion/`;
  - a missing, corrupt or incomplete macOS zip prints `WARNING ... WITHOUT the macOS build` and the
    release goes out with the two Windows assets; a missing Windows build stops the release;
  - the release notes describe each asset, including how to open the macOS app (below);
  - syncs, then creates release `v<version>` at the tip of `build/legion-game`, marked latest.

## 3. Report

Give the owner the release URL from the last line, the asset sizes (three, or say which is missing), and
any WARNING lines (stale build, uncommitted changes, missing macOS zip). Mention that the release is public.

## 4. The macOS build (what testers need to know)

- `Legion-macos.zip` holds `Legion.app`: a universal binary (Apple Silicon and Intel; Info.plist minimums macOS 11 on
  Apple Silicon and 10.12 on Intel, but the Metal renderer likely needs a newer macOS; untested). It is **ad-hoc signed and not notarized** (no
  Apple developer account), so Gatekeeper blocks the first launch.
- To open it: unzip, drag `Legion.app` to Applications, **right-click it, choose Open, then Open** in the
  dialog (needed once). If macOS says the app "is damaged and can't be opened", remove the download
  quarantine flag with `xattr -cr /Applications/Legion.app`, then open it. On recent macOS (Sequoia and
  later) the right-click route can be hidden: use System Settings > Privacy & Security > "Open Anyway".
- Steam works as on Windows: the Steam client must be running (AppID 480, the dev ID; the app ID is set in
  `project.godot` and passed to `steamInitEx`, so no `steam_appid.txt` is needed in the bundle). Without
  Steam, bot, hot-seat and LAN play still work.
- Not verifiable without a Mac: that the app launches, that Steam initialises and its overlay hooks Metal,
  that the ad-hoc signature validates (`codesign --verify --deep --strict Legion.app`), and the render result.
  The first tester on a Mac should report back; run the checks above.
