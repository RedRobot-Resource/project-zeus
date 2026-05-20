#!/usr/bin/env python3
"""Zeus runtime launcher.

This entry point keeps Zeus operationally separate from Hermes by resolving a
Zeus-owned home directory before importing the shared Hermes CLI runtime.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path
from typing import Any, Dict, Iterable

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


def _write_start_here(zeus_home: Path) -> None:
    guide_path = zeus_home / "ZEUS_START_HERE.md"
    if guide_path.exists():
        return
    guide_path.write_text(
        "# Zeus Start Here\n\n"
        "Zeus by Red Robot Resource is installed as a Windows AI client. "
        "Runs independently from Hermes Agent with its own home at "
        "`%LOCALAPPDATA%\\Zeus`, config, sessions, logs, and gateway service.\n\n"
        "## First launch\n\n"
        "Run `zeus setup` to connect model and platform settings. Then run "
        "`zeus` to open the client.\n\n"
        "## Gateway service\n\n"
        "Use `zeus gateway install` once to register the Zeus gateway service. "
        "The Windows installer also creates helper commands including "
        "`zeus-gateway-start.cmd`, `zeus-gateway-stop.cmd`, and "
        "`zeus-gateway-status.cmd`.\n\n"
        "## Repair and update\n\n"
        "Use the Start Menu Zeus repair and update commands if the app shell, "
        "shortcuts, or local command shims need to be recreated.\n",
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
    _write_start_here(zeus_home)

    os.environ["HERMES_HOME"] = str(zeus_home)
    os.environ.setdefault("ZEUS_HOME", str(zeus_home))
    os.environ.setdefault("HERMES_RUNTIME_BRAND", ZEUS_PRODUCT_NAME)
    return zeus_home


def _check_file(path: Path, label: str) -> Dict[str, Any]:
    return {"label": label, "ok": path.is_file(), "path": str(path)}


def _check_dir(path: Path, label: str) -> Dict[str, Any]:
    return {"label": label, "ok": path.is_dir(), "path": str(path)}


def build_zeus_health_report(zeus_home: Path | None = None) -> Dict[str, Any]:
    """Build a small Zeus-specific onboarding health report.

    This intentionally avoids running the full Hermes doctor flow. It answers a
    first-run Windows user's practical question: can Zeus start, where is its
    isolated home, and what safe command should I run next?
    """
    home = (zeus_home or resolve_zeus_home()).expanduser().resolve()
    config_path = home / "config.yaml"
    guide_path = home / "ZEUS_START_HERE.md"
    checks = [
        _check_dir(home, "Expected Zeus home"),
        _check_file(config_path, "Zeus config"),
        _check_file(guide_path, "First-run guide"),
    ]

    config: Dict[str, Any] = {}
    if config_path.exists():
        try:
            loaded = yaml.safe_load(config_path.read_text(encoding="utf-8")) or {}
            if isinstance(loaded, dict):
                config = loaded
        except Exception as exc:
            checks.append({"label": "Config readable", "ok": False, "detail": str(exc), "path": str(config_path)})

    checks.append(
        {
            "label": "Zeus skin default",
            "ok": config.get("display", {}).get("skin") == "zeus",
            "path": str(config_path),
        }
    )
    checks.append(
        {
            "label": "Independent runtime",
            "ok": config.get("runtime", {}).get("can_run_alongside_hermes") is True,
            "path": str(config_path),
        }
    )

    ready = all(bool(item.get("ok")) for item in checks)
    return {
        "product": ZEUS_PRODUCT_NAME,
        "vendor": ZEUS_VENDOR,
        "home": str(home),
        "ready": ready,
        "checks": checks,
        "next_steps": [
            "Run: zeus setup",
            "Run: zeus gateway install",
            "Run: zeus-gateway-status.cmd",
            "Repair: zeus-repair.cmd",
        ],
    }


def format_zeus_health_report(report: Dict[str, Any]) -> str:
    lines = [
        "Zeus Onboarding Health",
        f"Product: {report['product']} by {ZEUS_VENDOR}",
        f"Home: {report['home']}",
        "",
        "Checks:",
    ]
    for item in report.get("checks", []):
        status = "OK" if item.get("ok") else "MISSING"
        detail = f" ({item.get('path')})" if item.get("path") else ""
        if item.get("detail"):
            detail += f" {item['detail']}"
        lines.append(f"  {status}: {item.get('label')}{detail}")

    lines.extend(["", "Next safe step:"])
    if report.get("ready"):
        lines.append("  Run: zeus setup")
    else:
        lines.append("  Repair: zeus-repair.cmd")
    lines.extend(["", "Useful commands:"])
    lines.extend(f"  {step}" for step in report.get("next_steps", []))
    return "\n".join(lines)


def handle_zeus_builtin_command(argv: Iterable[str] | None = None) -> bool:
    args = list(sys.argv[1:] if argv is None else argv)
    if not args:
        return False
    command = args[0].lower()
    if command not in {"health", "welcome", "onboarding"}:
        return False
    report = build_zeus_health_report(resolve_zeus_home())
    print(format_zeus_health_report(report))
    return True


def main() -> None:
    """Launch the shared CLI runtime after pinning it to Zeus home."""
    ensure_zeus_runtime()
    if handle_zeus_builtin_command():
        return
    from hermes_cli.main import main as hermes_main

    hermes_main()


if __name__ == "__main__":
    main()
