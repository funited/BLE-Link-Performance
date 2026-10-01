function x = ebnoAtPer(ebno, per, target)
%EBNOATPER Eb/No (dB) where a PER curve first drops to TARGET (linear interp).
%   Returns NaN if the curve never reaches the target on this grid.
x = NaN;
i = find(per <= target, 1);
if isempty(i), return; end
if i == 1, x = ebno(1); return; end
x = interp1(per([i-1 i]), ebno([i-1 i]), target);
end
