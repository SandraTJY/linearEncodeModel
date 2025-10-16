function [X, Y] = normaliseAndRecentre(X, Y, normaliseX)
% *normaliseAndRecentre*: Normalises and optionally recentres X and Y matrices
% INPUT:
% X        - design matrix [nFrames x nPredictors]
% Y        - output matrix [nFrames x nOutputs]

% OUTPUT:
% X, Y     - normalised and recentered matrices

[~, p] = size(X);
pY = size(Y, 2);

% Compute means and stds
XStd = std(X, 0, 1);
XMean = mean(X, 1);
YMean = mean(Y, 1);
if normaliseX
    X = bsxfun(@rdivide, X, XStd);  % normalise if asked
    X = bsxfun(@minus, X, XMean);
end

Y = bsxfun(@minus, Y, YMean);

% Prepare XTX, ep, renorm, betas
% XTX = X' * X;
% ep = eye(p);
% renorm = XStd';
% betas = NaN(p, pY);

end


