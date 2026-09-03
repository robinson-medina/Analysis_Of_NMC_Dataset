function createGraphicalAbstractMethodsFigure(pngsDir, dataPaperFiguresDir)
%CREATEGRAPHICALABSTRACTMETHODSFIGURE Generate the paper graphical abstract.
% Summary: Builds a three-column Methods graphical abstract with minimal text.
% Author: GitHub Copilot
% Date: 2026-08-19
% Inputs/Outputs: pngsDir and dataPaperFiguresDir receive PDF/PNG outputs.

if ~exist(pngsDir, 'dir')
    mkdir(pngsDir);
end
if ~exist(dataPaperFiguresDir, 'dir')
    mkdir(dataPaperFiguresDir);
end

rng(7);

navy = [7 33 79] ./ 255;
blue = [0 70 150] ./ 255;
cyan = [0 151 170] ./ 255;
green = [12 150 74] ./ 255;
red = [215 45 45] ./ 255;
orange = [230 128 28] ./ 255;
purple = [123 76 160] ./ 255;
grey = [88 98 110] ./ 255;
lightGrey = [238 242 247] ./ 255;
lineGrey = [192 204 220] ./ 255;
ink = [25 30 40] ./ 255;

fig = figure('Units', 'centimeters', 'Position', [2 2 31 17.4], ...
    'Color', 'w', 'Renderer', 'painters');
ax = axes(fig, 'Position', [0 0 1 1], 'XLim', [0 1], 'YLim', [0 1], ...
    'Visible', 'off');
hold(ax, 'on');

rectangle(ax, 'Position', [0 0 1 1], 'FaceColor', 'w', 'EdgeColor', 'none');
rectangle(ax, 'Position', [0 0 1 0.18], 'FaceColor', [0.97 0.985 1.00], 'EdgeColor', 'none');

text(ax, 0.5, 0.965, {'Characterization, ageing and post-mortem dataset'; ...
    'of commercial 58Ah prismatic NMC cells'}, 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'top', 'FontName', 'Times New Roman', 'FontSize', 21, ...
    'FontWeight', 'bold', 'Color', navy, 'Clipping', 'off');

laneX = [0.175 0.500 0.825];
laneW = 0.255;
for k = 1:2
    plot(ax, [0.335*k 0.335*k], [0.165 0.865], ':', 'Color', lineGrey, 'LineWidth', 1.0);
end

laneTitles = {'Post-mortem', 'Characterisation', 'Ageing'};
laneSub = {'teardown + half-cells', 'protocol matrix', 'accelerated campaign'};
laneColors = [cyan; blue; red];
for k = 1:3
    drawLaneHeader(ax, laneX(k), 0.835, k, laneTitles{k}, laneSub{k}, laneColors(k, :), navy);
end

% Column 1: post-mortem and half-cell measurements.
x = laneX(1);
drawCell(ax, x - 0.075, 0.715, 0.72, navy, blue);
drawArrow(ax, x - 0.025, 0.715, x + 0.035, 0.715, navy, 1.5);
drawOpenedCell(ax, x + 0.080, 0.715, 0.86, navy, cyan);
text(ax, x, 0.655, 'teardown', 'HorizontalAlignment', 'center', 'FontName', 'Times New Roman', ...
    'FontSize', 15, 'FontWeight', 'bold', 'Color', ink);

drawMicrographMosaic(ax, x - 0.072, 0.450, 0.120, 0.115, navy, cyan, green, purple);
drawOcpMiniPlot(ax, x + 0.080, 0.438, 0.140, 0.115, blue, red, ink);
text(ax, x - 0.072, 0.585, 'SEM/EDX', 'HorizontalAlignment', 'center', 'FontName', 'Times New Roman', ...
    'FontSize', 14, 'FontWeight', 'bold', 'Color', ink);
text(ax, x + 0.080, 0.585, 'OCP', 'HorizontalAlignment', 'center', 'FontName', 'Times New Roman', ...
    'FontSize', 14, 'FontWeight', 'bold', 'Color', ink);

drawElectrodeStrip(ax, x, 0.255, 0.190, 0.060, navy, cyan);
text(ax, x, 0.190, 'geometry', 'HorizontalAlignment', 'center', 'FontName', 'Times New Roman', ...
    'FontSize', 15, 'FontWeight', 'bold', 'Color', ink);

% Column 2: characterisation protocol.
x = laneX(2);
drawCellCluster(ax, x, 0.710, navy, blue);
text(ax, x, 0.655, '3 cells', 'HorizontalAlignment', 'center', 'FontName', 'Times New Roman', ...
    'FontSize', 15, 'FontWeight', 'bold', 'Color', ink);

