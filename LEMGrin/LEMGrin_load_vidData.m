%% LEMGrin data loading script to load and compile the video data and
% organise them as a table, stored in the object obj for running the
% configuration.

% NOTE: If you use this example, please connect to the lakLab server before
% proceeding.

% Define subjects and sessions of interest
sessionList = options.expRef;

if ~exist('allObjs', 'var') || isempty(allObjs)
    allObjs = struct();  % container for all sessions
end

% Loop through selected sessions
for iSes = [2,3,5]   % or use 1:length(sessionList)
    expRef = sessionList{iSes};

    if isempty(expRef)
        warning('Skipping empty session at index %d', iSes);
        continue;
    end

    mouse = expRef(end-4:end);
    sessionField = matlab.lang.makeValidName(['session_' expRef]);

    fprintf('Processing session %s (%d of %d)\n', expRef, iSes, length(sessionList));

    try
        %% --- Load video H5 data ---
        filename = fullfile(options.vidDataRoot, mouse, expRef(1:10), expRef(12), [expRef '_face_FacemapPose.h5']);
        mouth_x     = h5read(filename,'/Facemap/mouth/x');
        mouth_y     = h5read(filename,'/Facemap/mouth/y');
        lowerlip_x  = h5read(filename,'/Facemap/lowerlip/x');
        lowerlip_y  = h5read(filename,'/Facemap/lowerlip/y');

        %% --- Load motion PCs ---
        matFile = fullfile(options.vidDataRoot, mouse, expRef(1:10), expRef(12), [expRef '_face_proc.mat']);
        load(matFile);

        % retain first 10 PCs
        if exist('movSVD_0','var') && ~isempty(movSVD_0) && ~exist('movSVD_1','var')
            MovementPC = movSVD_0(:,1:10);
        elseif exist('movSVD_1','var') && ~isempty(movSVD_1)
            MovementPC = movSVD_1(:,1:10);
        end

        if exist('motSVD_0','var') && ~isempty(motSVD_0) && ~exist('motSVD_1','var')
            MotionPC = motSVD_0(:,1:10);
        elseif exist('motSVD_1','var') && ~isempty(motSVD_1)
            MotionPC = motSVD_1(:,1:10);
        end

        %% --- Get event times ---
        try
            event_times = getEventTimes(expRef, 'face_camera_strobe');
        catch ME
            warning('Could not retrieve event times for %s: %s', expRef, ME.message);
            nFrames = max([size(MotionPC,1), size(MovementPC,1), size(mouth_x,1)]);
            event_times = NaN(nFrames,1);
        end

        %% --- Align lengths ---
        arrays = {mouth_x, mouth_y, lowerlip_x, lowerlip_y, MovementPC, MotionPC};
        nFrames = max(cellfun(@(x) size(x,1), arrays));

        % pad/trim event_times
        if length(event_times) < nFrames
            event_times(end+1:nFrames) = NaN;
        elseif length(event_times) > nFrames
            event_times = event_times(1:nFrames);
        end

        % pad/trim all arrays to nFrames
        for k = 1:length(arrays)
            if size(arrays{k},1) < nFrames
                padSize = nFrames - size(arrays{k},1);
                arrays{k} = [arrays{k}; NaN(padSize,size(arrays{k},2))];
            elseif size(arrays{k},1) > nFrames
                arrays{k} = arrays{k}(1:nFrames,:);
            end
        end
        [mouth_x, mouth_y, lowerlip_x, lowerlip_y, MovementPC, MotionPC] = deal(arrays{:});

        %% --- Build session table ---
        session_table = table( ...
            repmat(categorical({mouse}), nFrames, 1), ...
            repmat(categorical({expRef}), nFrames, 1), ...
            event_times, ...
            mouth_x, mouth_y, ...
            lowerlip_x, lowerlip_y, ...
            MovementPC, ...
            MotionPC, ...
            'VariableNames', {'mouse','expRef','eventTimes','mouth_x','mouth_y','lowerlip_x','lowerlip_y','MovementPC','MotionPC'} ...
        );

        %% --- Save to allObjs ---
        obj = struct();
        obj.vid = session_table;
        allObjs.(sessionField) = obj;

        fprintf('Saved video data for session %s into allObjs.%s\n', expRef, sessionField);

    catch ME
        warning('Failed processing session %s: %s', expRef, ME.message);
    end
end

disp('All selected video sessions compiled successfully.');
