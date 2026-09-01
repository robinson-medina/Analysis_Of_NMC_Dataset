%% plotReferencePerformanceCycle
% Summary: Create a publication-formatted overview plot (current, voltage,
% temperature, and cumulative capacity) for a user-selected time window.
% The plot mirrors the overview layout but is zoomed to the provided start
% and end timestamps for Reference Performance Cycle visualization.
% Author: GitHub Copilot
% Date: 2026-06-02
% Inputs/Outputs:
%   Inputs:
%   - timeWithGaps: datetime array with inserted gaps
%   - current: current vector in A
%   - voltage: voltage vector in V
%   - cellTemp: cell temperature vector in degC
%   - chamberTemp: chamber temperature vector in degC
%   - cumulative_integral: cumulative capacity vector in Ah (kept in the
%     interface for compatibility with existing calls; not plotted here)
%   - cellNum: cell identifier string
%   - cellLabel: descriptive cell label string
%   - startTime: start datetime for zoom window
%   - endTime: end datetime for zoom window
%   Outputs:
%   - No explicit output. Creates one formatted figure.
function plotReferencePerformanceCycle(timeWithGaps, current, voltage, cellTemp, chamberTemp, cumulative_integral, cellNum, cellLabel, startTime, endTime) %#ok<INUSD>

% Keep interface parity with overview plot even though capacity is hidden in RPC.
unused_capacity_ah = cumulative_integral; %#ok<NASGU>

% Define publication palette colors in the preferred project order.
darkblue = [1 17 181] ./ 255;
red = [255 0 0] ./ 255;
green = [12 195 82] ./ 255;  % used for the zoom-box / inset-frame edges
black = [0 0 0];

% Ensure start/end inputs are datetime values and ordered correctly.
startTime = datetime(startTime);
endTime = datetime(endTime);
if endTime < startTime
    tmpTime = startTime;
    startTime = endTime;
    endTime = tmpTime;
end

% Build a mask for samples inside the requested zoom window.
validWindowMask = (timeWithGaps >= startTime) & (timeWithGaps <= endTime) & ~isnat(timeWithGaps);

% Slice once to the requested window so every subplot only processes in-scope data.
timePlot = timeWithGaps(validWindowMask);
currentPlot = current(validWindowMask);
voltagePlot = voltage(validWindowMask);
cellTempPlot = cellTemp(validWindowMask);
chamberTempPlot = chamberTemp(validWindowMask);

% Fail fast when the requested window does not contain any data points.
if isempty(timePlot)
    error('No data points found in the requested RPC window [%s, %s].', string(startTime), string(endTime));
end

% If the requested window starts inside a synthetic gap inserted by
% insertNaNAtGaps, the NaT gap marker itself is already filtered out by
% validWindowMask above, but the first REAL sample can still lie later
% than startTime. That leaves visible blank space between the left x-limit
% and the first plotted sample. To remove only this LEADING blank while
% preserving intentional INTERNAL gaps later in the traces, we:
%   1) trim any leading rows whose plotted signals are all NaN, and then
%   2) prepend one synthetic sample at startTime, reusing the first real
%      sample values so the line starts continuously at the window edge.
leadingFiniteMask = ~(isnan(currentPlot) & isnan(voltagePlot) & ...
                      isnan(cellTempPlot) & isnan(chamberTempPlot));
firstRealIdx = find(leadingFiniteMask, 1, 'first');
if isempty(firstRealIdx)
    error('No finite plotted samples found in the requested RPC window [%s, %s].', string(startTime), string(endTime));
end
if firstRealIdx > 1
    timePlot = timePlot(firstRealIdx:end);
    currentPlot = currentPlot(firstRealIdx:end);
    voltagePlot = voltagePlot(firstRealIdx:end);
    cellTempPlot = cellTempPlot(firstRealIdx:end);
    chamberTempPlot = chamberTempPlot(firstRealIdx:end);
end
if timePlot(1) > startTime
    timePlot = [startTime; timePlot];
    currentPlot = [currentPlot(1); currentPlot];
    voltagePlot = [voltagePlot(1); voltagePlot];
    cellTempPlot = [cellTempPlot(1); cellTempPlot];
    chamberTempPlot = [chamberTempPlot(1); chamberTempPlot];
end

% Create a publication figure sized for a double-column (figure*) import at
% natural size (R-021). FIG_W_CM is tuned so the tight-cropped exported PDF
% width is ~85% of the paper text width (0.85 x 522 pt = 443.7 pt = 15.66 cm);
% the height keeps the original 17.4:10 aspect ratio.
fig = figure('Name', [cellNum ' - Reference Performance Cycle'], 'Color', 'w');
fig.Units = 'centimeters';
FIG_W_CM = 16.58;   % tuned so exported width ~= 443.7 pt (85% of textwidth)
FIG_H_CM = 9.53;    % preserves the original 17.4:10 aspect ratio
PUB_FONTSIZE = 8;   % main axis/label/tick/zone/legend text = paper caption (\footnotesize) size
fig.Position(3:4) = [FIG_W_CM FIG_H_CM];
fig.PaperPositionMode = 'auto';

% Arrange three vertically stacked panels for RPC publication view.
tl = tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
% Reserve headroom above the top subplot so zone labels/arrows remain visible.
tl.Units = 'normalized';
tl.OuterPosition = [0 0 1 0.90];

% Plot current in the top panel.
ax1 = nexttile;
plot(ax1, timePlot, currentPlot, 'Color', darkblue, 'LineWidth', 1.1);
ylabel(ax1, 'Current [A]', 'FontName', 'Times New Roman', 'FontSize', PUB_FONTSIZE);
grid(ax1, 'on');
ax1.Layer = 'top';

% Plot voltage in the second panel.
ax2 = nexttile;
plot(ax2, timePlot, voltagePlot, 'Color', darkblue, 'LineWidth', 1.1);
ylabel(ax2, 'Voltage [V]', 'FontName', 'Times New Roman', 'FontSize', PUB_FONTSIZE);
grid(ax2, 'on');
ax2.Layer = 'top';

% Plot cell and chamber temperature in the third panel.
ax3 = nexttile;
hCell = plot(ax3, timePlot, cellTempPlot, 'Color', darkblue, 'LineWidth', 1.0);
hold(ax3, 'on');
hChamber = plot(ax3, timePlot, chamberTempPlot, 'Color', red, 'LineWidth', 1.0);
hold(ax3, 'off');
ylabel(ax3, 'Temperature [\circC]', 'Interpreter', 'tex', 'FontName', 'Times New Roman', 'FontSize', PUB_FONTSIZE);
legend(ax3, [hCell hChamber], {'Cell', 'Chamber'}, 'Location', 'southwest', 'Box', 'off', 'FontName', 'Times New Roman', 'FontSize', PUB_FONTSIZE);
grid(ax3, 'on');
ax3.Layer = 'top';

% Keep the x-axis label on the last remaining panel.
xlabel(ax3, 'Time', 'FontName', 'Times New Roman', 'FontSize', PUB_FONTSIZE);

% Apply shared x-limits and consistent publication typography to all panels.
allAxes = [ax1 ax2 ax3];
for ax = allAxes
    xlim(ax, [startTime endTime]);
    ax.FontName = 'Times New Roman';
    ax.FontSize = PUB_FONTSIZE;
    ax.LabelFontSizeMultiplier = 1;   % axis labels same size as ticks/caption (default 1.1 enlarges them)
    ax.TitleFontSizeMultiplier = 1;
    ax.LineWidth = 0.8;
end

% Define 4 RPC zone boundaries as editable datetime variables.
% zone1StartTime controls where the FIRST zone arrow/shading begins.
% zone4EndTime controls where the FOURTH zone arrow/shading ends.
% These are independent from the full-figure x-limits, which still come
% from startTime / endTime above.
zone1StartTime = datetime(2024, 4, 23, 11, 15, 59);
zone1EndTime   = datetime(2024, 4, 24, 0, 14, 59);
zone2EndTime   = datetime(2024, 4, 28, 3, 12, 5);
zone3EndTime   = datetime(2024, 4, 29, 3, 4, 16);
zone4EndTime   =  datetime(2024, 4, 29, 22, 03, 25);;

% Keep the user-editable outer zone limits inside the visible figure
% window so the arrows/shading cannot extend beyond the plotted data.
zoneWindowStart = max(datetime(zone1StartTime), startTime);
zoneWindowEnd   = min(datetime(zone4EndTime),   endTime);
if zoneWindowEnd < zoneWindowStart
    tmpZoneTime = zoneWindowStart;
    zoneWindowStart = zoneWindowEnd;
    zoneWindowEnd = tmpZoneTime;
