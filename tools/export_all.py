"""Export every Legion build in one go: Windows playtest + dev, and macOS.

    python -I -X utf8 tools/export_all.py                 # import, then Windows (playtest + dev) and macOS
    python -I -X utf8 tools/export_all.py --only macos    # or: --only windows
    python -I -X utf8 tools/export_all.py --check          # only report whether an export would be allowed
    python -I -X utf8 tools/export_all.py --build-dir D:/somewhere/build   # default: <repo>/build

Outputs (what tools/publish_github.py uploads):
    build/windows/Legion.exe + Legion.pck (+ the GodotSteam dll, steam_api64.dll, steam_appid.txt)
    build/windows-dev/Legion-dev.exe + Legion-dev.pck (written by the legion_export editor plugin)
    build/macos/Legion-macos.zip (Legion.app, universal, ad-hoc signed)

Safety:
- After a Windows export, rebuilds build/Legion-friends.zip and build/Legion-dev.zip (owner, 17 Nov).
- Refuses to run while any process named Legion* is running (the game or the dev build): overwriting the
  pck under a live game breaks its art loading. It never kills anything.
- The macOS zip is exported to a scratch folder, checked, and only then moved into build/macos, so a failed
  export never replaces a good zip with a half-written one.
- Every step is verified (exit code, fresh files, contents) and a failed step makes the whole run exit 1
  with FAILED in the summary. Nothing is reported as exported unless it was checked.
- Run it from the repo that holds the commit you want to ship. In a git worktree, pass --build-dir if the
  builds belong in the main tree's build/ folder.

The Godot executable comes from --godot, then the GODOT environment variable, then the default path below.
"""
import argparse
import os
import shutil
import subprocess
import sys
import time
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = os.path.join(ROOT, "legion")
DEFAULT_GODOT = os.path.join(os.path.expanduser("~"), "Downloads", "Godot_v4.7.2-stable_win64.exe", "Godot_v4.7.2-stable_win64_console.exe")
WINDOWS_PRESET = "Windows Desktop"
MACOS_PRESET = "macOS"
WINDOWS_FILES = ["Legion.exe", "Legion.pck", "libgodotsteam.windows.template_release.x86_64.dll", "steam_api64.dll",
                 "steam_appid.txt"]
DEV_FILES = ["Legion-dev.exe", "Legion-dev.pck"]
MACOS_REQUIRED = ["Legion.app/Contents/MacOS/Legion", "Legion.app/Contents/Info.plist",
                  "Legion.app/Contents/Resources/Legion.pck", "Legion.app/Contents/_CodeSignature/CodeResources",
                  "Legion.app/Contents/Frameworks/libgodotsteam.macos.template_release.universal.dylib",
                  "Legion.app/Contents/Frameworks/libsteam_api.dylib"]
FORBIDDEN_IN_PCK = ("tests/", "addons/gdUnit4", "addons/legion_export", "reports/")


def running_legion(tasklist_csv):
    """Names of the Legion* processes in `tasklist /FO CSV /NH` output (one quoted image name per line)."""
    found = []
    for line in tasklist_csv.splitlines():
        line = line.strip()
        if not line.startswith('"'):
            continue
        name = line.split('","')[0].strip('"')
        # 2026-11-17: also the game's old name (RLDB.exe, RLDB-dev.exe): a build exported before the rename
        # still runs from these build folders, and the export rewrites or removes files it reads lazily.
        if name.lower().startswith(("legion", "rldb")):
            found.append(name)
    return found


