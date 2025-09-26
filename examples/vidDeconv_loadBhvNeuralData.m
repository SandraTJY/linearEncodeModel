%% vidDeconv_loadBhvNeuralData
% An example data loading script to load and compile the behavioural data and
% organise them as a table, stored in the object obj, for running the
% configuration.

% Define subjects and sessions
mouseList = {'MFE008'};
sessionList = {'2022-09-13_1'};
options = vidDeconv_options;
options.plotDesignMatrix = true;

for i = 1:length(mouseList)
    mouse = mouseList{i};
    session = sessionList{i};
    expRef = strcat(session, '_', mouse);
    lookupKey = strcat(expRef(1:10), '_', expRef(12), '_', mouse);

    % --- Load the behavioural file ---
    bhvFile = fullfile(options.bhvDataRoot, [(mouse), options.bhvFileExtension]);
    opts = detectImportOptions(bhvFile, 'Delimiter', ',', 'ReadVariableNames', true);
    bhvTable = readtable(bhvFile, opts);

    % --- Load neural data ---
    neuralFile = fullfile(options.neuralDataRoot, [(mouse), options.neuralFileExtension]);
    neuralTable = readtable(neuralFile, opts);
    
    % Put the data tables of this animal and session to obj
    obj.neural = neuralTable(strcmp(neuralTable.expRef, lookupKey), :);
    obj.neural.Timestamp = str2double(obj.neural.Timestamp); % Some data wrangling due to formatting issues
    obj.bhv = bhvTable(strcmp(bhvTable.expRef, lookupKey), :);

    % Indicate the trial start and end time per trial
    for t = 1:height(obj.bhv)
        obj.bhv.trialStartTime(t) = obj.bhv.stimulusOnsetTime(t);
        obj.bhv.trialEndTime(t) = obj.bhv.outcomeTime(t);
    end
    
    % Calculate the trial duration (as exact, no kernel lags) per trial
    for t = 1:height(obj.bhv)
        obj.bhv.trialDuration(t) = obj.bhv.outcomeTime(t) - obj.bhv.stimulusOnsetTime(t);
    end
    
    % Define contrast values and their corresponding string labels
    contrastLevels = [0, 0.0625, 0.125, 0.25, 0.5, 1];
    contrastLabels = {'0', '00625', '0125', '025', '05', '1'};
    
    % Loop through trials
    nTrials = height(obj.bhv);

    % As stimContrast0 does not have any laterality, initalise it
    % separately
    obj.bhv.stimContrast0 = nan(nTrials, 1);  % Special column for 0% contrast
    
    % Initialise stimContrast columns (without 0 contrast) to NaN
    for j = 2:numel(contrastLevels)
        % For stimulus contrasts
        colNameR = ['stimContrastR' contrastLabels{j}];
        colNameL = ['stimContrastL' contrastLabels{j}];
        obj.bhv.(colNameR) = nan(nTrials,1);
        obj.bhv.(colNameL) = nan(nTrials,1);
    end

    % Initalise reward and noReward columns with all contrast levels
    for k = 1:numel(contrastLevels)
        % For reward (rewarded + unrewarded)
        obj.bhv.(['rewardR' contrastLabels{k}]) = nan(nTrials,1);
        obj.bhv.(['rewardL' contrastLabels{k}]) = nan(nTrials,1);
        obj.bhv.(['noRewardR' contrastLabels{k}]) = nan(nTrials,1);
        obj.bhv.(['noRewardL' contrastLabels{k}]) = nan(nTrials,1);
    end
    
    % Choice columns
    obj.bhv.choiceR = nan(nTrials,1);
    obj.bhv.choiceL = nan(nTrials,1);
    
    % Populate the columns based on logic
    for t = 1:nTrials
        c = obj.bhv.contrast(t);
        ch = obj.bhv.choice{t};       % 'Right' or 'Left'
        fb = obj.bhv.feedback{t};     % 'Rewarded' or 'Unrewarded'
        
        % --- Stimulus Contrast ---
        if c == 0
            obj.bhv.('stimContrast0')(t) = 1;
        elseif c > 0
            idx = find(contrastLevels == c);
            if ~isempty(idx)
                obj.bhv.(['stimContrastR' contrastLabels{idx}])(t) = 1;
            end
        elseif c < 0
            idx = find(contrastLevels == abs(c));
            if ~isempty(idx)
                obj.bhv.(['stimContrastL' contrastLabels{idx}])(t) = 1;
            end
        end
    
        % --- Choice ---
        if strcmp(ch, 'Right')
            obj.bhv.choiceR(t) = 1;
        elseif strcmp(ch, 'Left')
            obj.bhv.choiceL(t) = 1;
        end
    
        % --- Reward ---
        if c ~= 0 && ~isempty(ch)
            absC = abs(c);
            idx = find(contrastLevels == absC);
            if ~isempty(idx)
                label = contrastLabels{idx};
                if strcmp(fb, 'Rewarded')
                    if strcmp(ch, 'Right')
                        obj.bhv.(['rewardR' label])(t) = 1;
                    elseif strcmp(ch, 'Left')
                        obj.bhv.(['rewardL' label])(t) = 1;
                    end
                elseif strcmp(fb, 'Unrewarded')
                    if strcmp(ch, 'Right')
                        obj.bhv.(['noRewardR' label])(t) = 1;
                    elseif strcmp(ch, 'Left')
                        obj.bhv.(['noRewardL' label])(t) = 1;
                    end
                end
            end
        elseif c == 0 && ~isempty(ch)
            % Handle special case for 0% contrast
            label = '0';
            if strcmp(fb, 'Rewarded')
                if strcmp(ch, 'Right')
                    obj.bhv.(['rewardR' label])(t) = 1;
                elseif strcmp(ch, 'Left')
                    obj.bhv.(['rewardL' label])(t) = 1;
                end
            elseif strcmp(fb, 'Unrewarded')
                if strcmp(ch, 'Right')
                    obj.bhv.(['noRewardR' label])(t) = 1;
                elseif strcmp(ch, 'Left')
                    obj.bhv.(['noRewardL' label])(t) = 1;
                end
            end
        end
    end

    % Initialise choiceHistory column
    obj.bhv.choiceHistory = nan(nTrials,1);

    % Compute choiceHistory based on previous trial's choice
    for t = 2:nTrials % there is no choice history on the 1st trial
        prevChoice = obj.bhv.choice{t-1};
        if strcmp(prevChoice, 'Right')
            obj.bhv.choiceHistory(t) = 1;
        elseif strcmp(prevChoice, 'Left')
            obj.bhv.choiceHistory(t) = -1;
        else
            obj.bhv.choiceHistory(t) = nan; % no response / missing
        end
    end
end
