#!/usr/bin/env python3
import sys
import tomllib
from pathlib import Path

TOML = Path(__file__).resolve().parent.parent / "sources.toml"
DATA = tomllib.loads(TOML.read_text())


def fail(message):
    print(message, file=sys.stderr)
    raise SystemExit(1)


def lookup(path):
    node = DATA
    for part in path.split("."):
        if not isinstance(node, dict) or part not in node:
            fail("sources: unknown key: " + path)
        node = node[part]
    return node


def main(argv):
    if len(argv) < 2:
        fail("usage: sources.py <source|native|release|releases|list> ...")
    cmd = argv[1]
    if cmd == "source":
        node = lookup("sources." + argv[2])
        print(node[argv[3]])
    elif cmd == "native":
        group = DATA["native"][argv[2]]
        if argv[3] == "base_url":
            print(group["base_url"])
        elif argv[3] == "packages":
            for name, pkg in group["packages"].items():
                print("%s\t%s\t%s" % (name, pkg["version"], pkg["sha256"]))
        else:
            fail("sources: unknown native field: " + argv[3])
    elif cmd == "release":
        for release in DATA["release"]:
            if release["stage"] == argv[2]:
                key = argv[3]
                print(release.get(key, ""))
                return
        fail("sources: unknown release stage: " + argv[2])
    elif cmd == "releases":
        for release in DATA["release"]:
            print(release["stage"])
    elif cmd == "files":
        for path, digest in DATA["files"].items():
            print("%s\t%s" % (path, digest))
    elif cmd == "field":
        print(lookup(argv[2]))
    elif cmd == "release-fields":
        for release in DATA["release"]:
            if release["stage"] == argv[2]:
                print(" ".join(sorted(release)))
                return
        fail("sources: unknown release stage: " + argv[2])
    elif cmd == "list":
        for stage in ["seed", "seed-1.90"] + [r["stage"] for r in DATA["release"]]:
            print(stage)
    else:
        fail("sources: unknown command: " + cmd)


if __name__ == "__main__":
    main(sys.argv)
