classdef Modulation_for_LockIn < handle
    %Triggered_AI_Measurement Summary of this class goes here
    
    properties
        SamplingRate = 500e3;
        ni              % NIDAQ driver
        ExtClk = 1;     %set to 1 to clock to pulseblaster
        expectedTriggers
    end
    
    properties(SetAccess=private)
        taskNameAO = 'LockInModulation';
    end
    
    properties (Constant)
        libname = 'nidaqmx';
        libfilepath = 'C:\Users\QPG\AutomationSetup\Modules\+Drivers\+NIDAQ\@dev\nicaiu.dll';
        libheaderfile = 'C:\Program Files (x86)\National Instruments\NI-DAQ\DAQmx ANSI C Dev\include\NIDAQmx.h';
    end
    
  methods(Static)
        function obj = instance(AOWaveForm,VoltageLimOut)
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Modulation_for_LockIn(AOWaveForm,VoltageLimOut);
            end
            obj = Object;
        end
  end
    
  methods
        function obj = Modulation_for_LockIn(AOWaveForm,VoltageLimOut)
         
            obj.ni =  NIDAQ_Config_ver5(obj.libname, obj.libfilepath, obj.libheaderfile);
            obj.ni.UpdateAllLines()
            try
                obj.ni.StopTask(obj.taskNameAO);
            end

            obj.expectedTriggers = numel(AOWaveForm);
            obj.ni.CreateTask(obj.taskNameAO);
            obj.ni.ConfigureContGatedAOVoltageChan(obj.taskNameAO, VoltageLimOut(1)...
                , VoltageLimOut(2), obj.SamplingRate, obj.expectedTriggers, ...
                AOWaveForm);            
        end
        
        function start(obj)
%             obj.ni.StartTask(obj.taskNameAI);
            obj.ni.StartTask(obj.taskNameAO);
        end
        
%         function data = returnData(obj)
%             data = obj.ni.ReadAI(obj.taskNameAI,obj.expectedTriggers);
%             obj.ni.StopTask(obj.taskNameAI);
%             obj.ni.StopTask(obj.taskNameAO);
        
        function clean(obj)
%             obj.ni.ClearTask(obj.taskNameAI);
            obj.ni.ClearTask(obj.taskNameAO);
        end
        
        function stopModulation(obj)
            obj.ni.StopTask(obj.taskNameAO);
        end
        
        function stopAllTask(obj)
%             obj.ni.StopTask(obj.taskNameAI);
            obj.ni.StopTask(obj.taskNameAO);
        end
    end
end