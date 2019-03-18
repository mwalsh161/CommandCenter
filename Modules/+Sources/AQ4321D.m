classdef AQ4321D < Modules.Source
    % Source module for Ando AQ4321D L-Band laser
    % Settings: 
    % port - string, i.e. 'COM4', specifying serial port of device
    % frequency (THz)/wavelength (nm) - setting either is equivalent; 
    % listeners will update each to stay consistent
    % power_mW - power setting in mW (note that driver supports both mW and
    % dBm, but for GUI only mW is used)
    % 
    % Note that all of the get.property methods for these settings will
    % query the hardware
    %
    % On setting 'port' property, module will attempt to instantiate driver
    % with provided port string. If successful, other settings will be
    % populated with current values. If unsuccessful, port string resets to
    % 'No connection' and driver (property obj.serial) remains 
    % uninstantiated.
    
    properties
        prefs = {'port'};
        show_prefs = {'port','wavelength','frequency','power_mW'}
    end
    properties(SetObservable,SetAccess=private)
        source_on = false;
    end
    properties(SetObservable, AbortSet)
        port = 'Not Connected';
        wavelength = NaN;
        frequency = NaN;
        power_mW = NaN;
    end
    properties(Access=private)
        listeners
        serial
    end
    properties(Constant)
        c = 299792.458; %speed of light in nm*THz
    end
    methods(Access=protected)
        function obj = AQ4321D()
            obj.loadPrefs;
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.AQ4321D();
            end
            obj = Object;
        end
    end
    methods
        function set.port(obj,val)
            %upon setting of port, attempts connection; if successful, will
            %update settings in GUI to be consistent with current values
            err = [];
            if ~isempty(obj.serial)
                obj.serial.delete; %closes connection if already instantiated
                obj.serial = [];
                delete(obj.listeners)
            end
            try
                obj.serial = Drivers.AQ4321D.instance(val); %#ok<*MCSUP>
                obj.listeners = addlistener(obj.serial,'frequency',...
                    'PostSet',@(hObj,evdt)updateprop(hObj,evdt,obj));
                obj.listeners(end+1) = addlistener(obj,'frequency',...
                    'PostSet',@obj.updateWavelength);
                obj.listeners(end+1) = addlistener(obj.serial,'power_mW',...
                    'PostSet',@(hObj,evdt)updateprop(hObj,evdt,obj));
                obj.port = val;
            catch err
                if ~isempty(obj.serial) %connection made, error was elsewhere
                    obj.serial.delete; %need to close connection
                    obj.serial = [];
                end
                delete(obj.listeners)
                obj.port = 'Not Connected';
                obj.source_on = 0;
            end
            %In order to update GUI independent of whetehr or not
            %connection was successful, attempt to get each property in its
            %own try statement such that the errors thrown in case of no
            %connection are ignored
            proplist = {'source_on','GetEmission','frequency','frequency',...
                'power_mW','power_mW'};
            if ~isempty(obj.serial)
                for i=1:2:length(proplist)
                    obj.(proplist{i}) = obj.serial.(proplist{i+1});
                end
                obj.wavelength = obj.c/obj.frequency;
            else
                obj.wavelength = NaN;
                obj.frequency = NaN;
                obj.power_mW = NaN;
            end
            if ~isempty(err)
                rethrow(err)
            end
        end
        function delete(obj)
            %deletes connection and listeners
            if ~isempty(obj.serial)
                obj.serial.delete;
            end
            delete(obj.listeners)
        end
        function on(obj)
            %turns laser emission on
            assert(~isempty(obj.serial),'Not Connected!')
            obj.serial.SetEmission(true)
            obj.source_on = true;
        end
        function off(obj)
            %turns laser emission off
            assert(~isempty(obj.serial),'Not Connected!')
            obj.serial.SetEmission(false)
            obj.source_on = false;
        end
        
        %set methods that talk to driver
        function set.frequency(obj,val)
            %sets frequency in THz by calling driver method SetFrequency
            if isnan(val)
                obj.frequency = NaN;
                return
            end
            assert(~isempty(obj.serial),'Not connected')
            obj.serial.SetFrequency(val);
            obj.frequency = val;
        end
        function set.wavelength(obj,val)
            %sets wavelength in nm by triggering listener for frequency
            %since this always talks to the driver through set.frequency,
            %no need to check if serial conncetion
            obj.frequency = obj.c/val;
            obj.wavelength = val;
        end
        function set.power_mW(obj,val)
            %sets power in mW by calling driver method SetPower
            if isnan(val)
                obj.power_mW = NaN;
                return
            end
            assert(~isempty(obj.serial),'Not connected')
            obj.serial.SetPower(val,'mw')
            obj.power_mW = val;
        end
        
        %Listener functions for keeping wavelength/frequency consistent
        function updateWavelength(obj,~,~)
            %listener callback to keep frequency and wavelength consistent
            obj.wavelength = obj.c/obj.frequency;
        end
    end
end
