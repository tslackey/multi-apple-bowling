#!/usr/bin/env python3
"""Build, run, test, and archive helpers for Multi Platform Bowling.

Mac is the everyday host. Apple TV is a separate host destination — never launch both.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "Multi Platform Bowling" / "Multi Platform Bowling.xcodeproj"
SCHEME = "Multi Platform Bowling"
BUNDLE_ID = "slackey.personal.Multi-Platform-Bowling"
DERIVED = ROOT / ".build" / "DerivedData"
CORE = ROOT / "Packages" / "BowlingGameCore"
EXPORT_OPTIONS = ROOT / "Scripts" / "ExportOptions-app-store.plist"
TEAM_ID = "J9K9VC58LW"

PLATFORM_CONFIG = {
    "macos": {
        "generic": "generic/platform=macOS",
        "product_dirs": ["Debug", "Release"],
        "device_keywords": (),
        "sim_keywords": (),
        "archive_sdk": "macosx",
    },
    "ios": {
        "generic": "generic/platform=iOS",
        "sim_generic": "generic/platform=iOS Simulator",
        "product_dirs": ["Debug-iphoneos", "Release-iphoneos", "Debug-iphonesimulator", "Release-iphonesimulator"],
        "device_keywords": ("iphone", "ipad"),
        "sim_keywords": ("iphone", "ipad"),
        "archive_sdk": "iphoneos",
    },
    "tvos": {
        "generic": "generic/platform=tvOS",
        "sim_generic": "generic/platform=tvOS Simulator",
        "product_dirs": ["Debug-appletvos", "Release-appletvos", "Debug-appletvsimulator", "Release-appletvsimulator"],
        "device_keywords": ("apple tv", "appletv", "tvos"),
        "sim_keywords": ("apple tv", "tv"),
        "archive_sdk": "appletvos",
    },
}


def run(command: list[str], **kwargs) -> subprocess.CompletedProcess:
    print("+", " ".join(command), flush=True)
    return subprocess.run(command, check=kwargs.pop("check", True), **kwargs)


def xcodebuild(extra: list[str], configuration: str = "Debug") -> None:
    command = [
        "xcodebuild",
        "-project",
        str(PROJECT),
        "-scheme",
        SCHEME,
        "-derivedDataPath",
        str(DERIVED),
        "-configuration",
        configuration,
        "-allowProvisioningUpdates",
        "DEVELOPMENT_TEAM=" + TEAM_ID,
        *extra,
    ]
    run(command)


def find_app() -> Path:
    products = DERIVED / "Build" / "Products"
    matches = sorted(products.glob("*/*.app"))
    if not matches:
        raise SystemExit(f"No .app found under {products}")
    return matches[-1]


def test() -> None:
    run(["swift", "test"], cwd=CORE)


def build(platform: str, configuration: str = "Debug") -> None:
    cfg = PLATFORM_CONFIG[platform]
    xcodebuild(["-destination", cfg["generic"], "build"], configuration=configuration)


def list_simulators(platform: str) -> list[dict]:
    raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"])
    data = json.loads(raw)
    keywords = PLATFORM_CONFIG[platform]["sim_keywords"]
    found = []
    for runtime, devices in data.get("devices", {}).items():
        runtime_l = runtime.lower()
        if platform == "ios" and "ios" not in runtime_l and "iphoneos" not in runtime_l:
            continue
        if platform == "tvos" and "tvos" not in runtime_l and "appletv" not in runtime_l:
            continue
        for device in devices:
            name = device.get("name", "").lower()
            if keywords and not any(k in name for k in keywords):
                continue
            if device.get("isAvailable"):
                found.append(device)
    return found


def list_physical_devices(platform: str) -> list[str]:
    try:
        proc = subprocess.run(
            ["xcrun", "devicectl", "list", "devices"],
            check=False,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError:
        return []
    if proc.returncode != 0:
        return []
    keywords = PLATFORM_CONFIG[platform]["device_keywords"]
    devices = []
    for line in proc.stdout.splitlines():
        lower = line.lower()
        if "unavailable" in lower or "offline" in lower:
            continue
        if keywords and not any(k in lower for k in keywords):
            continue
        if "connected" in lower or "available" in lower or "paired" in lower:
            devices.append(line.strip())
    return devices


def pick_udid_from_devicectl(platform: str) -> str | None:
    proc = subprocess.run(
        ["xcrun", "devicectl", "list", "devices", "--json-output", "/dev/stdout"],
        check=False,
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0 or not proc.stdout.strip():
        return None
    try:
        payload = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return None
    keywords = PLATFORM_CONFIG[platform]["device_keywords"]
    results = payload.get("result", payload)
    devices = results.get("devices", []) if isinstance(results, dict) else []
    for device in devices:
        name = str(device.get("deviceProperties", {}).get("name", "")).lower()
        platform_name = str(device.get("hardwareProperties", {}).get("platform", "")).lower()
        udid = device.get("hardwareProperties", {}).get("udid") or device.get("identifier")
        haystack = f"{name} {platform_name}"
        if keywords and not any(k in haystack for k in keywords):
            continue
        state = str(device.get("connectionProperties", {}).get("transportType", "")).lower()
        if udid:
            return str(udid)
        _ = state
    return None


def run_macos(configuration: str) -> None:
    xcodebuild(["-destination", "platform=macOS", "build"], configuration=configuration)
    app = find_app()
    run(["open", str(app)])


def run_simulator(platform: str, configuration: str) -> None:
    sims = list_simulators(platform)
    if not sims:
        raise SystemExit(f"No available {platform} simulators")
    sim = sims[0]
    udid = sim["udid"]
    dest = f"platform={'iOS Simulator' if platform == 'ios' else 'tvOS Simulator'},id={udid}"
    xcodebuild(["-destination", dest, "build"], configuration=configuration)
    run(["xcrun", "simctl", "boot", udid], check=False)
    run(["open", "-a", "Simulator"], check=False)
    app = find_app()
    run(["xcrun", "simctl", "install", udid, str(app)])
    run(["xcrun", "simctl", "launch", udid, BUNDLE_ID])


def run_device(platform: str, configuration: str) -> None:
    udid = pick_udid_from_devicectl(platform)
    dest_name = "iOS" if platform == "ios" else "tvOS"
    if udid:
        dest = f"platform={dest_name},id={udid}"
    else:
        dest = PLATFORM_CONFIG[platform]["generic"]
        print(f"No paired {platform} device id found; building generic {dest_name} then looking for install targets.")
    xcodebuild(["-destination", dest, "build"], configuration=configuration)
    app = find_app()
    if not udid:
        raise SystemExit(
            f"Built {app}, but no paired {platform} device is available.\n"
            "Connect/pair an iPhone or Apple TV (Xcode › Window › Devices and Simulators), "
            "or use `make run-ios-sim` / `make run-tvos-sim`."
        )
    run(["xcrun", "devicectl", "device", "install", "app", "--device", udid, str(app)])
    run(
        [
            "xcrun",
            "devicectl",
            "device",
            "process",
            "launch",
            "--device",
            udid,
            BUNDLE_ID,
        ]
    )


def run_platform(platform: str, simulator: bool, configuration: str) -> None:
    if platform == "macos":
        run_macos(configuration)
        return
    if simulator:
        run_simulator(platform, configuration)
        return
    if pick_udid_from_devicectl(platform):
        run_device(platform, configuration)
    else:
        print(f"No physical {platform} device on the local network; using simulator.")
        run_simulator(platform, configuration)


def archive(platform: str) -> Path:
    archive_path = ROOT / ".build" / "Archives" / f"{platform}.xcarchive"
    archive_path.parent.mkdir(parents=True, exist_ok=True)
    dest = {
        "macos": "generic/platform=macOS",
        "ios": "generic/platform=iOS",
        "tvos": "generic/platform=tvOS",
    }[platform]
    xcodebuild(
        [
            "-destination",
            dest,
            "-archivePath",
            str(archive_path),
            "archive",
        ],
        configuration="Release",
    )
    return archive_path


def export_and_upload(archive_path: Path) -> None:
    export_dir = ROOT / ".build" / "Export"
    export_dir.mkdir(parents=True, exist_ok=True)
    command = [
        "xcodebuild",
        "-exportArchive",
        "-archivePath",
        str(archive_path),
        "-exportPath",
        str(export_dir),
        "-exportOptionsPlist",
        str(EXPORT_OPTIONS),
        "-allowProvisioningUpdates",
    ]
    key_id = os.environ.get("ASC_KEY_ID")
    issuer = os.environ.get("ASC_ISSUER_ID")
    key_path = os.environ.get("ASC_KEY_PATH")
    if key_id and issuer and key_path:
        command += [
            "-authenticationKeyID",
            key_id,
            "-authenticationKeyIssuerID",
            issuer,
            "-authenticationKeyPath",
            key_path,
        ]
        run(command)
        return

    print(
        f"Archived {archive_path}\n"
        "Skipping App Store Connect upload (no ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_PATH).\n"
        "Open the archive in Xcode Organizer, or rerun `make release-*` with an App Store Connect API key."
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["test", "build", "run", "archive", "release"])
    parser.add_argument("platform", nargs="?", choices=["macos", "ios", "tvos"])
    parser.add_argument("--simulator", action="store_true")
    parser.add_argument("--configuration", default=None)
    args = parser.parse_args()

    if args.command == "test":
        test()
        return

    if not args.platform:
        raise SystemExit("platform required for this command (macos, ios, or tvos)")

    configuration = args.configuration or ("Release" if args.command in {"archive", "release"} else "Debug")

    if args.command == "build":
        build(args.platform, configuration)
    elif args.command == "run":
        run_platform(args.platform, args.simulator, configuration)
    elif args.command == "archive":
        archive(args.platform)
    elif args.command == "release":
        export_and_upload(archive(args.platform))


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        sys.exit(error.returncode)
