classdef Triggered_CTIA_Measurement < handle
    %Triggered_AI_Measurement Summary of this class goes here
    
    properties
        ni              % NIDAQ driver
        ExtClk = 1;     %set to 1 to clock to pulseblaster
        expectedTriggers
    end
    
    properties(SetAccess=private)
        taskNameAO = 'CTIAGating';
        taskNameAI = 'DMDSyncPulse';
    end
    
    properties (Constant)
        libname = 'nidaqmx';
        libfilepath = 'C:\Users\QPG\AutomationSetup\Modules\+Drivers\+NIDAQ\@dev\nicaiu.dll';
        libheaderfile = 'C:\Program Files (x86)\National Instruments\NI-DAQ\DAQmx ANSI C Dev\include\NIDAQmx.h';
        SamplingRate = 500e3;
    end
    
  methods(Static)
        function obj = instance(expectedTriggers,triggerVector,VoltageLimIn,VoltageLimOut)
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Triggered_CTIA_Measurement(expectedTriggers,triggerVector,VoltageLimIn,VoltageLimOut);
            end
            obj = Object;
        end
  end
    
  methods
        function obj = Triggered_CTIA_Measurement(expectedTriggers,triggerVector,VoltageLimIn,VoltageLimOut)
         
            obj.ni =  NIDAQ_Config_ver5(obj.libname, obj.libfilepath, obj.libheaderfile);
            obj.ni.UpdateAllLines()
            try
                obj.ni.StopTask(obj.taskNameAI);
                obj.ni.StopTask(obj.taskNameAO);
            end
            obj.expectedTriggers = expectedTriggers;
            
            obj.ni.CreateTask(obj.taskNameAI);
            obj.ni.ConfigureAIVoltageChan...
                (obj.taskNameAI, VoltageLimIn(1), VoltageLimIn(2)...
                , obj.SamplingRate, obj.expectedTriggers,obj.ExtClk);
            
            obj.ni.CreateTask(obj.taskNameAO);
            obj.ni.ConfigureGatedAOVoltageChan(obj.taskNameAO, VoltageLimOut(1)...
                , VoltageLimOut(2), obj.SamplingRate, obj.expectedTriggers, ...
                triggerVector);            
        end
        
        function start(obj)
            obj.ni.StartTask(obj.taskNameAI);
            obj.ni.StartTask(obj.taskNameAO);
        end
        
        function data = returnData(obj)
            data = obj.ni.ReadAI(obj.taskNameAI,obj.expectedTriggers);
            obj.ni.StopTask(obj.taskNameAI);
            obj.ni.StopTask(obj.taskNameAO);
        end
        
        function clean(obj)
            obj.ni.ClearTask(obj.taskNameAI);
            obj.ni.ClearTask(obj.taskNameAO);
        end
        
        function stopAllTask(obj)
            obj.ni.StopTask(obj.taskNameAI);
            obj.ni.StopTask(obj.taskNameAO);
        end
    end
end