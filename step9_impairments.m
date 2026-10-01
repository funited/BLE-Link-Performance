%% STEP 9 - RF impairment cost table: Eb/No penalty at 30.8% PER vs an ideal link
% LE1M, AWGN, discriminator receiver, 500 packets/point. For each impairment
% value, a short Eb/No sweep around threshold gives the Eb/No at 30.8% PER;
% penalty = that minus the unimpaired threshold. blePerSim options:
% CFO_Hz, TimingDrift_ppm (RX resampling), PhaseNoise_dBcHz (comm.PhaseNoise,
% level at 100 kHz offset), DCOffset (fraction of wanted RMS).
close all;
if ~isfolder("results/figs"), mkdir("results/figs"); end

NP   = 500;
EbNo = 5:0.5:20;
base = {'NumPackets', NP, 'Receiver', "discriminator"};

imp = struct( ...
  'Name',   {"CFO",       "Timing drift", "Phase noise",       "DC offset"}, ...
  'Opt',    {'CFO_Hz',    'TimingDrift_ppm', 'PhaseNoise_dBcHz', 'DCOffset'}, ...
  'Values', {[0 25 50 100 150]*1e3, [0 10 20 35 50], [-Inf -100 -90 -80 -75 -70], [0 0.05 0.1 0.2 0.3]}, ...
  'Scale',  {1e-3,        1,           1,                   100}, ...
  'Unit',   {"kHz",       "ppm",       "dBc/Hz @100 kHz",   "% of RMS"});

fprintf('Unimpaired reference:\n');
perRef = blePerSim("LE1M", EbNo, base{:});
reqRef = ebnoAtPer(EbNo, perRef, 0.308);
fprintf('Reference Eb/No at 30.8%% PER: %.2f dB\n', reqRef);

rows = {};
for m = 1:numel(imp)
    v = imp(m).Values;
    imp(m).req = nan(size(v));
    for j = 1:numel(v)
        fprintf('\n%s = %g\n', imp(m).Name, v(j));
        if isinf(v(j)) && v(j) < 0          % "no phase noise" = reference
            imp(m).req(j) = reqRef;
            continue
        end
        pj = blePerSim("LE1M", EbNo, base{:}, imp(m).Opt, v(j));
        imp(m).req(j) = ebnoAtPer(EbNo, pj, 0.308);
        rows(end+1, :) = {imp(m).Name, v(j)*imp(m).Scale, imp(m).Unit, ...
                          imp(m).req(j), imp(m).req(j) - reqRef}; %#ok<SAGROW>
    end
end
T9 = cell2table(rows, 'VariableNames', ["Impairment","Value","Unit","EbNo_req_dB","Penalty_dB"]);
disp(T9)
fprintf('(NaN = PER never reached 30.8%% below %.0f dB Eb/No)\n', EbNo(end));

figure('Name','Step 9 - Impairments');
tiledlayout(2,2);
for m = 1:numel(imp)
    nexttile;
    x = imp(m).Values * imp(m).Scale;
    if imp(m).Name == "Phase noise", x(isinf(x)) = -110; end
    plot(x, imp(m).req - reqRef, '-o', 'LineWidth', 1.2); grid on;
    xlabel(sprintf('%s (%s)', imp(m).Name, imp(m).Unit)); ylabel('Penalty (dB)');
    title(imp(m).Name);
end
sgtitle(sprintf('LE1M Eb/No penalty at 30.8%% PER vs ideal (%.1f dB), discriminator RX', reqRef));
exportgraphics(gcf, 'results/figs/Step_9_-_Impairments.png', 'Resolution', 120);
save("results/step9.mat", "imp", "reqRef", "perRef", "EbNo", "NP", "T9");
