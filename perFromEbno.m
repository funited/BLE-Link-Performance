function p = perFromEbno(ebnoGrid, perCurve, x)
%PERFROMEBNO Look up PER for any Eb/No (scalar or matrix) from a simulated curve.
%   Below the simulated range PER = 1, above it PER = 0.
p = interp1(ebnoGrid, perCurve, x, 'linear');
p(x < ebnoGrid(1))   = 1;
p(x > ebnoGrid(end)) = 0;
end
