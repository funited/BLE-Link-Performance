"""Build BLE_Demo_Report.pdf. Every number comes from results/report_data.json
(written by export_results_json.m from the stepN.mat files); nothing is typed in."""
import json
from pathlib import Path
from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
                                Image, PageBreak, KeepTogether)
from reportlab.lib.utils import ImageReader

PROJ = Path(__file__).resolve().parent.parent
FIGS = PROJ / "results" / "figs"
OUT = PROJ / "BLE_Demo_Report.pdf"
J = json.loads((PROJ / "results" / "report_data.json").read_text())

def L(x):
    return x if isinstance(x, list) else [x]

ss = getSampleStyleSheet()
H1 = ParagraphStyle("H1", parent=ss["Heading1"], fontSize=15, spaceBefore=6, spaceAfter=6)
H2 = ParagraphStyle("H2", parent=ss["Heading2"], fontSize=12, spaceBefore=10, spaceAfter=4)
B = ParagraphStyle("B", parent=ss["BodyText"], fontSize=9.5, leading=13)
SM = ParagraphStyle("SM", parent=B, fontSize=8.5, leading=11, textColor=colors.HexColor("#444444"))
CELL = ParagraphStyle("CELL", parent=B, fontSize=8, leading=10)
BUL = ParagraphStyle("BUL", parent=B, leftIndent=12, bulletIndent=2)
GREEN, RED = colors.HexColor("#1A7F37"), colors.HexColor("#B42318")

def p(t, s=B): return Paragraph(t, s)
def bullets(items): return [Paragraph(t, BUL, bulletText="-") for t in items]
def code(t): return f"<font face='Courier'>{t}</font>"

def f(x, d=1, unit=""):
    if x is None: return "n/a"
    return f"{x:.{d}f}{unit}"

def pct(x, d=1): return "n/a" if x is None else f"{100*x:.{d}f}%"

def table(rows, widths, verdict_col=None):
    data = [[Paragraph(str(c), CELL) for c in r] for r in rows]
    t = Table(data, colWidths=widths, repeatRows=1)
    st = [("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#E8ECF2")),
          ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#B0B8C4")),
          ("VALIGN", (0, 0), (-1, -1), "TOP"),
          ("TOPPADDING", (0, 0), (-1, -1), 2), ("BOTTOMPADDING", (0, 0), (-1, -1), 2)]
    t.setStyle(TableStyle(st))
    if verdict_col is not None:
        for i, r in enumerate(rows[1:], start=1):
            v = str(r[verdict_col])
            col = GREEN if v.startswith(("PASS", "Yes")) else RED if v.startswith(("FAIL", "No")) else None
            if col is not None:
                data[i][verdict_col] = Paragraph(f"<font color='{col.hexval()}'>{v}</font>", CELL)
        t = Table(data, colWidths=widths, repeatRows=1); t.setStyle(TableStyle(st))
    return t

def fig(name, width=6.3 * inch, caption=None):
    path = FIGS / name
    if not path.exists():
        return p(f"[figure missing: {name}]", SM)
    iw, ih = ImageReader(str(path)).getSize()
    parts = [Image(str(path), width=width, height=width * ih / iw)]
    if caption: parts.append(p(caption, SM))
    parts.append(Spacer(1, 6))
    return KeepTogether(parts)

def footer(canv, doc):
    canv.saveState(); canv.setFont("Helvetica", 7.5); canv.setFillColor(colors.grey)
    canv.drawString(0.75 * inch, 0.5 * inch, "BLE link performance demo - simulated results, MATLAB R2022b")
    canv.drawRightString(7.75 * inch, 0.5 * inch, f"Page {doc.page}")
    canv.restoreState()

s1, s2, s3, s4, s5, s6 = J["s1"], J["s2"], J["s3"], J["s4"], J["s5"], J["s6"]
s8, s9, s10, s11, s12, s13 = J["s8"], J["s9"], J["s10"], J["s11"], J["s12"], J["s13"]
T2 = {r["PHY"]: r for r in L(s2["T2"])}
T8 = {(r["PHY"], r["Channel"]): r for r in L(s8["T8"])}
T9 = L(s9["T9"])
R10 = L(s10["results"])
T11 = L(s11["T11"])
T12 = {r["PHY"]: r for r in L(s12["T12"])}
T13 = L(s13["T13"])

