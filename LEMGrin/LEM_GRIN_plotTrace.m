%% Parameters
numSessionsToPlot = 5;
numCellsToPlot = 5;
intervalLength = 20; % seconds

events = {'stimulusOnsetTime','choiceStartTime','goCueTime','rewardTime'};
colors = lines(numel(events)); % distinct colors for event lines

% Randomly sample sessions
rng('shuffle');
plotSessions = randsample(sessionList, numSessionsToPlot);

figure;

for s = 1:numSessionsToPlot
    session = plotSessions{s};
    sessionField = matlab.lang.makeValidName(['session_' session]);
    
    if ~isfield(allObjs, sessionField)
        warning('Session %s not found.', session);
        continue;
    end
    
    neuralTable = allObjs.(sessionField).neural;
    bhvTable = allObjs.(sessionField).bhv;
    
    % Choose cells (first N or fewer if session has fewer)
    cellNames = neuralTable.Properties.VariableNames;
    cellNames(strcmp(cellNames,'time')) = [];
    numCells = min(numCellsToPlot, numel(cellNames));
    
    % Choose a random 20s interval
    timeVector = neuralTable.time;
    maxStart = max(timeVector) - intervalLength;
    if maxStart <= 0
        continue;
    end
    startTime = rand()*maxStart;
    endTime = startTime + intervalLength;
    idxRange = timeVector >= startTime & timeVector <= endTime;
    
    % Plot
    subplot(numSessionsToPlot,1,s); hold on;
    offset = 0;
    for c = 1:numCells
        thisCell = neuralTable.(cellNames{c});
        plot(timeVector(idxRange), thisCell(idxRange) + offset, 'k'); % shifted trace
        offset = offset + 1; % vertical offset so traces don't overlap
    end
    
    % Overlay events
    for e = 1:numel(events)
        eventTimes = bhvTable.(events{e});
        eventTimes = eventTimes(eventTimes >= startTime & eventTimes <= endTime);
        for t = 1:numel(eventTimes)
            xline(eventTimes(t), 'Color', colors(e,:), 'LineWidth', 1.5, ...
                'DisplayName', events{e});
        end
    end
    
    xlabel('Time (s)');
    ylabel('Neural activity (offset by cell)');
    title(sprintf('Session %s (random 20s, %d cells)', session, numCells));
    legend(events, 'Location', 'eastoutside');
end
