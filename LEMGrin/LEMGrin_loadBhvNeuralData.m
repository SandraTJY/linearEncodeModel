%% LMEGrin_loadBhvNeuralData
% A script for the LRM_Grin study for data loading script to load and compile 
% the behavioural and neural data and organise them as a table, stored in the 
% object obj, for running the configuration.

% Define subjects and sessions
mouseList = {'JM007'};
sessionList = {'2024-09-16_2'};

for i = 1:length(mouseList)
    mouse = mouseList{i};
    session = sessionList{i};
    expRef = strcat(session, '_', mouse);
    lookupKey = strcat(expRef(1:10), '_', expRef(12), '_', mouse);
    opts = detectImportOptions(bhvFile, 'Delimiter', ',', 'ReadVariableNames', true);

    % --- Load neural data ---
    neuralFile = fullfile(options.neuralDataRoot, ...
    strcat(sessionList, '_', mouse), ...
    options.neuralFileExtension);
    neuralTable = readtable(string(neuralFile));

    % --- Load the behavioural file ---
    bhvFile = fullfile(options.bhvDataRoot, ...
        strcat(sessionList, '_', mouse), ...
    strcat(sessionList, '_', mouse, options.bhvFileExtension));
    bhvTable = readtable(string(bhvFile), 'Delimiter', ',', 'ReadVariableNames', true);
    
    % Put the data tables of this animal and session to obj
    obj.neural = neuralTable;
    timestamp = load(string(fullfile(options.neuralDataRoot, ...
    strcat(sessionList, '_', mouse), strcat(sessionList, '_', mouse, options.neuralDataTimestampExtension)))); % Some data wrangling due to formatting issues
    if length(timestamp) ~= width(obj.neural)
        timestamp = timestamp(1:width(obj.neural), :);
    end
    obj.neuralTimestamps = timestamp;
    obj.bhv = bhvTable;

    % Indicate the trial start and end time per trial
    for t = 1:height(obj.bhv)
        obj.bhv.trialStartTime(t) = obj.bhv.trialStartTime(t);
        obj.bhv.trialEndTime(t) = obj.bhv.endTrialTime(t);
    end
    
    % Calculate the trial duration (as exact, no kernel lags) per trial
    for t = 1:height(obj.bhv)
        obj.bhv.trialDuration(t) = obj.bhv.trialEndTime(t) - obj.bhv.trialStartTime(t);
    end
    
    % Define contrast values and their corresponding string labels
    % contrastLevels = [0, 0.0625, 0.125, 0.25, 0.5, 1];
    % contrastLabels = {'0', '00625', '0125', '025', '05', '1'};
    
    % Get unique contrast values from both sides
    contrastLevels = unique([obj.bhv.contrastLeft; obj.bhv.contrastRight]);
    
    % Initialise labels
    contrastLabels = cell(size(contrastLevels));
    
    for i = 1:length(contrastLevels)
        val = contrastLevels(i);
        if val == 0
            contrastLabels{i} = '0';
        elseif val == 1
            contrastLabels{i} = '1';
        else
            % Convert to string without '0.'
            s = strrep(num2str(val), '0.', '');
            % Remove trailing zeros (like 0.2500 -> '025')
            s = regexprep(s, '0+$', '');
            contrastLabels{i} = s;
        end
    end
    
    % Loop through trials
    nTrials = height(obj.bhv);
    
    % --- Initialise stimContrast columns ---
    obj.bhv.stimContrast0 = nan(nTrials, 1); % special 0% contrast column
    for j = 2:numel(contrastLevels)
        colNameR = ['stimContrastR' contrastLabels{j}];
        colNameL = ['stimContrastL' contrastLabels{j}];
        obj.bhv.(colNameR) = nan(nTrials,1);
        obj.bhv.(colNameL) = nan(nTrials,1);
    end
    
    % --- Initialise reward/noReward columns ---
    for k = 1:numel(contrastLevels)
        obj.bhv.(['rewardR' contrastLabels{k}]) = nan(nTrials,1);
        obj.bhv.(['rewardL' contrastLabels{k}]) = nan(nTrials,1);
        obj.bhv.(['noRewardR' contrastLabels{k}]) = nan(nTrials,1);
        obj.bhv.(['noRewardL' contrastLabels{k}]) = nan(nTrials,1);
    end
    
    % --- Initialise choice columns ---
    obj.bhv.choiceR = nan(nTrials,1);
    obj.bhv.choiceL = nan(nTrials,1);
    
    % --- Initialise new columns ---
    obj.bhv.punishSound = nan(nTrials,1);
    obj.bhv.goCue = nan(nTrials,1);
    
    % --- Populate columns ---
    for t = 1:nTrials
        % --- Stimulus contrast ---
        cL = obj.bhv.contrastLeft(t);
        cR = obj.bhv.contrastRight(t);
    
        if cL == 0 && cR == 0
            obj.bhv.stimContrast0(t) = 1;
        else
            if cL ~= 0
                idx = find(contrastLevels == abs(cL));
                if ~isempty(idx)
                    obj.bhv.(['stimContrastL' contrastLabels{idx}])(t) = 1;
                end
            end
            if cR ~= 0
                idx = find(contrastLevels == abs(cR));
                if ~isempty(idx)
                    obj.bhv.(['stimContrastR' contrastLabels{idx}])(t) = 1;
                end
            end
        end
    
        % --- Choice ---
        ch = obj.bhv.choice{t};
        if strcmp(ch, 'Right')
            obj.bhv.choiceR(t) = 1;
        elseif strcmp(ch, 'Left')
            obj.bhv.choiceL(t) = 1;
        end
    
        % --- Reward ---
        if ~isnan(obj.bhv.rewardTime(t)) && strcmp(obj.bhv.feedback(t),'Rewarded') && obj.bhv.rewardTime(t) ~= 0 && ~isempty(ch)
            if strcmp(ch, 'Right')
                side = 'R';
                cVal = cR; 
            elseif strcmp(ch, 'Left')
                side = 'L';
                cVal = cL; 
            end
            idx = find(contrastLevels == abs(cVal));
            if ~isempty(idx)
                label = contrastLabels{idx};
                obj.bhv.(['reward' side label])(t) = 1;
            end
        elseif ~isempty(ch) && strcmp(obj.bhv.feedback(t),'Unrewarded')
            % No reward case
            if strcmp(ch, 'Right')
                side = 'R';
                cVal = cR;
            elseif strcmp(ch, 'Left')
                side = 'L';
                cVal = cL;
            end
            idx = find(contrastLevels == abs(cVal));
            if ~isempty(idx)
                label = contrastLabels{idx};
                obj.bhv.(['noReward' side label])(t) = 1;
            end
        end
    
        % --- Punish sound ---
        if ~isnan(obj.bhv.punishSoundOnsetTime(t))
            obj.bhv.punishSound(t) = 1;
        end
    
        % --- Go cue ---
        if ~isnan(obj.bhv.goCueTime(t))
            obj.bhv.goCue(t) = 1;
        end
    end
end