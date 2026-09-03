"""
plotGITTAndOCP - overlay BoL/EoL GITT OCV points with the first/last C/50
OCP curves on a shared signed-Q axis.

Python counterpart of Functions/plotGITTAndOCP.m, used by
python_scripts/PlotCellSummary.py (todo #012).

Author: GitHub Copilot (for Robinson Medina / Feye Hoekstra)
Date: 2026-08-24
"""


def _plot_gitt_points(ax, gitt_ep, col):
    if not gitt_ep:
        return None
    (h,) = ax.plot(gitt_ep['cumQ_signed_Ah'], gitt_ep['OCV_V'], 'o',
                    markeredgecolor=col, markerfacecolor=col, markersize=4, linestyle='none')
    return h


def _plot_c50_phase(ax, c50, col):
    h_disch = None
    if not c50 or len(c50.get('dischQ_Ah', [])) == 0:
        return h_disch
    (h_disch,) = ax.plot(c50['dischQ_Ah'], c50['dischV'], '--', color=col, linewidth=1.0)
    if len(c50.get('chargeQ_Ah', [])) > 0:
        ax.plot(c50['chargeQ_Ah'], c50['chargeV'], '--', color=col, linewidth=1.0)
    return h_disch


def plot_gitt_and_ocp(ax, bol_gitt, eol_gitt, bol_c50, eol_c50, col_bol, col_eol,
                       font_name='Times New Roman', font_size=8):
    """Overlay BoL/EoL GITT OCV points + C/50 OCP curves on a shared signed-Q axis."""

    handles, labels = [], []

    h_bd = _plot_c50_phase(ax, bol_c50, col_bol)
    if h_bd is not None:
        handles.append(h_bd)
        labels.append('BoL OCV')

    h_ed = _plot_c50_phase(ax, eol_c50, col_eol)
    if h_ed is not None:
        handles.append(h_ed)
        labels.append('EoL OCV')

    h_bg = _plot_gitt_points(ax, bol_gitt, col_bol)
    if h_bg is not None:
        handles.append(h_bg)
        labels.append('BoL GITT')

    h_eg = _plot_gitt_points(ax, eol_gitt, col_eol)
    if h_eg is not None:
        handles.append(h_eg)
        labels.append('EoL GITT')

    ax.set_xlabel('Cumulative charge [Ah]')
    ax.set_ylabel('Voltage / OCV [V]')
    ax.set_title('OCV: BoL vs EoL', fontweight='normal')
    ax.grid(True)

    if handles:
        ax.legend(handles, labels, loc='best', frameon=False, fontsize=font_size, ncol=2)
    else:
        ax.text(0.5, 0.5, 'No GITT detected and no C/50 OCP available',
                transform=ax.transAxes, ha='center', fontsize=font_size - 1)


__all__ = ['plot_gitt_and_ocp']
