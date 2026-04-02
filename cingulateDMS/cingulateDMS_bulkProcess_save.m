%%% Bulk process sessions for linear encoding

model_output_dir = "\\qnap-al001.dpag.ox.ac.uk\STan\Data\linearEncodeModel_output\model_10-27_stimreward\";
mkdir(model_output_dir);
% Initialise options, which will contain the sessions asked for 
options = cingulateDMS_options();

%% --- Redefine subjects and sessions ---
sessionList = {'2025-06-12_1_SAT037', '2025-06-13_1_SAT037', ...
       '2025-06-16_1_SAT037', '2025-06-17_1_SAT037', ...
       '2025-06-18_1_SAT037', '2025-06-19_1_SAT037', ...
       '2025-07-16_1_SAT037', '2025-07-17_1_SAT037', ...
       '2025-07-18_1_SAT037', '2025-07-23_1_SAT037', ...
       '2025-07-29_1_SAT037', '2025-07-30_2_SAT037', ...
       '2025-07-31_2_SAT037', '2025-08-01_2_SAT037', ...
       '2025-08-04_1_SAT037', '2025-08-05_1_SAT037', ...
       '2025-08-06_1_SAT037'};
options.expRef = sessionList;
% Load and Organise neural and behavioral data
cingulateDMS_loadBhvNeuralData(); % creates allObj, obj...

fprintf('---\nTotal sessions in obj: %s\n', numel(options.expRef));
for i = 1:numel(options.expRef)
    try
        session = options.expRef{i};
        fprintf('---\nProcessing for session: %s\n', session);
    
        session_split = strsplit(session, '_');
        recordingDate = session_split{1};
        sessionID = session_split{2};
        animalID = session_split{3};
    
        output_dir = fullfile(model_output_dir, animalID, session);
        
        sessionField = matlab.lang.makeValidName(['session_' session]);
        obj = allObjs.(sessionField);
        % Design matrix building, Cross validation etc
        obj = run_cingulateDMS_config(obj, session, options);
    
        %% For exporting only the parts of obj that are needed in Python
        mkdir(output_dir);
    
        all_variables = fieldnames(obj);
        variables_keep = [];
        for v = 1:numel(all_variables)
            if ~startsWith(all_variables(v), 'crossVa') % Only export clean and standardised cell-specific traces, but keep regression results in crossVal
                if startsWith(all_variables(v), 'cell') 
                        if endsWith(all_variables(v), 'CleanStandardised')
                            variables_keep = [variables_keep all_variables(v)]; 
                        end
                else
                    variables_keep = [variables_keep all_variables(v)]; 
                end
            end
        end
        
        obj_export = struct();
        for v = 1:numel(variables_keep)
            obj_export.(variables_keep{v}) = obj.(variables_keep{v});
        end
        obj_export.options = options;
        
        %% Also export crossVal as its own file
        crossVal_export = obj.crossVal;
        % 
        
        save(fullfile(output_dir, 'obj.mat'), '-struct','obj_export');
        save(fullfile(output_dir, 'crossVal.mat'),'-struct','crossVal_export');
        fprintf('---\nExported obj and crossVal structs for %s\n', session)

    catch ME
        warning('Error processing session %s: %s', session, ME.message);
    end

end