end

% Normalize internal boundaries so they are sorted and clipped to the
% user-selected zone window rather than always using the full figure
% window. This lets zone 1 start later and/or zone 4 end earlier.
internalBoundaries = sort([zone1EndTime, zone2EndTime, zone3EndTime]);
internalBoundaries = max(internalBoundaries, zoneWindowStart);
internalBoundaries = min(internalBoundaries, zoneWindowEnd);

% Build zone edges and labels (4 zones = 5 edge points).
zoneEdges = [zoneWindowStart, internalBoundaries, zoneWindowEnd];
zoneLabels = {'Initialization', 'C/50 (dis) charge cycle', 'Pulses', 'Drive cycle'};

% Draw vertical boundary lines on all subplots at each internal zone boundary.
for boundaryIdx = 1:numel(internalBoundaries)
    boundaryTime = internalBoundaries(boundaryIdx);
    xline(ax1, boundaryTime, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.75, 'HandleVisibility', 'off');
    xline(ax2, boundaryTime, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.75, 'HandleVisibility', 'off');
    xline(ax3, boundaryTime, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.75, 'HandleVisibility', 'off');
end

% Add alternating shaded backgrounds to delimit zones on all three subplots.
shadeColor = [0.95 0.95 0.95];
% Optional zone 0: shaded preamble from the full figure-window start to
% the editable start of zone 1. This segment intentionally has NO top
% arrow and NO label; it only exists to visually shade the pre-zone data.
if zoneWindowStart > startTime
    zone0Start = startTime;
    zone0End   = zoneWindowStart;

    yLim1 = ylim(ax1);
    patch(ax1, [zone0Start zone0End zone0End zone0Start], [yLim1(1) yLim1(1) yLim1(2) yLim1(2)], ...
        shadeColor, 'EdgeColor', 'none', 'HandleVisibility', 'off');

    yLim2 = ylim(ax2);
    patch(ax2, [zone0Start zone0End zone0End zone0Start], [yLim2(1) yLim2(1) yLim2(2) yLim2(2)], ...
        shadeColor, 'EdgeColor', 'none', 'HandleVisibility', 'off');

    yLim3 = ylim(ax3);
    patch(ax3, [zone0Start zone0End zone0End zone0Start], [yLim3(1) yLim3(1) yLim3(2) yLim3(2)], ...
        shadeColor, 'EdgeColor', 'none', 'HandleVisibility', 'off');
end

