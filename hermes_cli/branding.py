"""Runtime-visible product branding helpers.

The shared codebase still contains Hermes internals for upstream compatibility.
This module controls the user-facing product labels shown by runtime clients
such as Zeus.
"""

from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class RuntimeBranding:
    product_name: str
    vendor_name: str
    version_product: str
    compact_tagline: str
    status_title: str
    cli_status_title: str
    user_facing_intro: str


def _is_zeus_runtime() -> bool:
    home = os.environ.get("ZEUS_HOME", "").strip()
    hermes_home = os.environ.get("HERMES_HOME", "").strip()
    homes_match = bool(home and hermes_home and home == hermes_home)
    brand = os.environ.get("HERMES_RUNTIME_BRAND", "").strip().lower()
    return brand == "zeus" and homes_match


def get_runtime_branding() -> RuntimeBranding:
    """Return visible product labels for the active runtime."""
    if _is_zeus_runtime():
        return RuntimeBranding(
            product_name="Zeus",
            vendor_name="Red Robot Resource",
            version_product="Zeus Client",
            compact_tagline="AI Client Framework",
            status_title="Zeus Status",
            cli_status_title="Zeus CLI Status",
            user_facing_intro="Zeus is a Red Robot Resource AI client.",
        )

    return RuntimeBranding(
        product_name="Hermes Agent",
        vendor_name="Nous Research",
        version_product="Hermes Agent",
        compact_tagline="AI Agent Framework",
        status_title="Hermes Agent Status",
        cli_status_title="Hermes CLI Status",
        user_facing_intro="Hermes Agent is an AI agent by Nous Research.",
    )
