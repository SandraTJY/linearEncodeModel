%% Initialise results struct
results = struct();

% List of events
events = {'stimulusOnsetTime','choiceStartTime','rewardTime'};

% Loop over sessions
for s = 1:length(sessionList)
    session = sessionList{s};
    sessionField = matlab.lang.makeValidName(['session_' session]);
    
    if ~isfield(allObjs, sessionField)
        warning('Session %s not found in allObjs.', sessionField);
        continue;
    end
    
    % Run the linear encode model set-up to make sure global timeline is
    % aligned
    allObjs.(sessionField) = setupLinearEncodeModel(allObjs.(sessionField), session, options);

    neuralTable = allObjs.(sessionField).neural;
    bhvTable = allObjs.(sessionField).bhv;
    
    % Find all cells (all columns except 'time')
    cellNames = neuralTable.Properties.VariableNames;
    cellNames(strcmp(cellNames,'time')) = [];
    
    % Initialise session struct
    results.(sessionField) = struct();
    
    % Loop over cells
    for c = 1:length(cellNames)
        cellName = cellNames{c};
        neuralData = neuralTable.(cellName);
        timeVector = neuralTable.time;  % time aligned with neural data
        
        % Initialise cell struct
        results.(sessionField).(cellName) = struct();
        
        % Loop over events
        for e = 1:length(events)
            eventName = events{e};
            eventTimes = bhvTable.(eventName);  % vector of trial times
            
            baselineVals = [];
            postEventVals = [];
            
            % Loop over trials
            for t = 1:length(eventTimes)
                evTime = eventTimes(t);
                
                % Skip if NaN or invalid
                if isnan(evTime)
                    continue;
                end
                
                % Define baseline and post-event windows
                baselineWindow = [evTime-0.5, evTime];
                postWindow = [evTime, evTime+0.8]; % I think the reward activity ramp out slightly later, so I put it as 1.5s for now
                
                % Find indices in neural data
                baselineIdx = find(timeVector >= baselineWindow(1) & timeVector < baselineWindow(2));
                postIdx = find(timeVector >= postWindow(1) & timeVector < postWindow(2));
                
                if isempty(baselineIdx) || isempty(postIdx)
                    continue;
                end
                
                % Compute mean neural activity in each window
                baselineVals(t) = mean(neuralData(baselineIdx));
                postEventVals(t) = mean(neuralData(postIdx));
            end
            
            % Perform Wilcoxon signed-rank test
            if ~isempty(baselineVals) && ~isempty(postEventVals)
                [p,h] = signrank(postEventVals, baselineVals);
                results.(sessionField).(cellName).(eventName).pValue = p;
                results.(sessionField).(cellName).(eventName).significant = h;
                results.(sessionField).(cellName).(eventName).baselineMean = mean(baselineVals);
                results.(sessionField).(cellName).(eventName).postMean = mean(postEventVals);
            else
                results.(sessionField).(cellName).(eventName).pValue = NaN;
                results.(sessionField).(cellName).(eventName).significant = NaN;
            end
        end
    end
end

%% Save results
save('neuralEventResponses.mat','results');

%% Summarise results across cells and sessions
summaryData = {};  % cell array to collect rows for CSV
header = {'Session','Cell','NumSignificant','SignificantEvents'};

% Loop over sessions
sessionFields = fieldnames(results);
for s = 1:numel(sessionFields)
    sessionField = sessionFields{s};
    cellFields = fieldnames(results.(sessionField));
    
    % Loop over cells
    for c = 1:numel(cellFields)
        cellName = cellFields{c};
        eventFields = fieldnames(results.(sessionField).(cellName));
        
        sigCount = 0;
        sigEvents = {};
        
        % Loop over events for this cell
        for e = 1:numel(eventFields)
            eventName = eventFields{e};
            h = results.(sessionField).(cellName).(eventName).significant;
            if isequal(h,1)   % significant response
                sigCount = sigCount + 1;
                sigEvents{end+1} = eventName;
            end
        end
        
        % Add to summary table
        summaryData(end+1,:) = {sessionField, cellName, sigCount, strjoin(sigEvents, ',')}; %#ok<AGROW>
    end
end

%% Convert to table and save as CSV
summaryTable = cell2table(summaryData, 'VariableNames', header);

% Save nicely as CSV
writetable(summaryTable, 'neuralEventSummary.csv');

