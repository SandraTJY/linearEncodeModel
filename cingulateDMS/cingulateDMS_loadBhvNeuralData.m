%% LEMGrin_loadBhvNeuralData
% A script for the cingulateDMS study for data loading script to load and compile 
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
    session_split = strsplit(session, '_');
    recordingDate = session_split{1};
    sessionID = session_split{2};
    animalID = session_split{3};
    obj = struct(); % start fresh for each session
    problematicTrials = [];  % initialize

    % try
        missingInThisSession = {};  % temporary list for this session

        %% --- Behavioural file ---
        bhvFile = fullfile(options.bhvDataRoot, animalID, session, strcat(session, options.bhvFileExtension));
        if ~isfile(bhvFile)
            warning('Missing behavioural file: %s', bhvFile);
            missingInThisSession{end+1} = bhvFile;
        end

        %% --- Neural file ---
        neuralFile = fullfile(options.neuralDataRoot, animalID, session, strcat(session, options.neuralFileExtension));
        if ~isfile(neuralFile)
            warning('Missing neural file: %s', neuralFile);
            missingInThisSession{end+1} = neuralFile;
        end

        %% --- Timestamp file ---
        timestampFile = dir(fullfile(options.rawDataRoot, animalID, recordingDate, sessionID, ...
                                    (options.neuralDataTimestampExtension)));
        timestampFile = fullfile(timestampFile(1).folder, timestampFile(1).name);
        if ~isfile(timestampFile)
            warning('Missing timestamp file: %s', timestampFile);
            missingInThisSession{end+1} = timestampFile;
        end

        %% --- Licktrace file ---
        lickTraceFile = dir(fullfile(options.bhvDataRoot, animalID, session, (options.lickTraceFileExtension)));
        if ~isempty(lickTraceFile)
            lickTraceFile = fullfile(lickTraceFile(1).folder, lickTraceFile(1).name);
            if isfile(lickTraceFile)
                lickTraceTable = readtable(lickTraceFile, 'Delimiter', ',', 'ReadVariableNames', true);
                obj.lickTrace = lickTraceTable;
            end
        end

        %% --- Exclude session if any files missing ---
        if ~isempty(missingInThisSession)
            missingFiles.(matlab.lang.makeValidName(session)) = missingInThisSession;
            fprintf('Skipping session %s due to missing files.\n', session);
            % continue;
        end

        %% --- Load files ---
        bhvTable = readtable(bhvFile, 'Delimiter', ',', 'ReadVariableNames', true);
        bhvTable.Properties.VariableNames = matlab.lang.makeValidName(bhvTable.Properties.VariableNames);

        % Also, modify any Time column with trialOffsets if applicable
        if ismember('trialOffsets', bhvTable.Properties.VariableNames)
            trialOffsets = bhvTable.trialOffsets;
            % Get Time columns, and reassign their values to incorporate
            % trialOffsets
            mask = find(~cellfun('isempty', regexp(bhvTable.Properties.VariableNames, 'Time')));
            for c = 1:numel(mask)
                colName = string(bhvTable.Properties.VariableNames(mask(c)));
                bhvTable.(colName) = bhvTable.(colName) + trialOffsets; 
            end
        end
        
        % Small code chunk to fill in NaN rewardTimes in unrewarded trials
        rewardTimes = bhvTable.rewardTime; % (options.variableDefs.reward.timeRef);
        stimulusOnsetTimes = bhvTable.stimulusOnsetTime; % (options.variableDefs.stimulus.timeRef);
        rewardTimes(isnan(rewardTimes)) = stimulusOnsetTimes(isnan(rewardTimes)) + 2; %(options.variableDefs.stimulus.betaPostTime);
           
        bhvTable.rewardTime = rewardTimes;
        obj.bhv = bhvTable;

        neuralTable = readtable(neuralFile);
        timestamp = load(timestampFile);
        n_frames = width(neuralTable)-1; %1st column is cellID
        if length(timestamp) ~= n_frames
            timestamp = timestamp(1:n_frames, :)/20000;
        end

        neuralArray = table2array(neuralTable(2:size(neuralTable,1), 2:size(neuralTable,2)))'; % 1st row in neuralTable is frame index, 1st column in neuralTable is cell index. Exclude from downstream analysis otherwise it will be misconstrued as cell0's dff/every cell's 1st frame
        cellNames = strcat("cell", string(0:(size(neuralArray, 2)-1)));
        obj.neural = array2table(neuralArray, 'VariableNames', cellNames);
        obj.neural.time = timestamp;

        %% --- Determine session type ---
        if ismember('rewardProbRev', obj.bhv.Properties.VariableNames)
            options.reversal = 1; % a mid-reversal session
            options.rewProbColumn = 'rewardProbRev';
        else 
            options.reversal = 0; % a non-reversal session
            options.rewProbColumn = 'rewardProb';
        end
        %% --- Trial timing ---
        trialDuration = 6;
        obj.bhv.trialStartTime = obj.bhv.(options.firstTrialEvent);
        obj.bhv.trialEndTime   = obj.bhv.trialStartTime + trialDuration;

        % Get unique stimulus identity (reward probability) names
        obj.bhv.stimName = erase(obj.bhv.(options.rewProbColumn), '% Rewarded'); %remove ' Rewarded' substrings
        rewardProbLabels = unique([obj.bhv.stimName]);

        % Loop through trials
        nTrials = height(obj.bhv);

        % --- Initialise rewardProb columns ---
        for j = 1:numel(rewardProbLabels)
            obj.bhv.(['stim' rewardProbLabels{j}]) = zeros(nTrials,1);
        end

        % --- Initialise reward/noReward (x stim) columns ---
        obj.bhv.rewarded = nan(nTrials,1);
        obj.bhv.unrewarded = nan(nTrials,1);

        % --- StimOnset and RewardOnset ---
        if ismember('stimOnset', fieldnames(options.variableDefs))
            obj.bhv.stimOnset = ones(nTrials,1);
        end
        if ismember('stimOffset', fieldnames(options.variableDefs))
            obj.bhv.stimOffset = ones(nTrials,1);
        end
        if ismember('rewardOnset', fieldnames(options.variableDefs))
            obj.bhv.rewardOnset = (obj.bhv.rewardVolume>0);
            % Rep rewardOnset as (-1,1) not (0,1)?
            obj.bhv.rewardOnset(~obj.bhv.rewardVolume>0) = -1 * ones(size(size(obj.bhv.rewardOnset(~obj.bhv.rewardVolume>0))));
        end

        % --- First lick post-stim --- %
        if ismember('prelickOnset', fieldnames(options.variableDefs))
            varName = options.variableDefs.prelickOnset.vars{1};
            prelickOnsetTimes = obj.bhv.(options.variableDefs.prelickOnset.timeRef);
            obj.bhv.(varName) = zeros(nTrials, 1);
            obj.bhv.(varName)(~isnan(prelickOnsetTimes)) = 1;
        end

        % --- Stimulus X Prelick interaction --- %
        if ismember('stimulusXprelick', fieldnames(options.variableDefs))
            for k = 1:numel(rewardProbLabels)
                trials_mask = strcmp(obj.bhv.stimName, string(rewardProbLabels{k}));
                allTrialsRewarded = sum(obj.bhv.rewardVolume(trials_mask) > 0) == sum(trials_mask);
                allTrialsUnrewarded = sum(obj.bhv.rewardVolume(trials_mask) == 0) == sum(trials_mask);
    
                if allTrialsRewarded % i.e. 100% stim
                    obj.bhv.(['stim' rewardProbLabels{k} '_rewarded']) = nan(nTrials,1);
                elseif allTrialsUnrewarded % i.e. 0% stim
                    obj.bhv.(['stim' rewardProbLabels{k} '_unrewarded']) = nan(nTrials,1);
                elseif ~allTrialsRewarded && ~allTrialsUnrewarded
                    obj.bhv.(['stim' rewardProbLabels{k} '_rewarded']) = nan(nTrials,1);
                    obj.bhv.(['stim' rewardProbLabels{k} '_unrewarded']) = nan(nTrials,1);
                end
            end
        end

        % --- Initialise prelicked columns ---
        if ismember('prelick', fieldnames(options.variableDefs))
            obj.bhv.prelick = nan(nTrials,1);
        end

        % --- Initialise choice columns for relevant bhvTables only ---
        if ismember('choice', obj.bhv.Properties.VariableNames)
            obj.bhv.go = nan(nTrials,1);
            obj.bhv.nogo = nan(nTrials,1);
        end

        %% --- Populate trial-by-trial columns ---
        for t = 1:nTrials
            % try
                
                % rewardProb columns
                stimIdentity = obj.bhv.stimName{t}; %e.g. 0 or '0-->100'
                obj.bhv.(['stim' stimIdentity])(t) = 1;

                % Reward columns
                obj.bhv.rewarded(t) = obj.bhv.rewardVolume(t) > 0;
                obj.bhv.unrewarded(t) = obj.bhv.rewardVolume(t) == 0;

                % Prelicked columns
                if ismember('prelick', obj.bhv.Properties.VariableNames)
                    obj.bhv.prelick(t) = obj.bhv.lickData_binned(t) > 0;
                end

                % Choice columns
                if ismember('choice', obj.bhv.Properties.VariableNames)
                    ch = obj.bhv.choice{t};
                    if strcmp(ch, 'NoGo')
                        obj.bhv.nogo(t) = 1;
                    else
                        obj.bhv.go(t) = 1;
                    end
                end

            % catch ME
            %     warning('Error processing trial %d: %s', t, ME.message);
            %     problematicTrials(end+1) = t;
            %     continue;
            % end
        end

        %% --- Populate interaction columns ---
        % Stim x Rewarded columns
        if ismember('stimulusXreward', fieldnames(options.variableDefs))
            for k = 1:numel(rewardProbLabels)
                if ismember(['stim' rewardProbLabels{k} '_rewarded'], obj.bhv.Properties.VariableNames)
                    obj.bhv.(['stim' rewardProbLabels{k} '_rewarded']) = obj.bhv.(['stim' rewardProbLabels{k}]) & obj.bhv.rewarded;
                end
                if ismember(['stim' rewardProbLabels{k} '_unrewarded'], obj.bhv.Properties.VariableNames)
                    obj.bhv.(['stim' rewardProbLabels{k} '_unrewarded']) = obj.bhv.(['stim' rewardProbLabels{k}]) & obj.bhv.unrewarded;
    
                end
            end
        end

        % Stim x Prelicked columns
        if ismember('stimulusXprelick', fieldnames(options.variableDefs))
            for k = 1:numel(rewardProbLabels)
                trials_mask = strcmp(obj.bhv.stimName, string(rewardProbLabels{k}));
                allTrialsPrelicked = sum(obj.bhv.prelick(trials_mask) > 0) == sum(trials_mask);
                allTrialsNonlicked = sum(obj.bhv.prelick(trials_mask) == 0) == sum(trials_mask);
                if ~allTrialsPrelicked && ~allTrialsNonlicked
                    obj.bhv.(['stim' rewardProbLabels{k} '_prelicked']) = obj.bhv.(['stim' rewardProbLabels{k}]) & obj.bhv.prelick;
                    obj.bhv.(['stim' rewardProbLabels{k} '_nonlicked']) = obj.bhv.(['stim' rewardProbLabels{k}]) & ~obj.bhv.prelick;
                end
            end
        end


    % catch ME
    %     warning('Error processing session %s: %s', session, ME.message);
    % end

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

