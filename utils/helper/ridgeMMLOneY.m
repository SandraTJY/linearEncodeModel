function [L, flag] = ridgeMMLOneY(q, d2, n, YVar, alpha2, timeoutSec, startL)
% ridgeMMLOneY - Estimate optimal ridge lambda for a single output using MML
%
% INPUT:
%   q        - number of valid singular values
%   d2       - [q×1] squared singular values of X
%   n        - number of observations
%   YVar     - variance of output variable (norm squared)
%   alpha2   - [q×1] squared SVD-projected output values
%   timeoutSec - (optional) max search time in seconds, default = inf
%   startL   - (optional) starting lambda for search, default = 0
%
% OUTPUT:
%   L        - estimated optimal lambda
%   flag     - fminbnd convergence flag (1 = success, 0 = fail, 2 = timeout)
if nargin < 6 || isempty(timeoutSec)
    timeoutSec = inf;
end
if nargin < 7 || isempty(startL)
    startL = 0;
end
smooth = 7; stepSwitch = 25; stepDenom = 100;
smBuffer = NaN(1, smooth); testValsL = NaN(1, smooth);
smBufferI = 0;
% Negative log-likelihood function
NLLFunc = @(L) -(q*log(L) - sum(log(L + d2(1:q))) ...
    - n*log(YVar - sum(alpha2(1:q)./(L + d2(1:q)))));
done = false; NLL = Inf;
t0 = tic;
% --- Early coarse search around startL ---
patience = 3; noImprovement = 0; bestNLL = Inf; bestL = NaN;
for k = 0:stepSwitch*4
    if toc(t0) > timeoutSec
        warning('Timeout during lambda search');
        [~, idx] = min(smBuffer);
        L = testValsL(idx);
        flag = 2; % timeout but best-so-far
        return;
    end
    currentL = startL + k/4;   % coarse grid around startL
    smBufferI = mod(smBufferI, smooth) + 1;
    prevNLL = NLL;
    NLL = NLLFunc(currentL);
    smBuffer(smBufferI) = NLL;
    testValsL(smBufferI) = currentL;
    if NLL < bestNLL
        bestNLL = NLL;
        bestL = currentL;
        noImprovement = 0;
    else
        noImprovement = noImprovement + 1;
    end
    if noImprovement >= patience
        minL = max(0, bestL - 1);
        maxL = bestL + 1;
        done = true;
        break;
    end
end
% --- Extended search if early stopping not triggered ---
if ~done
    L = currentL;
    NLL = mean(smBuffer);
    while ~done
        if toc(t0) > timeoutSec
            warning('Timeout during extended lambda search');
            L = 1; flag = 0;
            return;
        end
        L = L + L / stepDenom;
        smBufferI = mod(smBufferI, smooth) + 1;
        prevNLL = NLL;
        smBuffer(smBufferI) = NLLFunc(L);
        testValsL(smBufferI) = L;
        NLL = mean(smBuffer);
        if NLL > prevNLL
            smBufferI = smBufferI - floor((smooth-1)/2);
            smBufferI = smBufferI + smooth*(smBufferI<1);
            maxL = testValsL(smBufferI);
            smBufferI = smBufferI - 2;
            smBufferI = smBufferI + smooth*(smBufferI<1);
            minL = testValsL(smBufferI);
            done = true;
        end
    end
end
% --- Refined search using fminbnd ---
opts = optimset('Display', 'off', 'MaxIter', 500, 'MaxFunEvals', 500);
[L, ~, flag] = fminbnd(NLLFunc, max(0, minL), maxL, opts);
end