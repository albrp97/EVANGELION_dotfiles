#!/usr/bin/env python3
import json
import os
import shutil
import stat
import sys
import time
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[2]
CONFIG_PATH = Path.home() / ".config/karabiner/karabiner.json"
RULES_PATH = (
    ROOT_DIR
    / "dotfiles/macos-v2/.config/karabiner/assets/complex_modifications/"
    / "command-space-region-screenshot.json"
)
RULE_DESCRIPTION = "MacBook Rice v2: Command+Space launcher actions"
LEGACY_RULE_DESCRIPTIONS = {
    "MacBook Rice v2: Command+Space, then P copies a screen region",
    "Command+Space leader launcher",
    RULE_DESCRIPTION,
}


def new_config() -> dict:
    return {
        "global": {
            "check_for_updates_on_startup": True,
            "show_in_menu_bar": True,
            "show_profile_name_in_menu_bar": False,
        },
        "profiles": [
            {
                "name": "MacBook Rice v2",
                "selected": True,
                "devices": [],
                "simple_modifications": [],
                "fn_function_keys": [],
                "complex_modifications": {
                    "parameters": {
                        "basic.simultaneous_threshold_milliseconds": 50,
                        "basic.to_delayed_action_delay_milliseconds": 500,
                        "basic.to_if_alone_timeout_milliseconds": 1000,
                        "basic.to_if_held_down_threshold_milliseconds": 500,
                        "mouse_motion_to_scroll.speed": 100,
                    },
                    "rules": [],
                },
                "virtual_hid_keyboard": {"keyboard_type_v2": "ansi"},
            }
        ],
    }


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    try:
        rule_asset = json.loads(RULES_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"Could not read the v2 Karabiner shortcut rule: {error}")

    asset_rules = rule_asset.get("rules")
    if not isinstance(asset_rules, list) or len(asset_rules) != 1:
        fail("The v2 Karabiner shortcut asset must contain exactly one rule.")
    rule = asset_rules[0]
    if rule.get("description") != RULE_DESCRIPTION:
        fail("The v2 Karabiner shortcut asset has an unexpected rule description.")

    if CONFIG_PATH.exists():
        try:
            config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            fail(f"Could not read Karabiner's active configuration: {error}")
    else:
        config = new_config()

    profiles = config.get("profiles")
    if not isinstance(profiles, list) or not profiles:
        fail("Karabiner's configuration has no profiles; refusing to replace it.")
    selected_profiles = [
        profile
        for profile in profiles
        if isinstance(profile, dict) and profile.get("selected") is True
    ]
    if len(selected_profiles) != 1:
        fail("Expected exactly one selected Karabiner profile.")

    profile = selected_profiles[0]
    complex_modifications = profile.setdefault("complex_modifications", {})
    if not isinstance(complex_modifications, dict):
        fail("The selected Karabiner profile has invalid complex modifications.")
    rules = complex_modifications.setdefault("rules", [])
    if not isinstance(rules, list):
        fail("The selected Karabiner profile has an invalid rules list.")

    updated_rules = [
        existing
        for existing in rules
        if not (
            isinstance(existing, dict)
            and existing.get("description") in LEGACY_RULE_DESCRIPTIONS
        )
    ]
    updated_rules.append(rule)
    complex_modifications["rules"] = updated_rules

    CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
    previous_bytes = CONFIG_PATH.read_bytes() if CONFIG_PATH.exists() else None
    rendered = (json.dumps(config, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
    if previous_bytes == rendered:
        print("Karabiner's Command+Space launcher is already configured.")
        return

    if previous_bytes is not None:
        backup_dir = Path.home() / ".macbook-rice-v2-backup/karabiner"
        backup_dir.mkdir(parents=True, exist_ok=True)
        backup_path = backup_dir / f"karabiner-{time.strftime('%Y%m%d-%H%M%S')}.json"
        suffix = 1
        while backup_path.exists():
            backup_path = backup_dir / f"karabiner-{time.strftime('%Y%m%d-%H%M%S')}-{suffix}.json"
            suffix += 1
        shutil.copy2(CONFIG_PATH, backup_path)

    temporary_path = CONFIG_PATH.with_name(
        f"{CONFIG_PATH.name}.tmp.{os.getpid()}"
    )
    try:
        temporary_path.write_bytes(rendered)
        mode = stat.S_IMODE(CONFIG_PATH.stat().st_mode) if CONFIG_PATH.exists() else 0o600
        temporary_path.chmod(mode)
        os.replace(temporary_path, CONFIG_PATH)
    finally:
        temporary_path.unlink(missing_ok=True)

    print("Configured the selected Karabiner profile for Command+Space launcher actions.")


if __name__ == "__main__":
    main()
