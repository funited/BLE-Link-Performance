function tf = wifiOverlap(fMHz, wifiCenterMHz, wifiBWMHz)
%WIFIOVERLAP True for BLE channels whose ~2 MHz-wide signal overlaps a Wi-Fi channel.
%   tf = wifiOverlap(bleChanFreqMHz(0:36), 2437, 20)
%   A BLE channel (centre f, about +/-1 MHz wide) overlaps a Wi-Fi channel of
%   occupied bandwidth W centred at fc when |f - fc| < W/2 + 1.
%   Shared by Step 1 (hopping) and Step 6 (coexistence) so both count the same channels.
if nargin < 2, wifiCenterMHz = 2437; end   % Wi-Fi channel 6
if nargin < 3, wifiBWMHz = 20; end
tf = abs(fMHz - wifiCenterMHz) < wifiBWMHz/2 + 1;
end
