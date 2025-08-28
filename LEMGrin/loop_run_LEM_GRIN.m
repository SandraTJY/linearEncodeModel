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

expRef = options.expRef;

% Initialise container for processed sessions
processedObj = struct();

for i = 1:length(expRef)
    sessionName = expRef{i};
    fieldName   = matlab.lang.makeValidName(['session_' sessionName]); % MATLAB-compatible field name

    % Run the configuration for this session
    objSession = run_vidDeconv_config(obj, sessionName, options);

    % Save the processed object in the structured container
    processedObj.(fieldName) = objSession;

    % Optional: display progress
    fprintf('Processed session: %s\n', sessionName);
end

% Save the full processedObj for later use
saveFileName = fullfile(options.savePath, 'processed_sessions.mat'); % set your save path
save(saveFileName, 'processedObj', '-v7.3');

fprintf('All sessions processed and saved to %s\n', saveFileName);
