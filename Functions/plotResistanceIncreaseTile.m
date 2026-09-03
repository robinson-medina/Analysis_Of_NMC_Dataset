function plotResistanceIncreaseTile(axTime, axFEC, combined_df, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, plot_title)
% plotResistanceIncreaseTile - Draw a resistance-vs-time and resistance-vs-FEC
% pair of traces into caller-supplied axes, instead of creating a new figure.
%
% Summary: Mirrors the standalone plotResistanceIncrease() figure logic used
%          in PlotResistanceIncrease_Detailed.m, but targets externally
%          created axes (axTime, axFEC) so several datasets can be combined
%          as columns/tiles of one shared figure (e.g. via tiledlayout).
% Author: NEXTBMS Team
% Date: 2026-08-07
%
% Inputs:
%   axTime         - target axes for the Time [days] vs Resistance subplot
%   axFEC          - target axes for the FEC vs Resistance subplot
%   combined_df    - table with columns cell_number, Timestamp,
%                    "Resistance [Ohm]", CheckupResistanceFEC
%   cell_list      - cellstr/string array of all cell numbers, plotted as
%                    thin grey background traces for context
%   cell_plot_list - cellstr/string array of highlighted cell numbers
%   label_list     - legend label per highlighted cell
%   colormap_list  - line color per highlighted cell
%   Marker_list    - line style per highlighted cell
%   plot_title     - base title, suffixed with '(vs Time)' / '(vs FEC)'
%
% Outputs: none (draws directly into axTime/axFEC)

    % --- Time vs Resistance ---
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
        plot(axTime, time_days, current_cell.("Resistance [Ohm]"), 'LineWidth', 2, 'Color', [0.5 0.5 0.5 0.2], 'HandleVisibility', 'off');
    end

    % Highlighted cells: colored, legend-bearing traces.
    legend_handles = [];
    legend_labels = {};
    for idx = 1:length(cell_plot_list)
        cell_name = cell_plot_list{idx};
        mask = strcmp(combined_df.("cell_number"), cell_name);
        current_cell = combined_df(mask, :);
        if isempty(current_cell)
            warning('Cell %s not found in data', cell_name);
            continue;
        end
        time_days = days(current_cell.("Timestamp") - current_cell.("Timestamp")(1));
        h = plot(axTime, time_days, current_cell.("Resistance [Ohm]"), '-o', 'LineWidth', 2, 'Color', colormap_list{idx}, ...
            'MarkerFaceColor', colormap_list{idx}, 'MarkerSize', 4, 'LineStyle', Marker_list{idx});
        legend_handles = [legend_handles, h]; %#ok<AGROW>
        legend_labels{end+1} = label_list{idx}; %#ok<AGROW>
    end

    grid(axTime, 'on');
    set(axTime, 'GridLineStyle', '--', 'GridAlpha', 0.6, 'FontSize', 11);
    xlabel(axTime, 'Time [days]', 'FontSize', 11);
    ylabel(axTime, 'Checkup Resistance [\Omega]', 'FontSize', 11);
    if ~isempty(plot_title)
        title(axTime, [plot_title ' (vs Time)'], 'FontSize', 11);
    end
    if ~isempty(legend_handles)
        legend(axTime, legend_handles, legend_labels, 'FontSize', 11, 'Location', 'best', 'Interpreter', 'none');
    end
    hold(axTime, 'off');

    % --- FEC vs Resistance ---
    hold(axFEC, 'on');
    % Background: every cell in the dataset, thin grey lines for context.
    for i = 1:length(cell_list)
        cell_name = cell_list{i};
        mask = strcmp(combined_df.("cell_number"), cell_name);
        current_cell = combined_df(mask, :);
        if isempty(current_cell)
            continue;
        end
        plot(axFEC, current_cell.CheckupResistanceFEC, current_cell.("Resistance [Ohm]"), 'LineWidth', 2, 'Color', [0.5 0.5 0.5 0.2], 'HandleVisibility', 'off');
    end

    % Highlighted cells: colored, legend-bearing traces.
    legend_handles = [];
    legend_labels = {};
    maxFEC_highlight = 0;
    for idx = 1:length(cell_plot_list)
        cell_name = cell_plot_list{idx};
        mask = strcmp(combined_df.("cell_number"), cell_name);
        current_cell = combined_df(mask, :);
        if isempty(current_cell)
            continue;
        end
        h = plot(axFEC, current_cell.CheckupResistanceFEC, current_cell.("Resistance [Ohm]"), '-o', 'LineWidth', 2, 'Color', colormap_list{idx}, ...
            'MarkerFaceColor', colormap_list{idx}, 'MarkerSize', 4, 'LineStyle', Marker_list{idx});
        legend_handles = [legend_handles, h]; %#ok<AGROW>
        legend_labels{end+1} = label_list{idx}; %#ok<AGROW>
        if ~isempty(current_cell.CheckupResistanceFEC)
            maxFEC_highlight = max([maxFEC_highlight; max(current_cell.CheckupResistanceFEC)]);
        end
    end

    grid(axFEC, 'on');
    set(axFEC, 'GridLineStyle', '--', 'GridAlpha', 0.6, 'FontSize', 11);
    xlabel(axFEC, 'Full Equivalent Cycles (FEC)', 'FontSize', 11);
    ylabel(axFEC, 'Checkup Resistance [\Omega]', 'FontSize', 11);
    if ~isempty(plot_title)
        title(axFEC, [plot_title ' (vs FEC)'], 'FontSize', 11);
    end
    if maxFEC_highlight > 0
        xlim(axFEC, [0, maxFEC_highlight]);
    end
    if ~isempty(legend_handles)
        legend(axFEC, legend_handles, legend_labels, 'FontSize', 11, 'Location', 'best', 'Interpreter', 'none');
    end
    hold(axFEC, 'off');
end