for zoneIdx = 1:4
    % Shade every other zone for visual separation while preserving readability.
    if mod(zoneIdx, 2) == 0
        zoneStart = zoneEdges(zoneIdx);
        zoneEnd = zoneEdges(zoneIdx + 1);

        yLim1 = ylim(ax1);
        patch(ax1, [zoneStart zoneEnd zoneEnd zoneStart], [yLim1(1) yLim1(1) yLim1(2) yLim1(2)], ...
            shadeColor, 'EdgeColor', 'none', 'HandleVisibility', 'off');

        yLim2 = ylim(ax2);
        patch(ax2, [zoneStart zoneEnd zoneEnd zoneStart], [yLim2(1) yLim2(1) yLim2(2) yLim2(2)], ...
            shadeColor, 'EdgeColor', 'none', 'HandleVisibility', 'off');

        yLim3 = ylim(ax3);
        patch(ax3, [zoneStart zoneEnd zoneEnd zoneStart], [yLim3(1) yLim3(1) yLim3(2) yLim3(2)], ...
            shadeColor, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    end
end

% Replot traces on top of shaded regions so lines remain visually dominant.
hold(ax1, 'on');
hold(ax2, 'on');
hold(ax3, 'on');
plot(ax1, timePlot, currentPlot, '-', 'Color', darkblue, 'LineWidth', 1.1, 'HandleVisibility', 'off');
plot(ax2, timePlot, voltagePlot, '-', 'Color', darkblue, 'LineWidth', 1.1, 'HandleVisibility', 'off');
plot(ax3, timePlot, chamberTempPlot, '-', 'Color', red, 'LineWidth', 1.0, 'HandleVisibility', 'off');
plot(ax3, timePlot, cellTempPlot, '-', 'Color', darkblue, 'LineWidth', 1.0, 'HandleVisibility', 'off');
hold(ax1, 'off');
hold(ax2, 'off');
hold(ax3, 'off');

% Re-assert grid visibility after overlays.
grid(ax1, 'on');
grid(ax2, 'on');
grid(ax3, 'on');

% Place zone arrows/labels using the same geometry as the combined
% characterization figure so placement stays consistent across publications.
yLimCurrentData = ylim(ax1);
yRangeCurrent = yLimCurrentData(2) - yLimCurrentData(1);

% Freeze y-limits so off-axis annotations do not trigger autoscaling and
% slide back into the plotting area.
ylim(ax1, yLimCurrentData);
ylim(ax2, ylim(ax2));
ylim(ax3, ylim(ax3));

yPosArrow = yLimCurrentData(2) + 0.06 * yRangeCurrent;
yPosLabel = yLimCurrentData(2) + 0.14 * yRangeCurrent;

% Inset arrowheads slightly from each boundary line to avoid visual overlap.
windowDays = days(endTime - startTime);
arrowInset = days(0.01 * windowDays);

for zoneIdx = 1:4
    % Compute each zone span and midpoint from neighboring edge timestamps.
    zoneStart = zoneEdges(zoneIdx);
    zoneEnd = zoneEdges(zoneIdx + 1);
    zoneMid = zoneStart + (zoneEnd - zoneStart) / 2;

    % Apply inset to keep arrowheads clear of dashed boundary lines.
    xLeft = zoneStart + arrowInset;
    xRight = zoneEnd - arrowInset;
    if xRight <= xLeft
        xLeft = zoneStart;
        xRight = zoneEnd;
    end

    % Draw the horizontal shaft of the double-headed zone arrow.
    line(ax1, [xLeft xRight], [yPosArrow yPosArrow], 'Color', black, 'LineWidth', 0.75, 'Clipping', 'off', 'HandleVisibility', 'off');

    % Draw left and right arrowheads as line markers to avoid clearing axes.
    line(ax1, xLeft, yPosArrow, 'LineStyle', 'none', 'Marker', '<', 'MarkerSize', 5, 'Color', black, 'MarkerFaceColor', black, 'Clipping', 'off', 'HandleVisibility', 'off');
    line(ax1, xRight, yPosArrow, 'LineStyle', 'none', 'Marker', '>', 'MarkerSize', 5, 'Color', black, 'MarkerFaceColor', black, 'Clipping', 'off', 'HandleVisibility', 'off');

    % Place zone label centered above its arrow in publication typography.
    text(ax1, zoneMid, yPosLabel, zoneLabels{zoneIdx}, ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom', ...
        'Interpreter', 'tex', ...
        'FontName', 'Times New Roman', ...
        'FontSize', PUB_FONTSIZE, ...
        'Clipping', 'off');
end

% Intentionally no figure title for publication layout.

% Add voltage zoom inset overlay positioned over the temperature subplot (ax3).
% User specification: zoom on April 28 between 18:32:00 and 18:50:00, voltage 3.60-3.72V.
% These are specific times on a known date within the reference cycle.

% Define the target day and clock times.
% Reference cycle: 2024-04-23 to 2024-04-30, zoom target is 2024-04-28.
% Wider-than-tall zoom window: long time span, tight voltage band that hugs the data.
targetDate = datetime(2024, 4, 28);
targetStartClock = duration(18, 37, 59);   % Widened start to make the box wider
targetEndClock = duration(18, 39, 30);     % Widened end (22 min span)
zoomVMin = 3.58;  % Tighter lower bound so box matches data height
zoomVMax = 3.74;  % Tighter upper bound so box matches data height

% Extract time-of-day (clock) component for all times in the reference cycle.
timeOfDay = timeWithGaps - dateshift(timeWithGaps, 'start', 'day');

% Find times on the target date within the target clock window and voltage range.
% Build the expected time bounds for the target date.
dateStart = targetDate;
dateEnd = targetDate + duration(23, 59, 59);

% Mask for April 28 + clock window + voltage band.
zoomMask = (timeWithGaps >= dateStart) & (timeWithGaps <= dateEnd) & ...
           (timeOfDay >= targetStartClock) & (timeOfDay <= targetEndClock) & ...
           (voltage >= zoomVMin) & (voltage <= zoomVMax) & ~isnat(timeWithGaps);

% Fallback: same clock window on any day inside the requested cycle.
if sum(zoomMask) == 0
    zoomMask = (timeWithGaps >= startTime) & (timeWithGaps <= endTime) & ...
               (timeOfDay >= targetStartClock) & (timeOfDay <= targetEndClock) & ...
               (voltage >= zoomVMin) & (voltage <= zoomVMax) & ~isnat(timeWithGaps);
end

% Extract time window.
if sum(zoomMask) > 0
    zoomStartTime = min(timeWithGaps(zoomMask));
    zoomEndTime = max(timeWithGaps(zoomMask));
else
    % Fallback: no data found in the target window.
    zoomStartTime = startTime;
    zoomEndTime = startTime;
end

% Only create inset if zoom region has data.
if sum(zoomMask) > 0
    timeZoom = timeWithGaps(zoomMask);
    voltageZoom = voltage(zoomMask);

    % --- Independent clock window for the SMALL voltage highlight box ---
    % Decouple the small rectangle drawn on ax2 from targetStartClock /
    % targetEndClock (which control the inset CONTENT window). Edit the two
    % values below to move/resize the small box without changing the inset.
    % Default values match the inset window so existing behavior is kept.
    boxTargetStartClock = duration(18, 34, 0);   % small-box start clock time
    boxTargetEndClock   = duration(18, 50, 0);   % small-box end clock time

    % Build a mask for the small-box clock window, restricted to the same
    % date and voltage band used by the inset.
    boxMask = (timeWithGaps >= dateStart) & (timeWithGaps <= dateEnd) & ...
              (timeOfDay >= boxTargetStartClock) & (timeOfDay <= boxTargetEndClock) & ...
              (voltage >= zoomVMin) & (voltage <= zoomVMax) & ~isnat(timeWithGaps);
    if sum(boxMask) == 0
        % Fallback: if the user's small-box window has no samples, reuse the
        % inset window so something still renders.
        boxMask = zoomMask;
    end
    timeBox    = timeWithGaps(boxMask);
    voltageBox = voltage(boxMask);

    % Tightly hug the actual filtered data, then expand the highlight
    % rectangle around its center to make the box prominently visible on
    % the main voltage plot. The inset still shows the un-expanded data.
    boxTimeStart = min(timeBox);
    boxTimeEnd   = max(timeBox);
    boxVMin      = min(voltageBox);
    boxVMax      = max(voltageBox);

    % Expansion factor: doubled from previous (5x, 2x) so the highlight
    % rectangle is roughly twice as large on the voltage plot.
    timeScale = 15.0;
    voltScale = 2.5;
    tMid      = boxTimeStart + (boxTimeEnd - boxTimeStart) / 2;
    tHalf     = (boxTimeEnd - boxTimeStart) / 2;
    boxTimeStart = tMid - timeScale * tHalf;
    boxTimeEnd   = tMid + timeScale * tHalf;

    vMid  = (boxVMin + boxVMax) / 2;
    vHalf = max((boxVMax - boxVMin) / 2, 0.02);
    boxVMin = vMid - voltScale * vHalf;
    boxVMax = vMid + voltScale * vHalf;

    % NOTE: the small highlight box is NOT drawn here. Drawing it as a
    % data-space plot inside ax2 caused the box to silently shift whenever
    % later operations (creating the inset axes, drawInsetOuterFrame,
    % uistack) re-flowed ax2's pixel position. The connectors are computed
    % in figure-normalized coordinates AFTER all reflow is done, so the box
    % must use the same snapshot to stay aligned. The box is drawn below,
    % from the exact same srcRect used for the connector start points.
    
    % Create inset axes positioned in upper-right corner of temperature subplot (ax3).
    % Make the inset much larger for clear visibility (55% of ax3 width/height).
    ax3Pos = ax3.Position;
    insetWidth = 0.20;   % 55% of ax3 width.
    insetHeight = 0.55;  % 55% of ax3 height.
    insetPos = [ax3Pos(1) + 0.48 * ax3Pos(3), ax3Pos(2) + 0.2 * (1 - insetHeight) * ax3Pos(4), ...
                insetWidth * ax3Pos(3), insetHeight * ax3Pos(4)];
    
    % Create inset axes with a solid white background so the underlying
    % temperature plot is fully hidden behind the zoomed view.
    axInset = axes('Parent', fig, 'Position', insetPos);
    axInset.Color = [1 1 1];  % solid white fill for the plot box
    
    % Plot the voltage data in the inset.
    % Create line plot with darkblue color.
    plot(axInset, timeZoom, voltageZoom, 'Color', darkblue, 'LineWidth', 2.5);
    
    % Style the inset axes.
    axInset.FontName = 'Times New Roman';
    axInset.FontSize = 8;
    axInset.LineWidth = 1.2;
    axInset.Box = 'on';
    % Enable the grid using axis properties because grid(...) does not accept styling arguments here.
    axInset.XGrid = 'on';
    axInset.YGrid = 'on';
    axInset.GridLineStyle = '--';
    axInset.GridAlpha = 0.5;
    axInset.GridColor = [0.7 0.7 0.7];
    
    % Set axis limits explicitly.
    xlim(axInset, [zoomStartTime zoomEndTime]);
    ylim(axInset, [zoomVMin zoomVMax]);

    % Show exactly 3 evenly-spaced ticks on each axis; skip labels to keep the inset clean.
    % Datetime ticks: start, midpoint, end of zoom window.
    xTicks = zoomStartTime + (zoomEndTime - zoomStartTime) * [0, 0.5, 1];
    axInset.XTick = xTicks;
    % Use explicit tick labels for compatibility with MATLAB releases that
    % do not expose DatetimeTickFormat on axes objects.
    axInset.XTickLabel = cellstr(datestr(xTicks, 'HH:MM'));
    axInset.YTick = linspace(zoomVMin, zoomVMax, 3);  % 3 evenly-spaced voltage ticks.
    % Format Y tick labels to exactly 2 decimal places for publication consistency.
    axInset.YTickLabel = arrayfun(@(v) sprintf('%.2f', v), axInset.YTick, 'UniformOutput', false);
    title(axInset, 'Zoom V', 'FontName', 'Times New Roman', 'FontSize', 8, 'FontWeight', 'bold');

    % Draw an outer frame that encloses the inset plot together with ticks
    % and title, so inset text is visually separated from ax3 labels.
    % Pass [] as the anchor so the manual vertical placement in insetPos is
    % preserved (otherwise the frame routine re-centers the inset to the
    % middle of ax3, overriding any custom Y offset set above).
    drawnow;
    insetFramePos = drawInsetOuterFrame(fig, axInset, []);

    % Bring the inset axes (and its frame, drawn just above) to the front
    % BEFORE the connectors so any final reflow happens first.
    uistack(axInset, 'top');

    % Force a final render pass so every axes' rendered pixel position
    % reflects all prior changes (zone arrows reserving top space, inset
    % creation, frame insertion, uistack).
    drawnow;

    % --- Vertical Delta-V arrow inside the voltage zoom inset ----------
    % Mirror of the Delta-I arrow drawn later inside the current inset.
    % Draw a strictly vertical double-headed arrow at x = 18:38:30
    % spanning from y1 = 3.70 V (initial) to y2 = 3.50 V (final), with a
    % '$\Delta V$' LaTeX label centered at the arrow's mid y-position and
    % placed to the LEFT of the arrow.
    deltaVArrowClock = duration(18,38,30);                                % time-of-day where the step occurs
    deltaVArrowTime  = targetDate + deltaVArrowClock;                     % full datetime on the target date
    deltaV_y1        = 3.71;                                              % initial voltage [V]
    deltaV_y2        = 3.60;                                              % final voltage   [V]
    % Convert (datetime, V) endpoints into figure-normalized coords. Using
    % the SAME deltaVArrowTime for both endpoints guarantees the arrow is
    % exactly vertical regardless of inset width.
    [xArrowFigV, yArrowFigV1] = dataToFigureNormalized(axInset, deltaVArrowTime, deltaV_y1);
    [~,          yArrowFigV2] = dataToFigureNormalized(axInset, deltaVArrowTime, deltaV_y2);
    % Draw the vertical double-headed arrow.
    deltaVArrow = annotation(fig, 'doublearrow', ...
        [xArrowFigV xArrowFigV], [yArrowFigV1 yArrowFigV2]);
    deltaVArrow.Color       = [0 0 0];
    deltaVArrow.LineWidth   = 1.0;
    deltaVArrow.Head1Length = 6; deltaVArrow.Head1Width = 6;
    deltaVArrow.Head2Length = 6; deltaVArrow.Head2Width = 6;
    % Label centered vertically on the arrow midpoint, just to its LEFT.
    labelBoxWV = 0.05;                                                    % textbox width in fig-norm units
    labelBoxHV = 0.025;                                                   % textbox height in fig-norm units
    labelGapV  = 0.006;                                                   % horizontal gap between label box and arrow
    labelXV = xArrowFigV - labelGapV - labelBoxWV;                        % right edge of box sits 'labelGapV' left of arrow
    labelYV = 0.5 * (yArrowFigV1 + yArrowFigV2);                          % midpoint of the two y-levels
    deltaVLabel = annotation(fig, 'textbox', ...
        [labelXV, labelYV - labelBoxHV/2, labelBoxWV, labelBoxHV], ...
        'String', '$\Delta V$', 'Interpreter', 'latex', ...
        'FontName', 'Times New Roman', 'FontSize', 9, ...
        'EdgeColor', 'none', 'BackgroundColor', 'none', ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
        'FitBoxToText', 'on');                                            %#ok<NASGU>

    % --- Horizontal dashed leader line at the lower arrow endpoint -----
    % Independent of the arrow itself: a dashed horizontal segment at the
    % "final" voltage level (deltaV_y2) running from deltaVLeaderXStart
    % (18:38:00) to deltaVLeaderXEnd (18:39:00). It crosses the arrow's
    % x (18:38:30) at exactly the bottom-arrow endpoint, marking the
    % post-step voltage level on the trace.
    deltaVLeaderXStartClock = duration(18,38,20);                          % left x of dashed line
    deltaVLeaderXEndClock   = duration(18,39,20);                          % right x of dashed line
    deltaVLeaderY           = deltaV_y2;                                  % y level [V] (change to deltaV_y1 for top instead)
    deltaVLeaderXStartTime  = targetDate + deltaVLeaderXStartClock;       % full datetime: line start
    deltaVLeaderXEndTime    = targetDate + deltaVLeaderXEndClock;         % full datetime: line end
    % Convert both endpoints into figure-normalized coords. Re-using the
    % same y for both ensures the line is perfectly horizontal.
    [xLeaderFigStart, yLeaderFig] = dataToFigureNormalized(axInset, deltaVLeaderXStartTime, deltaVLeaderY);
    [xLeaderFigEnd,   ~]          = dataToFigureNormalized(axInset, deltaVLeaderXEndTime,   deltaVLeaderY);
    deltaVLeader = annotation(fig, 'line', ...
        [xLeaderFigStart xLeaderFigEnd], [yLeaderFig yLeaderFig]);
    deltaVLeader.Color     = [0 0 0];
    deltaVLeader.LineStyle = '--';
    deltaVLeader.LineWidth = 0.8;                                         %#ok<NASGU>

    % --- R_RPT formula annotation to the right of the voltage inset ----
    % Place a LaTeX textbox just outside the right edge of the voltage
    % inset's OUTER frame (insetFramePos), vertically centered on the
    % frame's mid-height. Coordinates are figure-normalized.
    rRPTGap     = 0.014;                                                  % horizontal gap from frame right edge [fig-norm]
    rRPTBoxW    = 0.18;                                                   % textbox width  [fig-norm]
    rRPTBoxH    = 0.08;                                                   % textbox height [fig-norm]
    rRPTBoxX    = insetFramePos(1) + insetFramePos(3) + rRPTGap;          % left edge of textbox
    rRPTBoxY    = insetFramePos(2) + 0.5 * insetFramePos(4) - rRPTBoxH/2; % center on frame mid-height
    rRPTLabel = annotation(fig, 'textbox', ...
        [rRPTBoxX, rRPTBoxY, rRPTBoxW, rRPTBoxH], ...
        'String', '$R_{RPT} = \frac{\Delta V}{\Delta I}$', 'Interpreter', 'latex', ...
        'FontName', 'Times New Roman', 'FontSize', 10, ...
        'EdgeColor', 'none', 'BackgroundColor', 'none', ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');     %#ok<NASGU>
    drawnow;

    % --- Stable, race-free placement of box + connectors ---
    % Problem: tiledlayout can re-flow ax2 one more time after the inset
    % axes is created (display/export both can trigger another layout
    % pass). Any single snapshot of ax2's pixel position therefore goes
    % stale, and box + connectors end up locked to each other but offset
    % from the data.
    %
    % Solution: pin ax2's position to its current value so future reflows
    % cannot move it, then compute the box rectangle and the connector
    % start corners from the same fresh snapshot, then iteratively refresh
    % until ax2's pixel position no longer changes between drawnow calls.

    % Pin ax2 so subsequent reflows don't shift it. This requires reading
    % the rendered (true) inner position, then assigning it back in the
    % axes' own coordinate space (relative to its parent container).
    ax2.Units = 'normalized';
    pinnedPos = ax2.Position;  %#ok<NASGU>  (kept as defensive marker)
    % Same for ax1/ax3 so the whole stack stops drifting once we draw.
    ax1.Units = 'normalized'; ax1.Position = ax1.Position;
    ax2.Units = 'normalized'; ax2.Position = ax2.Position;
    ax3.Units = 'normalized'; ax3.Position = ax3.Position;
    drawnow;

    % Initial snapshot of figure-normalized box rect and connector ends.
    srcTL = axesDataRectToFigureNormalized(fig, ax2, ...
        boxTimeStart, boxTimeEnd, boxVMin, boxVMax);  % [x y w h]

    % --- Empirical nudge of the source (highlight) rectangle ---------------
    % MATLAB's ancestor-chain composition for the ax2 rectangle still leaves
    % the annotation slightly off the data in this layout. User-measured
    % offset: shift the box right by ~3 of the OLD box widths and down by
    % ~2 of the OLD box heights. We just doubled the box size, so to keep
    % the same absolute pixel offset the per-current-box multipliers must
    % be halved (3.0 -> 1.5 width, 2.0 -> 1.0 height).
    boxNudgeRight = 1.3;   % in units of (current) box width
    boxNudgeDown  = 1.3;   % in units of (current) box height
    srcTL(1) = srcTL(1) + boxNudgeRight * srcTL(3);
    srcTL(2) = srcTL(2) - boxNudgeDown  * srcTL(4);

    % Recompute corners after the nudge so connectors start at the new box.
    [srcTL_x, srcTL_y, srcBR_x, srcBR_y] = rectCorners(srcTL);

    % Top connector now lands on the TOP-RIGHT of the large voltage inset
    % (instead of TOP-LEFT) so both leader lines anchor to its right edge.
    dstTL_x = insetFramePos(1) + insetFramePos(3);
    dstTL_y = insetFramePos(2) + insetFramePos(4);
    dstBR_x = insetFramePos(1) + insetFramePos(3);
    dstBR_y = insetFramePos(2);

    % Create annotations once, store handles so we can refresh them.
    boxEdgeColor   = [0 0 0];       % black
    connectorColor = [0.35 0.35 0.35];
    hBox  = annotation(fig, 'rectangle', srcTL, ...
        'EdgeColor', boxEdgeColor, 'LineWidth', 0.5, 'LineStyle', '-', ...
        'FaceColor', 'none');
    hL1 = annotation(fig, 'line', [srcTL_x dstTL_x], [srcTL_y dstTL_y], ...
        'Color', connectorColor, 'LineWidth', 0.8);
    hL2 = annotation(fig, 'line', [srcBR_x dstBR_x], [srcBR_y dstBR_y], ...
        'Color', connectorColor, 'LineWidth', 0.8);

    % Iterate: force redraw, re-resolve ax2 pixel position, update box +
    % connectors. Stop when no movement is detected (typical: 1-2 passes).
    prevSrc = srcTL;
    for refreshPass = 1:5
        drawnow;
        srcTLNew = axesDataRectToFigureNormalized(fig, ax2, ...
            boxTimeStart, boxTimeEnd, boxVMin, boxVMax);
        % Re-apply the same empirical nudge so the refresh stays consistent
        % with the initial placement instead of snapping back to the raw
        % computed rect.
        srcTLNew(1) = srcTLNew(1) + boxNudgeRight * srcTLNew(3);
        srcTLNew(2) = srcTLNew(2) - boxNudgeDown  * srcTLNew(4);
        if max(abs(srcTLNew - prevSrc)) < 1e-4
            break;  % converged
        end
        prevSrc = srcTLNew;
        [tx, ty, bx, by] = rectCorners(srcTLNew);
        hBox.Position = srcTLNew;
        hL1.X = [tx dstTL_x]; hL1.Y = [ty dstTL_y];
        hL2.X = [bx dstBR_x]; hL2.Y = [by dstBR_y];
    end

    % =====================================================================
    % CURRENT ZOOM INSET (placed directly above the voltage zoom inset)
    % ---------------------------------------------------------------------
    % Reuses the SAME time window (timeZoom / zoomStartTime / zoomEndTime)
    % already computed for the voltage inset, but plots the current signal
    % instead. A small highlight rectangle is added on ax1 (current panel)
    % and two diagonal connector lines link it to the new inset's frame,
    % following the exact same stabilize-iterate pattern as the voltage
    % inset so layout reflows cannot leave the box/connectors misaligned.
    % =====================================================================

    % --- Tunable variables for the new CURRENT zoom inset --------------
    % These are intentionally grouped together so they are easy to find
    % and adjust. Mirror the voltage tuning variables defined earlier
    % (insetWidth, insetHeight, timeScale, voltScale, boxNudgeRight,
    % boxNudgeDown).
    currentInsetWidth               = insetWidth;          % large inset width  (fraction of ax3 width) - matched to voltage inset
    currentInsetHeight              = insetHeight;         % large inset height (fraction of ax3 height) - matched to voltage inset
    currentInsetXOffset             = 0.00;                % horizontal shift of large inset relative to voltage inset frame (figure-normalized)
    currentInsetYOffsetAboveVoltage = 0.04;                % vertical gap above voltage inset frame (figure-normalized)
    currentZoomYPaddingFraction     = 0.10;                % padding added above/below current data range in the large inset
    currentBoxTimeScale             = timeScale;           % horizontal expansion of small ax1 rectangle around data span
    currentBoxYScale                = 1.6;                 % vertical expansion of small ax1 rectangle around data span
    currentBoxNudgeRight            = boxNudgeRight;       % manual x-correction of small ax1 rectangle (units of its own width)
    currentBoxNudgeDown             = -0.2;        % manual y-correction of small ax1 rectangle (units of its own height)
    currentConnectorColor           = [0.35 0.35 0.35];    % grey leader lines
    currentBoxEdgeColor             = [0 0 0];             % black small-rectangle edge

    % --- Extract current data over the SAME zoom mask used for voltage --
    % zoomMask was built earlier from the voltage inset tacurrentBoxYScalerget window, so
    % indexing current with the same mask guarantees the time axes match.
    currentZoom = current(zoomMask);

    % --- Compute padded y-limits for the large current inset ------------
    % Take the raw data range, then expand symmetrically by
    % currentZoomYPaddingFraction so the trace does not touch the borders.
    currentZoomYMin_raw = min(currentZoom);
    currentZoomYMax_raw = max(currentZoom);
    currentZoomYRange   = currentZoomYMax_raw - currentZoomYMin_raw;
    if currentZoomYRange <= 0
        % Degenerate flat-current case: fall back to a small absolute pad.
        currentZoomYRange = max(abs([currentZoomYMin_raw, currentZoomYMax_raw, 1]));
    end
    currentZoomYMin = currentZoomYMin_raw - currentZoomYPaddingFraction * currentZoomYRange;
    currentZoomYMax = currentZoomYMax_raw + currentZoomYPaddingFraction * currentZoomYRange;

    % --- Compute the large current-inset position above the voltage one -
    % Align the current inset's plot box exactly above the voltage inset's
    % plot box. We anchor to insetPos (the voltage axes' Position) rather
    % than insetFramePos (which includes TightInset margins for ticks and
    % title), so the two plot rectangles share identical x-position and
    % width. Vertical placement uses the OUTER voltage frame so the new
    % inset sits clear of the voltage inset's title/ticks.
    currentInsetPos = [ ...
        insetPos(1) + currentInsetXOffset, ...
        insetFramePos(2) + insetFramePos(4) + currentInsetYOffsetAboveVoltage, ...
        insetPos(3), ...
        currentInsetHeight * ax3Pos(4)];

    % --- Create the current inset axes with publication styling --------
    % Solid white background so anything underneath (ax2 trace, gridlines,
    % shading) is fully hidden behind the zoomed view.
    axInsetCurrent = axes('Parent', fig, 'Position', currentInsetPos);
    axInsetCurrent.Color = [1 1 1];

    % Plot the zoomed current trace in the same dark-blue used elsewhere.
    plot(axInsetCurrent, timeZoom, currentZoom, 'Color', darkblue, 'LineWidth', 2.5);

    % Match the visual style of the voltage inset (font/size/grid/box).
    axInsetCurrent.FontName      = 'Times New Roman';
    axInsetCurrent.FontSize      = 8;
    axInsetCurrent.LineWidth     = 1.2;
    axInsetCurrent.Box           = 'on';
    axInsetCurrent.XGrid         = 'on';
    axInsetCurrent.YGrid         = 'on';
    axInsetCurrent.GridLineStyle = '--';
    axInsetCurrent.GridAlpha     = 0.5;
    axInsetCurrent.GridColor     = [0.7 0.7 0.7];

    % Lock the inset axis to the shared zoom window and the padded y-range.
    xlim(axInsetCurrent, [zoomStartTime zoomEndTime]);
    ylim(axInsetCurrent, [currentZoomYMin currentZoomYMax]);

    % Use 3 evenly-spaced ticks per axis to keep the inset readable.
    xTicksCurrent = zoomStartTime + (zoomEndTime - zoomStartTime) * [0, 0.5, 1];
    axInsetCurrent.XTick      = xTicksCurrent;
    axInsetCurrent.XTickLabel = cellstr(datestr(xTicksCurrent, 'HH:MM'));
    axInsetCurrent.YTick      = linspace(currentZoomYMin, currentZoomYMax, 3);
    % Format Y tick labels to whole numbers for publication consistency.
    axInsetCurrent.YTickLabel = arrayfun(@(v) sprintf('%.0f', v), axInsetCurrent.YTick, 'UniformOutput', false);

    % Title placed above the inset for symmetry with the voltage inset.
    title(axInsetCurrent, 'Zoom I', 'FontName', 'Times New Roman', 'FontSize', 8, 'FontWeight', 'bold');

    % --- Align outer frame X with the voltage inset's outer frame -------
    % insetPos (used for both inner plot boxes) only guarantees that the
    % INNER plot rectangles share x and width. The visible black FRAME is
    % offset on each side by axes' TightInset (room for Y tick labels and
    % title). Current Y ticks ("-58.00" ...) are wider than voltage ticks
    % ("3.58" ...), so the left TightInset margins differ and the two
    % outer frames end up offset horizontally. We fix this by:
    %   1) measuring the current inset's TightInset after a drawnow,
    %   2) shifting the inset axes so its frame's LEFT edge matches the
    %      voltage frame's left edge (insetFramePos(1)),
    %   3) adjusting its width so the RIGHT edge also matches.
    drawnow;
    tiCurrent = axInsetCurrent.TightInset;
    newLeft  = insetFramePos(1) + tiCurrent(1);                          % inner-axes left so frame.left == voltage frame.left
    newRight = insetFramePos(1) + insetFramePos(3) - tiCurrent(3);       % inner-axes right so frame.right == voltage frame.right
    axInsetCurrent.Position(1) = newLeft;
    axInsetCurrent.Position(3) = max(newRight - newLeft, 0.01);          % guard against negative width

    % Draw the same outer white frame + black border around plot + ticks.
    drawnow;
    insetFramePosCurrent = drawInsetOuterFrame(fig, axInsetCurrent, []);

    % Push the new inset above other elements so its ticks/title are visible.
    uistack(axInsetCurrent, 'top');
    drawnow;

    % --- Vertical Delta-I arrow inside the current zoom inset ----------
    % Draw a strictly vertical double-headed arrow at x = 18:38:30
    % spanning from y1 = 5.69 A (initial) to y2 = -63.83 A (final), with
    % a '$\Delta I$' LaTeX label centered at the arrow's mid y-position.
    deltaIArrowClock = duration(18,38,30);                                % time-of-day where the step occurs
    deltaIArrowTime  = targetDate + deltaIArrowClock;                     % full datetime on the target date
    deltaI_y1        =   0.0;                                            % initial current [A]
    deltaI_y2        = -63.83;                                            % final current   [A]
    % Convert (datetime, A) endpoints into figure-normalized coordinates
    % because annotation() lives in figure space, not axes space. Using
    % the SAME deltaIArrowTime for both endpoints guarantees the arrow
    % is exactly vertical regardless of inset width.
    [xArrowFig, yArrowFig1] = dataToFigureNormalized(axInsetCurrent, deltaIArrowTime, deltaI_y1);
    [~,         yArrowFig2] = dataToFigureNormalized(axInsetCurrent, deltaIArrowTime, deltaI_y2);
    % Draw the vertical double-headed arrow.
    deltaIArrow = annotation(fig, 'doublearrow', ...
        [xArrowFig xArrowFig], [yArrowFig1 yArrowFig2]);
    deltaIArrow.Color       = [0 0 0];                                    % solid black for print clarity
    deltaIArrow.LineWidth   = 1.0;
    deltaIArrow.Head1Length = 6; deltaIArrow.Head1Width = 6;
    deltaIArrow.Head2Length = 6; deltaIArrow.Head2Width = 6;
    % Label centered vertically on the arrow midpoint, just to its LEFT.
    labelBoxW = 0.05;                                                     % textbox width in fig-norm units
    labelBoxH = 0.025;                                                    % textbox height in fig-norm units
    labelGap  = 0.006;                                                    % horizontal gap between label box and arrow
    labelX = xArrowFig - labelGap - labelBoxW;                            % right edge of box sits 'labelGap' left of arrow
    labelY = 0.5 * (yArrowFig1 + yArrowFig2);                             % midpoint of the two y-levels
    deltaILabel = annotation(fig, 'textbox', ...
        [labelX, labelY - labelBoxH/2, labelBoxW, labelBoxH], ...
        'String', '$\Delta I$', 'Interpreter', 'latex', ...
        'FontName', 'Times New Roman', 'FontSize', 9, ...
        'EdgeColor', 'none', 'BackgroundColor', 'none', ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
        'FitBoxToText', 'on');                                            %#ok<NASGU>
    drawnow;

    % --- Small highlight rectangle on the CURRENT panel (ax1) ----------
    % Independent clock window for the small ax1 box so it is decoupled
    % from targetStartClock / targetEndClock (inset content window).
    currentBoxTargetStartClock = boxTargetStartClock;   % default: follow voltage small-box window
    currentBoxTargetEndClock   = boxTargetEndClock;

    % Mask for the current small-box clock window. Note: we deliberately
    % do NOT apply the voltage band (zoomVMin/zoomVMax) here because that
    % filter is meaningless for current; we just use date + clock.
    boxCurrentMask = (timeWithGaps >= dateStart) & (timeWithGaps <= dateEnd) & ...
                     (timeOfDay >= currentBoxTargetStartClock) & ...
                     (timeOfDay <= currentBoxTargetEndClock) & ~isnat(timeWithGaps);
    if sum(boxCurrentMask) == 0
        boxCurrentMask = zoomMask;  % fallback so something renders
    end
    timeBoxCurrent    = timeWithGaps(boxCurrentMask);
    currentBoxData    = current(boxCurrentMask);

    % Start from the actual data extent inside the small-box window.
    boxCurrentTimeStart = min(timeBoxCurrent);
    boxCurrentTimeEnd   = max(timeBoxCurrent);
    boxCurrentMin       = min(currentBoxData);
    boxCurrentMax       = max(currentBoxData);

    % Expand the rectangle around its center using the same x-expansion
    % factor as the voltage box, plus an independent y-expansion factor
    % because current ranges are very different from voltage ranges.
    tMidCurrent  = boxCurrentTimeStart + (boxCurrentTimeEnd - boxCurrentTimeStart) / 2;
    tHalfCurrent = (boxCurrentTimeEnd - boxCurrentTimeStart) / 2;
    boxCurrentTimeStart = tMidCurrent - currentBoxTimeScale * tHalfCurrent;
    boxCurrentTimeEnd   = tMidCurrent + currentBoxTimeScale * tHalfCurrent;

    cMid  = (boxCurrentMin + boxCurrentMax) / 2;
    cHalf = max((boxCurrentMax - boxCurrentMin) / 2, 0.5);  % guard against flat data
    boxCurrentMin = cMid - currentBoxYScale * cHalf;
    boxCurrentMax = cMid + currentBoxYScale * cHalf;

    % Initial conversion of the box rectangle from ax1 data-space into
    % figure-normalized coordinates so we can render it as an annotation
    % (annotations live in figure space, not axes space).
    srcTLC = axesDataRectToFigureNormalized(fig, ax1, ...
        boxCurrentTimeStart, boxCurrentTimeEnd, boxCurrentMin, boxCurrentMax);

    % Apply the same empirical pixel-offset nudge in units of the current
    % rect size so the highlight stays visually glued to the data when
    % MATLAB reflows the tiledlayout one more time after annotation.
    srcTLC(1) = srcTLC(1) + currentBoxNudgeRight * srcTLC(3);
    srcTLC(2) = srcTLC(2) - currentBoxNudgeDown  * srcTLC(4);

    % Resolve the four corners used to anchor the diagonal connectors.
    % Top connector now lands on the TOP-RIGHT of the large current inset
    % (instead of TOP-LEFT) so it points to the right edge of the frame.
    [srcTLC_x, srcTLC_y, srcBRC_x, srcBRC_y] = rectCorners(srcTLC);
    dstTLC_x = insetFramePosCurrent(1) + insetFramePosCurrent(3);
    dstTLC_y = insetFramePosCurrent(2) + insetFramePosCurrent(4);
    dstBRC_x = insetFramePosCurrent(1) + insetFramePosCurrent(3);
    dstBRC_y = insetFramePosCurrent(2);

    % Create the small rectangle and the two leader lines once; we will
    % refresh their Position/X/Y inside the stabilize loop below.
    hBoxCurrent = annotation(fig, 'rectangle', srcTLC, ...
        'EdgeColor', currentBoxEdgeColor, 'LineWidth', 0.5, 'LineStyle', '-', ...
        'FaceColor', 'none');
    hL1C = annotation(fig, 'line', [srcTLC_x dstTLC_x], [srcTLC_y dstTLC_y], ...
        'Color', currentConnectorColor, 'LineWidth', 0.8);
    hL2C = annotation(fig, 'line', [srcBRC_x dstBRC_x], [srcBRC_y dstBRC_y], ...
        'Color', currentConnectorColor, 'LineWidth', 0.8);

    % Stabilize-iterate: same idea as for the voltage rectangle. Force a
    % drawnow, re-resolve ax1's figure-normalized rect, re-apply the
    % nudge, and stop once nothing moves anymore.
    prevSrcCurrent = srcTLC;
    for refreshPassCurrent = 1:5
        drawnow;
        srcTLCNew = axesDataRectToFigureNormalized(fig, ax1, ...
            boxCurrentTimeStart, boxCurrentTimeEnd, boxCurrentMin, boxCurrentMax);
        srcTLCNew(1) = srcTLCNew(1) + currentBoxNudgeRight * srcTLCNew(3);
        srcTLCNew(2) = srcTLCNew(2) - currentBoxNudgeDown  * srcTLCNew(4);
        if max(abs(srcTLCNew - prevSrcCurrent)) < 1e-4
            break;  % converged
        end
        prevSrcCurrent = srcTLCNew;
        [txC, tyC, bxC, byC] = rectCorners(srcTLCNew);
        hBoxCurrent.Position = srcTLCNew;
        hL1C.X = [txC dstTLC_x]; hL1C.Y = [tyC dstTLC_y];
        hL2C.X = [bxC dstBRC_x]; hL2C.Y = [byC dstBRC_y];
    end

