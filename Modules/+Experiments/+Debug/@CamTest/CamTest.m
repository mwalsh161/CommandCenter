classdef CamTest < Modules.Experiment
    
    properties
        binning_vec = [1,2,4,8];
        
        status
        tests
        camera;
        data;
        pulseblaster;
        prefs = {'exposure','gain','Num_Images','camera_hw','laser_hw','ip'};
    end
    
    properties(SetObservable)
        exposure = 50; %ms
        EMGain = 3;
        gain = 4;
        Num_Images=10;
        camera_hw=3; %indexed from 1
        laser_hw=4;  %indexed from 1
        ip='localhost'
    end
    
    properties(Access=private)
        abort_request = false;  % Request flag for abort
    end
    
    methods(Access=private)
        function obj = CamTest()
            obj.loadPrefs;
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.Debug.CamTest();
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
            assert(isfield(dat,'status') && isfield(dat,'tests') && isfield(dat,'driver'),'Selected file is not recognized CamTest format.');
            assert(~isempty(dat.status),'CamTest results empty; cannot write report.')
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
       
        
        function axImage=get_image_axis_handle(obj)
            hObj = findall(0,'name','CommandCenter');
            handles = guidata(hObj);
            axImage = handles.axImage;
        end
        
        function s=setup_PB_sequence(obj)
            obj.pulseblaster = Drivers.PulseBlaster.Remote.instance(obj.ip);
            MeasTime = obj.camera.getExposure*1000; % us (microseconds)
            
            % Make some chanels
            laser = channel('laser','color','r','hardware',obj.laser_hw-1);
            camera= channel('camera','color','g','hardware',obj.camera_hw-1);
            
            
            % Make sequence
            s = sequence('CamTest');
            s.channelOrder = [laser,camera];
            
            % laser duration
            n_laser = node(s.StartNode,laser,'delta',0,'units','us');
            n_laser = node(n_laser,laser,'delta',MeasTime,'units','us');
            
            
            % camera exposure duration
            n_camera = node(s.StartNode,camera,'delta',0,'units','us');
            n_camera = node(n_camera,camera,'delta',MeasTime,'units','us');%expose
            
        end
      
        function abort(obj)
           obj.abort_request = true;
        end
        
        function data = GetData(obj,~,~)
            if isempty(obj.tests)
                data = [];
            else
                data.camera = obj.camera;
                data.tests = obj.tests;
                data.status = obj.status;
            end
        end
        
    end
    
end