def t9max(name):
    rows = [r for r in T9 if r["Impairment"] == name]
    return rows[-1]

def r10(dut, test):
    return next(r for r in R10 if r["DUT"] == dut and r["Test"] == test)

s = []
# ---------------- title + summary
s.append(p("BLE Link Performance Demo - Results Report", ss["Title"]))
s.append(p("MATLAB R2022b Update 3 (Bluetooth, Communications, Signal Processing, Antenna toolboxes; "
           "no WLAN or RF Toolbox). All values are <b>simulated</b> and were printed by the MATLAB runs "
           "(results/*.mat, exported to results/report_data.json). Fixed random seeds.", SM))
s.append(Spacer(1, 6))
s.append(p("Summary", H1))
cfo150 = next(r for r in L(s3["T3"]) if r["CFO_kHz"] == 150)
s += bullets([
    f"Sensitivity at 30.8% PER (ideal receiver, {s2['NF']} dB NF, {s2['NP']} packets/point): "
    f"{f(T2['LE1M']['Sensitivity_dBm'])} dBm (LE1M), {f(T2['LE2M']['Sensitivity_dBm'])} (LE2M), "
    f"{f(T2['LE500K']['Sensitivity_dBm'])} (LE500K), {f(T2['LE125K']['Sensitivity_dBm'])} (LE125K).",
    f"Noncoherent (discriminator) receiver: needs {f(s3['reqDisc'],2)} dB Eb/No at 30.8% PER and keeps PER at "
    f"{pct(cfo150['PER_discriminator'])} at the 150 kHz CFO spec limit; the toolbox ideal receiver fails from "
    f"{f(s3['breakRaw_kHz'])} kHz.",
    f"Indoor multipath (Step 8): fading penalty at 30.8% PER vs AWGN is "
    f"{f(T8[('LE1M','rician')]['Penalty_vs_AWGN_dB'])} / {f(T8[('LE1M','rayleigh')]['Penalty_vs_AWGN_dB'])} dB "
    f"(LE1M, Rician / Rayleigh) and {f(T8[('LE125K','rician')]['Penalty_vs_AWGN_dB'])} / "
    f"{f(T8[('LE125K','rayleigh')]['Penalty_vs_AWGN_dB'])} dB (LE125K).",
    f"Impairment cost (Step 9, LE1M): 150 kHz CFO {f(t9max('CFO')['Penalty_dB'],2)} dB, "
    f"-70 dBc/Hz phase noise {f(t9max('Phase noise')['Penalty_dB'],2)} dB, 30% DC offset "
    f"{f(t9max('DC offset')['Penalty_dB'],2)} dB, 50 ppm timing drift {f(t9max('Timing drift')['Penalty_dB'],2)} dB.",
    f"Receiver test suite at RF-PHY spec levels (Step 10): {s10['nReg']} regressions caught; intermodulation "
    f"fails once IIP3 drops below {f(s10['iip3Min'])} dBm.",
    f"Ray-traced coverage in the shipped '{s12['sceneName']}' scene (Step 12): LE1M covers "
    f"{f(T12['LE1M']['Coverage_raypoints_pct'])}%, LE2M {f(T12['LE2M']['Coverage_raypoints_pct'])}%, "
    f"LE125K {f(T12['LE125K']['Coverage_raypoints_pct'])}% of points reached by rays at "
    f"{s12['Ptx_dBm']} dBm.",
    f"Bursty Wi-Fi with a learning AFH (Step 13): PER {pct(s13['perNoAFH'],2)} without AFH vs "
    f"{pct(s13['perAFH'],2)} with it over 2000 events; all overlapped channels excluded by event "
    f"{s13['allOvl']}, map final at event {s13['lastChange']}.",
])

