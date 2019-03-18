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
    properties(SetAccess={?Drivers.NIDAQ.task,?Drivers.NIDAQ.dev},SetObservable,AbortSet)
        state = NaN                    % Last set state
    end
    properties(Access={?Drivers.NIDAQ.dev,?Drivers.NIDAQ.out})
        niListener                     % Handle to NIDAQ's listener to state_change
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
            line = ['/' dev.DeviceChannel '/' upper(line)];
            obj.dev = dev;
            obj.line = line;
            obj.name = name;
            if nargin < 4
                limits = [dev.AnalogOutMinVoltage dev.AnalogOutMaxVoltage];
            end
            obj.limits = limits;
            obj.check;
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
end

