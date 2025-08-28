%% === Collect DA Beta Kernels Across Sessions ===
allObjsFile = 'allObjs.mat';
load(allObjsFile, 'allObjs', 'allIDs');  % load session objects

nExp = 50; fs = 20; tVec = (0:nExp-1)/fs;
smoothWin = 5; xLimits = [0 1.7];

smoothBeta = @(x) movmean(x, smoothWin);

DA_stim_all = containers.Map();  
DA_rew_all  = containers.Map();  

for s = 1:length(allObjs)
    obj = allObjs{s};
    
    % --- Extract regressor labels & beta kernels ---
    regLabels = obj.crossVal.full.regNames;  
    grandAvgDABeta  = obj.crossVal.full.betaDA;  

    % --- Stimulus regressors ---
    stim_DA = containers.Map(); 
    for i = 1:length(regLabels)
        startIdx = (i-1)*nExp + 1;
        endIdx   = startIdx + nExp - 1;
        regName = regLabels{i};
        if contains(regName,'stimContrast')
            if endIdx <= length(grandAvgDABeta)
                stim_DA(regName) = grandAvgDABeta(startIdx:endIdx); 
            end
        end
    end

    % --- Reward regressors ---
    rew_DA = containers.Map();
    for i = 1:length(regLabels)
        startIdx = (i-1)*nExp + 1;
        endIdx   = startIdx + nExp - 1;
        regName = regLabels{i};
        if contains(regName,'reward')
            if endIdx <= length(grandAvgDABeta)
                rew_DA(regName) = grandAvgDABeta(startIdx:endIdx); 
            end
        end
    end

    % --- Merge L/R kernels per base contrast dynamically ---
    stimKeys = keys(stim_DA);
    baseKeys = unique(cellfun(@(k) regexprep(k, '^stimContrast[LR]?', ''), stimKeys, 'UniformOutput', false));
    for k = 1:length(baseKeys)
        baseKey = baseKeys{k};
        lkey = ['stimContrastL' baseKey]; rkey = ['stimContrastR' baseKey];
        valsDA = {};
        if isKey(stim_DA,lkey), valsDA{end+1}=stim_DA(lkey); end
        if isKey(stim_DA,rkey), valsDA{end+1}=stim_DA(rkey); end
        if ~isempty(valsDA)
            if ~isKey(DA_stim_all, baseKey), DA_stim_all(baseKey)=[]; end
            DA_stim_all(baseKey) = [DA_stim_all(baseKey), cat(2, valsDA{:})];
        end
    end

    % --- Merge reward regressors ---
    rewKeys = keys(rew_DA);
    baseKeys = unique(cellfun(@(k) regexprep(k, '^reward[LR]?', ''), rewKeys, 'UniformOutput', false));
    for k = 1:length(baseKeys)
        baseKey = baseKeys{k};
        lkey = ['rewardL' baseKey]; rkey = ['rewardR' baseKey];
        valsDA = {};
        if isKey(rew_DA,lkey), valsDA{end+1}=rew_DA(lkey); end
        if isKey(rew_DA,rkey), valsDA{end+1}=rew_DA(rkey); end
        if isKey(rew_DA, ['reward' baseKey]), valsDA{end+1}=rew_DA(['reward' baseKey]); end
        if ~isempty(valsDA)
            if ~isKey(DA_rew_all, baseKey), DA_rew_all(baseKey)=[]; end
            DA_rew_all(baseKey) = [DA_rew_all(baseKey), cat(2, valsDA{:})];
        end
    end
end

%% === Plot averaged DA beta kernels across sessions ===
stimKeys = keys(DA_stim_all); rewKeys = keys(DA_rew_all);
nStim = length(stimKeys); nRew = length(rewKeys);

alphas = linspace(1,0.2,max(nStim,nRew))'; 
blues = flipud([linspace(0,0.5,nStim)', linspace(0.2,0.8,nStim)', linspace(0.8,1,nStim)']);

figure

% --- Stimulus-Aligned DA ---
subplot(1,2,1); hold on;
for i=1:nStim
    yMat = DA_stim_all(stimKeys{i});
    yMean = mean(yMat,2,'omitnan');  % average across sessions ignoring NaNs
    p = plot(tVec, smoothBeta(yMean), 'Color', blues(i,:), 'LineWidth', 1.5); 
    p.Color(4)=alphas(i);
end
title('Stimulus-Aligned DA'); xlabel('Time (s)'); ylabel('DA Beta'); xlim(xLimits);

% --- Reward-Aligned DA ---
subplot(1,2,2); hold on;
for i=1:nRew
    yMat = DA_rew_all(rewKeys{i});
    yMean = mean(yMat,2,'omitnan');
    p = plot(tVec, smoothBeta(yMean), 'Color', blues(i,:), 'LineWidth', 1.5); 
    p.Color(4)=alphas(i);
end
title('Reward-Aligned DA'); xlabel('Time (s)'); ylabel('DA Beta'); xlim(xLimits);