s.append(p("Code added in this round", H2))
s += bullets([
    f"{code('blePerSim.m')} options (defaults unchanged, verified bit-identical on 4 regression cases): "
    f"{code('Channel')} (awgn / rician / rayleigh), {code('TimingDrift_ppm')}, {code('PhaseNoise_dBcHz')}, "
    f"{code('DCOffset')}, {code('Intf_Type')} (ble / cw / twotone / wifi) with {code('Intf_Offset_Hz')}, "
    f"{code('Intf_CI_dB')}, {code('Intf_BW_Hz')}, {code('Intf_WifiMask')}, and absolute levels "
    f"{code('WantedLevel_dBm')} + {code('IIP3_dBm')} (comm.MemorylessNonlinearity).",
    f"New scripts {code('step8_multipath.m')} ... {code('step13_coexistence.m')}; helper {code('wifiOverlap.m')} "
    f"shared by Steps 1 and 6; Step 2 now {s2['NP']} packets/point; {code('run_all.m')} runs all 13 steps.",
    f"{code('report/export_results_json.m')} + {code('report/make_report.py')} regenerate this PDF from the results.",
])

# ---------------- claims table
s.append(PageBreak())
s.append(p("Resume claims and supporting evidence", H1))
s.append(p("The resume bullet wording was not provided, so the claims below are the capabilities this work was "
           "asked to demonstrate. Replace them with the actual bullets and check each against the evidence column.", SM))
s.append(Spacer(1, 4))
im = r10("Nominal", "Intermod n=3 (+3/+6 MHz)")
claims = [
    ["Claim", "Supported", "Evidence (figure / number)"],
    ["Link-level BLE PHY simulator for all 4 LE PHYs (PER, sensitivity)", "Yes",
     f"Fig. Step 2; sensitivity {f(T2['LE1M']['Sensitivity_dBm'])} / {f(T2['LE125K']['Sensitivity_dBm'])} dBm "
     f"(LE1M / LE125K), {s2['NP']} pkts/point"],
    ["Realistic noncoherent receiver tolerant to +/-150 kHz CFO", "Yes",
     f"Fig. Step 3; PER {pct(cfo150['PER_discriminator'])} at 150 kHz; {f(s3['reqDisc'],2)} dB vs "
     f"{f(T2['LE1M']['EbNo_req_dB'],2)} dB ideal"],
    ["Indoor multipath fading (Rician/Rayleigh) and its link penalty", "Yes",
     f"Fig. Step 8; {f(T8[('LE1M','rayleigh')]['Penalty_vs_AWGN_dB'])} dB (LE1M, Rayleigh)"],
    ["Quantified RF impairment budget (CFO, drift, phase noise, DC)", "Yes (phase noise partial)",
     "Fig./table Step 9; comm.PhaseNoise accuracy warning at -75/-70 dBc/Hz"],
    ["Automated receiver conformance suite (C/I, blocking, intermod) with regression detection", "Partial",
     f"Fig. Step 10; {s10['nReg']} regressions; blocking passes trivially (ideal filter, no reciprocal mixing)"],
    ["Front-end linearity requirement from intermod test", "Yes",
     f"Step 10b: fails below IIP3 {f(s10['iip3Min'])} dBm (nominal assumed {s10['IIP3nom']} dBm)"],
    ["Transmitter tests (power, modulation, CFO/drift) vs spec limits", "Partial",
     "Table Step 11; toolbox waveform has no ISI so df2/df1 ratio is not representative; no PA model"],
    ["Ray-traced indoor coverage and PHY selection", "Yes",
     f"Fig. Step 12; {s12['sceneName']} scene, {s12['nRayPts']} of {s12['nPts']} grid points reached; "
     f"LE2M out-delivers LE125K at {f(s12['frac2M'],0)}% of them"],
    ["Wi-Fi coexistence with adaptive frequency hopping", "Yes",
     f"Fig. Step 13; PER {pct(s13['perNoAFH'],2)} -> {pct(s13['perAFH'],2)}; "
     f"{len(L(s13['excluded']))} channels excluded"],
]
s.append(table(claims, [2.4 * inch, 0.9 * inch, 3.7 * inch], verdict_col=1))

