classdef CalibrateReadoutTime  < Modules.Experiment
    
    properties(Constant)
        minSequenceDuration = 14; % minimum programmable length in ns
    end
    
    properties
        background = 1; %background contrast
        selection %determines if the user has made a selection 
        ax  %axes for data
        optimumReadTime  %output of experiment
        abort_request = false;
        data;
        pulseblaster  %handle for pulseblaster
        Ni  %handle to nidaq
        image_axes  %image axis handle of CC
        laser  %laser handle
        SG  %signal generator handle
        ReadOutTime %current read out time of the laser
        f %image figure handle that APD streams to
        prefs = {'CWFreq','piTime','MWPower','minReadOutTime',...
            'maxReadOutTime','LaserStep','ip','nidaqName','SNR',...
            'apdLine','maxCounts','repeatMax' ,'padding',...
           'reInitializationTime'}
    end
    
    properties(SetObservable)
        CWFreq = 2.75e9; %Hz
        piTime = 100; %ns
        MWPower = 10; %dbm
        ip = 'localhost';
        nidaqName = 'dev1'
        SNR = 100;% averages will be increased until this SNR is reached
        apdLine = 3; %indexed from 1
        minReadOutTime = 100; %minimum laser readoutTime in ns
        maxReadOutTime = 1000; %maximum expeceted delay in ns
        LaserStep = 10; %laser step size in ns
        maxCounts = 1e4;
        repeatMax = 1e6;
        padding = 1000; %time between MW and laser readout in ns
        reInitializationTime = 2000; %time to reinitialize the NV to 0 state in ns
    end
    
    methods(Access=private)
        function obj = CalibrateReadoutTime()
            obj.loadPrefs;
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.Calibration.CalibrateReadoutTime();
            end
            obj = Object;
        end
    end
    
    methods
        
        function set.minReadOutTime(obj,val)
            assert(isnumeric(val),'minReadOutTime must be dataType numeric')
            assert(val > obj.minSequenceDuration ,['minReadOutTime must be greater than  ',num2str(obj.minSequenceDuration)])
            obj.minReadOutTime = val;
        end
        
        function set.maxReadOutTime(obj,val)
            assert(isnumeric(val),'maxReadOutTime must be dataType numeric')
            assert(val > obj.minReadOutTime + obj.LaserStep  ,['maxReadOut'...
                'Time must be greater than  ',num2str(obj.minReadOutTime + obj.LaserStep)])
            assert(val < obj.reInitializationTime,['maxReadOutTime must be less than ', num2str(obj.reInitializationTime)])
            obj.maxReadOutTime = val;
        end
        
        function set.LaserStep(obj,val)
            assert(isnumeric(val),'LaserStep must be dataType numeric')
            assert(val > obj.minSequenceDuration ,['LaserStep must be greater than  ',num2str(obj.minSequenceDuration)])
            obj.LaserStep = val;
        end
        
        function set.reInitializationTime(obj,val)
            assert(isnumeric(val),'reInitializationTime must be dataType numeric')
            assert(val > obj.maxReadOutTime ,['reInitializationTime must be greater than  ',num2str(obj.maxReadOutTime)])
            obj.reInitializationTime = val;
        end
        
        function set.piTime(obj,val)
            assert(isnumeric(val),'piTime must be dataType numeric')
            assert(val > obj.minSequenceDuration ,['piTime must be greater than  ',num2str(obj.minSequenceDuration)])
            obj.piTime = val;
        end
        
        function run(obj,statusH,managers,ax)
            
            obj.abort_request=0;
            obj.selection = false;
            %%
            
            modules = managers.Sources.modules;
            obj.laser = obj.find_active_module(modules,'Laser532_PB');
            obj.laser.off;
            %%
            
            obj.Ni = Drivers.NIDAQ.dev.instance(obj.nidaqName);
            obj.Ni.ClearAllTasks;
            %%
            
            obj.pulseblaster = Drivers.PulseBlaster.Remote.instance(obj.ip);
            %% 
            
            obj.SG = obj.find_active_module(modules,'Signal_Generator');
            obj.SG.serial.reset;
            obj.SG.serial.setUnitPower;
            obj.SG.MWFrequency  = obj.CWFreq;
            obj.SG.MWPower = obj.MWPower;
            
            %%
            obj.get_image_axis_handle;
            obj.ax = ax;
            [obj.optimumReadTime] = obj.CalibrateReadout;
            
            %% display message to user
            
            message = sprintf('Your optimal readout time is %d ns.',obj.optimumReadTime);
            msgbox(message);
            
            
            %% cleanup experiment
            obj.Ni.ClearAllTasks;
            delete(obj.f);
            obj.laser.off;
            obj.SG.serial.reset;
            
        end
        
        function module_handle = find_active_module(obj,modules,active_class_to_find)
            module_handle = [];
            for index=1:length(modules)
                class_name=class(modules{index});
                num_levels=strsplit(class_name,'.');
                truth_table=contains(num_levels,active_class_to_find);
                if sum(truth_table)>0
                    module_handle=modules{index};
                end
            end
            assert(~isempty(module_handle)&& isvalid(module_handle),['No actice class under ',active_class_to_find,' in CommandCenter as a source!'])
        end
        
        function get_image_axis_handle(obj)
            hObj = findall(0,'name','CommandCenter');
            handles = guidata(hObj);
            obj.image_axes = handles.axImage;
        end
        
        function readOutVector = determineReadOutVector(obj)
            readOutVector = obj.minReadOutTime:obj.LaserStep:obj.maxReadOutTime;
            if ~(readOutVector(end) == obj.maxReadOutTime) && ~obj.selection
                Question = sprintf('MaxReadOutTime is %d instead of %d. Continue?',readOutVector(end),obj.maxReadOutTime);
                ButtonName = questdlg(Question,'Choose','yes','no','no');
                obj.selection = true;
                if strcmpi(ButtonName,'no')
                    obj.abort;
                end
            end
        end
        
        function abort(obj)
            obj.abort_request = true;
            obj.Ni.ClearAllTasks;
            delete(obj.f);
            obj.laser.off;
            obj.SG.serial.reset;
        end
        
        function plot_data(obj)
            readOutVector = obj.determineReadOutVector; %time in ns
            errorbar(readOutVector,100*(obj.background - obj.data.contrast_vector),100*obj.data.error_vector,'parent',obj.ax)
            xlim(obj.ax,readOutVector([1,end]));
            xlabel(obj.ax,'Readout Time (ns)')
            ylabel(obj.ax,'Contrast (%)')
            axis(obj.ax,'tight')
        end
       
        function data = GetData(obj,~,~)
            data.readOutVector = obj.determineReadOutVector;
            data.data = obj.data;
            data.optimumReadTime = obj.optimumReadTime;
            data.CWFreq = obj.CWFreq;
            data.piTime = obj.piTime;
            data.MWPower =obj.MWPower;
            data.ip = obj.ip;
            data.nidaqName = obj.nidaqName;
            data.SNR = obj.SNR;
            data.apdLine = obj.apdLine;
            data.maxCounts = obj.maxCounts;
            data.repeatMax = obj.repeatMax;
            data.padding =obj.padding;
            data.reInitializationTime = obj.reInitializationTime;
            data.background = obj.background;
        end
    end
end