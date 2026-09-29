#!/usr/bin/env python3
import plistlib
import subprocess
import sys


DEFAULT_PARAMETERS = {
    "28": [51, 20, 1179648],
    "29": [51, 20, 1441792],
    "30": [52, 21, 1179648],
    "31": [52, 21, 1441792],
    "64": [32, 49, 1048576],
    "65": [32, 49, 1572864],
    "184": [53, 23, 1179648],
}


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    shortcut_ids = sys.argv[1:]
    if not shortcut_ids:
        fail("Usage: configure-disabled-hotkeys.py <shortcut-id> [...]")
    if any(
        shortcut_id not in DEFAULT_PARAMETERS
        and shortcut_id not in {str(value) for value in range(118, 127)}
        for shortcut_id in shortcut_ids
    ):
        fail("Unsupported macOS symbolic hotkey ID.")

    exported = subprocess.run(
        ["/usr/bin/defaults", "export", "com.apple.symbolichotkeys", "-"],
        check=False,
        capture_output=True,
    )
    if exported.returncode != 0:
        fail(
            "Could not export macOS keyboard shortcuts: "
            + exported.stderr.decode("utf-8", errors="replace").strip()
        )
    try:
        preferences = plistlib.loads(exported.stdout)
    except plistlib.InvalidFileException as error:
        fail(f"Could not parse macOS keyboard shortcuts: {error}")

    hotkeys = preferences.get("AppleSymbolicHotKeys")
    if not isinstance(hotkeys, dict):
        fail("The macOS symbolic hotkey preferences are missing or invalid.")

    for shortcut_id in shortcut_ids:
        shortcut = hotkeys.get(shortcut_id)
        if shortcut is None:
            shortcut = {}
        if not isinstance(shortcut, dict):
            fail(f"macOS symbolic hotkey {shortcut_id} has an invalid entry.")
        shortcut["enabled"] = False

        default_parameters = DEFAULT_PARAMETERS.get(shortcut_id)
        if default_parameters is not None:
            value = shortcut.get("value")
            if value is None:
                value = {"parameters": default_parameters, "type": "standard"}
                shortcut["value"] = value
            if not isinstance(value, dict):
                fail(f"macOS symbolic hotkey {shortcut_id} has an invalid value.")

            parameters = value.get("parameters", default_parameters)
            if not isinstance(parameters, list):
                fail(f"macOS symbolic hotkey {shortcut_id} has invalid parameters.")
            try:
                value["parameters"] = [int(parameter) for parameter in parameters]
            except (TypeError, ValueError):
                fail(f"macOS symbolic hotkey {shortcut_id} has invalid parameters.")
            value.setdefault("type", "standard")

        hotkeys[shortcut_id] = shortcut

    imported = subprocess.run(
        ["/usr/bin/defaults", "import", "com.apple.symbolichotkeys", "-"],
        input=plistlib.dumps(preferences, fmt=plistlib.FMT_XML),
        check=False,
        capture_output=True,
    )
    if imported.returncode != 0:
        fail(
            "Could not update macOS keyboard shortcuts: "
            + imported.stderr.decode("utf-8", errors="replace").strip()
        )

    verified = subprocess.run(
        ["/usr/bin/defaults", "export", "com.apple.symbolichotkeys", "-"],
        check=False,
        capture_output=True,
    )
    if verified.returncode != 0:
        fail("Could not verify the updated macOS keyboard shortcuts.")
    try:
        updated_hotkeys = plistlib.loads(verified.stdout)["AppleSymbolicHotKeys"]
    except (KeyError, plistlib.InvalidFileException) as error:
        fail(f"Could not verify the updated macOS keyboard shortcuts: {error}")

    for shortcut_id in shortcut_ids:
        shortcut = updated_hotkeys.get(shortcut_id)
        if not isinstance(shortcut, dict) or shortcut.get("enabled") is not False:
            fail(f"macOS symbolic hotkey {shortcut_id} did not disable correctly.")
        if shortcut_id in DEFAULT_PARAMETERS:
            parameters = (shortcut.get("value") or {}).get("parameters")
            if (
                not isinstance(parameters, list)
                or any(type(parameter) is not int for parameter in parameters)
            ):
                fail(f"macOS symbolic hotkey {shortcut_id} has invalid parameter types.")


if __name__ == "__main__":
    main()
