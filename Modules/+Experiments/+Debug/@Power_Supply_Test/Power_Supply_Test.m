classdef Power_Supply_Test < Modules.Experiment
    
    properties
       
        tests;
        report = []
        status = 'fail'    
        prefs = {'Current','Voltage','Volt_Limit','Current_Limit','Resistor'}
    end
    
    properties(SetObservable)
        Current=0.01; %mA
        Voltage=1;    %V
        Volt_Limit=0.01;  %make it something small
        Current_Limit=10e-6; %make it something small
        Resistor = {'Yes','No'} %do you wish to test current control by connecting a resistor? 
    end
    
    properties (Constant)
        %dont change these
        current_limit_default = 0.05; %mA the default current limit of a power supply upon construction
        voltage_limit_default = 5; %V the default voltage limit of a power supply upon construction
    end
    
    properties(Access=private)
        abort_request = false;  % Request flag for abort
        serial   % PowerSupply handle
        data   
    end
    
    methods(Access=private)
        function obj = Power_Supply_Test()
            obj.loadPrefs;
        end
    end
    
    methods(Static)
        
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.Debug.Power_Supply_Test();
            end
            obj = Object;
        end
        
        function GenerateReport()
            %WriteReport will parse a user-selected experiment file and
            %generate a report as a .txt file
            [dataname,datapath,~] = uigetfile('*.mat','Select datafile for parsing');
            dat = load(fullfile(datapath,dataname));
            
            %Run checks to ensure file is parseable format
            assert(isfield(dat,'data'),'Selected file is not recognized Experiment format.');
            assert(isfield(dat.data,'data'),'Selected file is not recognized Experiment format.');
            dat = dat.data.data;
            assert(isfield(dat,'status') && isfield(dat,'tests') && isfield(dat,'driver'),'Selected file is not recognized Power_Supply_Test format.');
            assert(~isempty(dat.status),'Power_Supply_Test results empty; cannot write report.')
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
        
        function updateLogger(obj,msg)
            obj.logger.log(msg)
            drawnow;
            obj.report = [obj.report; msg];
        end
        
        function updateWindow(obj,statusH,updatedString)
            set(statusH,'string',...
                updatedString);
            drawnow;
        end
        
        function abort(obj)
            obj.serial.delete;
            obj.abort_request = true;
        end
       
        function data = GetData(obj,~,~)
            data.status = obj.status;
            data.tests = obj.tests;
            data.report = obj.report;
            data.driver = class(obj.serial);
        end
    
    end
    
end
