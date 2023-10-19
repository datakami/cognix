import json
import sys
from dataclasses import dataclass, field, asdict
from typing import Optional
import subprocess
from shutil import rmtree
from pathlib import Path
from urllib.request import urlretrieve
from tempfile import TemporaryDirectory
import os
import pygit2 as git
import ssl

# todo: why is this neccesary :|
cafile = ssl.get_default_verify_paths().cafile
context = ssl.create_default_context(cafile=cafile)
def def_https(*args, **kwargs):
    return ssl.create_default_context(*args, cafile=cafile, **kwargs)
ssl._create_default_https_context = def_https

@dataclass
class Spec:
    src: str
    rev: Optional[str] = None
    ref: Optional[str] = None
    build_include: list[str] = field(default_factory=list)
    download_include: list[str] = field(default_factory=list)

@dataclass
class Download:
    url: str
    dest: str
    hash: str

@dataclass
class Lock:
    rev: str
    hash: str
    download_files: list[Download]

def get_lfs_file(repo, commit, path):
    return f"https://huggingface.co/{repo}/resolve/{commit}/{path}"

def parseLFS(p: Path):
    ret = {}
    if p.stat().st_size >= 1024:
        return None
    with p.open() as f:
        for line in f:
            [k, v] = line.strip().split(" ", 1)
            ret[k] = v
    if not ("version" in ret and "oid" in ret and "size" in ret):
        return None
    return ret
    
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
        
        nixHash = subprocess.run(["nix", "hash", "path", str(root)], capture_output=True, encoding='utf8').stdout.strip()
    return Lock(rev, nixHash, downloads)

def build(root: Path, spec: Spec, lock: Lock):
    rev = git_repo_to_path(f"https://huggingface.co/{spec.src}", root, spec.ref, lock.rev)
    build_files = allglob(root, spec.build_include)
    for download in collect_downloads(spec.src, rev, root, build_files):
        print("downloading", download.dest, file=sys.stderr)
        urlretrieve(download.url, str(root / download.dest))

def run(root: Path, spec: Spec, lock: Lock):
    build_files = allglob(root, spec.build_include)
    download_files = allglob(root, spec.download_include)
    downloads = collect_downloads(spec.src, rev, root, download_files - build_files)
    for download in downloads:
        print("downloading", download.dest, file=sys.stderr)
        urlretrieve(download.url, str(root / download.dest))

def readJSON(ps: str):
    p = Path(ps)
    with p.open() as f:
        return json.load(f)

def toJSON(o):
    return json.dumps(asdict(o), indent=2)

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("usage: fetchHuggingface.py <command> <args>")
        exit(1)
    match sys.argv[1]:
        case "lock":
            j = readJSON(sys.argv[2])
            if type(j) is list:
                print(json.dumps([asdict(lock(Spec(**spec))) for spec in j], indent=2))
            else:
                print(toJSON(lock(Spec(**j))))
        case "build":
            build(Path(sys.argv[2]), Spec(**readJSON(sys.argv[3])), Lock(**readJSON(sys.argv[4])))
        case "run":
            run(Path(sys.argv[2]), Spec(**readJSON(sys.argv[3])), Lock(**readJSON(sys.argv[4])))
        case _:
            print("unknown command")
            exit(1)
            
