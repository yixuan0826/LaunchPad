"""Utilities module for Rin Launcher."""

from .helpers import (
    is_admin,
    run_as_admin,
    get_app_data_dir,
    expand_variables,
    find_executable,
)

__all__ = [
    "is_admin",
    "run_as_admin",
    "get_app_data_dir",
    "expand_variables",
    "find_executable",
]