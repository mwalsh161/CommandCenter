classdef DebugSuperClass_invisible < Modules.Experiment
    %DebugSuperClass_invisible is a superclass for Debug type experiments.
    %These experiments test drivers of equipment to make sure that they are
    %operating correctly.
    
    properties
        status %pass or fail status of a particular test
        tests  %cell array of structures that has information on all the tests given
        driver
    end
    
    methods(Static)
        function GenerateReport()
            %WriteReport will parse a user-selected experiment file and
            %generate a report as a .txt file
            [dataname,datapath,~] = uigetfile('*.mat','Select datafile for parsing');
            dat = load(fullfile(datapath,dataname));
            
            %Run checks to ensure file is parseable format
            assert(isfield(dat,'data'),'Selected file is not recognized Experiment format.');
            assert(isfield(dat.data,'data'),'Selected file is not recognized Experiment format.');
            dat = dat.data.data;
            assert(isfield(dat,'status') && isfield(dat,'tests') && isfield(dat,'driver'),'Selected file is not of a recognized format.');
            assert(~isempty(dat.status),'results empty; cannot write report.')
            report = sprintf('Test of device %s\n',dat.driver);
            FAILED = false;
            SKIPPED = false;
            try
                for i=1:length(dat.tests)
                    test = dat.tests(i);
                    report = [report, sprintf('Test %s: ',test.name)];
                    if test.success == 1
                        report = [report, sprintf('passed\n')];
                    elseif test.success == 0
                        report = [report, sprintf('failed\n')];
                        report = [report, sprintf('\t%s\n',test.err.message)];
                        report = [report, sprintf('\tTest output: %s\n',string(test.output))];
                        FAILED = true;
                    elseif test.success == -1
                        report = [report, sprintf('skipped\n')];
                        SKIPPED = true;
                    else
                        report = [report, sprintf('status unknown\n')];
                        FAILED = true;
                    end
                end
                if FAILED
                    report = [report, sprintf('\nFailed at least one test; see error report above.')];
                elseif SKIPPED
                    report = [report, sprintf('\nPassed all tests, but some skipped; see report above.')];
                else
                    report = [report, sprintf('\nPassed all tests.')];
                end
            catch
                error('failed test parsing; tests may be in unexpected format')
            end
            [filepath,filename,~] = fileparts(fullfile(datapath,dataname));
            fileHandle = fopen([filepath,'\', filename, '_report.txt'],'wt');
            fprintf(fileHandle, report);
            fclose(fileHandle);
            winopen([filepath,'\', filename, '_report.txt']);
        end
    end
    
    methods
        function test = run_test(obj,name,set,check,expectedOutput,varargin)
            %Inputs:
            %   name: string describing the test
            %   set: a function @()func for the functionality being tested
            %   check: a function @()func that outputs a check on success of set
            %   expectedOutput: exact output the check() should return
            %   varargin: optional boolean input for tests that can be
            %             skipped - true for skip, false for do not skip
            %Output:
            %   test = struct with fields name, success, and err
            %       name = input test name
            %       success = 1 if success, 0 if fail, -1 if skipped
            %       err = any errors that occurred, including failed check
            test.name = name;
            test.err = [];
            test.output = [];
            try
                if nargin == 6 && varargin{1} %check if skip
                    test.success = -1;
                    msg = sprintf('Skipped %s',test.name);
                else
                    set();
                    test.output = check();
                    assert(isequal(test.output,expectedOutput),'Unexpected output');
                    test.success = 1;
                    msg = sprintf('Passed %s',test.name);
                end
            catch err
                test.success = 0;
                test.err = err;
                msg = sprintf('Failed %s',test.name);
            end
            obj.logger.log(msg)
            drawnow;
            assert(~obj.abort_request,'User aborted');
        end
    end
    
end