end

% ---- C_RPT integration-window annotation on ax1 (current panel) ----------
% Draw a horizontal double-arrow at I = -50 A spanning Apr 24 -> Apr 26,
% with 'a' / 'b' tick labels at the endpoints and a LaTeX caption showing
% C_RPT = \int_a^b I dt above the arrow.
drawnow;  % settle layout before reading ax1 position

% Endpoints in ax1 data space.
crptY      = -60;                              % current level (A)
crptXStart = datetime(2024, 4, 23, 10, 00, 0);   % left endpoint  -> labelled 'a'
crptXEnd   = datetime(2024, 4, 25, 17, 0, 0); % right endpoint -> labelled 'b'

% Convert data-space endpoints to figure-normalized coordinates using the
% same ancestor-chain helper that handles the tiledlayout correctly.
[xA_fig, yA_fig] = dataToFigureNormalized(ax1, crptXStart, crptY);
[xB_fig, yB_fig] = dataToFigureNormalized(ax1, crptXEnd,   crptY);

% Double-headed arrow (figure annotation lives in figure-normalized coords).
annotation(fig, 'doublearrow', [xA_fig xB_fig], [yA_fig yB_fig], ...
    'Color', [0 0 0], 'LineWidth', 1.0, ...
    'Head1Style', 'vback2', 'Head2Style', 'vback2', ...
    'Head1Length', 8, 'Head2Length', 8, ...
    'Head1Width',  8, 'Head2Width',  8);

