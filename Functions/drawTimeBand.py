"""
drawTimeBand - draw a semi-transparent vertical time band on every axes in
ax_list between t0 and t1 (datetime).

Python counterpart of Functions/drawTimeBand.m.

Author: GitHub Copilot (for Robinson Medina / Feye Hoekstra)
Date: 2026-08-24
"""

import numpy as np


def draw_time_band(ax_list, t0, t1, rgb, alpha):
    """Draw a shaded vertical band [t0, t1] on every axes in ax_list, sent to the back."""

    for ax in ax_list:
        ylim = ax.get_ylim()
        if ylim is None or not all(np.isfinite(ylim)):
            continue
        ax.axvspan(t0, t1, facecolor=rgb, alpha=alpha, edgecolor='none', zorder=0)


__all__ = ['draw_time_band']
