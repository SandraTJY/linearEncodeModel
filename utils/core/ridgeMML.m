function [lambda, betas, convergenceFailures] = ridgeMML(X, Y, lambda, verbose, timeoutSec)
% ridgeMML: Ridge Regression using Marginal Maximum Likelihood (MML)
% Supports flexible lambda input: empty, scalar, or vector/grid.
%
% INPUT:
%   X: [n x p] design matrix
%   Y: [n x pY] outcome matrix
%   lambda: optional
%       []       -> automatic MML search
%       scalar   -> fixed lambda for all outputs
%       vector   -> treated as a grid of starting points for MML
%   verbose: (optional) logical, default = true
%   timeoutSec: (optional) numeric, default = 30 seconds per output
%
% OUTPUT:
%   lambda: [1 x pY] optimal ridge parameters
%   betas: [p+1 x pY] ridge coefficients (includes intercept)
%   convergenceFailures: [1 x pY] logical flags (true = failed)

    % ----------------------------
    % Defaults and checks
    % ----------------------------
    if nargin < 5 || isempty(timeoutSec), timeoutSec = 30; end
    if nargin < 4 || isempty(verbose), verbose = true; end

    if size(X,1) ~= size(Y,1)
        error('X and Y must have the same number of rows.');
    end

    [n, pX] = size(X);
    pY = size(Y,2);

    convergenceFailures = false(1, pY);

    % ----------------------------
    % Handle lambda input
    % ----------------------------
    if isempty(lambda)
        computeLambda = true;
        lambdaGrid = [];
    elseif isscalar(lambda)
        computeLambda = false;
        lambda = repmat(lambda, 1, pY);
    elseif isnumeric(lambda) && numel(lambda) > 1
        computeLambda = true;
        lambdaGrid = lambda(:)';
    else
        error('Invalid lambda input: must be empty, scalar, or numeric vector.');
    end

    % ----------------------------
    % Compute SVD quantities
    % ----------------------------
    if issparse(X)
        [U, S, V] = svds(X, min(size(X)));
    else
        [U, S, V] = svd(X, 0);
    end

    d = diag(S);
    d2 = d.^2;
    q = numel(d);
    alph = S * U' * Y;
    alpha2 = alph.^2;
    YVar = sum(Y.^2, 1);

    lambdaPrior = 1;
    lambdaPriorWeight = 0;
    lambdaMin = 1e-6;
    lambdaOut = NaN(1, pY);

    % ----------------------------
    % MML loop per output
    % ----------------------------
    for i = 1:pY
        if computeLambda
            % choose start lambda
            if exist('lambdaGrid','var') && ~isempty(lambdaGrid)
                startLambda = median(lambdaGrid);
            else
                startLambda = 1;
            end

            % estimate lambda using MML (ridgeMMLOneY handles optimization)
            [lambda_i, flag] = ridgeMMLOneY(q, d2, n, YVar(i), alpha2(:,i), timeoutSec, startLambda);

            % apply weak prior and floor
            if lambdaPriorWeight > 0
                lambda_i = (lambda_i + lambdaPriorWeight * lambdaPrior) / (1 + lambdaPriorWeight);
            end
            lambda_i = max(lambda_i, lambdaMin);
            lambdaOut(i) = lambda_i;
            convergenceFailures(i) = (flag < 1);

        else
            lambdaOut(i) = lambda(i);
        end

        if verbose && mod(i,10)==0
            fprintf('[%s] MML selected lambda for %d/%d\n', datestr(now,'HH:MM:SS'), i, pY);
        end
    end

    lambda = lambdaOut;

    % ----------------------------
    % Compute final ridge regression betas
    % ----------------------------
    Xfull = [ones(n,1), X];
    p = size(Xfull,2);
    ep = eye(p); ep(1,1) = 0;  % do not penalize intercept
    XTX = Xfull' * Xfull;
    XTY = Xfull' * Y;

    betas = NaN(p, pY);
    for i = 1:pY
        betas(:,i) = (XTX + lambda(i)*ep) \ XTY(:,i);
    end
    betas(isnan(betas)) = 0;
end
