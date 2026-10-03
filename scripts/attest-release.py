#!/usr/bin/env python3
"""Save a native Theos package and its symbols, then verify ABI and signatures."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("--version", required=True)
parser.add_argument("--scheme", required=True, choices=["rootless", "roothide"])
parser.add_argument("--output", required=True, type=Path)
args = parser.parse_args()
arch = {"rootless": "arm64", "roothide": "arm64e"}[args.scheme]
label = {"rootless": "rootless", "roothide": "roothide-relaxin"}[args.scheme]
args.output.mkdir(parents=True, exist_ok=True)
artifact = args.output / f"codes.wingchan.ve-enhanced_{args.version}_{label}_iphoneos-{arch}.deb"
shutil.copyfile(f"packages/codes.wingchan.ve-enhanced_{args.version}_iphoneos-{arch}.deb", artifact)
spec = importlib.util.spec_from_file_location("package_abi", "scripts/verify-package-abi.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
report = module.check_package(artifact, args.scheme, args.version)
if report["errors"]:
    raise RuntimeError(report["errors"])
(args.output / f"{args.scheme}-abi.json").write_text(json.dumps(report, indent=2) + "\n")
symbol_uuids = {}
for source in Path(".theos/obj").rglob("*.dSYM"):
    destination = args.output / f"{args.scheme}-symbols" / source.relative_to(".theos/obj")
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source, destination, dirs_exist_ok=True)
    text = subprocess.check_output(["xcrun", "dwarfdump", "--uuid", str(destination)], text=True)
    symbol_uuids.setdefault(source.name, set()).update(line.split()[1] for line in text.splitlines())
checks = []
for name, data in module.tar_files(module.ar_members(artifact.read_bytes()), "data"):
    if name not in report["binaries"]:
        continue
    binary = args.output / f"{args.scheme}-payload" / name
    binary.parent.mkdir(parents=True, exist_ok=True)
    binary.write_bytes(data)
    subprocess.run(["codesign", "--verify", "--strict", "--all-architectures", "--verbose=2", str(binary)], capture_output=True, text=True, check=True)
    text = subprocess.check_output(["xcrun", "dwarfdump", "--uuid", str(binary)], text=True)
    uuids = {line.split()[1] for line in text.splitlines()}
    if uuids != symbol_uuids.get(binary.name + ".dSYM"):
        raise RuntimeError(f"Saved dSYM UUID mismatch: {binary.name}")
    platform = subprocess.check_output(["xcrun", "dyld_info", "-platform", "-arch", "arm64e", str(binary)], text=True)
    checks.append({"binary": name, "slices": report["binaries"][name], "signature_verified": True, "symbols_verified": True, "uuids": sorted(uuids), "dyld_info": platform.replace(str(binary), binary.name)})
record = {
    "version": args.version, "scheme": args.scheme, "artifact": artifact.name,
    "bytes": artifact.stat().st_size, "sha256": hashlib.sha256(artifact.read_bytes()).hexdigest(),
    "source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
    "tracked_source_clean": subprocess.run(["git", "diff", "--quiet"]).returncode == 0,
    "compiler": subprocess.check_output(["xcrun", "clang", "--version"], text=True).splitlines()[0],
    "xcode": subprocess.check_output(["xcodebuild", "-version"], text=True).strip(),
    "signer": "Apple codesign ad-hoc", "runtime_validation_complete": False, "binary_checks": checks,
}
(args.output / f"{args.scheme}-attestation.json").write_text(json.dumps(record, indent=2) + "\n")
print(artifact.name, record["sha256"], "ABI, signatures and dSYM UUIDs verified")
