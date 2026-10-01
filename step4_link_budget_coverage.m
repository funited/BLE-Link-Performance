%% STEP 4 - Link budget, range and an indoor PER coverage map   (~1 min)
% What you learn:
%  - link margin = Ptx + Gtx + Grx - path loss - sensitivity
%  - range per PHY from a log-distance path-loss model
%  - how a coverage map turns a PER curve into "where does the link work?"
%  NOTE: the floor plan below is a TOY model (distance + wall loss).
%        Swap PL for your Wireless InSite / ML path-loss grid later.
close all;
S = load("results/step2_per.mat");

Ptx = -20;          % dBm, low-power wearable setting
Gt  = 0; Gr = 0;    % dBi
PL0 = 40;           % dB, free-space loss at 1 m, 2.4 GHz
n   = 3;            % path-loss exponent, indoor

%% 4a. Link budget -> range
range_m = 10.^((Ptx + Gt + Gr - S.sens - PL0) / (10*n));
T4 = table(S.phys.', S.sens.', range_m.', ...
    'VariableNames', ["PHY","Sensitivity_dBm","Range_m"]);
disp(T4)

%% 4b. Coverage map on a 30 m x 20 m floor with two interior walls
[X, Y] = meshgrid(0:0.25:30, 0:0.25:20);
tx = [3 10];                               % transmitter position (m)
d  = max(hypot(X - tx(1), Y - tx(2)), 0.5);
walls = [10 20]; wallLoss = 6;             % dB per wall crossed
nWalls = (X > walls(1)) + (X > walls(2));
PL  = PL0 + 10*n*log10(d) + wallLoss*nWalls;
Prx = Ptx + Gt + Gr - PL;

coverage = zeros(1, numel(S.phys));
thrMaps  = zeros([size(X) numel(S.phys)]);
figure('Name','Step 4 - Coverage maps');
tiledlayout(2,2);
for i = 1:numel(S.phys)
    ebnoMap = Prx - (-174 + 10*log10(S.rb(i)) + S.NF);
    perMap  = perFromEbno(S.EbNo, S.PER(i,:), ebnoMap);
    thrMaps(:,:,i) = S.rb(i) * (1 - perMap);           % delivered bit rate
    coverage(i) = 100 * mean(perMap(:) < 0.308);
    nexttile;
    imagesc(X(1,:), Y(:,1), perMap); axis xy equal tight; caxis([0 1]); colorbar;
    hold on; plot(tx(1), tx(2), 'w^', 'MarkerFaceColor', 'w');
    xline(walls, 'w-', 'LineWidth', 1.5);
    title(sprintf('%s PER - %.0f%% covered', S.phys(i), coverage(i)));
    xlabel('x (m)'); ylabel('y (m)');
end

% Where does fast LE2M still deliver more bits than long-range LE125K?
i2 = find(S.phys == "LE2M"); ic = find(S.phys == "LE125K");
wins2M = thrMaps(:,:,i2) > thrMaps(:,:,ic);
frac2Mwins = 100 * mean(wins2M(:));
figure('Name','Step 4 - 2M vs Coded');
imagesc(X(1,:), Y(:,1), double(wins2M)); axis xy equal tight; colormap(gca, [0.85 0.3 0.3; 0.3 0.6 0.9]);
title(sprintf('Blue: LE2M delivers more throughput than LE125K (%.0f%% of floor)', frac2Mwins));
xlabel('x (m)'); ylabel('y (m)');

T4b = table(S.phys.', coverage.', 'VariableNames', ["PHY","Coverage_pct"]);
disp(T4b)
save("results/step4.mat", "T4", "T4b", "range_m", "coverage", "frac2Mwins", "Ptx", "n", "wallLoss");
