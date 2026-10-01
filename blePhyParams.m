function p = blePhyParams(phy)
%BLEPHYPARAMS Symbol rate, coding rate and bit rate for each BLE PHY.
%   LE1M  : GFSK, 1 Msym/s, uncoded            -> 1 Mbps
%   LE2M  : GFSK, 2 Msym/s, uncoded            -> 2 Mbps
%   LE500K: GFSK, 1 Msym/s, FEC + S=2 coding   -> 500 kbps
%   LE125K: GFSK, 1 Msym/s, FEC + S=8 coding   -> 125 kbps
switch string(phy)
    case "LE1M",   p.symRate = 1e6; p.codeRate = 1;   p.bitRate = 1e6;
    case "LE2M",   p.symRate = 2e6; p.codeRate = 1;   p.bitRate = 2e6;
    case "LE500K", p.symRate = 1e6; p.codeRate = 1/2; p.bitRate = 500e3;
    case "LE125K", p.symRate = 1e6; p.codeRate = 1/8; p.bitRate = 125e3;
    otherwise, error("Unknown PHY: %s", phy);
end
end