% Small 'a' label just below the left endpoint of the arrow.
labelBoxW = 0.025;   % textbox width (figure-normalized)
labelBoxH = 0.025;   % textbox height (figure-normalized)
labelDy   = -0.020;  % vertical offset below arrow for a/b labels
annotation(fig, 'textbox', ...
    [xA_fig - labelBoxW/2, yA_fig + labelDy - labelBoxH/2, labelBoxW, labelBoxH], ...
    'String', '$a$', 'Interpreter', 'latex', ...
    'EdgeColor', 'none', 'FitBoxToText', 'off', ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'FontName', 'Times New Roman', 'FontSize', 11);

% Matching 'b' label just below the right endpoint.
annotation(fig, 'textbox', ...
    [xB_fig - labelBoxW/2, yB_fig + labelDy - labelBoxH/2, labelBoxW, labelBoxH], ...
    'String', '$b$', 'Interpreter', 'latex', ...
    'EdgeColor', 'none', 'FitBoxToText', 'off', ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'FontName', 'Times New Roman', 'FontSize', 11);

% LaTeX equation caption centred above the arrow.
eqBoxW = 0.20;     % textbox width (figure-normalized)
eqBoxH = 0.035;    % textbox height (figure-normalized)
eqDy   = 0.035;    % vertical offset above arrow for equation
xMid_fig = (xA_fig + xB_fig) / 2;
yMid_fig = (yA_fig + yB_fig) / 2;
annotation(fig, 'textbox', ...
    [xMid_fig - eqBoxW/2, yMid_fig + eqDy - eqBoxH/2, eqBoxW, eqBoxH], ...
    'String', '$C_{RPT} = \int_a^b I\,dt$', 'Interpreter', 'latex', ...
    'EdgeColor', 'none', 'FitBoxToText', 'off', ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'FontName', 'Times New Roman', 'FontSize', 12);

