"""Resolve and create the R-022 Python figure-output directory.

Author: GitHub Copilot
Date: 2026-08-25
Inputs: script_stem - Extensionless entry-script path relative to python_scripts.
Outputs: Path to the created Python figure-output directory.
"""

import re
import os
import tempfile
from pathlib import Path


def get_figure_output_dir(script_stem: str) -> Path:
    """Return the R-022 output directory for a Python entry-script path."""

    # Reject non-string identifiers before applying string-specific validation.
    if not isinstance(script_stem, str):
        raise TypeError("script_stem must be a string.")

    # Normalize Windows separators so both separator styles share one validation path.
    normalized_stem = script_stem.replace("\\", "/")

    # Reject blank, absolute, and drive-qualified paths before they can escape the output root.
    if not normalized_stem or normalized_stem.startswith("/") or re.match(r"^[A-Za-z]:/", normalized_stem):
        raise ValueError("script_stem must be a non-empty path relative to python_scripts.")

    # Split the relative identifier into segments for independent validation.
    path_parts = normalized_stem.split("/")

    # Permit only Python/MATLAB-style entry-script identifiers and reject traversal or empty segments.
    for path_part in path_parts:
        if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", path_part):
            raise ValueError(f"script_stem contains an invalid path segment: {path_part!r}.")

    # Locate the shared Functions directory from this module rather than relying on the caller cwd.
    functions_dir = Path(__file__).resolve().parent

    # In the staging repository, Functions/ is a sibling of JournalScripts/. In the
    # public repository, Functions/ is copied next to python_scripts/ and there is
    # no JournalScripts/ folder; default public-run output therefore goes to a temp
    # folder unless NEXTBMS_FIGURE_ROOT explicitly points elsewhere.
    journal_scripts_dir = functions_dir.parent / "JournalScripts"
    if journal_scripts_dir.exists():
        output_dir = journal_scripts_dir / "Figures" / "python"
    else:
        output_base = Path(os.environ.get("NEXTBMS_FIGURE_ROOT", tempfile.gettempdir()))
        if "NEXTBMS_FIGURE_ROOT" not in os.environ:
            output_base /= "NEXTBMS_PublicRepositoryFigures"
        output_dir = output_base / "python"

    # Append the validated entry-script path.
    for path_part in path_parts:
        output_dir /= path_part

    # Create the destination on first use so individual writers need no directory plumbing.
    output_dir.mkdir(parents=True, exist_ok=True)
    return output_dir