def legion_processes():
    """The running Legion* processes. Raises RuntimeError if the process list cannot be read: an export must
    not go ahead on a guess."""
    if os.name == "nt":
        r = subprocess.run(["tasklist", "/FO", "CSV", "/NH"], capture_output=True, text=True)
        if r.returncode != 0:
            raise RuntimeError("tasklist failed: " + (r.stderr or r.stdout).strip())
        return running_legion(r.stdout)
    r = subprocess.run(["ps", "-A", "-o", "comm="], capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError("ps failed: " + (r.stderr or r.stdout).strip())
    return [os.path.basename(n) for n in r.stdout.split("\n") if os.path.basename(n).lower().startswith("legion")]


def pck_paths(data):
    """File paths in a Godot 4 .pck (format 3) held in memory."""
    import struct
    if data[:4] != b"GDPC":
        raise ValueError("not a Godot pck")
    dir_off = struct.unpack("<Q", data[32:40])[0]
    count = struct.unpack("<I", data[dir_off:dir_off + 4])[0]
    p, out = dir_off + 4, []
    for _ in range(count):
        n = struct.unpack("<I", data[p:p + 4])[0]
        out.append(data[p + 4:p + 4 + n].rstrip(b"\0").decode("utf-8"))
        p += 4 + n + 8 + 8 + 16 + 4
    return out


def check_macos_zip(path):
    """Problems with an exported macOS zip, as a list of strings (empty = good)."""
    problems = []
    try:
        with zipfile.ZipFile(path) as z:
            names = set(z.namelist())
            bad = z.testzip()
            if bad:
                problems.append("corrupt member " + bad)
            for n in MACOS_REQUIRED:
                if n not in names:
                    problems.append("missing " + n)
            if not problems:
                head = z.read("Legion.app/Contents/MacOS/Legion")[:8]
                if head[:4] != b"\xca\xfe\xba\xbe" or head[4:8] != b"\x00\x00\x00\x02":
                    problems.append("Legion.app/Contents/MacOS/Legion is not a 2-architecture universal binary")
                pck = pck_paths(z.read("Legion.app/Contents/Resources/Legion.pck"))
                leaked = [n for n in pck if any(f in n for f in FORBIDDEN_IN_PCK)]
                if leaked:
                    problems.append("pck holds excluded paths, e.g. " + leaked[0])
                kinds = {k for k in ("s3tc", "etc2") if any(n.endswith(k + ".ctex") for n in pck)}
                if kinds != {"s3tc", "etc2"}:
                    problems.append("pck lacks a texture format (has %s; needs s3tc and etc2)" % sorted(kinds))
    except (zipfile.BadZipFile, OSError, ValueError) as e:
        problems.append("unreadable: %s" % e)
    return problems


def check_windows(build_dir, since):
    """Problems with the Windows playtest and dev folders after an export that started at `since`."""
    problems = []
    for folder, files in (("windows", WINDOWS_FILES), ("windows-dev", DEV_FILES)):
        for f in files:
            p = os.path.join(build_dir, folder, f)
            if not os.path.exists(p):
                problems.append("missing %s/%s" % (folder, f))
            elif f.endswith((".exe", ".pck")) and os.path.getmtime(p) < since:
                problems.append("%s/%s was not rewritten by this export" % (folder, f))
    return problems


def godot(godot_exe, *args):
    """Runs Godot in legion/. Returns (exit code, output)."""
    print("+ godot " + " ".join(args), flush=True)
    r = subprocess.run([godot_exe, "--headless", "--path", PROJECT, *args], capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    return r.returncode, (r.stdout or "") + (r.stderr or "")


def tail(text, n=25):
    return "\n".join(text.strip().splitlines()[-n:])


def export_windows(godot_exe, build_dir):
    since = time.time() - 2
    out = os.path.join(build_dir, "windows", "Legion.exe")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    appid = os.path.join(os.path.dirname(out), "steam_appid.txt")
    if not os.path.exists(appid):   # hand-placed once in build/windows; the exporter does not create it
        with open(appid, "w", encoding="ascii", newline="") as f:
            f.write("480")          # Spacewar, the Steam dev App ID (project.godot [steam] app_id)
        print("Wrote %s (App ID 480)." % appid)
    code, text = godot(godot_exe, "--export-release", WINDOWS_PRESET, out)
    if code != 0:
        return ["godot exited %d:\n%s" % (code, tail(text))]
    # The legion_export plugin writes the dev copy; if its pck is older, copy it (as the handoff says).
    dev_pck = os.path.join(build_dir, "windows-dev", "Legion-dev.pck")
    if os.path.exists(dev_pck) and os.path.getmtime(dev_pck) < os.path.getmtime(out.replace(".exe", ".pck")):
        shutil.copyfile(out.replace(".exe", ".pck"), dev_pck)
    return check_windows(build_dir, since)


def export_macos(godot_exe, build_dir):
    scratch = os.path.join(build_dir, "macos", ".export-tmp")
    shutil.rmtree(scratch, ignore_errors=True)
    os.makedirs(scratch)
    tmp_zip = os.path.join(scratch, "Legion-macos.zip")
    code, text = godot(godot_exe, "--export-release", MACOS_PRESET, tmp_zip)
    if code != 0:
        shutil.rmtree(scratch, ignore_errors=True)
        return ["godot exited %d:\n%s" % (code, tail(text))]
    if not os.path.exists(tmp_zip):
        shutil.rmtree(scratch, ignore_errors=True)
        return ["godot reported success but wrote no zip:\n" + tail(text)]
    problems = check_macos_zip(tmp_zip)
    if not problems:
        os.replace(tmp_zip, os.path.join(build_dir, "macos", "Legion-macos.zip"))
    shutil.rmtree(scratch, ignore_errors=True)
    return problems


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", choices=["windows", "macos"], help="export just one platform")
    ap.add_argument("--godot", default=os.environ.get("GODOT", DEFAULT_GODOT), help="Godot 4.7.2 console exe")
    ap.add_argument("--build-dir", default=os.path.join(ROOT, "build"))
    ap.add_argument("--skip-import", action="store_true", help="skip the `--import` pass (the .godot cache is fresh)")
    ap.add_argument("--check", action="store_true", help="only check that an export is allowed, then stop")
    a = ap.parse_args()

    try:
        busy = legion_processes()
    except RuntimeError as e:
        sys.exit("REFUSED: cannot tell whether Legion is running (%s). Not exporting." % e)
    if busy:
        sys.exit("REFUSED: %s is running. Close it first (overwriting the pck under a live game breaks its art). "
                 "Nothing was exported." % ", ".join(sorted(set(busy))))
    if not os.path.exists(a.godot):
        sys.exit("Godot not found at %s. Pass --godot or set GODOT." % a.godot)
    print("No Legion process is running; export allowed.")
    if a.check:
        return
    build_dir = os.path.abspath(a.build_dir)
    print("Build folder: " + build_dir)

    if not a.skip_import:
        code, text = godot(a.godot, "--import")
        if code != 0:
            sys.exit("FAILED: godot --import exited %d:\n%s" % (code, tail(text)))
    steps = []
    if a.only in (None, "windows"):
        steps.append(("Windows playtest + dev", export_windows))
    if a.only in (None, "macos"):
        steps.append(("macOS", export_macos))
    failed = False
    for label, fn in steps:
        problems = fn(a.godot, build_dir)
        if problems:
            failed = True
            print("FAILED %s:\n  - %s" % (label, "\n  - ".join(problems)))
        else:
            print("OK     %s (checked)" % label)
    for label, ran in (("Windows playtest + dev", a.only in (None, "windows")), ("macOS", a.only in (None, "macos"))):
        if not ran:
            print("NOT RUN %s (--only %s)" % (label, a.only))
    if failed:
        sys.exit(1)
    # Owner, 17 Nov: the friends zip (and the dev zip) are rebuilt on every Windows export, so the file to send
    # to testers is never older than the build. Same packaging as tools/publish_github.py (its zip_build).
    if a.only in (None, "windows") and os.path.normcase(build_dir) == os.path.normcase(os.path.join(ROOT, "build")):
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import publish_github
        for asset, spec in publish_github.BUILDS.items():
            publish_github.zip_build(asset, *spec)
    elif a.only in (None, "windows"):
        print("NOT RUN zips: --build-dir is not the repo's build/, so build/Legion-friends.zip was NOT rebuilt.")
    print("All requested exports done. Next: python -I -X utf8 tools/publish_github.py release")


if __name__ == "__main__":
    main()