drawProtocolRibbon(ax, x, 0.555, blue, lineGrey, ink);
drawWaveformPanel(ax, x - 0.078, 0.360, 0.120, 0.115, blue, ink, 'GITT');
drawPulsePanel(ax, x + 0.078, 0.360, 0.120, 0.115, orange, ink, 'HPPC');
drawNyquistPanel(ax, x, 0.210, 0.155, 0.105, blue, ink);
text(ax, x, 0.168, 'EIS', 'HorizontalAlignment', 'center', 'FontName', 'Times New Roman', ...
    'FontSize', 14, 'FontWeight', 'bold', 'Color', ink);

% Column 3: ageing campaign.
x = laneX(3);
drawManyCells(ax, x - 0.055, 0.712, navy, blue, green);
text(ax, x + 0.080, 0.724, '41 cells', 'HorizontalAlignment', 'center', 'FontName', 'Times New Roman', ...
    'FontSize', 15, 'FontWeight', 'bold', 'Color', ink);
text(ax, x + 0.080, 0.684, '38 conditions', 'HorizontalAlignment', 'center', 'FontName', 'Times New Roman', ...
    'FontSize', 15, 'FontWeight', 'bold', 'Color', ink);

drawFactorIcons(ax, x, 0.535, red, blue, green, ink);
drawRptLoop(ax, x - 0.060, 0.345, 0.105, 0.095, blue, navy);
drawAgingTrend(ax, x + 0.075, 0.333, 0.115, 0.110, red, orange, green, blue, ink);
text(ax, x - 0.060, 0.465, 'RPT', 'HorizontalAlignment', 'center', 'FontName', 'Times New Roman', ...
    'FontSize', 14, 'FontWeight', 'bold', 'Color', ink);
text(ax, x + 0.075, 0.465, 'BOL  →  EOL', 'HorizontalAlignment', 'center', 'FontName', 'Times New Roman', ...
    'FontSize', 14, 'FontWeight', 'bold', 'Color', ink);

drawLiStripping(ax, x, 0.205, 0.170, 0.085, red, ink);
text(ax, x, 0.165, 'Li stripping', 'HorizontalAlignment', 'center', 'FontName', 'Times New Roman', ...
    'FontSize', 14, 'FontWeight', 'bold', 'Color', ink);

% Shared output statement and small data glyphs.
rectangle(ax, 'Position', [0.105 0.055 0.790 0.065], 'Curvature', 0.35, ...
    'FaceColor', lightGrey, 'EdgeColor', lineGrey, 'LineWidth', 1.0);
text(ax, 0.500, 0.087, 'open data for modelling, benchmarking and battery analytics', ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontName', 'Times New Roman', ...
    'FontSize', 16, 'FontWeight', 'bold', 'Color', grey);
for k = 1:3
    drawArrow(ax, laneX(k), 0.145, laneX(k), 0.122, lineGrey, 1.0);
end

pdfOut = fullfile(pngsDir, 'GraphicalAbstract_Methods.pdf');
pngOut = fullfile(pngsDir, 'GraphicalAbstract_Methods.png');
figOut = fullfile(pngsDir, 'GraphicalAbstract_Methods.fig');
exportgraphics(fig, pdfOut, 'ContentType', 'vector');
exportgraphics(fig, pngOut, 'Resolution', 300);
savefig(fig, figOut);
copyfile(pdfOut, fullfile(dataPaperFiguresDir, 'GraphicalAbstract_Methods.pdf'));
copyfile(pngOut, fullfile(dataPaperFiguresDir, 'GraphicalAbstract_Methods.png'));
fprintf('Created %s\n', pdfOut);
fprintf('Created %s\n', pngOut);
end

function drawLaneHeader(ax, cx, cy, number, titleText, subtitle, color, navy)
rectangle(ax, 'Position', [cx-0.118 cy-0.043 0.236 0.073], 'Curvature', 0.12, ...
    'FaceColor', [0.96 0.98 1.00], 'EdgeColor', color, 'LineWidth', 1.2);
rectangle(ax, 'Position', [cx-0.116 cy-0.041 0.045 0.069], 'Curvature', 0.50, ...
    'FaceColor', color, 'EdgeColor', 'none');
text(ax, cx-0.094, cy-0.006, sprintf('%d', number), 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', 'FontName', 'Times New Roman', 'FontSize', 16, ...
    'FontWeight', 'bold', 'Color', 'w');