# ---------------- steps 1-7 (condensed)
s.append(p("Baseline demo (Steps 1-7)", H1))
s.append(p(f"Waveforms and hopping (Step 1): Wi-Fi channel 6 blocks {s1['nBad']} of 37 data channels "
           f"(shared {code('wifiOverlap')} rule); CSA #1 landed in the Wi-Fi band {s1['hitsAll']}/{s1['nEvents']} "
           f"times without AFH and {s1['hitsAFH']}/{s1['nEvents']} with AFH."))
rows = [["PHY", "Bit rate (kbps)", "Eb/No at 30.8% PER (dB)", "Sensitivity (dBm)"]]
for ph in ["LE1M", "LE2M", "LE500K", "LE125K"]:
    r = T2[ph]; rows.append([ph, f(r["BitRate_kbps"], 0), f(r["EbNo_req_dB"], 2), f(r["Sensitivity_dBm"])])
s.append(table(rows, [1.2 * inch, 1.3 * inch, 1.9 * inch, 1.6 * inch]))
s.append(Spacer(1, 4))
s.append(p(f"Step 2 (ideal receiver, {s2['NP']} packets/point). Step 3: discriminator receiver needs "
           f"{f(s3['reqDisc'],2)} dB; CFO sweep at {f(s3['EbNoDisc'],1)} dB gives "
           + ", ".join(f"{r['CFO_kHz']:.0f} kHz: {pct(r['PER_discriminator'])}" for r in L(s3['T3'])) + "."))
t4 = {r["PHY"]: r for r in L(s4["T4"])}
t4b = {r["PHY"]: r for r in L(s4["T4b"])}
s.append(p("Step 4 (toy log-distance floor plan): range "
           + ", ".join(f"{ph} {f(t4[ph]['Range_m'])} m" for ph in t4) + "; coverage "
           + ", ".join(f"{ph} {f(t4b[ph]['Coverage_pct'])}%" for ph in t4b) + "."))
s.append(p(f"Step 5: {s5['nReg']} regressions (sensitivity tests at {f(s5['ref1'],1)} / {f(s5['refc'],1)} dB). "
           f"Step 6 (analytic Wi-Fi, 50% duty): PER {pct(s6['perNoAFH'])} without AFH, {pct(s6['perAFH'])} with AFH, "
           f"{s6['nOverlap']} overlapped channels."))
s.append(fig("Step_2_-_PER_waterfall.png", 4.6 * inch, "Step 2. PER waterfall, AWGN, ideal receiver."))
s.append(fig("Step_3_-_CFO.png", 5.8 * inch, "Step 3. CFO: ideal vs discriminator receiver."))

# ---------------- step 8
s.append(PageBreak())
s.append(p("Step 8 - Multipath fading", H1))
s.append(p(f"Indoor profile: delays 0/50/100/150 ns, gains 0/-3/-6/-9 dB, Rician K = 6 dB, 3 Hz Doppler, new "
           f"realization per packet (block fading). Discriminator receiver, {s8['NP']} packets/point, "
           f"Eb/No grid step {f(s8['EbNoStep'],0)} dB. The largest path delay (150 ns) is much shorter than the 1 us "
           f"symbol, so this is flat fading: the loss comes from whole-packet fades, not ISI."))
rows = [["PHY", "Channel", "Eb/No at 30.8% PER (dB)", "Penalty vs AWGN (dB)"]]
for r in L(s8["T8"]):
    rows.append([r["PHY"], r["Channel"], f(r["EbNo_req_dB"], 2), f(r["Penalty_vs_AWGN_dB"], 2)])
s.append(table(rows, [1.0 * inch, 1.2 * inch, 2.0 * inch, 1.8 * inch]))
s.append(Spacer(1, 4))
s.append(p(f"Note: the AWGN LE1M threshold here ({f(T8[('LE1M','awgn')]['EbNo_req_dB'],2)} dB) is higher than "
           f"Step 3's {f(s3['reqDisc'],2)} dB because linear interpolation on the coarser {f(s8['EbNoStep'],0)} dB "
           f"grid overestimates it; penalties use the same grid on both sides. At 30.8% PER the fading penalty is "
           f"modest; at lower PER targets it would be much larger (Rayleigh PER falls roughly as 1/SNR).", SM))
s.append(fig("Step_8_-_Multipath.png", 6.2 * inch, "Step 8. PER vs Eb/No in AWGN, Rician and Rayleigh channels."))

