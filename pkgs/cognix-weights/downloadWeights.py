import sys
import subprocess
from pathlib import Path
from shared import Spec, Lock, readSpecs, readLocks

def pget(url: str, dest: Path):
    subprocess.run(["pget", url, "-o", str(dest)], check=True)

def run(root: Path, spec: Spec, lock: Lock):
    for download in lock.download_files:
        dest = root / spec.src / download.dest
        if dest.exists():
            print("Already downloaded", dest, file=sys.stderr)
            continue
        tmp_file = dest.with_suffix(dest.suffix + ".tmp")
        dest.parent.mkdir(parents=True, exist_ok=True)
        # download to temp file, remove first
        tmp_file.unlink(missing_ok=True)
        # todo: timeout
        pget(download.url, tmp_file)
        tmp_file.rename(dest)

if __name__ == '__main__':
    if len(sys.argv) < 4:
        print("usage: downloadWeights.py <root> <specs> <locks>")
        exit(1)
    root = Path(sys.argv[1])
    specs = readSpecs(sys.argv[2])
    locks = readLocks(sys.argv[3])
    for spec, lock in zip(specs, locks):
        run(root, spec, lock)
