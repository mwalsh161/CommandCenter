classdef Saturation < Modules.Experiment
    % Continuously acquires data from the APD and Thorlabs PM100 power meter and plots them. 
    % User should rotate the polarizer/HWP.
    
    properties
        pm_data;
        apd_data;
        linein = 'APD1';
        lineout = 'CounterSync';
        acquire = false; % this tracks when the user wants to stop acquiring data
        nsamples = 1; % number of samples the APD collects
        wavelength = 532;
        prefs = {'linein', 'lineout', 'acquire', 'nsamples', 'wavelength'};
    end

    properties (SetAccess=private)
        PM100;
        counter;
    end
    
    methods(Access=private)
        function obj = Saturation()
            obj.loadPrefs;
            obj.PM100 = Drivers.PM100.instance();
            obj.counter = Drivers.Counter.instance(obj.linein,obj.lineout);
        end
    end

    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.Saturation();
            end
            obj = Object;
        end
    end

    methods
        run(obj,status,managers,ax)
        
        function delete(obj)
            obj.PM100.delete;
        end

        function abort(obj)
            obj.acquire = false;
        end

        function dat = GetData(obj,stageManager,imagingManager)
        % Saves the in v. out power, the excitation wavelength, and the dwell time and number of samples for the APD
            dat.in_power = obj.pm_data;
            dat.out_power = obj.apd_data;            

            dat.in_wavelength = obj.PM100.get_wavelength();
            dat.dwell_time = obj.counter.dwell;
            dat.nsamples = obj.nsamples;
        end

        function settings(obj,panelH)
        % Creates a button for the user to stop acquiring data once it has started and a place for user to set the
        % measurement wavelength of the PM
            spacing = 2.25;

            uicontrol(panelH,'style','text','string','Excitation Wavelength (nm):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*3 25 1.25]);
            
            uicontrol(panelH,'style','edit','string',obj.wavelength,...
                'units','characters','callback',@obj.set_wl,...
                'horizontalalignment','left','position',[26 spacing*3 20 1.5]);

            uicontrol(panelH,'style','text','string','APD Dwell Time:','horizontalalignment','right',...
                'units','characters','position',[0 spacing*2 25 1.25]);
            
            uicontrol(panelH,'style','edit','string',obj.counter.dwell,...
                'units','characters','callback',@obj.set_dwell,...
                'horizontalalignment','left','position',[26 spacing*2 20 1.5]);

            uicontrol(panelH,'style','text','string','APD Number of Samples:','horizontalalignment','right',...
                'units','characters','position',[0 spacing 25 1.25]);
            
            uicontrol(panelH,'style','edit','string',obj.nsamples,...
                'units','characters','callback',@obj.set_nsample,...
                'horizontalalignment','left','position',[26 spacing 20 1.5]);
        end

        function stop_acquire(obj, varargin)
        % Callback function for the stop acquisition button
            obj.acquire = false;
        end

        function set_wl(obj, src, varargin)
            obj.wavelength = str2num(get(src, 'string'));
        end

        function set_dwell(obj, src, varargin)
            obj.counter.dwell = str2num(get(src, 'string'));
        end

        function set_nsample(obj, src, varargin)
            obj.nsamples = str2num(get(src, 'string'));
        end
    end
end