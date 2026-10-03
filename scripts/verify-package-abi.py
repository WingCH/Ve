#!/usr/bin/env python3
"""Check Ve package metadata and arm64e ABI markers without installing it.

This check does not prove runtime compatibility or pointer authentication.
Chained pointer formats are reported for comparison, not used as an ABI gate.
"""

import argparse
import io
import json
from pathlib import Path
import struct
import subprocess
import sys
import tarfile


CPU_ARM64 = 0x0100000C
CPU_ARM64E = 2
# Apple XNU machine.h: "pointer authentication with versioned ABI".
# https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/mach/machine.h
PTRAUTH_ABI = 0x80000000


def unpack(data, offset, layout):
    size = struct.calcsize(layout)
    if offset < 0 or offset + size > len(data):
        raise ValueError("Truncated binary structure")
    return struct.unpack_from(layout, data, offset)


def ar_members(data):
    if not data.startswith(b"!<arch>\n"):
        raise ValueError("The package is not an ar archive")
    offset = 8
    members = {}
    while offset < len(data):
        header = data[offset:offset + 60]
        if len(header) != 60 or header[58:] != b"`\n":
            raise ValueError("Invalid ar member header")
        name = header[:16].decode("ascii").strip().rstrip("/")
        size = int(header[48:58].decode("ascii").strip())
        start = offset + 60
        if size < 0 or start + size > len(data) or name in members:
            raise ValueError("Invalid or duplicate ar member")
        members[name] = data[start:start + size]
        offset = start + size + size % 2
    if members.get("debian-binary") != b"2.0\n":
        raise ValueError("Unsupported Debian package format")
    return members


def tar_files(members, prefix):
    names = [name for name in members if name.startswith(prefix + ".tar")]
    if len(names) != 1:
        raise ValueError("Expected one " + prefix + " archive")
    data = members[names[0]]
    if names[0].endswith(".zst"):
        data = subprocess.run(["zstd", "-dc"], input=data, capture_output=True, check=True).stdout
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:*") as archive:
        for member in archive:
            if member.isfile():
                yield member.name.removeprefix("./"), archive.extractfile(member).read()


def macho_slices(data):
    magic = data[:4]
    formats = {
        b"\xca\xfe\xba\xbe": (">", False),
        b"\xbe\xba\xfe\xca": ("<", False),
        b"\xca\xfe\xba\xbf": (">", True),
        b"\xbf\xba\xfe\xca": ("<", True),
    }
    if magic in formats:
        endian, wide = formats[magic]
        count, = unpack(data, 4, endian + "I")
        layout = endian + ("IIQQII" if wide else "IIIII")
        stride = struct.calcsize(layout)
        slices = []
        for index in range(count):
            cpu, subtype, offset, size, *_ = unpack(data, 8 + index * stride, layout)
            if size < 32 or offset + size > len(data):
                raise ValueError("Invalid Mach-O slice bounds")
            image = data[offset:offset + size]
            if unpack(image, 4, "<II") != (cpu, subtype):
                raise ValueError("Fat and Mach-O CPU headers disagree")
            slices.append(image)
        return slices
    return [data]


