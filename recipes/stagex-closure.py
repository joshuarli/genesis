#!/usr/bin/env python3
import argparse
import os
import sys
import tomllib
from collections import OrderedDict


class ClosureError(Exception):
    pass


def containerfile_deps(path):
    deps = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.startswith("COPY"):
                parts = line.split()
                if len(parts) > 1 and parts[1].startswith("--from="):
                    dep = parts[1].split("=", 1)[1]
                    if dep.startswith("stagex/"):
                        deps.append(dep.split("/", 1)[1])
            elif line.startswith("FROM stagex/"):
                deps.append(line.split()[1].split("/", 1)[1])
            elif line.startswith("FROM --platform=linux/386 stagex/"):
                deps.append(line.split()[2].split("/", 1)[1])
    return list(OrderedDict.fromkeys(deps))


def load_packages(root):
    packages = OrderedDict()
    packages_root = os.path.join(root, "packages")
    if not os.path.isdir(packages_root):
        raise ClosureError("not a StageX source tree: " + root)
    for stage in sorted(os.listdir(packages_root)):
        stage_dir = os.path.join(packages_root, stage)
        if not os.path.isdir(stage_dir):
            continue
        for name in sorted(os.listdir(stage_dir)):
            pkg_dir = os.path.join(stage_dir, name)
            containerfile = os.path.join(pkg_dir, "Containerfile")
            toml_path = os.path.join(pkg_dir, "package.toml")
            if not os.path.isfile(containerfile) or not os.path.isfile(toml_path):
                continue
            with open(toml_path, "rb") as f:
                data = tomllib.load(f)
            info = data.get("package", {})
            deps = containerfile_deps(containerfile)
            sources = data.get("sources", {})
            names = [name] + list(info.get("subpackages", []))
            for package_name in names:
                packages[f"{stage}-{package_name}"] = {
                    "stage": stage,
                    "name": package_name,
                    "origin": name,
                    "version": info.get("version"),
                    "version_from": info.get("version_from"),
                    "platforms": info.get("platforms", []),
                    "deps": deps,
                    "sources": sources,
                }
    for package in packages.values():
        source = package["version_from"]
        if not source:
            continue
        dependency = packages.get(source)
        if dependency is None:
            raise ClosureError(f"{package['stage']}-{package['name']}: version_from missing package {source}")
        package["version"] = dependency["version"]
    return packages


def resolve(packages, target):
    order = []
    state = {}

    def visit(name):
        if state.get(name) == "done":
            return
        if state.get(name) == "active":
            raise ClosureError("dependency cycle at " + name)
        package = packages.get(name)
        if package is None:
            raise ClosureError("missing package: " + name)
        state[name] = "active"
        for dep in sorted(package["deps"]):
            visit(dep)
        state[name] = "done"
        order.append(name)

    visit(target)
    return order


def source_set(packages, order):
    sources = OrderedDict()
    for name in order:
        package = packages[name]
        for source_name, source in package["sources"].items():
            key = (source["hash"], source.get("file", ""))
            entry = sources.setdefault(key, {"packages": [], "source": source_name})
            if package["origin"] not in entry["packages"]:
                entry["packages"].append(package["origin"])
    return sources


def main(argv):
    parser = argparse.ArgumentParser(description="Measure the StageX dependency closure of one package")
    parser.add_argument("--stagex-src", required=True)
    parser.add_argument("--target", default="core-rust")
    parser.add_argument("--commit", default="")
    parser.add_argument("--sources", action="store_true", help="list unique source archives")
    args = parser.parse_args(argv)

    try:
        packages = load_packages(args.stagex_src)
        order = resolve(packages, args.target)
    except ClosureError as error:
        print("stagex-closure: " + str(error), file=sys.stderr)
        return 1

    sources = source_set(packages, order)
    print("stagex-commit\t" + (args.commit or "-"))
    print("stagex-source\t" + os.path.abspath(args.stagex_src))
    print("target\t" + args.target)
    print("packages\t" + str(len(order)))
    print("sources\t" + str(len(sources)))
    print("package\tstage\tversion\tdirect-deps")
    for name in order:
        package = packages[name]
        print("\t".join([
            name,
            package["stage"],
            package["version"] or "-",
            ",".join(sorted(package["deps"])) or "-",
        ]))
    if args.sources:
        print("source-hash\tfile\tpackages")
        for (digest, filename), entry in sources.items():
            print("\t".join([digest, filename, ",".join(sorted(entry["packages"]))]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
