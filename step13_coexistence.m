%% STEP 13 - Bursty Wi-Fi interference and a learning AFH, 2000 connection events
% (a) Per-channel PER from waveform simulation (discriminator RX, LE1M, 500 packets):
%     Wi-Fi channel 6 (2437 MHz) as 20 MHz band-limited Gaussian noise
%     (OFDM-like) at -55 dBm, wanted BLE -80 dBm, NF 7 dB. The Wi-Fi noise is
%     added at 16 MHz sampling and goes through the discriminator's channel
%     filter with the BLE signal, so edge channels see only partial interference.
% (b) Event-level Monte Carlo: Wi-Fi bursts 1-3 ms on / 1-3 ms off (50% duty),
%     connection interval 7.5 ms, 376 us packet; a packet that overlaps a
%     burst fails with that channel's Wi-Fi-on PER, otherwise with the Wi-Fi-off PER.
%     CSA #1 (hop 7) with (1) no AFH and (2) a learning AFH: all 37 channels
%     used at start, a channel is marked bad when it has >= 20 uses and its PER
%     over its last 20 uses is > 20%; the map is then remapped (min 2 channels).
close all;
if ~isfolder("results/figs"), mkdir("results/figs"); end
S2 = load("results/step2_per.mat");
NF = S2.NF; NP = 500;
S_dBm = -80; Pwifi_dBm = -55; wifiC = 2437; wifiBW = 20e6;
ebno = S_dBm + 174 - 60 - NF;                  % LE1M Eb/No at the wanted level

%% (a) per-channel PER, Wi-Fi on / off
ch = 0:36; f = bleChanFreqMHz(ch);
common = {'NumPackets', NP, 'StopAtZero', false, 'Receiver', "discriminator", 'SamplesPerSymbol', 16};
fprintf('Wi-Fi off:\n');
perOff = blePerSim("LE1M", ebno, common{:});
perOn = zeros(size(ch));
for k = 1:numel(ch)
    fprintf('ch %2d (%d MHz, Wi-Fi offset %+3d MHz): ', ch(k), f(k), wifiC - f(k));
    perOn(k) = blePerSim("LE1M", ebno, common{:}, 'Intf_Type', "wifi", ...
        'Intf_Offset_Hz', (wifiC - f(k))*1e6, 'Intf_BW_Hz', wifiBW, ...
        'Intf_CI_dB', S_dBm - Pwifi_dBm, 'Intf_WifiMask', true, 'Seed', 100 + k);
end
overlap = wifiOverlap(f, wifiC, wifiBW/1e6);

%% (b) 2000 connection events
rng(7);
nEv = 2000; ci = 7.5e-3; tPkt = 376e-6;
T = nEv * ci + 0.01;
edges = []; tt = 0; on = rand < 0.5;           % burst timeline
while tt < T
    d = 1e-3 + 2e-3*rand;
    if on, edges(end+1, :) = [tt, tt + d]; end %#ok<SAGROW>
    tt = tt + d; on = ~on;
end
duty = sum(diff(edges, 1, 2)) / T;
tEv = (0:nEv-1) * ci;
hit = false(1, nEv);
for e = 1:nEv
    hit(e) = any(edges(:,1) < tEv(e) + tPkt & edges(:,2) > tEv(e));
end
u = rand(1, nEv);                               % same random draws for both runs

% (1) no AFH
[seqA, failA] = runLink(false, hit, u, perOn, perOff);
% (2) learning AFH
[seqB, failB, mapHist, badSet, lastChange, exclEvent] = runLink(true, hit, u, perOn, perOff);
allOvl = max(exclEvent(overlap));                % all geometrically overlapped channels excluded

