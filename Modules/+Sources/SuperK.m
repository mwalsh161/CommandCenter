classdef SuperK < Modules.Source
    %   SuperK used to control all aspects of the superK laser.
    %
    %   The emission state of the laser is controlled by serial connection
    %   

    
    properties
        host = 'No Server'; % host of computer with and server
        show_prefs = {'Power','Pulse_Picker','Rep_Rate','Center_Wavelength',...
            'Bandwidth','Attenuation','host'};
        Power = Prefs.Double('max',100,'min',0,'units','%','allow_nan',false,...
            'set','setPower','tag','setPower');
        Pulse_Picker = Prefs.Integer('max',40,'min',1,'help_text','Divider of max rep rate',...
            'set','getPulsePicker','tag','getPulsePicker');
        Rep_Rate = Prefs.Double('units','MHz','readonly',true,...
            'set','getRepRate','tag','getRepRate');
        Center_Wavelength = Prefs.Double('min',0,'units','nm',...
            'set','getWavelength','tag','getWavelength');
        Bandwidth = Prefs.Double('min',0,'units','nm',...
            'set','getBandwidth','tag','getBandwidth');
        Attenuation = Prefs.Double('max',100,'min',0,'units','%',...
            'set','getND','tag','getND');
        prefs = {'host'};
    end
    properties(SetObservable,SetAccess=private)
        source_on = false;
        running                      % Boolean specifying if StaticLines program running
    end
    properties(SetAccess=private,Hidden)
        status                       % Text object reflecting running
        path_button
        comm = hwserver.empty
    end
    methods(Access=protected)
        function obj = SuperK()
            obj.loadPrefs;
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.SuperK();
            end
            obj = Object;
        end
    end
    methods
        function delete(obj)
            if obj.comm_isvalid
                delete(obj.comm);
            end
        end
        function setNum(obj,val,pref)
            obj.serial.(pref.tag.set)(val);

        end
        function set.host(obj,val)
            err = [];
            if obj.comm_isvalid
                delete(obj.comm);
            end
            if isempty(val) || strcmp(val,'No Server')
                obj.comm = hwserver.empty;
                obj.host = 'No Server';
                return
            end
            try
                obj.comm = Drivers.SuperK.instance(val);
                obj.host = val;   
            catch err
                obj.host = 'No Server';
            end
            if ~isempty(err)
                rethrow(err)
            end
        end
        function on(obj)
            obj.comm.on();
            obj.source_on = true;
        end
        function off(obj)
            obj.comm.off();
            obj.source_on = false;
        end

        function arm(obj)
            % nothing needs to be done since SuperK just needs on/off methods
        end
        
        function val = get.comm(obj)
            d = dbstack(1);
            if ~strcmp(d(1).name,'SuperK.comm_isvalid') % avoid recursive call
                assert(obj.comm_isvalid,'Not connected (set.host)');
            end
            val = obj.comm;
        end
        
        function val = comm_isvalid(obj) % get method allows direct access to comm
            val = any(isvalid(obj.comm));
        end
    end
end