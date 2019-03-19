classdef CMOS_SG < Modules.Source
    %Hewlett Packard serial source class
    
    properties
        PBline = 1;                  % Pulse Blaster flag bit (indexed from 1)
        CMOS_Chip_Control
        serial
        SGref
        prefs = {'MWFrequency','MWPower','MW_switch_PB_line','SG_trig_PB_line','ip'};
    end
    
    properties (SetObservable)
        MWFrequency = 3e9; %MW frequency
        MWPower = -30; %dBm of SG
        MW_switch_PB_line = 1; %pulseblaster hardware line (indexed from 1) for mw_switch
        SG_trig_PB_line = 2;% hw line to trigger SG (indexed from 1)
        ip = 'localhost';      %ip address for the pulseblaster
    end
    
    
    properties(SetAccess=private, SetObservable)
        SG_name='Signal Generator 1';
        source_on = false;
        running
    end
    
    properties (Constant)
        PLLDivisionRatio = 32;
    end
    
    methods(Access=protected)
        function obj = CMOS_SG()
            obj.SGref = Sources.Signal_Generator.Hewlett_Packard.HP_PB_switch.instance;
            obj.serial = obj.SGref.serial;
            obj.loadPrefs;
        end
    end
    
    properties(SetAccess=private)
        PulseBlaster                 % Hardware handle
    end
    
    properties(Access=private)
        listeners
        status                       % Text object reflecting running
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.Signal_Generator.CMOS_SG();
            end
            obj = Object;
        end
    end
    
    methods
        function set.MWFrequency(obj,val)
            assert(isnumeric(val),'MWFrequency must be a number')
            obj.SGref.MWFrequency = val./obj.PLLDivisionRatio; %debugging happens here
            obj.MWFrequency = val;
        end
        
        function set.ip(obj,val)
            err = [];
            try
                obj.PulseBlaster = Drivers.PulseBlaster.StaticLines.instance(val); %#ok<*MCSUP>
                obj.source_on = obj.PulseBlaster.lines(obj.PBline);
                delete(obj.listeners)
                obj.listeners = addlistener(obj.PulseBlaster,'running','PostSet',@obj.isRunning);
                obj.ip = val;
                obj.isRunning;
            catch err
                obj.PulseBlaster = [];
                delete(obj.listeners)
                obj.source_on = 0;
                obj.ip = 'No Server';
            end
            if ~isempty(err)
                rethrow(err)
            end
        end
        
        function set.MWPower(obj,val)
            obj.SGref.MWPower = val; %debugging happens here
            obj.MWPower = obj.SGref.MWPower;
        end
        
        function MWFrequency = get.MWFrequency(obj)
            MWFrequency = obj.SGref.MWFrequency*obj.PLLDivisionRatio;
        end
        
        function MWPower = get.MWPower(obj)
            MWPower = obj.SGref.MWPower;
        end
        
        function on(obj,~)
            obj.SGref.on;
            obj.source_on = 1;
            assert(~isempty(obj.PulseBlaster),'No IP set!')
            obj.PulseBlaster.lines(obj.PBline) = true;
            obj.source_on = true;
        end
        
        function delete(obj)
            obj.SGref.delete;
            delete(obj.listeners);
        end
        
        function off(obj)
            assert(~isempty(obj.PulseBlaster),'No IP set!')
            obj.source_on = false;
            obj.PulseBlaster.lines(obj.PBline) = false;
            obj.SGref.off;
        end
        
        function PBlineCallback(obj,src,varargin)
            val = str2double(get(src,'string'));
            assert(round(val)==val&&val>0,'Number must be an integer greater than 0.')
            obj.PBline = val;
        end
        
        function ipCallback(obj,src,varargin)
            err = [];
            try
                obj.ip = get(src,'string');
            catch err
            end
            set(src,'string',obj.ip)
            if ~isempty(err)
                rethrow(err)
            end
        end
        function isRunning(obj,varargin)
            if isempty(obj.PulseBlaster)
                update = 'Not Connected';
                if ~isempty(obj.status)&&isvalid(obj.status)
                    set(obj.status,'string',update)
                end
                return
            end
            obj.running = obj.PulseBlaster.running;
            if ~isempty(obj.status)&&isvalid(obj.status)
                if obj.running
                    update = 'Running';
                else
                    update = 'Unknown State, to update, change state.';
                end
                set(obj.status,'string',update)
            end
        end
    end
end

    
   
   
   
       
      
      
       
    
