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


def test_phase4_zeus_runtime_overrides_visible_client_branding(tmp_path, monkeypatch):
    from zeus_cli import ensure_zeus_runtime
    from hermes_cli.branding import get_runtime_branding

    zeus_home = tmp_path / "Zeus"
    monkeypatch.setenv("ZEUS_HOME", str(zeus_home))
    monkeypatch.delenv("HERMES_RUNTIME_BRAND", raising=False)

    ensure_zeus_runtime()
    brand = get_runtime_branding()

    assert brand.product_name == "Zeus"
    assert brand.vendor_name == "Red Robot Resource"
    assert brand.status_title == "Zeus Status"
    assert brand.cli_status_title == "Zeus CLI Status"
    assert brand.version_product == "Zeus Client"
    assert brand.compact_tagline == "AI Client Framework"
    assert "Hermes" not in brand.user_facing_intro
    assert "Nous" not in brand.user_facing_intro


def test_phase4_zeus_version_and_compact_banner_hide_hermes_and_nous(tmp_path, monkeypatch):
    from zeus_cli import ensure_zeus_runtime
    from hermes_cli.banner import format_banner_version_label
    from hermes_cli.skin_engine import set_active_skin
    from cli import _build_compact_banner

    monkeypatch.setenv("ZEUS_HOME", str(tmp_path / "Zeus"))
    monkeypatch.delenv("HERMES_RUNTIME_BRAND", raising=False)
    ensure_zeus_runtime()
    set_active_skin("zeus")

    version_label = format_banner_version_label()
    compact = _build_compact_banner()

    assert version_label.startswith("Zeus Client v")
    assert "Hermes Agent" not in version_label
    assert "Nous Research" not in compact
    assert "Zeus" in compact
    assert "Red Robot Resource" in compact


def test_phase5_zeus_gateway_service_names_are_not_hermes(tmp_path, monkeypatch):
    from zeus_cli import ensure_zeus_runtime
    from hermes_cli.gateway import get_launchd_label, get_service_name, generate_systemd_unit

    monkeypatch.setenv("ZEUS_HOME", str(tmp_path / "Zeus"))
    monkeypatch.delenv("HERMES_RUNTIME_BRAND", raising=False)
    ensure_zeus_runtime()

    assert get_service_name() == "zeus-gateway"
    assert get_launchd_label() == "com.redrobotresource.zeus.gateway"

    unit = generate_systemd_unit()
    assert "Description=Zeus Gateway - Messaging Platform Integration" in unit
    assert " -m zeus_cli gateway run --replace" in unit
    assert 'Environment="ZEUS_HOME=' in unit
    assert 'Environment="HERMES_RUNTIME_BRAND=Zeus"' in unit
    assert "hermes-gateway" not in unit


def test_phase5_windows_gateway_service_uses_zeus_task_and_launcher(tmp_path, monkeypatch):
    from zeus_cli import ensure_zeus_runtime
    from hermes_cli import gateway_windows

    monkeypatch.setattr(gateway_windows.sys, "platform", "win32")
    monkeypatch.setenv("ZEUS_HOME", str(tmp_path / "Zeus"))
    monkeypatch.delenv("HERMES_RUNTIME_BRAND", raising=False)
    ensure_zeus_runtime()

    script = gateway_windows._build_gateway_cmd_script(
        "C:\\Zeus\\project-zeus\\.venv\\Scripts\\python.exe",
        "C:\\Zeus\\project-zeus",
        str(tmp_path / "Zeus"),
        "",
    )

    assert gateway_windows.get_task_name() == "Zeus_Gateway"
    assert "Zeus Gateway - Messaging Platform Integration" in script
    assert "set \"ZEUS_HOME=" in script
    assert "set \"HERMES_RUNTIME_BRAND=Zeus\"" in script
    assert " -m zeus_cli gateway run --replace" in script
    assert "hermes_cli.main" not in script


def test_phase5_installer_exposes_gateway_service_controls():
    script = Path("scripts/install-zeus.ps1").read_text(encoding="utf-8")

    assert "zeus-gateway-start.cmd" in script
    assert "zeus-gateway-stop.cmd" in script
    assert "zeus-gateway-status.cmd" in script
    assert "zeus gateway install" in script
    assert "zeus gateway start" in script
    assert "zeus gateway stop" in script
    assert "zeus gateway status" in script
    assert "Zeus gateway service" in script


def test_phase6_zeus_runtime_writes_first_run_guide(tmp_path, monkeypatch):
    from zeus_cli import ensure_zeus_runtime

    monkeypatch.setenv("ZEUS_HOME", str(tmp_path / "Zeus"))
    zeus_home = ensure_zeus_runtime()

    guide = zeus_home / "ZEUS_START_HERE.md"
    assert guide.is_file()
    text = guide.read_text(encoding="utf-8")
    assert "# Zeus Start Here" in text
    assert "Red Robot Resource" in text
    assert "zeus setup" in text
    assert "zeus gateway install" in text
    assert "zeus-gateway-start.cmd" in text
    assert "%LOCALAPPDATA%\\Zeus" in text
    assert "Runs independently from Hermes Agent" in text


def test_phase6_installer_creates_windows_app_shell_shortcuts():
    script = Path("scripts/install-zeus.ps1").read_text(encoding="utf-8")

    assert "$ZeusAppLauncherName = \"zeus-app.cmd\"" in script
    assert "New-ZeusAppShell" in script
    assert "scripts\\zeus-app.ps1" in script
    assert "$shortcut.TargetPath = Join-Path $ZeusBinDir $ZeusAppLauncherName" in script
    assert "Zeus Console.lnk" in script
    assert "zeus.cmd" in script
    assert "Launch Zeus by Red Robot Resource" in script


def test_phase6_zeus_app_shell_is_branded_and_keeps_window_open():
    shell = Path("scripts/zeus-app.ps1").read_text(encoding="utf-8")

    assert "Zeus by Red Robot Resource" in shell
    assert "$env:ZEUS_HOME" in shell
    assert "$env:HERMES_HOME" in shell
    assert "$env:HERMES_RUNTIME_BRAND = \"Zeus\"" in shell
    assert "ZEUS_START_HERE.md" in shell
    assert "zeus gateway status" in shell
    assert "NoExit" not in shell
    assert "Read-Host" in shell
