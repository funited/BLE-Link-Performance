%% STEP 3 - RF impairment: carrier frequency offset (CFO)   (~1 min)
% What you learn:
%  - real radios have crystal errors -> the carrier is off-frequency
%  - the spec allows up to +/-150 kHz; how much does it hurt PER?
%  - bleIdealReceiver is a coherent demodulator with no CFO/phase tracking,
%    so on its own it breaks within a few kHz. A real receiver estimates the
%    CFO from the known preamble + access address and removes it first.
close all;
S  = load("results/step2_per.mat");
i1 = find(S.phys == "LE1M");

EbNoTest = S.req(i1) + 3;              % 3 dB above the 30.8% point
if isnan(EbNoTest), EbNoTest = 10; end
fprintf('LE1M at Eb/No = %.1f dB\n', EbNoTest);

%% 3a. Raw receiver (no CFO correction): fine sweep to find where it breaks
cfoRaw = 0:2.5e3:30e3;                 % Hz
perRaw = zeros(size(cfoRaw));
fprintf('\nNo CFO correction:\n');
for k = 1:numel(cfoRaw)
    perRaw(k) = blePerSim("LE1M", EbNoTest, 'CFO_Hz', cfoRaw(k), ...
        'NumPackets', 200, 'StopAtZero', false);
end

%% 3b. Realistic noncoherent receiver with CFO removal: its own PER curve
% (noncoherent detection costs some Eb/No vs the ideal coherent receiver)
fprintf('\nDiscriminator receiver, no CFO:\n');
perDisc = blePerSim("LE1M", S.EbNo, 'Receiver', "discriminator");
reqDisc = ebnoAtPer(S.EbNo, perDisc, 0.308);
EbNoDisc = reqDisc + 3;                % same 3 dB headroom as 3a
if isnan(EbNoDisc), EbNoDisc = 14; end

%% 3c. Discriminator receiver: full CFO sweep past the spec limit
cfo    = 0:25e3:200e3;                 % Hz
perCFO = zeros(size(cfo));
fprintf('\nDiscriminator receiver at Eb/No = %.1f dB:\n', EbNoDisc);
for k = 1:numel(cfo)
    perCFO(k) = blePerSim("LE1M", EbNoDisc, 'CFO_Hz', cfo(k), ...
        'NumPackets', 200, 'StopAtZero', false, 'Receiver', "discriminator");
end

figure('Name','Step 3 - CFO');
tiledlayout(1,3);
nexttile;
plot(cfoRaw/1e3, perRaw, '-o', 'LineWidth', 1.2); hold on;
yline(0.308, ':', '30.8%'); grid on; ylim([0 1]);
xlabel('CFO (kHz)'); ylabel('PER');
title(sprintf('Ideal coherent RX, %.1f dB', EbNoTest));
nexttile;
semilogy(S.EbNo, max(S.PER(i1,:), 1e-3), '-o', S.EbNo, max(perDisc, 1e-3), '-s', 'LineWidth', 1.2);
yline(0.308, ':', '30.8%'); grid on; ylim([1e-3 1]);
xlabel('E_b/N_0 (dB)'); ylabel('PER'); legend('Ideal coherent', 'Discriminator', 'Location', 'southwest');
title('LE1M, no CFO');
nexttile;
plot(cfo/1e3, perCFO, '-o', 'LineWidth', 1.2); hold on;
xline(150, '--', 'spec limit'); yline(0.308, ':', '30.8%');
grid on; ylim([0 1]);
xlabel('CFO (kHz)'); ylabel('PER');
title(sprintf('Discriminator RX, %.1f dB', EbNoDisc));
sgtitle('Simulated LE1M PER vs carrier frequency offset');

breakRaw_kHz = NaN;
iBreak = find(perRaw > 0.308, 1);
if ~isempty(iBreak), breakRaw_kHz = cfoRaw(iBreak)/1e3; end

T3raw = table((cfoRaw/1e3).', perRaw.', 'VariableNames', ["CFO_kHz","PER_raw"]);
T3    = table((cfo/1e3).', perCFO.', 'VariableNames', ["CFO_kHz","PER_discriminator"]);
disp(T3raw)
disp(T3)
fprintf('Ideal coherent receiver fails 30.8%% PER from %.1f kHz CFO\n', breakRaw_kHz);
fprintf('Discriminator needs %.1f dB Eb/No at 30.8%% PER (ideal coherent: %.1f dB)\n', ...
    reqDisc, S.req(i1));
save("results/step3.mat", "cfo", "perCFO", "cfoRaw", "perRaw", "breakRaw_kHz", ...
    "EbNoTest", "EbNoDisc", "perDisc", "reqDisc", "T3", "T3raw");
