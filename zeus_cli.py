#!/usr/bin/env python3
"""Zeus runtime launcher.

This entry point keeps Zeus operationally separate from Hermes by resolving a
Zeus-owned home directory before importing the shared Hermes CLI runtime.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path
from typing import Any, Dict

import yaml


ZEUS_PRODUCT_NAME = "Zeus"
ZEUS_VENDOR = "Red Robot Resource"


def default_zeus_home() -> Path:
    """Return the default per-user Zeus home directory for this platform."""
    if os.name == "nt":
        local_app_data = os.environ.get("LOCALAPPDATA")
        if local_app_data:
            return Path(local_app_data) / "Zeus"
        return Path.home() / "AppData" / "Local" / "Zeus"
    return Path.home() / ".zeus"


def resolve_zeus_home() -> Path:
    """Resolve the Zeus home directory without consulting Hermes profile state."""
    override = os.environ.get("ZEUS_HOME")
    if override:
        return Path(override).expanduser().resolve()
    return default_zeus_home().expanduser().resolve()


def _deep_merge_missing(base: Dict[str, Any], defaults: Dict[str, Any]) -> Dict[str, Any]:
    """Merge defaults into base without overwriting existing user values."""
    for key, value in defaults.items():
        if isinstance(value, dict):
            current = base.get(key)
            if not isinstance(current, dict):
                base[key] = dict(value)
            else:
                _deep_merge_missing(current, value)
        else:
            base.setdefault(key, value)
    return base


def _zeus_runtime_defaults() -> Dict[str, Any]:
    return {
        "display": {
            "skin": "zeus",
        },
        "branding": {
            "product_name": ZEUS_PRODUCT_NAME,
            "vendor": ZEUS_VENDOR,
            "client_family": "Project Zeus",
        },
        "profiles": {
            "independent_from": "Hermes Agent",
        },
        "gateway": {
            "service_name": "zeus-gateway",
        },
        "runtime": {
            "home_name": "Zeus",
            "windows_client": True,
            "can_run_alongside_hermes": True,
            "upstream_compatibility": "isolated-home",
        },
    }


def _write_default_soul(zeus_home: Path) -> None:
    soul_path = zeus_home / "SOUL.md"
    if soul_path.exists():
        return
    soul_path.write_text(
        "# Zeus\n\n"
        "You are Zeus by Red Robot Resource. You run from an isolated Zeus home "
        "directory so Hermes Agent and Zeus can both exist on the same Windows "
        "machine without sharing runtime state, sessions, logs, or gateway "
        "ownership.\n",
        encoding="utf-8",
    )


def ensure_zeus_runtime() -> Path:
    """Create and select the independent Zeus runtime home.

    Existing user config is preserved. Missing Zeus identity keys are added so a
    first launch defaults to the built-in Zeus skin and a separate gateway name.
    """
    zeus_home = resolve_zeus_home()
    zeus_home.mkdir(parents=True, exist_ok=True)

    config_path = zeus_home / "config.yaml"
    if config_path.exists():
        loaded = yaml.safe_load(config_path.read_text(encoding="utf-8")) or {}
        config: Dict[str, Any] = loaded if isinstance(loaded, dict) else {}
    else:
        config = {}

    _deep_merge_missing(config, _zeus_runtime_defaults())
    config_path.write_text(yaml.safe_dump(config, sort_keys=False), encoding="utf-8")
    _write_default_soul(zeus_home)

    os.environ["HERMES_HOME"] = str(zeus_home)
    os.environ.setdefault("ZEUS_HOME", str(zeus_home))
    os.environ.setdefault("HERMES_RUNTIME_BRAND", ZEUS_PRODUCT_NAME)
    return zeus_home


def main() -> None:
    """Launch the shared CLI runtime after pinning it to Zeus home."""
    ensure_zeus_runtime()
    from hermes_cli.main import main as hermes_main

    hermes_main()


if __name__ == "__main__":
    main()