% crptXStart = datetime(2024, 4, 24);   % left  end of arrow ('a')
crptXEnd   = datetime(2024, 4, 26);   % right end of arrow ('b')crptXStart = datetime(2024, 4, 24);   % left  end of arrow ('a')
crptXEnd   = datetime(2024, 4, 26);   % right end of arrow ('b')Export RPC figure as vector PDF in the repo-level pngs folder, following
% the same publication export pattern used by the combined characterization figure.
drawnow;
scriptDir = fileparts(mfilename('fullpath'));
saveDir = fullfile(scriptDir, '..', 'JournalScripts', 'pngs');   % R-022: single figure output dir
if ~exist(saveDir, 'dir')
    mkdir(saveDir);
end
pdfFile = fullfile(saveDir, ['NextBMS_ReferencePerformanceCycle.pdf']); %#ok<NASGU>
% PDF export temporarily disabled while iterating on the figure layout.
exportgraphics(fig, pdfFile, 'ContentType', 'vector');
fprintf('RPC PDF saved: %s\n', pdfFile);

end

function addInsetConnectorLines(fig, sourceFramePos, destinationFramePos)
%ADDINSETCONNECTORLINES Draw two diagonal connector lines between the zoom-box
% corners and the matching corners of the inset axes.
%
% Line 1: top-left corner of the zoom rectangle  → top-left corner of the inset.
% Line 2: bottom-right corner of the zoom rectangle → bottom-right corner of the inset.

