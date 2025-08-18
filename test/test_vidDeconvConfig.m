classdef test_vidDeconvConfig < matlab.unittest.TestCase
    properties
        obj
        options
    end

    methods(TestMethodSetup)
        function setup(testCase)
            % Load or initialise obj and options
            testCase.obj = loadExampleObj();  % replace with your loading function
            testCase.options = vidDeconv_options;
        end
    end

    methods(Test)
        function testVariableDefsExist(testCase)
            varNames = fieldnames(testCase.options.variableDefs);
            testCase.verifyNotEmpty(varNames, 'No variableDefs defined in options.');
        end

        function testMandatoryTypesExist(testCase)
            varNames = fieldnames(testCase.options.variableDefs);

            hasEvent  = any(cellfun(@(f) strcmpi(testCase.options.variableDefs.(f).type, 'event'), varNames));
            hasNeural = any(cellfun(@(f) strcmpi(testCase.options.variableDefs.(f).type, 'neural'), varNames));

            testCase.verifyTrue(hasEvent, 'No EVENT regressors defined (mandatory).');
            testCase.verifyTrue(hasNeural, 'No NEURAL regressors defined (mandatory).');
        end

        function testVariableTypesValid(testCase)
            allowedTypes = {'event', 'trial', 'continuous', 'neural'};
            varNames = fieldnames(testCase.options.variableDefs);
            
            for i = 1:length(varNames)
                type = testCase.options.variableDefs.(varNames{i}).type;
                testCase.verifyTrue(ismember(type, allowedTypes), ...
                    sprintf('Variable %s has invalid type: %s', varNames{i}, type));
            end
        end

        function testTimeRefAndVarsExist(testCase)
            varNames = fieldnames(testCase.options.variableDefs);

            for i = 1:length(varNames)
                varDef = testCase.options.variableDefs.(varNames{i});
                
                % Check vars exist in obj
                for v = 1:length(varDef.vars)
                    testCase.verifyTrue(isfield(testCase.obj, varDef.vars{v}), ...
                        sprintf('Variable %s not found in obj.', varDef.vars{v}));
                end
                
                % Check timeRef
                if ismember(varDef.type, {'continuous', 'trial'})
                    testCase.verifyTrue(all(isnan(varDef.timeRef)), ...
                        sprintf('timeRef for %s must be NaN for type %s.', varNames{i}, varDef.type));
                else
                    for t = 1:length(varDef.timeRef)
                        testCase.verifyTrue(isfield(testCase.obj, varDef.timeRef{t}), ...
                            sprintf('timeRef %s not found in obj.', varDef.timeRef{t}));
                    end
                end
            end
        end

        function testRunConfigNoError(testCase)
            mouseList = testCase.options.animal;
            sessionListFull = unique(testCase.obj.bhv.expRef);
            sessionList = {erase(sessionListFull, ['_' mouseList(1)])};

            for i = 1:length(mouseList)
                mouse   = mouseList(i);
                session = sessionList{i};

                % Wrap run_vidDeconv_config in verifyWarningFree to catch runtime errors
                testCase.verifyWarningFree(@() run_vidDeconv_config(testCase.obj, mouse, session, testCase.options));
            end
        end
    end
end

% Helper function example (replace with your real loading)
function obj = loadExampleObj()
    load('exampleData.mat', 'obj'); % adjust path
end
