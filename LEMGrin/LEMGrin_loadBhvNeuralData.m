%% LEMGrin_loadBhvNeuralData
% A script for the LEM_Grin study for data loading script to load and compile 
% the behavioural and neural data and organise them as a table, stored in the 
% object obj, for running the configuration.

%% --- Define subjects and sessions ---
% sessionList = {'2024-09-16_2_JM007'};
sessionList = options.expRef;

%% --- Loop through mice / sessions ---
if ~exist('allObjs', 'var') || isempty(allObjs)
    allObjs = struct();
end

% for iSub = 1:length(sessionList)
for iSub = [2,3,5]
    session = sessionList{iSub};

    %% --- Load behavioural file ---
    bhvFile = fullfile(options.bhvDataRoot, ...
        session, ...
        strcat(session, options.bhvFileExtension));
    bhvTable = readtable(bhvFile, 'Delimiter', ',', 'ReadVariableNames', true);
    obj.bhv = bhvTable;

    %% --- Load neural data ---
    neuralFile = fullfile(options.neuralDataRoot, ...
        session, ...
        options.neuralFileExtension);
    neuralTable = readtable(neuralFile);

    %% --- Load neural timestamps ---
    timestampFile = fullfile(options.neuralDataRoot, ...
        session, ...
        strcat(session, options.neuralDataTimestampExtension));
    timestamp = load(timestampFile);
    if length(timestamp) ~= width(neuralTable)
        timestamp = timestamp(1:width(neuralTable), :)/20000;
    end

    %% --- Rename variables in neural data ---
    % Convert to numeric array first
    neuralArray = table2array(neuralTable);
    
    % Transpose to timepoints x cells
    neuralArrayT = neuralArray';
    
    % Convert back to table with proper column names
    cellNames = strcat("cell", string(0:(size(neuralArrayT, 2)-1)));  % 'cell0', 'cell1', ..., 'cell24'
    obj.neural = array2table(neuralArrayT, 'VariableNames', cellNames); 
    obj.neural.time = timestamp;
    
    %% --- Trial timing ---
    obj.bhv.trialStartTime = obj.bhv.trialStartTime;
    obj.bhv.trialEndTime = obj.bhv.endTrialTime;
    obj.bhv.trialDuration = obj.bhv.trialEndTime - obj.bhv.trialStartTime;

    %% --- Contrast setup ---
    contrastLevels = unique([obj.bhv.contrastLeft; obj.bhv.contrastRight]);
    contrastLabels = cell(size(contrastLevels));
    for j = 1:length(contrastLevels)
        val = contrastLevels(j);
        if val == 0
            contrastLabels{j} = '0';
        elseif val == 1
            contrastLabels{j} = '1';
        else
            % Scale by 10000, pad to 5 digits, strip trailing zeros
            scaled = round(val * 10000); 
            s = sprintf('%05d', scaled); 
            s = regexprep(s, '0+$', '');  % remove trailing zeros
            contrastLabels{j} = s;
        end
    end

    nTrials = height(obj.bhv);

    % %% --- Initialise base stimContrast columns (existing behaviour) ---
    % obj.bhv.stimContrast0 = nan(nTrials, 1);
    % for j = 2:numel(contrastLevels)  % skip 0 (handled by stimContrast0)
    %     obj.bhv.(['stimContrastR' contrastLabels{j}]) = nan(nTrials,1);
    %     obj.bhv.(['stimContrastL' contrastLabels{j}]) = nan(nTrials,1);
    % end
    % 
    % %% --- Initialise reward/noReward columns (existing behaviour) ---
    % for k = 1:numel(contrastLevels)
    %     obj.bhv.(['rewardR' contrastLabels{k}])   = nan(nTrials,1);
    %     obj.bhv.(['rewardL' contrastLabels{k}])   = nan(nTrials,1);
    %     obj.bhv.(['noRewardR' contrastLabels{k}]) = nan(nTrials,1);
    %     obj.bhv.(['noRewardL' contrastLabels{k}]) = nan(nTrials,1);
    % end

    %% --- helper to format orientation numbers safely ---
    % Keeps integers intact (e.g., 90 -> '90', 0 -> '0') and formats decimals (22.5 -> '22_5')
    fmtOri = @(x) strrep(regexprep(num2str(x), '(\.\d*?)0+$', '$1'), '.', '_');
    fmtNum = @(x) strrep(regexprep(num2str(x), '\.?0+$',''), '.', '_');

    % %% --- Initialise expanded stimContrast (with Ori) columns ---
    % % All unique orientation values (include 0), remove NaN if present
    % oriLevels = unique([obj.bhv.LeftOri; obj.bhv.RightOri]);
    % oriLevels(isnan(oriLevels)) = [];
    % 
    % for j = 2:numel(contrastLevels)   % non-zero contrasts only
    %     cLabel = contrastLabels{j};
    %     for sideChar = ['L','R']      % stimulus laterality for contrast
    %         for ov = reshape(oriLevels,1,[])
    %             onum = fmtOri(ov);                     
    %             colName = ['stimContrast' sideChar cLabel 'Ori' onum];  % just 'Ori'
    %             obj.bhv.(colName) = nan(nTrials,1);
    %         end
    %     end
    % end

    %% --- Populate columns ---
    for t = 1:nTrials

        % % ===== Stimulus contrast (existing) =====
        % if cL == 0 && cR == 0
        %     obj.bhv.stimContrast0(t) = 1;
        % else
        %     if cL ~= 0
        %         idx = find(contrastLevels == abs(cL));
        %         if ~isempty(idx)
        %             obj.bhv.(['stimContrastL' contrastLabels{idx}])(t) = 1;
        %         end
        %     end
        %     if cR ~= 0
        %         idx = find(contrastLevels == abs(cR));
        %         if ~isempty(idx)
        %             obj.bhv.(['stimContrastR' contrastLabels{idx}])(t) = 1;
        %         end
        %     end
        % end

        %% --- Populate expanded stimContrast with Ori (inside your per-trial loop) ---
        % --- Stimulus contrast ---
        cL = obj.bhv.contrastLeft(t);
        cR = obj.bhv.contrastRight(t);
    
        % ===== NEW: Expanded stimContrast with Ori =====
        if ~(cL == 0 && cR == 0)
            % Assign side and Ori based on non-zero contrast
            if cL ~= 0
                sideStim = 'L'; cVal = cL; oriNum = obj.bhv.LeftOri(t);
            else
                sideStim = 'R'; cVal = cR; oriNum = obj.bhv.RightOri(t);
            end
        
            idx = find(contrastLevels == abs(cVal));
            if ~isempty(idx)
                cLabel = contrastLabels{idx};
                colName = ['stimContrast' sideStim cLabel 'Ori' fmtOri(oriNum)];
                obj.bhv.(colName)(t) = 1;
            end
        
        else
            % Both contrasts zero
            cVal = 0; 
            cLabel = '0';  % explicitly define for zero contrast
            if obj.bhv.LeftOri(t) ~= 0
                oriNum = obj.bhv.LeftOri(t);
            elseif obj.bhv.RightOri(t) ~= 0
                oriNum = obj.bhv.RightOri(t);
            else
                oriNum = 0;
            end
            
            colName = ['stimContrast' cLabel 'Ori' fmtOri(oriNum)];
            obj.bhv.(colName)(t) = 1;
        end

        % Note: keep using obj.bhv.stimContrast0 for 0/0 contrast trials (no Ori expander)

        % ===== Choice (existing) =====
        ch = obj.bhv.choice{t};
        if strcmp(ch, 'Right')
            obj.bhv.choiceR(t) = 1;
        elseif strcmp(ch, 'Left')
            obj.bhv.choiceL(t) = 1;
        end

        % % ===== Reward / noReward (existing) =====
        % if ~isnan(obj.bhv.rewardTime(t)) && strcmp(obj.bhv.feedback(t),'Rewarded') && obj.bhv.rewardTime(t) ~= 0 && ~isempty(ch)
        %     if strcmp(ch, 'Right'); side = 'R'; cVal = cR; else; side = 'L'; cVal = cL; end
        %     idx = find(contrastLevels == abs(cVal));
        %     if ~isempty(idx)
        %         obj.bhv.(['reward' side contrastLabels{idx}])(t) = 1;
        %     end
        % elseif ~isempty(ch) && strcmp(obj.bhv.feedback(t),'Unrewarded')
        %     if strcmp(ch, 'Right'); side = 'R'; cVal = cR; else; side = 'L'; cVal = cL; end
        %     idx = find(contrastLevels == abs(cVal));
        %     if ~isempty(idx)
        %         obj.bhv.(['noReward' side contrastLabels{idx}])(t) = 1;
        %     end
        % end

       
        % ===== NEW: Reward columns with magnitude =====
        % Rewarded trials
        if ~isnan(obj.bhv.rewardTime(t)) && strcmp(obj.bhv.feedback(t), 'Rewarded') ...
                && obj.bhv.rewardTime(t) ~= 0 && ~isempty(ch)
            
            if strcmp(ch, 'Right')
                sideCh = 'R';
            else
                sideCh = 'L';
            end

            if strcmp(ch, 'Right')
                sideCh = 'R';
            else
                sideCh = 'L';
            end
            
            idx = find(contrastLevels == abs(cVal));
            if ~isempty(idx)
                cLabel = contrastLabels{idx};
                rmStr = fmtNum(obj.bhv.expectedRewardValue(t));
                colName = ['reward' sideCh cLabel 'RewMag' rmStr];
                obj.bhv.(colName)(t) = 1;
            end
        end
        
        % Unrewarded trials
        if strcmp(obj.bhv.feedback(t), 'Unrewarded') && ~isempty(ch)
            
            if strcmp(ch, 'Right')
                sideCh = 'R';
            else
                sideCh = 'L';
            end
            
            idx = find(contrastLevels == abs(cVal));
            if ~isempty(idx)
                cLabel = contrastLabels{idx};
                rmStr = fmtNum(obj.bhv.expectedRewardValue(t));
                colName = ['Unreward' sideCh cLabel 'RewMag' rmStr];
                obj.bhv.(colName)(t) = 1;
            end
        end

        % ===== Punish & Go cue (existing) =====
        if ~isnan(obj.bhv.punishSoundOnsetTime(t)), obj.bhv.punishSound(t) = 1; end
        if ~isnan(obj.bhv.goCueTime(t)),            obj.bhv.goCue(t)       = 1; end

    end

    % --- Save obj into allObjs ---
    sessionField = matlab.lang.makeValidName(['session_' session]);
    allObjs.(sessionField) = obj;
    fprintf('Saved session %s into allObjs.%s\n', session, sessionField);
end

disp('Behavioural and neural data loaded and compiled successfully.');
