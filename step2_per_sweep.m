%% STEP 2 - PER vs Eb/No for all four PHYs, then receiver sensitivity  (~10-15 min)
% What you learn:
%  - PER "waterfall" curves and the 30.8% PER reference point used by the spec
%  - LE1M and LE2M need about the same Eb/No (same modulation)
%  - coded PHYs need less Eb/No (coding gain)
%  - converting required Eb/No into sensitivity in dBm:
%        S = -174 + 10*log10(Rb) + NF + (Eb/No)_req
%    -> LE2M is ~3 dB worse in dBm (double bit rate = double noise bandwidth)
%    -> LE125K is several dB better (1/8 bit rate + coding gain)
close all;
if ~isfolder("results"), mkdir("results"); end

phys = ["LE1M","LE2M","LE500K","LE125K"];
EbNo = 0:1:14;          % dB
NP   = 1000;            % packets per point
NF   = 7;               % receiver noise figure incl. implementation loss (dB), assumed

PER = nan(numel(phys), numel(EbNo));
for i = 1:numel(phys)
    fprintf('\n%s\n', phys(i));
    PER(i,:) = blePerSim(phys(i), EbNo, 'NumPackets', NP);
end

figure('Name','Step 2 - PER waterfall');
semilogy(EbNo, max(PER, 1e-3).', '-o', 'LineWidth', 1.2); hold on;
yline(0.308, '--', '30.8% PER'); grid on; ylim([1e-3 1]);
xlabel('E_b/N_0 (dB)'); ylabel('Packet error rate');
legend(phys, 'Location', 'southwest');
title(sprintf('Simulated BLE PER, AWGN, %d packets/point', NP));

% Required Eb/No at 30.8% PER and sensitivity
req  = nan(1, numel(phys));
rb   = nan(1, numel(phys));
for i = 1:numel(phys)
    req(i) = ebnoAtPer(EbNo, PER(i,:), 0.308);
    p = blePhyParams(phys(i));
    rb(i) = p.bitRate;
end
sens = -174 + 10*log10(rb) + NF + req;

datasheet = [-95 NaN NaN -103];   % nRF52840, approximate - check the datasheet
T2 = table(phys.', rb.'/1e3, req.', sens.', datasheet.', ...
    'VariableNames', ["PHY","BitRate_kbps","EbNo_req_dB","Sensitivity_dBm","Datasheet_dBm"]);
disp(T2)
fprintf('LE2M vs LE1M sensitivity: %+.1f dB\n', sens(2) - sens(1));
fprintf('LE125K vs LE1M sensitivity: %+.1f dB\n', sens(4) - sens(1));

save("results/step2_per.mat", "phys", "EbNo", "PER", "req", "rb", "sens", "NF", "NP", "T2");
