%% STEP 6 - Wi-Fi / Bluetooth coexistence and AFH   (<1 min)
% What you learn:
%  - a 20 MHz Wi-Fi channel covers ~10 of the 37 BLE data channels
%  - per-channel SINR -> per-channel PER (using the Step 2 curve)
%  - average PER while hopping, with and without AFH
%  Simplified: Wi-Fi modeled as Gaussian noise in its band with a duty cycle.
close all;
S  = load("results/step2_per.mat");
i1 = find(S.phys == "LE1M");

ch   = 0:36;
f    = bleChanFreqMHz(ch);
S_dBm      = -80;       % wanted BLE signal at the receiver
Pwifi_dBm  = -55;       % Wi-Fi power at the BLE receiver (20 MHz total)
wifiCenter = 2437;      % Wi-Fi channel 6
wifiBW     = 20;        % MHz
duty       = 0.5;       % fraction of time Wi-Fi is transmitting

N_dBm   = -174 + 10*log10(1e6) + S.NF;                % noise in 1 MHz
overlap = wifiOverlap(f, wifiCenter, wifiBW);
I_dBm   = -Inf(size(ch));
I_dBm(overlap) = Pwifi_dBm - 10*log10(wifiBW);        % Wi-Fi power inside 1 MHz

ebnoOn  = S_dBm - 10*log10(10.^(N_dBm/10) + 10.^(I_dBm/10));  % LE1M: Eb/N0 ~ SINR
ebnoOff = S_dBm - N_dBm;
perOn   = perFromEbno(S.EbNo, S.PER(i1,:), ebnoOn);
perOff  = perFromEbno(S.EbNo, S.PER(i1,:), ebnoOff);
perCh   = duty*perOn + (1 - duty)*perOff;

perNoAFH = mean(perCh);            % hopping over all 37 channels
perAFH   = mean(perCh(~overlap));  % hopping only over clean channels

figure('Name','Step 6 - Coexistence');
b = bar(ch, perCh); b.FaceColor = 'flat';
b.CData(overlap,:) = repmat([0.85 0.3 0.3], sum(overlap), 1);
b.CData(~overlap,:) = repmat([0.3 0.6 0.9], sum(~overlap), 1);
grid on; xlabel('BLE data channel'); ylabel('PER');
title(sprintf('Simulated LE1M PER per channel with Wi-Fi ch 6: no AFH %.1f%%, AFH %.1f%%', ...
    100*perNoAFH, 100*perAFH));

fprintf('BLE channels overlapped by Wi-Fi: %d of 37\n', sum(overlap));
fprintf('Average PER without AFH: %.1f%%\n', 100*perNoAFH);
fprintf('Average PER with AFH:    %.1f%%\n', 100*perAFH);
save("results/step6.mat", "perCh", "perNoAFH", "perAFH", "overlap", "duty", "Pwifi_dBm", "S_dBm");
