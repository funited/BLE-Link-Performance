%% STEP 12 - Ray-traced indoor coverage (replaces the toy floor plan for these numbers)
% Ray tracing (propagationModel "raytracing", shooting-and-bouncing rays, up to
% 2 reflections, default surface material) in a shipped indoor STL scene at
% 2.44 GHz. TX -20 dBm, 0 dBi, RX grid at 0.8 m above the floor.
% Received power = incoherent sum of all ray powers at each grid point.
% PER per point from the Step 8 fading curves (discriminator RX): Rician (K = 6 dB)
% where a line-of-sight ray exists, Rayleigh where it does not.
% LE2M has no fading curve of its own: it uses the LE1M curve (same GFSK
% modulation; Step 2 shows the same Eb/No requirement, 6.77 vs 6.79 dB) with
% its own 2 Mbps noise bandwidth. LE500K is not included (no fading curve).
close all;
if ~isfolder("results/figs"), mkdir("results/figs"); end
S8 = load("results/step8.mat");
S2 = load("results/step2_per.mat");
NF = S2.NF;

% Pick the larger shipped indoor scene
cands = [string(which('office.stl')), string(which('conferenceroom.stl'))];
cands = cands(strlength(cands) > 0);
best = ""; bestA = 0;
for c = cands
    P = stlread(c).Points;
    A = prod(max(P(:,1:2)) - min(P(:,1:2)));
    fprintf('%s: x [%.2f %.2f] y [%.2f %.2f] z [%.2f %.2f] m\n', c, min(P(:,1)), max(P(:,1)), ...
        min(P(:,2)), max(P(:,2)), min(P(:,3)), max(P(:,3)));
    if A > bestA, bestA = A; best = c; end
end
stl = best;
P = stlread(stl).Points; lo = min(P); hi = max(P);
[~, sceneName] = fileparts(stl);
fprintf('Using %s\n', sceneName);

fc = 2.44e9; Ptx_dBm = -20;
txPos = [lo(1) + 0.5; lo(2) + 0.5; hi(3) - 0.3];        % near a ceiling corner
tx = txsite("cartesian", "AntennaPosition", txPos, "TransmitterFrequency", fc, ...
    "TransmitterPower", 10^((Ptx_dBm - 30)/10));
pm = propagationModel("raytracing", "CoordinateSystem", "cartesian", ...
    "Method", "sbr", "MaxNumReflections", 2);

% RX grid at 0.8 m, spacing chosen to keep ~600 points
m = 0.2; span = (hi(1:2) - lo(1:2)) - 2*m;
dx = max(0.2, sqrt(prod(span) / 600));
xs = lo(1)+m : dx : hi(1)-m;  ys = lo(2)+m : dx : hi(2)-m;
[X, Y] = meshgrid(xs, ys);
rxs = rxsite("cartesian", "AntennaPosition", [X(:) Y(:) repmat(lo(3) + 0.8, numel(X), 1)].');
fprintf('Grid: %d x %d points, %.2f m spacing, TX at [%.2f %.2f %.2f]\n', numel(ys), numel(xs), dx, txPos);

tic;
rays = raytrace(tx, rxs, pm, "Map", stl);
fprintf('Ray tracing took %.1f s\n', toc);
n = numel(X); Prx = -Inf(n,1); los = false(n,1); nRays = zeros(n,1);
for i = 1:n
    r = rays{i};
    if isempty(r), continue; end
    nRays(i) = numel(r);
    Prx(i) = Ptx_dBm + 10*log10(sum(10.^(-[r.PathLoss]/10)));
    los(i) = any([r.LineOfSight]);
end
Prx = reshape(Prx, size(X)); los = reshape(los, size(X));
fprintf('Points with rays: %d of %d, LOS: %d, Prx range %.1f to %.1f dBm\n', ...
    nnz(isfinite(Prx)), n, nnz(los), min(Prx(isfinite(Prx))), max(Prx(:)));

% PER per PHY
phys  = ["LE1M","LE2M","LE125K"];
curve = ["LE1M","LE1M","LE125K"];               % which Step 8 curve each PHY uses
ic = find(S8.chans == "rician"); ir = find(S8.chans == "rayleigh");
cov = zeros(1, numel(phys)); covRay = cov; marginMed = zeros(1, numel(phys));
perMaps = zeros([size(X) numel(phys)]); thr = perMaps;
for k = 1:numel(phys)
    rb = blePhyParams(phys(k)).bitRate;
    ebno = Prx - (-174 + 10*log10(rb) + NF);
    i8 = find(S8.phys == curve(k));
    pRic = perFromEbno(S8.EbNo, squeeze(S8.PER(i8, ic, :)).', ebno);
    pRay = perFromEbno(S8.EbNo, squeeze(S8.PER(i8, ir, :)).', ebno);
    per = pRay; per(los) = pRic(los); per(~isfinite(Prx)) = 1;
    perMaps(:,:,k) = per;
    thr(:,:,k) = rb * (1 - per);
    cov(k) = 100 * mean(per(:) < 0.308);
    hasRay = isfinite(Prx);
    covRay(k) = 100 * mean(per(hasRay) < 0.308);   % excludes points inside objects (no ray reaches them)
    req = S8.req(i8, ir); req(1) = S8.req(i8, ir);
    margin = ebno - S8.req(i8, ir);  margin(los) = ebno(los) - S8.req(i8, ic);
    marginMed(k) = median(margin(isfinite(margin)));
end
wins2M = thr(:,:,2) > thr(:,:,3);
frac2M = 100 * mean(wins2M(hasRay));        % over points reached by rays
T12 = table(phys.', curve.', cov.', covRay.', marginMed.', 'VariableNames', ...
    ["PHY","FadingCurve","Coverage_all_pct","Coverage_raypoints_pct","MedianLinkMargin_dB"]);
disp(T12)
fprintf('LE2M delivers more throughput than LE125K at %.0f%% of points reached by rays\n', frac2M);

figure('Name','Step 12 - Ray-traced coverage', 'Position', [100 100 1100 380]);
tiledlayout(1,2);
nexttile;
imagesc(xs, ys, Prx); axis xy equal tight; colorbar; hold on;
plot(txPos(1), txPos(2), 'w^', 'MarkerFaceColor', 'w');
contour(xs, ys, double(los), [0.5 0.5], 'k', 'LineWidth', 1);
title(sprintf('Ray-traced RX power (dBm), %s, TX %d dBm', sceneName, Ptx_dBm), 'Interpreter', 'none');
xlabel('x (m)'); ylabel('y (m)');
nexttile;
hI = imagesc(xs, ys, perMaps(:,:,1)); hI.AlphaData = isfinite(Prx); set(gca, 'Color', [0.8 0.8 0.8]); axis xy equal tight; caxis([0 1]); colorbar; hold on;
plot(txPos(1), txPos(2), 'w^', 'MarkerFaceColor', 'w');
title(sprintf('LE1M PER (Rician LOS / Rayleigh NLOS), grey = no ray, %.0f%% of reached points covered', covRay(1)));
xlabel('x (m)'); ylabel('y (m)');
exportgraphics(gcf, 'results/figs/Step_12_-_Raytrace_coverage.png', 'Resolution', 120);
save("results/step12.mat", "sceneName", "txPos", "Ptx_dBm", "xs", "ys", "Prx", "los", "nRays", ...
    "perMaps", "cov", "covRay", "marginMed", "frac2M", "T12", "dx");