text(ax, cx-0.058, cy+0.008, titleText, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
    'FontName', 'Times New Roman', 'FontSize', 17, 'FontWeight', 'bold', 'Color', navy);
text(ax, cx-0.058, cy-0.022, subtitle, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
    'FontName', 'Times New Roman', 'FontSize', 12.5, 'Color', [0.25 0.30 0.37]);
end

function drawCell(ax, cx, cy, scale, navy, blue)
w = 0.070*scale; h = 0.115*scale;
patch(ax, [cx-w/2 cx+w/2 cx+w/2 cx-w/2], [cy-h/2 cy-h/2+0.012*scale cy+h/2 cy+h/2-0.012*scale], ...
    [0.88 0.93 0.98], 'EdgeColor', navy, 'LineWidth', 1.1);
rectangle(ax, 'Position', [cx-w*0.28 cy+h/2-0.004*scale w*0.18 0.012*scale], 'FaceColor', [0.88 0.93 0.98], 'EdgeColor', navy, 'LineWidth', 0.9);
rectangle(ax, 'Position', [cx+w*0.10 cy+h/2-0.004*scale w*0.18 0.012*scale], 'FaceColor', [0.88 0.93 0.98], 'EdgeColor', navy, 'LineWidth', 0.9);
text(ax, cx, cy, '58 Ah', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontName', 'Times New Roman', 'FontSize', 10*scale, 'FontWeight', 'bold', 'Color', blue);
end

function drawOpenedCell(ax, cx, cy, scale, navy, cyan)
rectangle(ax, 'Position', [cx-0.046*scale cy-0.045*scale 0.092*scale 0.090*scale], 'Curvature', 0.08, 'FaceColor', [0.95 0.98 1.0], 'EdgeColor', navy, 'LineWidth', 1.0);
for k = 1:6
    yy = cy - 0.030*scale + (k-1)*0.012*scale;
    plot(ax, [cx-0.035*scale cx+0.035*scale], [yy yy+0.006*scale], '-', 'Color', cyan*(0.65+0.05*k), 'LineWidth', 1.4);
end
rectangle(ax, 'Position', [cx-0.053*scale cy+0.052*scale 0.106*scale 0.014*scale], 'FaceColor', [0.82 0.88 0.94], 'EdgeColor', navy, 'LineWidth', 0.8);
end

function drawArrow(ax, x1, y1, x2, y2, color, lw)
annotation(ax.Parent, 'arrow', [x1 x2], [y1 y2], 'Color', color, 'LineWidth', lw, 'HeadLength', 7, 'HeadWidth', 7);
end

function drawMicrographMosaic(ax, cx, cy, w, h, navy, cyan, green, purple)
colors = [cyan; green; purple; [0.70 0.55 0.35]];
for rr = 1:2
    for cc = 1:2
        x0 = cx - w/2 + (cc-1)*w/2;
        y0 = cy - h/2 + (rr-1)*h/2;
        rectangle(ax, 'Position', [x0 y0 w/2-0.006 h/2-0.006], 'FaceColor', [0.86 0.88 0.89], 'EdgeColor', navy, 'LineWidth', 0.75);
        for k = 1:11
            r = 0.004 + 0.006*rand();
            x = x0 + 0.008 + rand()*(w/2-0.022);
            y = y0 + 0.008 + rand()*(h/2-0.022);
            c = colors(randi(size(colors, 1)), :);
            rectangle(ax, 'Position', [x-r y-r 2*r 2*r], 'Curvature', [1 1], 'FaceColor', c, 'EdgeColor', 'none', 'FaceAlpha', 0.85);
        end
    end
end
end

function drawOcpMiniPlot(ax, cx, cy, w, h, blue, red, ink)
drawAxes(ax, cx-w/2, cy-h/2, w, h, ink);
t = linspace(0, 1, 80);
plot(ax, cx-w*0.42+t*w*0.82, cy-h*0.10 + h*0.34*log1p(6*t)/log(7), '-', 'Color', blue, 'LineWidth', 2.0);
plot(ax, cx-w*0.42+t*w*0.82, cy+h*0.18 - h*0.34*log1p(6*t)/log(7), '-', 'Color', red, 'LineWidth', 2.0);
end

function drawElectrodeStrip(ax, cx, cy, w, h, navy, cyan)
rectangle(ax, 'Position', [cx-w/2 cy-h/2 w h], 'FaceColor', [0.80 0.95 0.96], 'EdgeColor', navy, 'LineWidth', 1.0);
plot(ax, [cx-w/2-0.015 cx+w/2+0.015], [cy-h/2-0.018 cy-h/2-0.018], '-', 'Color', cyan, 'LineWidth', 1.2);
plot(ax, [cx-w/2-0.015 cx-w/2-0.015], [cy-h/2-0.018 cy+h/2], '-', 'Color', cyan, 'LineWidth', 1.2);
end

function drawCellCluster(ax, cx, cy, navy, blue)
drawCell(ax, cx-0.045, cy, 0.55, navy, blue);
drawCell(ax, cx, cy+0.010, 0.65, navy, blue);
drawCell(ax, cx+0.045, cy, 0.55, navy, blue);
end

function drawProtocolRibbon(ax, cx, cy, blue, lineGrey, ink)
labels = {'Init', 'GITT', 'CC', 'Dyn', 'HPPC', 'EIS'};
x = linspace(cx-0.110, cx+0.110, numel(labels));
for k = 1:numel(labels)
    rectangle(ax, 'Position', [x(k)-0.019 cy-0.019 0.038 0.038], 'Curvature', [1 1], 'FaceColor', [0.92 0.96 1.0], 'EdgeColor', blue, 'LineWidth', 1.1);
    text(ax, x(k), cy, sprintf('%d', k), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontName', 'Times New Roman', 'FontSize', 10, 'FontWeight', 'bold', 'Color', blue);
    text(ax, x(k), cy-0.046, labels{k}, 'HorizontalAlignment', 'center', 'FontName', 'Times New Roman', 'FontSize', 10.8, 'FontWeight', 'bold', 'Color', ink);
    if k < numel(labels)
        plot(ax, [x(k)+0.020 x(k+1)-0.020], [cy cy], '-', 'Color', lineGrey, 'LineWidth', 1.2);
    end
end
end

function drawWaveformPanel(ax, cx, cy, w, h, color, ink, labelText)
drawAxes(ax, cx-w/2, cy-h/2, w, h, ink);
xx = [0 .12 .12 .28 .28 .45 .45 .62 .62 .78 .78 1];
yy = [.35 .35 .62 .62 .40 .40 .52 .52 .26 .26 .48 .48];
plot(ax, cx-w*0.42+xx*w*0.84, cy-h*0.38+yy*h*0.74, '-', 'Color', color, 'LineWidth', 2.0);
text(ax, cx, cy+h*0.66, labelText, 'HorizontalAlignment', 'center', 'FontName', 'Times New Roman', 'FontSize', 13, 'FontWeight', 'bold', 'Color', ink);
end

function drawPulsePanel(ax, cx, cy, w, h, color, ink, labelText)
drawAxes(ax, cx-w/2, cy-h/2, w, h, ink);
for k = 1:5
    x0 = cx-w*0.38+(k-1)*w*0.18;
    y0 = cy-h*0.20;
    rectangle(ax, 'Position', [x0 y0 0.018 h*(0.34+0.16*mod(k,2))], 'FaceColor', [1.0 0.92 0.82], 'EdgeColor', color, 'LineWidth', 1.4);
end
text(ax, cx, cy+h*0.66, labelText, 'HorizontalAlignment', 'center', 'FontName', 'Times New Roman', 'FontSize', 13, 'FontWeight', 'bold', 'Color', ink);
end

function drawNyquistPanel(ax, cx, cy, w, h, color, ink)
drawAxes(ax, cx-w/2, cy-h/2, w, h, ink);
t = linspace(0, 1, 45);
y = 0.18 + 0.50*sin(t*pi).*exp(-0.2*t) + 0.12*t.^2;
plot(ax, cx-w*0.40+t*w*0.80, cy-h*0.36+y*h*0.72, '-o', 'Color', color, 'LineWidth', 1.8, 'MarkerSize', 2.4, 'MarkerIndices', 1:6:45);
end

function drawManyCells(ax, cx, cy, navy, blue, green)
for k = 1:6
    dx = (mod(k-1, 3)-1)*0.032;
    dy = (floor((k-1)/3)-0.5)*0.045;
    drawCell(ax, cx+dx, cy+dy, 0.34, navy, blue*(0.75+0.04*k)+green*0.06);
end
end

function drawFactorIcons(ax, cx, cy, red, blue, green, ink)
drawThermometer(ax, cx-0.075, cy, red);
drawGauge(ax, cx, cy, blue);
plot(ax, cx+0.053+[0 .016 .016 .036 .036 .058 .058 .076], cy-0.018+[.018 .018 .043 .006 .006 .035 .035 .035], '-', 'Color', green, 'LineWidth', 2.3);
text(ax, cx-0.075, cy-0.066, 'T', 'HorizontalAlignment', 'center', 'FontName', 'Times New Roman', 'FontSize', 12, 'FontWeight', 'bold', 'Color', ink);
text(ax, cx, cy-0.066, 'SoC', 'HorizontalAlignment', 'center', 'FontName', 'Times New Roman', 'FontSize', 12, 'FontWeight', 'bold', 'Color', ink);
text(ax, cx+0.080, cy-0.066, 'C-rate', 'HorizontalAlignment', 'center', 'FontName', 'Times New Roman', 'FontSize', 12, 'FontWeight', 'bold', 'Color', ink);
end

function drawThermometer(ax, cx, cy, red)
rectangle(ax, 'Position', [cx-0.006 cy-0.020 0.012 0.055], 'Curvature', 0.8, 'FaceColor', 'w', 'EdgeColor', red, 'LineWidth', 2.0);
rectangle(ax, 'Position', [cx-0.015 cy-0.038 0.030 0.030], 'Curvature', [1 1], 'FaceColor', red, 'EdgeColor', red);
end

function drawGauge(ax, cx, cy, blue)
theta = linspace(25, 155, 50) * pi / 180;
plot(ax, cx+0.035*cos(theta), cy+0.035*sin(theta), '-', 'Color', blue, 'LineWidth', 2.2);
plot(ax, [cx cx+0.025], [cy cy+0.015], '-', 'Color', blue, 'LineWidth', 2.2);
end

function drawRptLoop(ax, cx, cy, w, h, blue, navy)
rectangle(ax, 'Position', [cx-w/2 cy-h/2 w h], 'FaceColor', [0.91 0.96 1.0], 'EdgeColor', blue, 'LineWidth', 1.3);
for k = 1:4
    plot(ax, [cx-w*0.33 cx+w*0.33], [cy+h*0.28-(k-1)*h*0.18 cy+h*0.28-(k-1)*h*0.18], '-', 'Color', blue, 'LineWidth', 1.2);
end
annotation(ax.Parent, 'arrow', [cx+w*0.64 cx+w*0.86], [cy+0.010 cy+0.010], 'Color', navy, 'LineWidth', 1.4, 'HeadLength', 6, 'HeadWidth', 6);
annotation(ax.Parent, 'arrow', [cx+w*0.86 cx+w*0.64], [cy-0.014 cy-0.014], 'Color', navy, 'LineWidth', 1.4, 'HeadLength', 6, 'HeadWidth', 6);
end

function drawAgingTrend(ax, cx, cy, w, h, red, orange, green, blue, ink)
drawAxes(ax, cx-w/2, cy-h/2, w, h, ink);
colors = [blue; green; orange; red];
for k = 1:4
    t = linspace(0, 1, 20);
    y = 0.15 + 0.18*k + 0.18*t + 0.035*sin(2*pi*t+k);
    plot(ax, cx-w*0.40+t*w*0.80, cy-h*0.40+y*h*0.70, '-', 'Color', colors(k,:), 'LineWidth', 1.5);
end
end

function drawLiStripping(ax, cx, cy, w, h, red, ink)
drawAxes(ax, cx-w/2, cy-h/2, w, h, ink);
t = linspace(0, 1, 80);
y = 0.35 + 0.20*exp(-4*t) + 0.22*exp(-((t-0.45)/0.12).^2);
plot(ax, cx-w*0.42+t*w*0.84, cy-h*0.35+y*h*0.65, '-', 'Color', red, 'LineWidth', 2.0);
rectangle(ax, 'Position', [cx-w*0.06 cy-h*0.22 w*0.20 h*0.54], 'FaceColor', [1.0 0.90 0.90], 'EdgeColor', red, 'LineWidth', 1.0);
end

function drawAxes(ax, x0, y0, w, h, ink)
plot(ax, [x0 x0], [y0 y0+h], '-', 'Color', ink, 'LineWidth', 1.0);
plot(ax, [x0 x0+w], [y0 y0], '-', 'Color', ink, 'LineWidth', 1.0);
annotation(ax.Parent, 'arrow', [x0+w x0+w+0.010], [y0 y0], 'Color', ink, 'LineWidth', 0.9, 'HeadLength', 5, 'HeadWidth', 5);
annotation(ax.Parent, 'arrow', [x0 x0], [y0+h y0+h+0.010], 'Color', ink, 'LineWidth', 0.9, 'HeadLength', 5, 'HeadWidth', 5);
end
