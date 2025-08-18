%% loop_run_vidDeconv 
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

options = vidDeconv_options;
tmp = load('./exampleData/vid/vidData'); % Usually you would have a separate script to load and format the data

mouseList = options.animal;
sessionList = string(unique(obj.bhv.expRef));

for i = 1:length(mouseList)
    mouse   = mouseList{i};
    session = sessionList{i};
    sessionField = matlab.lang.makeValidName(['session_' session]);
    obj.vid = tmp.vidData.(mouse).(sessionField); 
    obj     = run_vidDeconv_config(obj, mouse, session, options);
end


