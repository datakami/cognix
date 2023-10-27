import sys
import subprocess
from shutil import rmtree, copyfileobj
from pathlib import Path
from urllib.request import urlretrieve, urlopen
from tempfile import TemporaryDirectory
import ssl

import tempfile
import pygit2 as git
from google.cloud import storage

from shared import Spec, Download, Lock, readLocks, readSpecs, toJSON, readLock, readSpec, parseLFS

# todo: why is this neccesary :|
cafile = ssl.get_default_verify_paths().cafile
context = ssl.create_default_context(cafile=cafile)
def def_https(*args, **kwargs):
    return ssl.create_default_context(*args, cafile=cafile, **kwargs)
ssl._create_default_https_context = def_https

def get_lfs_file(repo, commit, path):
    return f"https://huggingface.co/{repo}/resolve/{commit}/{path}"

def allglob(root: Path, patterns: list[str]) -> set[Path]:
    found = set()
    for pattern in patterns:
        for f in root.rglob(pattern):
            found.add(f.relative_to(root))
    return found
    
# todo: it would make sense to deal with LFS and globs here
def dump_tree(repo: git.Repository, t: git.Tree, root: Path):
    index = git.Index()
    index.read_tree(t)
    for entry in index:
        content = repo[entry.id].read_raw()
        path = root / entry.path
        path.parent.mkdir(parents=True, exist_ok=True)
        if entry.mode == git.GIT_FILEMODE_LINK:
            path.symlink_to(content.decode('utf-8'))
        else:
            path.write_bytes(content)
            path.chmod(entry.mode)

def git_repo_to_path(url, root, ref=None, rev=None):
    with TemporaryDirectory() as path:
        if rev is None:
            rev = "FETCH_HEAD"
        repo = git.init_repository(str(Path(path) / "tmp"))
        try:
            origin = repo.remotes["origin"]
            repo.remotes.set_url("origin", url)
        except KeyError:
            origin = repo.remotes.create("origin", url)
        refspec = None
        if ref is not None:
            refspec = [ref]
        origin.fetch(refspec, prune=git.GIT_FETCH_PRUNE)
        [commit, fetch_head] = repo.resolve_refish(rev)
        rev = str(commit.id)
        if root.exists():
            rmtree(root)
        dump_tree(repo, commit.peel(git.Tree), root)
    return rev

def collect_downloads(src, rev, root: Path, files: set[Path]) -> list[Download]:
    downloads = []
    for rel in files:
        lfs_spec = parseLFS(root / rel)
        if not lfs_spec:
            print(f"warning: matched {rel} but is not an LFS file", file=sys.stderr)
            continue
        downloads.append(Download(get_lfs_file(src, rev, rel), str(rel), lfs_spec["oid"]))
    return downloads

def nix_hash(path: Path):
    return subprocess.run(["nix", "hash", "path", str(path)], capture_output=True, encoding='utf8').stdout.strip()

def lock(spec: Spec) -> Lock:
    with TemporaryDirectory() as path:
        root = Path(path)
        rev = git_repo_to_path(f"https://huggingface.co/{spec.src}", root, spec.ref, spec.rev)
        build_files = allglob(root, spec.build_include)
        for download in collect_downloads(spec.src, rev, root, build_files):
            print("downloading", download.dest, file=sys.stderr)
            urlretrieve(download.url, str(root / download.dest))
        download_files = allglob(root, spec.download_include)
        for rel in build_files.intersection(download_files):
            print(f"warning: {rel} specified at build and runtime, defaulting to buildtime", file=sys.stderr)
        downloads = collect_downloads(spec.src, rev, root, download_files - build_files)
        nixHash = nix_hash(root)
    return Lock(rev, nixHash, downloads)

def build(root: Path, spec: Spec, lock: Lock):
    rev = git_repo_to_path(f"https://huggingface.co/{spec.src}", root, spec.ref, lock.rev)
    build_files = allglob(root, spec.build_include)
    for download in collect_downloads(spec.src, rev, root, build_files):
        print("downloading", download.dest, file=sys.stderr)
        urlretrieve(download.url, str(root / download.dest))

def push(spec: Spec, lock: Lock):
    storage_client = storage.Client()
    bucket = storage_client.bucket("replicate-weights")
    for download in lock.download_files:
        filename = f'{spec.src.replace("/", "--")}/{lock.rev}/{download.dest}'
        blob = bucket.blob(filename)
        if blob.exists():
            print("already uploaded:", filename, file=sys.stderr)
            continue
        with tempfile.TemporaryFile() as tmpfile:
            # TODO: timeout, retry, progress bar, stream directly
            print("Uploading", download.dest, file=sys.stderr)
            with urlopen(download.url) as response:
                copyfileobj(response, tmpfile)
            tmpfile.seek(0)
            blob.upload_from_file(
                tmpfile,
                content_type="application/octet-stream"
            )

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("usage: fetchHuggingface.py <command> <args>")
        exit(1)
    match sys.argv[1]:
        case "lock":
            specs = readSpecs(sys.argv[2])
            print(toJSON([lock(spec) for spec in specs]))
        case "build":
            root = Path(sys.argv[2])
            specData = readSpec(sys.argv[3])
            lockData = readLock(sys.argv[4])
            build(root, specData, lockData)
        case "push":
            specs = readSpecs(sys.argv[2])
            locks = readLocks(sys.argv[3])
            for specData, lockData in zip(specs, locks):
                push(specData, lockData)
        case _:
            print("unknown command")
            exit(1)
