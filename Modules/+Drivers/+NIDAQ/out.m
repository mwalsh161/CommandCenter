classdef out < handle
    %DAQout is a handle class for output lines for NIDAQ
    %   Makes it more convenient to modify properties of its state
    
    properties(SetAccess=immutable)
        dev                            % Drivers.NIDAQ.dev object
        type                           % digital/analog
        line                           % Physical Line name [see nidaqmx help]
        name                           % Alias - name used in MATLAB
        limits                         % [low,high] for analog lines
    end
%     properties(SetAccess={?Drivers.NIDAQ.task,?Drivers.NIDAQ.dev}, SetObservable, GetObservable)
    properties(SetObservable, GetObservable)
%          state = NaN                    % Last set state
        state = NaN;
    end
    properties(Access={?Drivers.NIDAQ.dev,?Drivers.NIDAQ.out})
        niListener                     % Handle to NIDAQ's listener to state_change
    end
    properties (Access=private, Hidden)
        pref;                           % The fake pref that is constructed to lead to this DAQ.
    end
    
    methods(Access=private)
        function check(obj)
            lineparts = strsplit(obj.line,'/');
            lname = lineparts{end};
            if numel(lname)>2&&strcmp(lname(1:3),'CTR')
                % Counters are ok, and should not go through test below.
                return
            end
            task = obj.dev.CreateTask('OutTest');
            try
                if obj.type(1) == 'd'
                    task.CreateChannels('DAQmxCreateDOChan',obj,[],obj.dev.DAQmx_Val_ChanPerLine);
                else
                    task.CreateChannels('DAQmxCreateAOVoltageChan',obj,[],0, 1,obj.dev.DAQmx_Val_Volts ,[]);
                end
            catch err
                task.Clear;
                rethrow(err)
            end
            task.Clear;
        end
    end
    methods(Access={?Drivers.NIDAQ.dev})
        function obj = out(dev,line,name,limits)
            assert(length(line)>=1,'Must have a line name')
            % Determine type of channel
            if lower(line(1))=='a'
                obj.type = 'analog';
            else
                obj.type = 'digital';
            end
            % Fix name to include device id
            pname = line;
            line = ['/' dev.DeviceChannel '/' upper(line)];
            obj.dev = dev;
            obj.line = line;
            obj.name = name;
            if nargin < 4 % This obviously does not matter for digital
                limits = [dev.AnalogOutMinVoltage dev.AnalogOutMaxVoltage];
            end
            assert(numel(limits)==2,'Limits should have two elements: [min max]');
            assert(limits(1) >= dev.AnalogOutMinVoltage, sprintf('Lower limit is below device min voltage (%g V)',dev.AnalogOutMinVoltage));
            assert(limits(2) <= dev.AnalogOutMaxVoltage, sprintf('Upper limit is above device max voltage (%g V)',dev.AnalogOutMaxVoltage));
            obj.limits = limits;
            obj.check;
            
            % Make and register a fake Pref:
            pref = Prefs.Double('name', obj.name, 'unit', 'V', 'min', limits(1), 'max', limits(2));
            pref.property_name = [lower(dev.DeviceChannel) '_' lower(line)];
            pref.property_name = lower(pname);
            pref.parent_class = class(dev);
            
            pref.writ_fn = @(x)(obj.writ(x));
            pref.read_fn = @()(obj.read());
%             pref.listen_fn = @(event, callback)(module_instance.addlistener(obj.property_name, event, callback));
%             pref.listen_fn = @(event, callback)(event.proplistener(obj, 'state', event, callback));
            pref.listen_fn = @(event, callback)([]);
            
            obj.pref = pref;
            
            pr = Base.PrefRegister.instance();
            pr.addPref(dev, pref);
        end
        function delete(obj)
            delete(obj.niListener)
        end
        function str = text(obj)
            ch = strsplit(obj.line,'/');
            ch = strjoin(ch(3:end),'/');
            str = [obj.name ': ' ch ' (' num2str(obj.state) ')'];
        end
    end
    methods
        function set_state(obj, val)
%             obj.type
            try
                if      strcmp(obj.type, 'digital')
                    obj.dev.WriteDOLines(obj.name, val);
                elseif  strcmp(obj.type, 'analog')
%                     true
%                     obj.dev
%                     val
                    obj.dev.WriteAOLines(obj.name, val);
                else    % Counter outputs NotImplemented.

                end
                
%                 obj.state = val;
            catch err
                warning(err.message);
            end
        end
        function tf = writ(obj, val)
            try
                obj.set_state(val);
                tf = true;
            catch
                tf = false;
            end
        end
        function val = read(obj)
            val = obj.state;
        end
    end
    methods
        function pref = get_meta_pref(obj)
            pref = obj.pref;
        end
    end
end