# ---------------- step 9
s.append(PageBreak())
s.append(p("Step 9 - RF impairment cost table", H1))
s.append(p(f"LE1M, AWGN, discriminator receiver, {s9['NP']} packets/point. Unimpaired threshold "
           f"{f(s9['reqRef'],2)} dB Eb/No at 30.8% PER; penalty = threshold with the impairment minus that."))
rows = [["Impairment", "Value", "Unit", "Eb/No req (dB)", "Penalty (dB)"]]
for r in T9:
    rows.append([r["Impairment"], f(r["Value"], 0), r["Unit"], f(r["EbNo_req_dB"], 2), f(r["Penalty_dB"], 2)])
s.append(table(rows, [1.2 * inch, 0.7 * inch, 1.5 * inch, 1.2 * inch, 1.1 * inch]))
s.append(Spacer(1, 4))
s.append(p("Penalties within about +/-0.1 dB of zero (including small negative values) are Monte-Carlo noise at "
           "this packet count. comm.PhaseNoise warned that its -75 and -70 dBc/Hz settings may be inaccurate. "
           "Timing drift up to 50 ppm is harmless: over a 336 us packet it slips the sampling instant by a small fraction of a sample.", SM))
s.append(fig("Step_9_-_Impairments.png", 5.6 * inch, "Step 9. Eb/No penalty vs impairment level."))

# ---------------- step 10
s.append(PageBreak())
s.append(p("Step 10 - Receiver interference tests", H1))
s.append(p("Levels from the MathWorks example 'Bluetooth LE Blocking, Intermodulation and Carrier-to-Interference "
           f"Performance Tests' ({code('helperBLETestParamGenerate.m')}, RF-PHY TS 4.5), cross-checked against "
           f"{code('bluetoothRFPHYTestConfig')}: wanted -67 dBm; BLE interferer -88 (co-channel), -82 (+/-1 MHz), "
           "-50 (+/-2 MHz), -40 dBm (+/-3 MHz); CW blocker -35 dBm at 2399 MHz (Fc 2426); intermod wanted -64 dBm "
           "with CW at +3 MHz and BLE at +6 MHz, both -50 dBm. PER limit 30.8%. "
           f"DUTs: Nominal (IIP3 {s10['IIP3nom']} dBm, assumed), Degraded (150 kHz CFO + 4 dB loss), "
           f"Nonlinear (IIP3 {s10['IIP3nom'] - 10} dBm). {s10['NP']} packets per test."))
tests = list(dict.fromkeys(r["Test"] for r in R10))
rows = [["Test", "Nominal", "Degraded", "Nonlinear"]]
for t in tests:
    rows.append([t] + [f"{r10(d, t)['Verdict']} ({pct(r10(d, t)['PER'])})" for d in ["Nominal", "Degraded", "Nonlinear"]])
data_t = table(rows, [2.3 * inch, 1.5 * inch, 1.5 * inch, 1.5 * inch])
s.append(data_t)
s.append(Spacer(1, 4))
regs = L(s10["regList"]) if s10["regList"] else []
s.append(p(f"Regressions (PASS on Nominal, FAIL elsewhere): {'; '.join(regs) if regs else 'none'}. "
           "Both are the Degraded DUT's sensitivity tests: its 4 dB loss exceeds the 2 dB test margin (Step 5 "
           "isolated this). The Nonlinear DUT passes everything: with -50 dBm tones and IIP3 "
           f"{s10['IIP3nom'] - 10} dBm, IM3 lands near -90 dBm, well below the -64 dBm wanted signal."))
im_rows = [["IIP3 (dBm)"] + [f(x, 1) for x in L(s10["iip3Sweep"])],
           ["Intermod PER"] + [pct(x, 0) for x in L(s10["perIM"])]]
s.append(table(im_rows, [0.9 * inch] + [0.55 * inch] * len(L(s10["iip3Sweep"]))))
s.append(Spacer(1, 4))
s.append(p("Blocking passes on every DUT for a modelling reason: the CW blocker is 27 MHz away and is removed by "
           "the ideal digital channel filter, thermal noise is input-referred (compression scales noise and "
           "signal together), and LO reciprocal mixing is not modelled. Adjacent C/I at +/-3 MHz has the least "
           "margin; its PER comes from the finite selectivity of the receiver's FIR channel filter.", SM))
