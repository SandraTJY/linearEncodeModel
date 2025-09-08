%% LEMGrin_loadBhvNeuralData
% A script for the LEM_Grin study for data loading script to load and compile 
% the behavioural and neural data and organise them as a table, stored in the 
% object obj, for running the configuration.

%% --- Define subjects and sessions ---
% sessionList = {'2024-09-16_2_JM007'};
sessionList = options.expRef;

%% --- Loop through sessions ---
if ~exist('allObjs', 'var') || isempty(allObjs)
    allObjs = struct();
end

% Initialise missing files record
missingFiles = struct();  % Will store session -> missing files

% Session loop
for iSub = 1:length(sessionList)
    session = sessionList{iSub};
    obj = struct(); % start fresh for each session
    problematicTrials = [];  % initialize

    try
        missingInThisSession = {};  % temporary list for this session

        %% --- Behavioural file ---
        bhvFile = fullfile(options.bhvDataRoot, session, strcat(session, options.bhvFileExtension));
        if ~isfile(bhvFile)
            warning('Missing behavioural file: %s', bhvFile);
            missingInThisSession{end+1} = bhvFile;
        end

        %% --- Neural file ---
        neuralFile = fullfile(options.neuralDataRoot, session, options.neuralFileExtension);
        if ~isfile(neuralFile)
            warning('Missing neural file: %s', neuralFile);
            missingInThisSession{end+1} = neuralFile;
        end

        %% --- Timestamp file ---
        timestampFile = fullfile(options.neuralDataRoot, session, strcat(session, options.neuralDataTimestampExtension));
        if ~isfile(timestampFile)
            warning('Missing timestamp file: %s', timestampFile);
            missingInThisSession{end+1} = timestampFile;
        end

        if ~isempty(missingInThisSession)
            missingFiles.(matlab.lang.makeValidName(session)) = missingInThisSession;
            fprintf('Skipping session %s due to missing files.\n', session);
            continue;
        end

        %% --- Load files ---
        bhvTable = readtable(bhvFile, 'Delimiter', ',', 'ReadVariableNames', true);
        bhvTable.Properties.VariableNames = matlab.lang.makeValidName(bhvTable.Properties.VariableNames);
        obj.bhv = bhvTable;

        neuralTable = readtable(neuralFile);
        timestamp = load(timestampFile);
        if length(timestamp) ~= width(neuralTable)
            timestamp = timestamp(1:width(neuralTable), :)/20000;
        end

        neuralArray = table2array(neuralTable)';
        cellNames = strcat("cell", string(0:(size(neuralArray, 2)-1)));
        obj.neural = array2table(neuralArray, 'VariableNames', cellNames);
        obj.neural.time = timestamp;

        %% --- Trial timing ---
        obj.bhv.trialStartTime = obj.bhv.trialStartTime;
        obj.bhv.trialEndTime   = obj.bhv.endTrialTime;
        obj.bhv.trialDuration  = obj.bhv.trialEndTime - obj.bhv.trialStartTime;

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
    
        %% --- Populate trial columns ---
        for t = 1:nTrials
            try
                %% --- Populate expanded stimContrast with Ori ---
                cL = obj.bhv.contrastLeft(t);
                cR = obj.bhv.contrastRight(t);

                % Assign side and Ori based on non-zero contrast
                if ~(cL == 0 && cR == 0)
                    if cL ~= 0
                        sideStim = 'L';
                        cVal = cL;
                        if ismember('LeftOri', obj.bhv.Properties.VariableNames)
                            oriNum = obj.bhv.LeftOri(t);
                        else
                            oriNum = 0;  % fallback
                            warning('Session %s, trial %d: LeftOri column missing. Using 0 as default.', session, t);
                        end
                    else
                        sideStim = 'R';
                        cVal = cR;
                        if ismember('RightOri', obj.bhv.Properties.VariableNames)
                            oriNum = obj.bhv.RightOri(t);
                        else
                            oriNum = 0;  % fallback
                            warning('Session %s, trial %d: RightOri column missing. Using 0 as default.', session, t);
                        end
                    end
                    idx = find(contrastLevels == abs(cVal));
                    if ~isempty(idx)
                        cLabel = contrastLabels{idx};
                        colName = ['stimContrast' sideStim cLabel 'Ori' fmtOri(oriNum)];
                        obj.bhv.(colName)(t) = 1;
                    end
                end

                % Choice columns
                if ismember('choice', obj.bhv.Properties.VariableNames)
                    ch = obj.bhv.choice{t};
                    if strcmp(ch, 'Right')
                        obj.bhv.choiceR(t) = 1;
                    elseif strcmp(ch, 'Left')
                        obj.bhv.choiceL(t) = 1;
                    end
                end

                % Reward columns
                if ismember('rewardTime', obj.bhv.Properties.VariableNames) && ...
                        ismember('feedback', obj.bhv.Properties.VariableNames)

                    if ~isempty(obj.bhv.rewardTime(t)) && ~isnan(obj.bhv.rewardTime(t)) && ...
                            strcmp(obj.bhv.feedback(t), 'Rewarded')
                        if strcmp(ch, 'Right'), sideCh = 'R'; else, sideCh = 'L'; end
                        idx = find(contrastLevels == abs(cVal));
                        if ~isempty(idx)
                            cLabel = contrastLabels{idx};
                            rmStr = fmtNum(obj.bhv.expectedRewardValue(t));
                            colName = ['reward' sideCh cLabel 'RewMag' rmStr];
                            obj.bhv.(colName)(t) = 1;
                        end
                    elseif strcmp(obj.bhv.feedback(t), 'Unrewarded')
                        if strcmp(ch, 'Right'), sideCh = 'R'; else, sideCh = 'L'; end
                        idx = find(contrastLevels == abs(cVal));
                        if ~isempty(idx)
                            cLabel = contrastLabels{idx};
                            rmStr = fmtNum(obj.bhv.expectedRewardValue(t));
                            colName = ['Unreward' sideCh cLabel 'RewMag' rmStr];
                            obj.bhv.(colName)(t) = 1;
                        end
                    end
                end

                % Punish & Go cue
                if ismember('punishSoundOnsetTime', obj.bhv.Properties.VariableNames) && ...
                        ~isnan(obj.bhv.punishSoundOnsetTime(t))
                    obj.bhv.punishSound(t) = 1;
                end
                if ismember('goCueTime', obj.bhv.Properties.VariableNames) && ...
                        ~isnan(obj.bhv.goCueTime(t))
                    obj.bhv.goCue(t) = 1;
                end

            catch ME
                warning('Error processing trial %d: %s', t, ME.message);
                problematicTrials(end+1) = t;
                continue;
            end
        end

    catch ME
        warning('Error processing session %s: %s', session, ME.message);
    end

    % --- Save session anyway ---
    sessionField = matlab.lang.makeValidName(['session_' session]);
    allObjs.(sessionField) = obj;
    if exist('problematicTrials','var') && ~isempty(problematicTrials)
        fprintf('Problematic trials detected in session %s: %s\n', session, mat2str(problematicTrials));
    end
    fprintf('Saved session %s into allObjs.%s\n', session, sessionField);
end

%% --- Display summary of missing files ---
missingSessions = fieldnames(missingFiles);
if ~isempty(missingSessions)
    fprintf('\nMissing files were found in the following sessions:\n');
    for k = 1:numel(missingSessions)
        s = missingSessions{k};
        fprintf('Session %s:\n', s);
        for f = 1:numel(missingFiles.(s))
            fprintf('   %s\n', missingFiles.(s){f});
        end
    end
else
    disp('All files found successfully.');
end

