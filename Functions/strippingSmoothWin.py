"""
strippingSmoothWin - site-dependent movmean window for dV/dt smoothing in
the Li-stripping analysis (A-002, todo #061).

Python counterpart of Functions/strippingSmoothWin.m.

Both the MATLAB source and this Python port resolve the site (TNO vs AIT)
via cellNumberToGroupChannel (temp_group 1/2 = TNO rigs A1/A2, temp_group
3/4 = AIT rigs A3/A4). MATLAB previously used a stale
`startsWith(cellNum, 'A1'/'A2')` check that always evaluated false once
cell IDs moved to the plain R-025 `Cell_<n>` form (an unintentional
regression from the #051 rename) - fixed on the MATLAB side 2026-08-25
(todo #105) to match this Python port, which already used the
cellNumberToGroupChannel lookup.

Author: GitHub Copilot (for Robinson Medina / Feye Hoekstra)
Date: 2026-08-24 (created); 2026-08-25 (MATLAB parity fix, see todo #105)
"""

import re
import sys
from pathlib import Path

_THIS_DIR = Path(__file__).resolve().parent
if str(_THIS_DIR) not in sys.path:
    sys.path.append(str(_THIS_DIR))

from cellNumberToGroupChannel import cell_number_to_group_channel  # noqa: E402


def stripping_smooth_win(cell_num):
    """Return the movmean window (samples on the 1 s grid) for cell_num."""

    if re.fullmatch(r'Cell_\d+', cell_num):
        cell_number = int(cell_num.split('Cell_')[1])
        temp_group, _channel = cell_number_to_group_channel(cell_number)
        if temp_group in (1, 2):
            return 5   # TNO rigs (A1/A2): low-noise sensors
        return 50      # AIT rigs (A3/A4) or unknown: noisier sensors
    # Legacy A1.xx/A2.xx-prefixed form, if ever encountered.
    if cell_num.startswith('A1') or cell_num.startswith('A2'):
        return 5
    return 50


__all__ = ['stripping_smooth_win']
