function SourceBeam(BeamWidth, theta, DI, envfil)
%% Generate a BELLHOP source beam pattern file.
% BeamWidth: target half beamwidth in degrees. Values <=0 or >=360 are
% treated as omnidirectional.
% theta:     reference angle vector in degrees.
% DI:        reference linear directivity amplitude at theta.
% envfil:    output file root, without the .sbp suffix.

validateattributes(BeamWidth, {'numeric'}, {'vector', 'nonempty', 'real'}, mfilename, 'BeamWidth');
validateattributes(theta, {'numeric'}, {'vector', 'nonempty', 'real'}, mfilename, 'theta');
validateattributes(DI, {'numeric'}, {'vector', 'nonempty', 'real', 'nonnegative'}, mfilename, 'DI');

theta = theta(:).';
DI = DI(:).';
if numel(theta) ~= numel(DI)
    error('SourceBeam:SizeMismatch', 'theta and DI must have the same length.');
end
if any(~isfinite(theta)) || any(~isfinite(DI))
    error('SourceBeam:NonFiniteInput', 'theta and DI must be finite.');
end

[theta, sortIdx] = sort(theta);
DI = DI(sortIdx);
[theta, uniqueIdx] = unique(theta, 'stable');
DI = DI(uniqueIdx);

targetWidth = BeamWidth(end);
if isOmnidirectional(targetWidth, DI)
    write_sbp(envfil, theta, zeros(size(theta)));
    return;
end

referenceWidth = estimateHalfBeamwidth(theta, DI);
if ~isfinite(referenceWidth) || referenceWidth <= 0
    error('SourceBeam:InvalidReferencePattern', ...
        'Cannot estimate a positive half beamwidth from the reference DI pattern.');
end

targetDI = resampleBeamPattern(theta, DI, referenceWidth, targetWidth);
targetDI = max(targetDI, realmin);
targetDI_dB = 20 * log10(targetDI);
write_sbp(envfil, theta, targetDI_dB);
end

function tf = isOmnidirectional(targetWidth, DI)
tf = targetWidth <= 0 || targetWidth >= 360 || ...
    (max(DI) - min(DI)) <= eps(max(1, max(DI)));
end

function width = estimateHalfBeamwidth(theta, DI)
[peakValue, peakIdx] = max(DI);
halfValue = peakValue / sqrt(2);
theta0 = theta(peakIdx);
offset = wrapTo180Local(theta - theta0);
[offset, sortIdx] = sort(offset);
pattern = DI(sortIdx);

rightIdx = find(offset >= 0 & pattern <= halfValue, 1, 'first');
leftIdx = find(offset <= 0 & pattern <= halfValue, 1, 'last');

rightWidth = interpolateCrossing(offset, pattern, halfValue, rightIdx, -1);
leftWidth = -interpolateCrossing(offset, pattern, halfValue, leftIdx, 1);
widths = [leftWidth, rightWidth];
width = mean(widths(isfinite(widths)));
end

function crossing = interpolateCrossing(offset, pattern, level, idx, neighborStep)
crossing = NaN;
neighborIdx = idx + neighborStep;
if isempty(idx) || neighborIdx < 1 || neighborIdx > numel(offset)
    return;
end

x = [offset(neighborIdx), offset(idx)];
y = [pattern(neighborIdx), pattern(idx)];
if y(1) == y(2)
    crossing = offset(idx);
else
    crossing = interp1(y, x, level, 'linear');
end
end

function targetDI = resampleBeamPattern(theta, DI, referenceWidth, targetWidth)
scale = referenceWidth / targetWidth;
[peakValue, peakIdx] = max(DI);
theta0 = theta(peakIdx);
offset = wrapTo180Local(theta - theta0);
sourceTheta = theta0 + offset * scale;
sourceTheta = unwrapToInputRange(sourceTheta, min(theta), max(theta));

targetDI = interp1(theta, DI, sourceTheta, 'pchip', min(DI));
targetDI = min(max(targetDI, min(DI)), peakValue);
end

function angle = wrapTo180Local(angle)
angle = mod(angle + 180, 360) - 180;
end

function angle = unwrapToInputRange(angle, minTheta, maxTheta)
while any(angle < minTheta)
    angle(angle < minTheta) = angle(angle < minTheta) + 360;
end
while any(angle > maxTheta)
    angle(angle > maxTheta) = angle(angle > maxTheta) - 360;
end
end
