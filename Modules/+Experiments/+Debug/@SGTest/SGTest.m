classdef SGTest < Experiments.Debug.DebugSuperClass_invisible
    %SGTest runs diagnostics on communicating with a signal generator (SG).
    %User should plug SG directly into an oscilloscope or spectrum analyzer
    %to verify correct outputs. These user-dependent checks are indicated
    %in the course of running SGTest
    
    properties
        freq_list
        power_list
        abort_request = false;  % Request flag for abort

        prefs = {'freq_CW','power_CW','min_freq','max_freq','freq_step',...
            'min_power','max_power','power_step','trigger_type','trig_ip','SG_trig_hw'}
    end
    
    properties(SetObservable)
        freq_CW = 2.5*10^9; %frequency for testing CW frequency setting
        power_CW = -70; %frequency for testing CW frequency setting
        min_freq = 2.5*10^9; %start frequency for LIST mode
        max_freq = 2.55*10^9; %stop frequency for LIST mode
        freq_step = 0.01*10^9; %frequency step for LIST mode
        min_power = -70; %start power for LIST mode
        max_power = -60; %stop power for LIST mode
        power_step = 1; %power step for LIST mode
        trigger_type = {'None','PulseBlaster','NIDAQ'}; %hardware options for triggering LIST mode stepping
        trig_ip = 'localhost'; %IP address of hw trigger for LIST mode
        SG_trig_hw = 2; %channel number or name of hw trigger for LIST mode 
    end
    
    properties(Access=private)
        SG;
        data;
        PulseBlaster;
        ni;
    end
    
    methods(Access=private)
        function obj = SGTest()
            obj.loadPrefs;
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.Debug.SGTest();
            end
            obj = Object;
        end
    end
    
    methods
        
        function abort(obj)
            obj.abort_request = true;
        end
                
        function set.trigger_type(obj,val)
            %Initializes hardware needed to trigger LIST mode stepping
            try
                switch val
                    case 'None'
                    case 'PulseBlaster'
                        obj.PulseBlaster = Drivers.PulseBlaster.StaticLines.instance(obj.trig_ip);
                    case 'NIDAQ'
                        obj.nidaq = Drivers.NIDAQ.dev.instance('Dev1');
                        try
                            lines = obj.nidaq.getLines(obj.SG_trig_hw,'out');
                        catch err
                            msg = err.message;
                            error('No line with name:\n%s',msg)
                        end
                    otherwise
                        error('SGTest trigger method not recognized.')
                end
                obj.trigger_type = val;
            catch err
                %if error in setting, reset to trigger type 'None'
                obj.trigger_type = 'None';
                rethrow(err);
            end
        end
        
        function StepList(obj)
            %Gives a pulse from the desired trigger method to the
            %signal generator to trigger a step in list mode
            pause_time = 1e-3; %1 ms pulse length
            switch obj.trigger_type
                case 'PulseBlaster'
                    obj.PulseBlaster.lines(obj.SG_trig_hw) = true;
                    pause(pause_time)
                    obj.PulseBlaster.lines(obj.SG_trig_hw) = false;
                case 'NIDAQ'
                    obj.nidaq.WriteDOLines(obj.SG_trig_hw,1)
                    pause(pause_time)
                    obj.nidaq.WriteDOLines(obj.SG_trig_hw,0)
                case 'None'
                    warning('No trigger type in testing ListMode.')
                otherwise
                    error('Unknown trigger type in testing ListMode.')
            end
        end
        
        function [freq_list, power_list] = BuildFreqLists(obj)
            %builds a list of constant power and a list of stepping
            %frequencies
            freq_list = obj.min_freq:obj.freq_step:obj.max_freq;
            power_list = obj.power_CW*ones(1,length(freq_list));
        end
        
        function [freq_list, power_list] = BuildPowerLists(obj)
            %builds a list of constant frequency and a list of stepping
            %powers
            power_list = obj.min_power:obj.power_step:obj.max_power;
            freq_list = obj.freq_CW*ones(1,length(power_list));
        end
        
        function data = GetData(obj,~,~)
            if isempty(obj.tests)
                data = [];
            else
                data.driver = obj.driver;
                data.tests = obj.tests;
                data.status = obj.status;
            end
        end
    end
end