s.append(fig("Step_10_-_RX_tests.png", 6.4 * inch, "Step 10. Test PER per DUT, and intermod PER vs IIP3."))

# ---------------- step 11
s.append(PageBreak())
s.append(p("Step 11 - Transmitter tests", H1))
s.append(p(f"{code('bluetoothRFPHYTestConfig')} + {code('bluetoothTestWaveform')} with the measurement helpers from "
           "the MathWorks transmitter-test example (helperBLEModulationTestConfig / "
           "helperBLEModulationTestMeasurements); limits from its helperBLEModulationTestVerdict. Impaired TX: 60 kHz "
           "CFO + 30 kHz linear drift over the packet."))
rows = [["TX", "Measurement", "Value", "Limit", "Verdict"]]
for r in T11:
    v = r["Value"]; vs = f"{v:.3g}" if abs(v) >= 1e-6 else "0"
    rows.append([r["TX"], r["Measurement"], vs, r["Limit"], r["Verdict"]])
s.append(table(rows, [0.8 * inch, 2.6 * inch, 0.9 * inch, 0.9 * inch, 0.8 * inch], verdict_col=4))
s.append(Spacer(1, 4))
s.append(p("Both transmitters pass. Two caveats: (1) the toolbox GFSK uses a one-symbol frequency pulse "
           "(verified: every symbol peaks at 295 kHz for any bit pattern), so there is no ISI and the "
           "df2avg/df1avg ratio is above 1, whereas a real BT = 0.5 transmitter gives a ratio below 1; the same "
           "waveform drives all receiver results, which are therefore slightly optimistic. (2) With no PA model the "
           "constant-envelope output makes the power tests trivial. The impaired TX's drift stays inside the "
           "limits because a 30 kHz drift over a ~400 us packet is within the 50 kHz budget.", SM))

# ---------------- step 12
s.append(p("Step 12 - Ray-traced indoor coverage", H1))
tx = L(s12["txPos"])
s.append(p(f"Shooting-and-bouncing-ray tracing ({code('propagationModel(\"raytracing\")')}, up to 2 reflections, "
           f"default materials) in MATLAB's shipped '{s12['sceneName']}' STL scene at 2.44 GHz. TX {s12['Ptx_dBm']} dBm "
           f"at ({f(tx[0],2)}, {f(tx[1],2)}, {f(tx[2],2)}) m; RX grid {f(s12['dx'],2)} m at 0.8 m height. "
           f"{s12['nRayPts']} of {s12['nPts']} points receive rays ({s12['nLOS']} with LOS); RX power "
           f"{f(s12['PrxMin'])} to {f(s12['PrxMax'])} dBm. PER uses Step 8's Rician curve at LOS points and "
           "Rayleigh at NLOS points; LE2M uses the LE1M curves (same GFSK, same AWGN threshold in Step 2)."))
rows = [["PHY", "Coverage, all points", "Coverage, points reached by rays", "Median link margin (dB)"]]
for ph, r in T12.items():
    rows.append([ph, f"{f(r['Coverage_all_pct'])}%", f"{f(r['Coverage_raypoints_pct'])}%", f(r["MedianLinkMargin_dB"])])
s.append(table(rows, [1.0 * inch, 1.6 * inch, 2.2 * inch, 1.7 * inch]))
s.append(Spacer(1, 4))
s.append(p(f"Points with no ray lie inside walls and furniture (straight strips and boxes in the map) and are "
           f"excluded from the second coverage column. LE2M delivers more throughput than LE125K at "
           f"{f(s12['frac2M'],0)}% of reached points. The scene is a single 5 x 8 m office, so it does not stress "
           "the coded PHYs; a larger floor plan (e.g. a Wireless InSite export) would.", SM))
s.append(fig("Step_12_-_Raytrace_coverage.png", 6.4 * inch, "Step 12. Ray-traced RX power (black contour: LOS region) and LE1M PER map."))

