# Linear Encode Model Toolbox

A MATLAB toolbox for linear encoding of video, neural, and behavioural data. This toolbox is designed to organise and analyse experimental datasets using a modular pipeline.

## Folder Structure
- **data/** – Contains behavioural, neural, and video data files. Users should supply their datasets in the correct format.  
- **examples/** – Demo scripts to show how to preprocess and structure data.  
- **main/** – Main configuration scripts. Run these after preparing your data objects.  
- **utils/** – Helper functions and main functions required by the pipeline.  
- **vidDeconv_options.m** – Defines paths, variable names, types, and parameters needed for your linear encode model.  

## Getting Started

### Set options

Before running any analysis, configure paths and parameters using:
```
options = vidDeconv_options;
```
This will generate an options struct with all folder pathways and model-specific parameters.

Prepare your data
In the `examples/` folder, run:

```
vidDeconv_extractFacemapData;    % Organise video/facial features
vidDeconv_loadBhvNeuralData;   % Load and Organise neural and behavioral data
```
These scripts compile your data into an obj struct containing:

*obj.neural* – neural data table
*obj.bhv – behavioral data table
obj.vid – video data table

*Note*: Users should modify these scripts to fit their dataset formats, and define/ compute any variables they would like to include in the analysis.

Run main analysis
Go to the `main/` folder and run:
```
loop_run_vidDeconv;
```
This script iterates over all animals and sessions:

- Loads your options struct from vidDeconv_options.m.
- Extracts the list of animals and sessions from your obj.bhv data.
- Loops through each animal-session pair and runs the pipeline via run_vidDeconv_config.

*Note*: Ensure that obj contains all necessary data (event, neural, and optional video data) before running the loop.

### Usage Example
```
% Load options
options = vidDeconv_options; % Make sure you change the configuration beforehand

% Prepare demo data
vidDeconv_extractFacemapData;
vidDeconv_loadBhvNeuralData;

% Run main pipeline
loop_run_vidDeconv;
```

## Pipeline — Step-by-Step

This section describes the chronological execution flow of the `loop_run_vidDeconv` pipeline.
Each step includes:

*Purpose* – Why this step exists
*Inputs* – What’s needed and in what format
*Outputs* – What’s returned and how it’s used later

### 0. Define model variables

Before running the pipeline, users must define `variableDefs` to specify which variables belong to each regressor group (neural, event, trial (optional), continuous (optional) etc.):

```
% Usage in the examples
options.variableDefs = struct( ...
  'stimulus', struct( ...
      'type', 'event', ...
      'timeRef', 'stimulusOnsetTime', ...
      'vars', {{ ...
          'stimContrast0', 'stimContrastR00625', 'stimContrastL00625', ...
          'stimContrastR0125', 'stimContrastL0125', ...
          'stimContrastR025', 'stimContrastL025', ...
          'stimContrastR05', 'stimContrastL05', ...
          'stimContrastR1', 'stimContrastL1' ...
      }} ...
  ), ...
  'reward', struct( ...
      'type', 'event', ...
      'timeRef', 'outcomeTime', ...
      'vars', {{ ...
          'rewardR0', 'rewardL0', ...
          'rewardR00625', 'rewardL00625', ...
          'rewardR0125', 'rewardL0125', ...
          'rewardR025', 'rewardL025', ...
          'rewardR05', 'rewardL05', ...
          'rewardR1', 'rewardL1'...
      }} ...
  ), ...
  'choice', struct( ...
      'type', 'event', ...
      'timeRef', 'choiceStartTime', ...
      'vars', {{'choiceR', 'choiceL'}} ...
  ), ...
  'neural', struct( ...
      'type', 'neural', ...
      'timeRef', {{'LeftDLS_DA', 'RightDLS_ACH'}} ...
  ), ...
  'vid', struct( ...
      'type', 'continuous', ...
      'timeRef', {{'eventTimes'}}, ...
      'vars', {{'MovementPC', 'MotionPC'}} ...
  ), ...
  'keypoint', struct( ...
      'type', 'continuous', ...
      'timeRef', {{'eventTimes'}}, ...
      'vars', {{'mouth_x', 'mouth_y', 'lowerlip_x', 'lowerlip_y'}} ...
  ), ...
  'vidAvg', struct( ...
      'type', 'trial', ...
      'timeRef', {{'NaN'}}, ...
      'vars', {{'MovementPC', 'MotionPC'}} ...
  ), ... 
  'choiceHistoryAvg', struct( ...
      'type', 'trial', ...
      'timeRef', {{'NaN'}}, ...
      'vars', {{'choiceHistory'}} ...
  ) ...
);
```

To visually check the design matrix for each regressor group (event, task, continuous), set:

```
options.plotDesignMatrix = true;  % set to false to disable plotting
```

*Tip*: This is useful for troubleshooting regressors and verifying that variables are correctly aligned.


### 1. Setup Session Model — `setupLinearEncodeModel`

*Purpose*:
Initialise a linearEncodeModel object for the given mouse and session. Loads behaviour, neural, and optional video data; aligns them to a global time axis.

*Inputs*:

- `mouseName` (string) – e.g., "AMK035"
- `expRef` (string) – e.g., "2023-06-13_1"
- `motionData` (table) – motion PCs + calibrated event times aligned to neural/behavioural data
- `options` (struct) – pipeline configuration

*Outputs*:
- `obj` (linearEncodeModel instance) – contains all loaded/processed data for downstream functions

### 2. Build Event Regressors — `buildEventRegressors`

*Purpose*:
Compile behavioural event regressors into a non-time-shifted design matrix.

*Inputs*:

- `obj` – from step 1
- `options` – configuration

*Outputs*:
- `obj` – updated with behavioural regressors in structured subfields

### 3. Build Video Regressors — `buildContinuousRegressors`
*Purpose*:
Extract and organise continuous video PCs into a non-time-shifted design matrix.

*Inputs*:
- `obj` – from step 2
- `options` – configuration

*Outputs*:
- `obj` – updated with video PC regressors, each labelled separately (MotionPC1, MotionPC2, …)

### 4. Build Trial Regressors — `buildTrialRegressors`
*Purpose*:
Create trial-based regressors (e.g., previous choice, difficulty) and insert them into a non-time-shifted design matrix.

*Inputs*:
- `obj` – from step 3
- `options` – configuration

*Outputs*:
- `obj` – updated with trial regressors

### 5. Get Event Design Matrix — `getEventDesignMatrix`
*Purpose*:
Extract only event-related regressors into a separate table for later expansion.

*Inputs*:
- `obj` – from step 4
- `options` – configuration

*Outputs*:
- `R` (table) – non-time-shifted event regressors

### 6. Create Time-Lagged (for events) or non-Time-Lagged (optional, video or trial) Design Matrices
*Purpose*:
Expand regressors over time to capture temporal dynamics.

*Functions & Outputs*:
- `createTaskDesignMatrix` → taskMat, taskLabels, taskIdx (event regressors, time-lagged)
- `createVideoDesignMatrix` → vidMat, vidLabels, vidIdx (video regressors)
- `createTrialDesignMatrix` → trialMat, trialLabels, trialIdx (trial regressors)

### 7. Visualise Design Matrices — `plotDesignMatrix`
*Purpose*:
Plot the first portion of each design matrix for inspection.

*Inputs*:
- Design matrix (expanded or non-expanded)
- `options`

*Outputs*:
- Heatmap visualisations

### 8. Filter Rows Outside Trials — `removeRowsOutsideTrialWindows`
*Purpose*:
Remove non-task time points (zero rows) and keep only data within trial windows.

*Inputs*:
- `obj` – behavioural data with trial timing
- Reference matrix (to detect zero rows within the matrix) 
- Other matrices to filter

*Outputs*:
- `cleanedMats` – filtered matrices (task, video, trial, neural signals)
- `trialVec` – trial number for each frame

### 9. Normalise & Re-centre — `normaliseAndRecentre`
*Purpose*:
Scale predictors and outputs to avoid computational issues.

*Inputs*:
- `X` – combined regressor matrix
- `Y` – neural signal matrix

*Outputs*:
- Normalised X, Y

### 10. Check & Orthogonalise — `checkAndOrthogonalise`
*Purpose*:
Detect and fix high correlations or linear dependencies between regressor groups.

*Inputs*:
- Expanded design matrix
- Labels & indices for task, video, trial regressors
- Correlation threshold (default: 0.95)

*Outputs*:
- Orthogonalised design matrix (`expandR`)
- Updated regressor index mapping (`regIdx`)

### 11. Ridge Regression — `ridgeMML`
*Purpose*:
Fit a ridge regression model using Marginal Maximum Likelihood (Karabatsos, 2017) to estimate optimal λ.

*Inputs*:
- `X` – expanded design matrix
- `Y` – neural data
- `Optional`: initial λ, verbosity, timeout, otherwise `[]`

*Outputs*:
- Optimal λ for each output
- Beta weights per regressor

### 12. Cross-Validated Model — `crossValModel`
*Purpose*:
Evaluate predictive performance (R²) using trial-based cross-validation.

*Inputs*:
- `X` – expanded design matrix
- `Y` – neural data
- `regLabels`, `regIdx` – grouping information
- `folds` – number of CV folds
- `trialVec` – trial labels (from `removeRowsOutsideTrialWindows`)

*Outputs*:
- Predicted fluorescence
- Beta weights per fold
- Reduced design matrices for selected regressors

## License
This toolbox was developed in the LakLab (Department of Physiology, Anatomy, and Genetics [DPAG], University of Oxford, UK). 

It is available for **academic and research purposes only**. If you use this toolbox in your work, please acknowledge the LakLab in any resulting publications or presentations.  

