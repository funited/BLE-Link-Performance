function f = bleChanFreqMHz(ch)
%BLECHANFREQMHZ BLE data channel index (0-36) -> RF centre frequency (MHz).
%   Data channels 0-10 sit at 2404-2424 MHz, 11-36 at 2428-2478 MHz.
%   (2402, 2426 and 2480 MHz are the advertising channels 37, 38, 39.)
f = zeros(size(ch));
lo = ch <= 10;
f(lo)  = 2404 + 2*ch(lo);
f(~lo) = 2428 + 2*(ch(~lo) - 11);
end
