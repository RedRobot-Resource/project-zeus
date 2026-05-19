"""Tests for the Zeus-branded runtime launcher."""

from __future__ import annotations

from pathlib import Path

import yaml


def test_ensure_zeus_runtime_creates_independent_home_with_zeus_skin(tmp_path, monkeypatch):
    from zeus_cli import ensure_zeus_runtime

    hermes_home = tmp_path / "hermes"
    zeus_home = tmp_path / "Zeus"
    monkeypatch.setenv("HERMES_HOME", str(hermes_home))
    monkeypatch.setenv("ZEUS_HOME", str(zeus_home))

    resolved = ensure_zeus_runtime()

    assert resolved == zeus_home
    assert Path(resolved).is_dir()
    assert Path(resolved) != hermes_home
    assert Path(resolved / "config.yaml").is_file()
    config = yaml.safe_load((resolved / "config.yaml").read_text(encoding="utf-8"))
    assert config["display"]["skin"] == "zeus"
    assert config["branding"]["product_name"] == "Zeus"
    assert config["branding"]["vendor"] == "Red Robot Resource"
    assert config["profiles"]["independent_from"] == "Hermes Agent"
    assert config["gateway"]["service_name"] == "zeus-gateway"
    assert config["runtime"]["home_name"] == "Zeus"
    assert config["runtime"]["windows_client"] is True
    assert config["runtime"]["can_run_alongside_hermes"] is True
    assert config["runtime"]["upstream_compatibility"] == "isolated-home"
    assert Path(resolved / "SOUL.md").read_text(encoding="utf-8").startswith("# Zeus")


def test_ensure_zeus_runtime_preserves_existing_user_config(tmp_path, monkeypatch):
    from zeus_cli import ensure_zeus_runtime

    zeus_home = tmp_path / "Zeus"
    zeus_home.mkdir()
    (zeus_home / "config.yaml").write_text(
        "model:\n  provider: openrouter\ndisplay:\n  skin: custom\n",
        encoding="utf-8",
    )
    monkeypatch.setenv("ZEUS_HOME", str(zeus_home))

    ensure_zeus_runtime()

    config = yaml.safe_load((zeus_home / "config.yaml").read_text(encoding="utf-8"))
    assert config["model"]["provider"] == "openrouter"
    assert config["display"]["skin"] == "custom"
    assert config["branding"]["product_name"] == "Zeus"
    assert config["runtime"]["can_run_alongside_hermes"] is True


def test_windows_installer_targets_project_zeus_and_separate_localappdata_home():
    script = Path("scripts/install-zeus.ps1").read_text(encoding="utf-8")

    assert "RedRobot-Resource/project-zeus.git" in script
    assert "$env:LOCALAPPDATA\\Zeus" in script
    assert "Zeus Installer" in script
    assert "hermes-agent.git" not in script
    assert "NousResearch" not in script
    assert "zeus" in script


def test_phase3_windows_installer_has_client_polish_surfaces():
    script = Path("scripts/install-zeus.ps1").read_text(encoding="utf-8")

    assert "[switch]$Update" in script
    assert "[switch]$Repair" in script
    assert "[switch]$Uninstall" in script
    assert "Start-Transcript" in script
    assert "ZeusInstallLog" in script
    assert "New-ZeusDesktopShortcut" in script
    assert "New-ZeusStartMenuShortcut" in script
    assert "Install-ZeusUninstaller" in script
    assert "Uninstall-Zeus" in script
    assert "Repair-Zeus" in script
    assert "Update-Zeus" in script
    assert "Zeus.lnk" in script
    assert "Uninstall Zeus.cmd" in script
    assert "zeus-repair.cmd" in script
    assert "zeus-update.cmd" in script
    assert "Desktop" in script
    assert "Start Menu" in script


def test_phase3_installer_keeps_user_state_safe_during_repair_and_uninstall():
    script = Path("scripts/install-zeus.ps1").read_text(encoding="utf-8")

    assert "PreserveUserData" in script
    assert "auth.json" in script
    assert "config.yaml" in script
    assert "sessions" in script
    assert "memories" in script
    assert "Remove-Item -Recurse -Force $InstallDir" in script
    assert "Remove-Item -Recurse -Force $ZeusHome" not in script
