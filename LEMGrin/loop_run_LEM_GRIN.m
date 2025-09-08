%% loop_run_LEM_GRIN
    % Loop across all animals and sessions. Ensure that the 
    % options struct, event, neural and video (optional) data is loaded before 
    % running the configuration file.
    
    % NOTE: please make sure you run 1) vidDeconv_options to get the configuration of the example, and 
    % 2) example/vidDeconv_loadBhvNeuralData to get the obj.bhv and obj. neural. As the vid loading is specific
    % to our server's path that is not accessible on GitHub, we've provided the vidData that is the loaded
    % output of the /example/vidDataLoadingTemplate/vidDeconv_extractFacemapData. 
    % You need not to run this file as it is highly specific to where
    % you store your video data, but you can treat this as a template to load
    % your own data.

% Ensure allObjs exists and is not empty
if ~exist('allObjs', 'var') || isempty(allObjs)
    error('allObjs does not exist or is empty. Please load your session data first.');
end

% Get all session names (fields of allObjs)
sessionList = fieldnames(allObjs);

% for i = 1:numel(sessionList)
for i = 1:6
    sessionName = sessionList{i};
    objSession  = allObjs.(sessionName); % get the session struct
    
    % Run the configuration for this session
    processedSession = run_vidDeconv_config(objSession, sessionName, options);
    
    % Save the processed object in the structured container
    allObjs.(sessionName) = processedSession;
    
    % Optional: display progress
    fprintf('Processed session: %s\n', sessionName);
end

% Save the full processedObj for later use
saveFileName = fullfile('allObjs_sessions.mat'); % set your save path
save(saveFileName, 'allObjs', '-v7.3');

fprintf('All sessions processed and saved to %s\n', saveFileName);
