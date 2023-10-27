import json
from dataclasses import dataclass, field
import dataclasses
from typing import Optional
from pathlib import Path

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

def readLocks(ps: str) -> list[Lock]:
    locks = readJSON(ps)
    if not isinstance(locks, list):
        locks = [locks]
    res = []
    for lock in locks:
        lock = Lock(**lock)
        lock.download_files = [Download(**d) for d in lock.download_files]
        res.push(lock)
    return res

def readSpecs(ps: str) -> list[Spec]:
    specs = readJSON(ps)
    if not isinstance(specs, list):
        specs = [specs]
    res = []
    for spec in specs:
        res.push(Spec(**spec))
    return res

class EnhancedJSONEncoder(json.JSONEncoder):
        def default(self, o):
            if dataclasses.is_dataclass(o):
                return dataclasses.asdict(o)
            return super().default(o)

def toJSON(o):
    return json.dumps(o, cls=EnhancedJSONEncoder, indent=2)