perNoAFH = mean(failA);  perAFH = mean(failB);
perAFHafter = mean(failB(lastChange+1:end));
fprintf('\nWi-Fi duty cycle realised: %.1f%%, packets overlapping a burst: %.1f%%\n', 100*duty, 100*mean(hit));
fprintf('Overall PER, no AFH:        %.2f%%\n', 100*perNoAFH);
fprintf('Overall PER, learning AFH:  %.2f%% (all 2000 events)\n', 100*perAFH);
fprintf('Learning AFH converged at event %d (last channel-map change); PER after that: %.2f%%\n', ...
    lastChange, 100*perAFHafter);
fprintf('All %d overlapped channels excluded by event %d; PER from then on: %.2f%%\n', nnz(overlap), allOvl, 100*mean(failB(allOvl+1:end)));
fprintf('Channels excluded by AFH: %s\n', mat2str(find(badSet) - 1));
fprintf('Channels overlapping Wi-Fi (wifiOverlap): %s\n', mat2str(find(overlap) - 1));
fprintf('Excluded but not overlapped: %d, overlapped but kept: %d\n', ...
    nnz(badSet & ~overlap), nnz(~badSet & overlap));

% per-channel PER seen in the event simulation (no AFH)
perChEvent = arrayfun(@(c) mean(failA(seqA == c)), ch);
T13 = table(ch.', f.', overlap.', perOn.', perChEvent.', badSet.', 'VariableNames', ...
    ["Channel","Freq_MHz","WifiOverlap","PER_WifiOn","PER_Events_noAFH","ExcludedByAFH"]);
disp(T13)

figure('Name','Step 13 - Coexistence', 'Position', [100 100 1100 420]);
tiledlayout(1,2);
nexttile;
bar(ch, perOn, 'FaceColor', [0.85 0.3 0.3]); hold on;
bar(ch, perChEvent, 0.4, 'FaceColor', [0.3 0.6 0.9]);
grid on; xlabel('BLE data channel'); ylabel('PER');
legend('Wi-Fi on (waveform sim)', 'Event sim, 50% bursts, no AFH', 'Location', 'northwest');
title('Per-channel PER, Wi-Fi ch 6 at -55 dBm, BLE -80 dBm');
nexttile;
w = 50;
plot(movmean(failA, w), 'LineWidth', 1); hold on; plot(movmean(failB, w), 'LineWidth', 1);
xline(lastChange, ':', 'AFH converged'); grid on; ylim([0 0.5]);
xlabel('Connection event'); ylabel(sprintf('PER (%d-event moving average)', w));
legend('No AFH', 'Learning AFH'); title('Learning AFH over 2000 events');
exportgraphics(gcf, 'results/figs/Step_13_-_Coexistence.png', 'Resolution', 120);
save("results/step13.mat", "perOn", "perOff", "overlap", "perNoAFH", "perAFH", "perAFHafter", ...
    "lastChange", "allOvl", "exclEvent", "badSet", "perChEvent", "duty", "T13", "mapHist", "NP");

%% ---- local function ----
function [seq, fail, mapHist, bad, lastChange, exclEvent] = runLink(useAFH, hit, u, perOn, perOff)
nEv = numel(hit); hop = 7; last = 0;
used = 0:36; bad = false(1, 37);
hist = cell(1, 37);                           % outcomes per channel
seq = zeros(1, nEv); fail = false(1, nEv);
mapHist = zeros(1, nEv); lastChange = 0; exclEvent = nan(1, 37);
for e = 1:nEv
    unmapped = mod(last + hop, 37); last = unmapped;
    if ismember(unmapped, used), c = unmapped; else, c = used(mod(unmapped, numel(used)) + 1); end
    p = perOff; if hit(e), p = perOn(c + 1); end
    fail(e) = u(e) < p;
    seq(e) = c;
    if useAFH
        hist{c+1}(end+1) = fail(e);
        h = hist{c+1};
        if numel(h) >= 20 && mean(h(end-19:end)) > 0.2 && numel(used) > 2
            bad(c+1) = true; used = find(~bad) - 1; lastChange = e; exclEvent(c+1) = e;
        end
    end
    mapHist(e) = numel(used);
end
end