% Source rectangle corners in normalized figure coordinates.
srcTL_x = sourceFramePos(1);
srcTL_y = sourceFramePos(2) + sourceFramePos(4);
srcBR_x = sourceFramePos(1) + sourceFramePos(3);
srcBR_y = sourceFramePos(2);

% Destination rectangle corners in normalized figure coordinates.
insetTL_x = destinationFramePos(1);
insetTL_y = destinationFramePos(2) + destinationFramePos(4);
insetBR_x = destinationFramePos(1) + destinationFramePos(3);
insetBR_y = destinationFramePos(2);

% Draw the two thin grey leader lines connecting matching diagonal corners.
annotation(fig, 'line', [srcTL_x insetTL_x], [srcTL_y insetTL_y], ...
    'Color', [0.35 0.35 0.35], 'LineWidth', 0.8);
annotation(fig, 'line', [srcBR_x insetBR_x], [srcBR_y insetBR_y], ...
    'Color', [0.35 0.35 0.35], 'LineWidth', 0.8);
end

function sourcePos = drawSourceZoomFrame(fig, sourceAxes, xStart, xEnd, yMin, yMax, frameColor)
%DRAWSOURCEZOOMFRAME Draw a dashed highlight rectangle directly in the source
% axes using DATA coordinates, then report its figure-normalized footprint.
%
% Drawing as an axes child guarantees the rectangle stays glued to the data,
% independent of tiledlayout re-flows triggered by zone arrows/labels.

% Convert datetime inputs to the axes' ruler-native form.
if isdatetime(sourceAxes.XLim)
    xStartPlot = datetime(xStart);
    xEndPlot   = datetime(xEnd);
else
    xStartPlot = xStart;
    xEndPlot   = xEnd;
end

% Draw the highlight rectangle in data coordinates as a hold-safe patch so
% it lines up perfectly with the voltage trace at the same (t, V) range.
prevHold = ishold(sourceAxes);
hold(sourceAxes, 'on');
hRect = plot(sourceAxes, ...
    [xStartPlot xEndPlot xEndPlot xStartPlot xStartPlot], ...
    [yMin yMin yMax yMax yMin], ...
    'LineStyle', '--', 'Color', frameColor, 'LineWidth', 1.5, ...
    'HandleVisibility', 'off'); %#ok<NASGU>
if ~prevHold
    hold(sourceAxes, 'off');
end

% Force a render pass so the next coordinate readout reflects the actual
% on-screen position (tiledlayout can re-flow after annotations are added).
drawnow;

% Compute the rectangle's footprint in figure-normalized coordinates for
% the connector lines. Read the axes' true pixel rectangle relative to the
% figure (descending through any tiledlayout containers), then map data ->
% normalized using the rendered XLim/YLim.
axPixelPos = getpixelposition(sourceAxes, true);
figOldUnits = fig.Units;
fig.Units = 'pixels';
figPixelPos = fig.Position;
fig.Units = figOldUnits;

axPosFigNorm = [ ...
    axPixelPos(1) / figPixelPos(3), ...
    axPixelPos(2) / figPixelPos(4), ...
    axPixelPos(3) / figPixelPos(3), ...
    axPixelPos(4) / figPixelPos(4) ];

xLim = sourceAxes.XLim;
yLim = sourceAxes.YLim;
if isdatetime(xLim)
    xLimNum = datenum(xLim);
    xS = datenum(xStartPlot);
    xE = datenum(xEndPlot);
else
    xLimNum = xLim;
    xS = xStartPlot;
    xE = xEndPlot;
end

xLeftN  = axPosFigNorm(1) + ((xS - xLimNum(1)) / (xLimNum(2) - xLimNum(1))) * axPosFigNorm(3);
xRightN = axPosFigNorm(1) + ((xE - xLimNum(1)) / (xLimNum(2) - xLimNum(1))) * axPosFigNorm(3);
yBotN   = axPosFigNorm(2) + ((yMin - yLim(1)) / (yLim(2) - yLim(1))) * axPosFigNorm(4);
yTopN   = axPosFigNorm(2) + ((yMax - yLim(1)) / (yLim(2) - yLim(1))) * axPosFigNorm(4);

sourcePos = [min(xLeftN, xRightN), min(yBotN, yTopN), ...
             abs(xRightN - xLeftN), abs(yTopN - yBotN)];
end

