function [laggedMat, lags] = expandSingleRegressor(trace, preFrames, postFrames)
% EXPANDSINGLEGRESSOR Expands a single regressor into time-shifted columns.
%   - trace: [nFrames x 1] vector of regressor values
%   - preFrames: number of frames before event to include (can be 0)
%   - postFrames: number of frames after event to include
%
% OUTPUTS:
%   - laggedMat: [nFrames x nLags] time-expanded regressor matrix
%   - lags: vector of lag indices corresponding to columns of laggedMat

nFrames = length(trace);
lags = -preFrames:(postFrames-1);  % includes 0 and postFrames
nLags = length(lags);

laggedMat = zeros(nFrames, nLags);

for iLag = 1:nLags
    lag = lags(iLag);
    
    if lag < 0
        % Pre-event lag
        shifted = [trace(-lag+1:end); zeros(-lag, 1)];
    elseif lag > 0
        % Post-event lag
        shifted = [zeros(lag, 1); trace(1:end-lag)];
    else
        % Zero lag (current frame)
        shifted = trace;
    end
    
    laggedMat(:, iLag) = shifted;
end
end
