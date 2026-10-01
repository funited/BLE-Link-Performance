%% STEP 8 - Multipath fading: PER vs Eb/No in AWGN, Rician and Rayleigh channels
% Indoor profile (blePerSim 'Channel' option): path delays [0 50 100 150] ns,
% gains [0 -3 -6 -9] dB, Rician K = 6 dB, 3 Hz max Doppler, a new fading
% realization every packet (block fading). Discriminator receiver, 500 packets/point.
% Delay spread (~60 ns rms) << 1 us symbol, so this is essentially flat fading:
% the penalty comes from deep fades of the whole packet, not from ISI.
close all;
if ~isfolder("results/figs"), mkdir("results/figs"); end

phys  = ["LE1M","LE125K"];
chans = ["awgn","rician","rayleigh"];
EbNo  = 0:2:40;
NP    = 500;

PER = nan(numel(phys), numel(chans), numel(EbNo));
req = nan(numel(phys), numel(chans));
for i = 1:numel(phys)
    for c = 1:numel(chans)
        fprintf('\n%s, %s\n', phys(i), chans(c));
        PER(i,c,:) = blePerSim(phys(i), EbNo, 'NumPackets', NP, 'Channel', chans(c), ...
            'Receiver', "discriminator");
        req(i,c) = ebnoAtPer(EbNo, squeeze(PER(i,c,:)).', 0.308);
    end
end
penalty = req - req(:,1);        % dB vs AWGN

T8 = table(repelem(phys.', numel(chans)), repmat(chans.', numel(phys), 1), ...
    reshape(req.', [], 1), reshape(penalty.', [], 1), ...
    'VariableNames', ["PHY","Channel","EbNo_req_dB","Penalty_vs_AWGN_dB"]);
disp(T8)

figure('Name','Step 8 - Multipath');
tiledlayout(1,2);
for i = 1:numel(phys)
    nexttile;
    semilogy(EbNo, max(squeeze(PER(i,:,:)), 1e-3).', '-o', 'LineWidth', 1.2); hold on;
    yline(0.308, ':', '30.8%'); grid on; ylim([1e-3 1]);
    xlabel('E_b/N_0 (dB)'); ylabel('PER'); title(phys(i));
    legend("AWGN", "Rician K=6 dB", "Rayleigh", 'Location', 'southwest');
end
sgtitle(sprintf('Simulated PER, indoor multipath, discriminator RX, %d packets/point', NP));
exportgraphics(gcf, 'results/figs/Step_8_-_Multipath.png', 'Resolution', 120);
save("results/step8.mat", "phys", "chans", "EbNo", "PER", "req", "penalty", "NP", "T8");
