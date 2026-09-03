"""
cellNumberToGroupChannel - Map a physical ageing-cell number to its test group/channel.

Summary: Maps a physical cell number (R-025 plain Cell_<n> convention) to its
ageing test (temp_group, channel) pair, using the campaign crosswalk in
ageing_test_plan.md. temp_group 1-4 correspond to campaigns A1-A4 (0 degC,
25 degC, 45 degC, 0-45 degC respectively).

Extracted 2026-08-24 from getCellLabel.py's embedded dict, so it can also be
imported from other Functions/ helpers (e.g. extractResistanceValues.py) that
need to know which campaign a cell belongs to without string-matching an
old-form cell-ID (which no longer exists under R-025).

Author: GitHub Copilot (for Feye Hoekstra / Robinson Medina)
Date: 2026-08-24
Inputs/Outputs: cell_number_to_group_channel(cell_number: int) -> (temp_group, channel);
(None, None) if the cell number is not part of the ageing set.
"""

# Physical cell number -> (temp_group, channel), derived from the campaign
# crosswalk in ageing_test_plan.md.
CELL_TO_GROUP_CHANNEL = {
    57: (1, 1), 60: (1, 2), 63: (1, 3), 66: (1, 4), 68: (1, 5), 71: (1, 6), 74: (1, 7), 72: (1, 8),
    11: (2, 1), 12: (2, 2), 56: (2, 2), 89: (2, 2), 93: (2, 2), 16: (2, 3), 30: (2, 4), 27: (2, 5),
    23: (2, 6), 34: (2, 7), 35: (2, 8), 43: (2, 9), 46: (2, 10), 42: (2, 11),
    45: (3, 1), 26: (3, 2), 28: (3, 3), 29: (3, 4), 40: (3, 5), 1: (3, 6), 3: (3, 7), 9: (3, 8),
    5: (3, 9), 22: (3, 10), 8: (3, 11), 47: (3, 12), 17: (3, 13), 25: (3, 14),
    49: (4, 1), 50: (4, 2), 53: (4, 3), 64: (4, 4), 70: (4, 5),
}


def cell_number_to_group_channel(cell_number):
    """Map a plain Cell_<n> cell number to (temp_group, channel); (None, None) if unknown."""
    return CELL_TO_GROUP_CHANNEL.get(cell_number, (None, None))