def inspect_slice(data):
    magic, cpu, subtype, filetype, count, command_size, *_ = unpack(data, 0, "<8I")
    if magic != 0xFEEDFACF or 32 + command_size > len(data):
        raise ValueError("Invalid 64-bit Mach-O header")
    report = {
        "cpu_type": f"0x{cpu:08x}",
        "cpu_subtype": f"0x{subtype:08x}",
        "architecture": "arm64e" if cpu == CPU_ARM64 and subtype & 0xFFFFFF == CPU_ARM64E else "arm64" if cpu == CPU_ARM64 and subtype & 0xFFFFFF == 0 else "other",
        "versioned_ptrauth_abi": bool(subtype & PTRAUTH_ABI),
        "filetype": filetype,
        "chained_pointer_formats": [],
    }
    offset = 32
    command_end = 32 + command_size
    for _ in range(count):
        command, size = unpack(data, offset, "<II")
        if size < 8 or offset + size > command_end:
            raise ValueError("Invalid Mach-O load command")
        if command == 0x32:
            platform, minimum, sdk, _ = unpack(data, offset + 8, "<4I")
            report["platform"] = platform
            report["minimum_os"] = minimum
            report["sdk"] = sdk
        elif command == 0x80000034:
            start, length = unpack(data, offset + 8, "<II")
            if start + length > len(data):
                raise ValueError("Invalid chained fixup bounds")
            fixups = data[start:start + length]
            _, starts_offset, *_ = unpack(fixups, 0, "<7I")
            segments, = unpack(fixups, starts_offset, "<I")
            for index in range(segments):
                relative, = unpack(fixups, starts_offset + 4 + index * 4, "<I")
                if relative:
                    pointer_format, = unpack(fixups, starts_offset + relative + 6, "<H")
                    report["chained_pointer_formats"].append(pointer_format)
        offset += size
    if offset != command_end:
        raise ValueError("Mach-O command count and size disagree")
    report["chained_pointer_formats"] = sorted(set(report["chained_pointer_formats"]))
    return report


def check_package(package, scheme, version):
    members = ar_members(package.read_bytes())
    controls = [data for name, data in tar_files(members, "control") if name == "control"]
    if len(controls) != 1:
        raise ValueError("Expected one package control file")
    control = dict(line.split(": ", 1) for line in controls[0].decode().splitlines() if ": " in line)
    errors = []
    architecture = {"rootless": "iphoneos-arm64", "roothide": "iphoneos-arm64e"}[scheme]
    for key, expected in (("Package", "codes.wingchan.ve-enhanced"), ("Version", version), ("Architecture", architecture)):
        if control.get(key) != expected:
            errors.append(f"{key}: expected {expected}, got {control.get(key)}")
    prefix = "var/jb/" if scheme == "rootless" else ""
    required = {
        prefix + "Library/MobileSubstrate/DynamicLibraries/VeCore.dylib",
        prefix + "Library/MobileSubstrate/DynamicLibraries/VeTarget.dylib",
        prefix + "Library/PreferenceBundles/VEEnhancedPreferences.bundle/VEEnhancedPreferences",
    }
    binaries = {}
    for name, data in tar_files(members, "data"):
        if name not in required:
            continue
        if name in binaries:
            raise ValueError("Duplicate package binary: " + name)
        slices = [inspect_slice(image) for image in macho_slices(data)]
        binaries[name] = slices
        if sorted(row["architecture"] for row in slices) != ["arm64", "arm64e"]:
            errors.append(name + ": expected one arm64 and one arm64e slice")
        for row in slices:
            if row.get("platform") != 2 or row.get("minimum_os", 0) < 14 << 16 or row["filetype"] != 6:
                errors.append(name + ": expected an iOS 14+ dylib")
            if row["architecture"] == "arm64e":
                if row["cpu_subtype"] != "0x80000002":
                    errors.append(name + ": expected native arm64e user ABI v0 (0x80000002), got " + row["cpu_subtype"])
    errors.extend("Missing package binary: " + name for name in sorted(required - binaries.keys()))
    return {"package": str(package), "scheme": scheme, "validation_scope": "native arm64e ABI markers; runtime compatibility is unverified", "control": control, "binaries": binaries, "errors": errors}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path)
    parser.add_argument("--scheme", choices=("rootless", "roothide"), required=True)
    parser.add_argument("--version", required=True)
    args = parser.parse_args()
    try:
        report = check_package(args.package, args.scheme, args.version)
    except (ValueError, OSError, tarfile.TarError, subprocess.SubprocessError) as error:
        print(json.dumps({"error": str(error)}))
        return 2
    print(json.dumps(report, indent=2))
    return 1 if report["errors"] else 0


if __name__ == "__main__":
    sys.exit(main())
