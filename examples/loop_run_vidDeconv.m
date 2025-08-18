%% loop_run_vidDeconv 
% Loop across all animals and sessions. Ensure that the 
% options struct, event, neural and video (optional) data is loaded before 
% running the configuration file.

options = vidDeconv_options;

mouseList = options.animal;
sessionListFull = unique(obj.bhv.expRef);
sessionList = {erase(sessionListFull, ['_' mouseList(1)])}; % adjust as needed

for i = 1:length(mouseList)
    mouse   = mouseList(i);
    session = sessionList{i};
    obj     = run_vidDeconv_config(obj, mouse, session, options);
end


