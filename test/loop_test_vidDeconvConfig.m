%% loop_test_vidDeconvConfig %%
% A loop file to run the unit tests for checking the modularity of the
% toolbox

for i = 1:length(mouseList)
    mouse   = mouseList(i);
    session = sessionList{i};
    
    % Pre-check config
    try
        results = runtests('test_vidDeconvConfig.m');
        if any([results.Failed])
            warning('Skipping %s - %s due to config errors', mouse, session);
            continue;
        end
    catch ME
        warning('Test execution failed: %s', ME.message);
        continue;
    end
    
    % Run main config
    obj = run_vidDeconv_config(obj, mouse, session, options);
end
