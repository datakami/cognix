import json
from dataclasses import dataclass, field
import dataclasses
from typing import Optional, List
from pathlib import Path

@dataclass
class Spec:
    src: str
    rev: Optional[str] = None
    ref: Optional[str] = None
    build_include: List[str] = field(default_factory=list)
    download_include: List[str] = field(default_factory=list)

@dataclass
class Download:
    url: str
    dest: str
    hash: str

@dataclass
class Lock:
    rev: str
    hash: str
    download_files: List[Download]

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
    

def readJSON(ps: str):
    p = Path(ps)
    with p.open() as f:
        return json.load(f)

def readLock(ps: str) -> Lock:
    lock = readJSON(ps)
    lock.download_files = [Download(**d) for d in lock.download_files]
    return Lock(**lock)

def readSpec(ps: str) -> Spec:
    spec = readJSON(ps)
    return Spec(**spec)

def readLocks(ps: str) -> List[Lock]:
    locks = readJSON(ps)
    if not isinstance(locks, list):
        locks = [locks]
    res = []
    for lock in locks:
        lockData = Lock(**lock)
        lockData.download_files = [Download(**d) for d in lock['download_files']]
        res.append(lockData)
    return res

def readSpecs(ps: str) -> List[Spec]:
    specs = readJSON(ps)
    if not isinstance(specs, list):
        specs = [specs]
    res = []
    for spec in specs:
        res.append(Spec(**spec))
    return res

class EnhancedJSONEncoder(json.JSONEncoder):
        def default(self, o):
            if dataclasses.is_dataclass(o):
                return dataclasses.asdict(o)
            return super().default(o)

def toJSON(o):
    return json.dumps(o, cls=EnhancedJSONEncoder, indent=2)