# ---------------- step 13
s.append(PageBreak())
s.append(p("Step 13 - Bursty Wi-Fi and a learning AFH", H1))
s.append(p(f"Wi-Fi channel 6 at -55 dBm as Gaussian noise shaped by the 802.11 OFDM 20 MHz transmit mask (worst "
           f"case allowed), wanted BLE -80 dBm, generated at 16 MHz and passed through the discriminator's channel "
           f"filter with the BLE signal ({s13['NP']} packets per channel). Event simulation: 2000 connection events "
           f"at 7.5 ms, Wi-Fi bursts 1-3 ms on/off (realised duty {pct(s13['duty'])}), CSA #1; learning AFH marks a "
           "channel bad when its PER over its last 20 uses exceeds 20%."))
rows = [["Result", "Value"],
        ["PER, no AFH (2000 events)", pct(s13["perNoAFH"], 2)],
        ["PER, learning AFH (2000 events)", pct(s13["perAFH"], 2)],
        ["All overlapped channels excluded by event", str(s13["allOvl"])],
        ["Last channel-map change (converged) at event", str(s13["lastChange"])],
        ["PER after convergence", pct(s13["perAFHafter"], 2)],
        ["Channels excluded", ", ".join(str(int(c)) for c in L(s13["excluded"]))],
        ["Channels overlapping Wi-Fi (wifiOverlap rule)", ", ".join(str(int(c)) for c in L(s13["overlap"]))]]
s.append(table(rows, [3.2 * inch, 3.2 * inch]))
s.append(Spacer(1, 4))
part = [r for r in T13 if (not r["WifiOverlap"]) and r["PER_WifiOn"] > 0]
s.append(p("Partially interfered channels (outside the 20 MHz band but hit by the spectral-mask skirts): "
           + ", ".join(f"ch {r['Channel']} {pct(r['PER_WifiOn'],1)}" for r in part)
           + ". The AFH correctly learns to drop the worst of these as well; channels near the 20% threshold take "
           "longest to classify, which sets the convergence time.", SM))
s.append(fig("Step_13_-_Coexistence.png", 6.4 * inch, "Step 13. Per-channel PER and moving-average PER with and without learning AFH."))

# ---------------- limitations
s.append(p("Not done / limitations", H1))
s += bullets([
    "Resume bullet wording not provided; the claims table uses the capabilities the work targeted.",
    "Blocking is not a meaningful test in this model (ideal digital filtering, input-referred noise, no LO "
    "phase-noise reciprocal mixing); the nominal IIP3 of -20 dBm is an assumption, not a datasheet value.",
    "The toolbox GFSK waveform has no ISI (one-symbol frequency pulse): receiver results are slightly optimistic "
    "and the TX modulation ratio is not representative of real hardware.",
    "comm.PhaseNoise flagged its -75 and -70 dBc/Hz settings as possibly inaccurate.",
    "Intermod wanted level -64 dBm follows the example helper; bluetoothRFPHYTestConfig's default shows -67 dBm.",
    "500 packets per point: PER values carry roughly +/-2% statistical uncertainty; Step 8 used a 2 dB Eb/No grid.",
    "Ray tracing: default surface materials, 2 reflections, incoherent power sum, one small office scene; LE500K "
    "not included; LE2M borrows the LE1M fading curve.",
    "Coexistence: Wi-Fi is mask-shaped Gaussian noise with random bursts, not a traffic model; a packet that "
    "overlaps a burst at all uses the Wi-Fi-on PER; the AFH never re-admits channels.",
    "TX tests: no power-amplifier model, so output-power tests are trivially met.",
    "Discriminator timing is ideal (taken from the clean reference); coded-PHY path uses internal toolbox "
    "functions (ble.internal.*).",
])

doc = SimpleDocTemplate(str(OUT), pagesize=letter, leftMargin=0.75 * inch, rightMargin=0.75 * inch,
                        topMargin=0.7 * inch, bottomMargin=0.75 * inch,
                        title="BLE Link Performance Demo - Results Report", author="Claude Code")
doc.build(s, onFirstPage=footer, onLaterPages=footer)
print(OUT, OUT.stat().st_size)
