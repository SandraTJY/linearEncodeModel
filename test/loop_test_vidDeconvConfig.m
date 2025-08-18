%% loop_test_vidDeconvConfig %%
% A loop file to run the unit tests for checking the modularity of the
% toolbox

%% loop_test_vidDeconvConfig.m

clear; clc;

% Define paths
options.vidDataRoot = './data/neural/'; % update with actual path if needed
options.bhvDataRoot = './data/behav/';
options.neuralDataRoot = './data/neural/';
options.bhvFileExtension = '_behav_probability_sessions.csv';
options.neuralFileExtension = '_fluor_timeseries_probability_sessions.csv';

% Define subjects and sessions
mouseList = {'MFE008'};
sessionList = {'2022-09-13_1'};

% Initialize main object to store data
obj = struct();

for i = 1:length(mouseList)
    mouse = mouseList{i};
    session = sessionList{i};
    expRef = strcat(session, '_', mouse);
    
    %% === Video / Facemap Data ===
    % Load session info
    sessionInfo = readtable('./data/instrumentalSessionInfo.csv', ...
        'FileType', 'text', 'Delimiter', ',', 'ReadVariableNames', true);

    vidData = struct();

    for s = 1:height(sessionInfo)
        if sessionInfo.video(s) == 1
            % Match session
            if strcmp(sessionInfo.animal_name{s}, mouse) && contains(sessionInfo.expRef{s}, session)
                disp(['Processing video for ', mouse, ' - ', session]);
                
                % Load h5 / mat files
                % (use same approach as vidDeconv_extractFacemapData)
                % Example:
                filename = fullfile(options.vidDataRoot, mouse, ...
                    [expRef '_face_FacemapPose.h5']);
                
                mouth_x = h5read(filename,'/Facemap/mouth/x');
                mouth_y = h5read(filename,'/Facemap/mouth/y');
                lowerlip_x = h5read(filename,'/Facemap/lowerlip/x');
                lowerlip_y = h5read(filename,'/Facemap/lowerlip/y');
                
                % Load motion PCs
                load(fullfile(options.vidDataRoot, mouse, [expRef '_face_proc.mat']), ...
                    'movSVD_0', 'motSVD_0');
                
                MovementPC = movSVD_0(:,1:10);
                MotionPC = motSVD_0(:,1:10);
                
                % Build table
                session_table = table(categorical({mouse}, length(mouth_x), 1), ...
                    repmat(categorical({expRef}), length(mouth_x), 1), ...
                    mouth_x, mouth_y, lowerlip_x, lowerlip_y, MovementPC, MotionPC);
                
                session_table.Properties.VariableNames{'Var1'} = 'mouse';
                session_table.Properties.VariableNames{'Var2'} = 'expRef';
                
                vidData.(mouse).(matlab.lang.makeValidName(['session_' expRef])) = session_table;
                
                obj.vid = vidData.(mouse).(matlab.lang.makeValidName(['session_' expRef]));
            end
        end
    end

    %% === Behavioural / Neural Data ===
    disp(['Processing behavioral & neural data for ', mouse, ' - ', session]);
    
    % Load behavioural data
    bhvFile = fullfile(options.bhvDataRoot, [mouse options.bhvFileExtension]);
    bhvTable = readtable(bhvFile);
    
    % Load neural data
    neuralFile = fullfile(options.neuralDataRoot, [mouse options.neuralFileExtension]);
    neuralTable = readtable(neuralFile);
    
    % Filter to session
    lookupKey = strcat(session, '_', mouse);
    obj.bhv = bhvTable(strcmp(bhvTable.expRef, lookupKey), :);
    obj.neural = neuralTable(strcmp(neuralTable.expRef, lookupKey), :);
    
    % Additional trial info (from vidDeconv_loadBhvNeuralData)
    obj.bhv.trialStartTime = obj.bhv.stimulusOnsetTime;
    obj.bhv.trialEndTime = obj.bhv.outcomeTime;
    obj.bhv.trialDuration = obj.bhv.outcomeTime - obj.bhv.stimulusOnsetTime;
    
    disp(['Completed processing for ', mouse, ' - ', session]);
end
