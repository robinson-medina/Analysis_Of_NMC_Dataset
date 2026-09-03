function plotCapacityDegradationTile(axTime, axFEC, combined_df, cell_list, cell_plot_list, colormap_list, Marker_list, plot_title)
% plotCapacityDegradationTile - Draw a relative-capacity-vs-time and
% vs-FEC pair of traces into caller-supplied axes, instead of creating a
% new figure.
%
% Summary: Mirrors the standalone plotCapacityDegradation() figure logic
%          used in PlotCapacityDegradation_detailed.m, but targets
%          externally created axes (axTime, axFEC) so several datasets
%          can be combined as columns/tiles of one shared figure (e.g.
%          via tiledlayout). Legends are intentionally omitted, matching
%          the current no-legend convention already applied to this
%          script's capacity plots.
% Author: NEXTBMS Team
% Date: 2026-08-07
%
% Inputs:
%   axTime         - target axes for the Time [days] vs Relative Capacity subplot
%   axFEC          - target axes for the FEC vs Relative Capacity subplot
%   combined_df    - table with columns cell_number, Timestamp,
%                    "Capacity [Ah]", CheckupCapacityFEC
%   cell_list      - cellstr/string array of all cell numbers, plotted as
%                    thin grey background traces for context
%   cell_plot_list - cellstr/string array of highlighted cell numbers
%   colormap_list  - line color per highlighted cell
%   Marker_list    - line style per highlighted cell
%   plot_title     - base title, suffixed with '(vs Time)' / '(vs FEC)'
%
% Outputs: none (draws directly into axTime/axFEC)

    % --- Time vs Relative Capacity ---
    hold(axTime, 'on');
    % Background: every cell in the dataset, thin grey lines for context.
    for i = 1:length(cell_list)
        cell_name = cell_list{i};
        mask = strcmp(combined_df.("cell_number"), cell_name);
        current_cell = combined_df(mask, :);
        if isempty(current_cell)
            continue;
        end
        time_days = days(current_cell.("Timestamp") - current_cell.("Timestamp")(1));
        rel_capacity = current_cell.("Capacity [Ah]") / current_cell.("Capacity [Ah]")(1) * 100;
        plot(axTime, time_days, rel_capacity, 'LineWidth', 2, 'Color', [0.5 0.5 0.5 0.2], 'HandleVisibility', 'off');
    end

    % Highlighted cells: colored traces (no legend, per project convention for this script).
    for idx = 1:length(cell_plot_list)
        cell_name = cell_plot_list{idx};
        mask = strcmp(combined_df.("cell_number"), cell_name);
        current_cell = combined_df(mask, :);
        if isempty(current_cell)
            warning('Cell %s not found in data', cell_name);
            continue;
        end
        time_days = days(current_cell.("Timestamp") - current_cell.("Timestamp")(1));
        rel_capacity = current_cell.("Capacity [Ah]") / current_cell.("Capacity [Ah]")(1) * 100;
        plot(axTime, time_days, rel_capacity, '-o', 'LineWidth', 2, 'Color', colormap_list{idx}, ...
            'MarkerFaceColor', colormap_list{idx}, 'MarkerSize', 4, 'LineStyle', Marker_list{idx}, 'HandleVisibility', 'off');
    end

    grid(axTime, 'on');
    set(axTime, 'GridLineStyle', '--', 'GridAlpha', 0.6, 'FontSize', 11);
    xlabel(axTime, 'Time [days]', 'FontSize', 11);
    ylabel(axTime, 'Relative Capacity [%]', 'FontSize', 11);
    if ~isempty(plot_title)
        title(axTime, [plot_title ' (vs Time)'], 'FontSize', 11);
    end
    xlim(axTime, [0, 425]);
    ylim(axTime, [78, 103]);
    hold(axTime, 'off');

    % --- FEC vs Relative Capacity ---
    hold(axFEC, 'on');
    % Background: every cell in the dataset, thin grey lines for context.
    for i = 1:length(cell_list)
        cell_name = cell_list{i};
        mask = strcmp(combined_df.("cell_number"), cell_name);
        current_cell = combined_df(mask, :);
        if isempty(current_cell)
            continue;
        end
        rel_capacity = current_cell.("Capacity [Ah]") / current_cell.("Capacity [Ah]")(1) * 100;
        plot(axFEC, current_cell.CheckupCapacityFEC, rel_capacity, 'LineWidth', 2, 'Color', [0.5 0.5 0.5 0.2], 'HandleVisibility', 'off');
    end

    % Highlighted cells: colored traces (no legend, per project convention for this script).
    maxFEC_highlight = 0;
    for idx = 1:length(cell_plot_list)
        cell_name = cell_plot_list{idx};
        mask = strcmp(combined_df.("cell_number"), cell_name);
        current_cell = combined_df(mask, :);
        if isempty(current_cell)
            continue;
        end
        rel_capacity = current_cell.("Capacity [Ah]") / current_cell.("Capacity [Ah]")(1) * 100;
        plot(axFEC, current_cell.CheckupCapacityFEC, rel_capacity, '-o', 'LineWidth', 2, 'Color', colormap_list{idx}, ...
            'MarkerFaceColor', colormap_list{idx}, 'MarkerSize', 4, 'LineStyle', Marker_list{idx}, 'HandleVisibility', 'off');
        if ~isempty(current_cell.CheckupCapacityFEC)
            maxFEC_highlight = max([maxFEC_highlight; max(current_cell.CheckupCapacityFEC)]);
        end
    end

    grid(axFEC, 'on');
    set(axFEC, 'GridLineStyle', '--', 'GridAlpha', 0.6, 'FontSize', 11);
    xlabel(axFEC, 'Full Equivalent Cycles (FEC)', 'FontSize', 11);
    ylabel(axFEC, 'Relative Capacity [%]', 'FontSize', 11);
    if ~isempty(plot_title)
        title(axFEC, [plot_title ' (vs FEC)'], 'FontSize', 11);
    end
    ylim(axFEC, [78, 103]);
    xlim(axFEC, [0, maxFEC_highlight]);
    hold(axFEC, 'off');
end