function framePos = drawInsetOuterFrame(fig, insetAxes, anchorAxesPos)
%DRAWINSETOUTERFRAME Draw a rectangle around the full inset footprint.
% The frame includes the plot box plus ticks and title by using TightInset.

insetPos = insetAxes.Position;
ti = insetAxes.TightInset;

framePos = [
    insetPos(1) - ti(1), ...
    insetPos(2) - ti(2), ...
    insetPos(3) + ti(1) + ti(3), ...
    insetPos(4) + ti(2) + ti(4) ...
];

% Re-center the full framed inset vertically to the middle of the anchor
% axes (ax3), then update inset position so frame and inset move together.
if nargin >= 3 && ~isempty(anchorAxesPos)
    targetCenterY = anchorAxesPos(2) + 0.5 * anchorAxesPos(4);
    currentCenterY = framePos(2) + 0.5 * framePos(4);
    deltaCenterY = targetCenterY - currentCenterY;

    insetPos(2) = insetPos(2) + deltaCenterY;
    insetAxes.Position = insetPos;

    % Recompute the frame from the updated inset position so tick/title
    % margins remain accurate after shifting.
    drawnow;
    insetPos = insetAxes.Position;
    ti = insetAxes.TightInset;
    framePos = [
        insetPos(1) - ti(1), ...
        insetPos(2) - ti(2), ...
        insetPos(3) + ti(1) + ti(3), ...
        insetPos(4) + ti(2) + ti(4) ...
    ];
end

% Keep the frame inside normalized figure bounds.
framePos(1) = max(0.0, framePos(1));
framePos(2) = max(0.0, framePos(2));
framePos(3) = min(framePos(3), 1.0 - framePos(1));
framePos(4) = min(framePos(4), 1.0 - framePos(2));

% Solid-white background that covers the FULL frame footprint (plot box +
% tick / title margins). We use a hidden background axes parented to the
% figure rather than an annotation rectangle so we can control z-order.
% Important: we must NOT stack this to the very bottom of the figure's
% children, because that would put it behind ax3 (the temperature plot
% that the inset sits on top of) and the temperature line would still
% bleed through. Instead, stack it just below the inset axes: above ax3
% and below the inset / its plot line / ticks / title.
bgAx = axes('Parent', fig, 'Position', framePos, ...
    'Color', [1 1 1], 'XColor', 'none', 'YColor', 'none', ...
    'XTick', [], 'YTick', [], 'Box', 'off', 'HitTest', 'off', ...
    'HandleVisibility', 'off');
% First push bg to top so it is above ax3, then push inset to top so the
% inset ends up above bg. Net result: bg covers ax3 over the frame area,
% and the inset (curve, ticks, title) remains visible on top of the
% white bg.
uistack(bgAx, 'top');
uistack(insetAxes, 'top');

% Black border on top of everything to outline the white box.
annotation(fig, 'rectangle', framePos, ...
    'EdgeColor', [0 0 0], 'LineWidth', 0.9, 'LineStyle', '-', ...
    'FaceColor', 'none');
end

function [xNorm, yNorm] = dataToFigureNormalized(ax, xData, yData)
%DATATOFIGURENORMALIZED Convert axes data coordinates into figure-normalized coordinates.
% This is needed because annotation objects live in figure space rather than axes space.
%
% Why we DO NOT use getpixelposition(ax, true): when the axes lives in a
% tiledlayout that has a custom OuterPosition (used here to reserve top
% headroom for zone arrows), getpixelposition has been observed to return
% an axes pixel rect that does NOT match where MATLAB actually renders the
% axes. The result is annotations drawn offset from the data they should
% mark. To get the rect MATLAB actually uses internally, we explicitly
% walk the ancestor chain (axes -> tiledlayout/panel -> ... -> figure),
% composing normalized Position rectangles at every level.

axPos = composedFigureNormalizedRect(ax);

% Convert datetime limits and inputs to numeric values when needed.
xLim = ax.XLim;
if isdatetime(xLim)
    xLim = datenum(xLim);
end
if isdatetime(xData)
    xData = datenum(xData);
end

% Map the x value from data space into the figure-normalized axes rectangle.
xNorm = axPos(1) + ((xData - xLim(1)) ./ (xLim(2) - xLim(1))) * axPos(3);

% Map the y value from data space into the figure-normalized axes rectangle.
yLim = ax.YLim;
yNorm = axPos(2) + ((yData - yLim(1)) ./ (yLim(2) - yLim(1))) * axPos(4);
end

function rect = composedFigureNormalizedRect(obj)
%COMPOSEDFIGURENORMALIZEDRECT Walk the ancestor chain and compose
% normalized Position rectangles to yield the object's true rect relative
% to the figure, in normalized units. Each container above the object is
% expressed in normalized units of ITS parent.

% Start with the object's own Position in its parent's normalized space.
rect = readNormalizedPosition(obj);

% Walk upward until we hit the figure.
parent = obj.Parent;
while ~isempty(parent) && ~isa(parent, 'matlab.ui.Figure')
    parentRect = readNormalizedPosition(parent);
    rect = [ ...
        parentRect(1) + rect(1) * parentRect(3), ...
        parentRect(2) + rect(2) * parentRect(4), ...
        rect(3) * parentRect(3), ...
        rect(4) * parentRect(4) ];
    parent = parent.Parent;
end
end

function pos = readNormalizedPosition(h)
%READNORMALIZEDPOSITION Return h.Position in normalized units relative to
% its parent, restoring the original Units afterwards.
oldUnits = h.Units;
cleaner = onCleanup(@() set(h, 'Units', oldUnits));
h.Units = 'normalized';
pos = h.Position;
% tiledlayout objects use OuterPosition as their "envelope"; their
% effective inner rectangle for child axes is .InnerPosition. Use the
% inner one when available so the composed rect matches what MATLAB lays
% children inside.
if isprop(h, 'InnerPosition') && isa(h, 'matlab.graphics.layout.TiledChartLayout')
    pos = h.InnerPosition;
end
end

function rectPos = axesDataRectToFigureNormalized(fig, ax, xStart, xEnd, yMin, yMax) %#ok<INUSL>
%AXESDATARECTTOFIGURENORMALIZED Return [x y w h] of a data-space rectangle
% expressed in figure-normalized coordinates, evaluated against the axes'
% currently rendered position and limits. Call AFTER drawnow so the result
% reflects any tiledlayout re-flow.

[xL, yB] = dataToFigureNormalized(ax, xStart, yMin);
[xR, yT] = dataToFigureNormalized(ax, xEnd, yMax);

rectPos = [min(xL, xR), min(yB, yT), abs(xR - xL), abs(yT - yB)];
end

function [tlX, tlY, brX, brY] = rectCorners(r)
%RECTCORNERS Return top-left and bottom-right corners of a [x y w h] rect.
tlX = r(1);
tlY = r(2) + r(4);
brX = r(1) + r(3);
brY = r(2);
end

function [xData, yData] = figureNormalizedToAxesData(ax, xNorm, yNorm)
%FIGURENORMALIZEDTOAXESDATA Inverse of dataToFigureNormalized.
% Projects a figure-normalized point into the axes' data coordinate space,
% using the axes' currently rendered pixel position and limits. Returns
% xData as datetime when the axes' XAxis is datetime, otherwise numeric.

% Resolve the axes' rendered position in figure-normalized coordinates.
axPixelPos = getpixelposition(ax, true);
fig = ancestor(ax, 'figure');
figOldUnits = fig.Units;
fig.Units = 'pixels';
figPixelPos = fig.Position;
fig.Units = figOldUnits;
axPos = [ ...
    axPixelPos(1) / figPixelPos(3), ...
    axPixelPos(2) / figPixelPos(4), ...
    axPixelPos(3) / figPixelPos(3), ...
    axPixelPos(4) / figPixelPos(4) ];

% Map x: figure-normalized -> ax data (numeric or datenum).
xLim = ax.XLim;
xIsDatetime = isdatetime(xLim);
if xIsDatetime
    xLimNum = datenum(xLim);
else
    xLimNum = xLim;
end
xDataNum = xLimNum(1) + ((xNorm - axPos(1)) ./ axPos(3)) * (xLimNum(2) - xLimNum(1));
if xIsDatetime
    xData = datetime(xDataNum, 'ConvertFrom', 'datenum');
else
    xData = xDataNum;
end

% Map y: figure-normalized -> ax data (numeric).
yLim = ax.YLim;
yData = yLim(1) + ((yNorm - axPos(2)) ./ axPos(4)) * (yLim(2) - yLim(1));
end
