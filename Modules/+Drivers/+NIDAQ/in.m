classdef in < handle
    %DAQin is a handle class for input lines for NIDAQ
    %   Makes it more convenient to modify properties of its state
    
    properties(SetAccess=immutable)
        dev                            % Drivers.NIDAQ.dev object
        type                           % digital/analog
        line                           % Physical Line name [see nidaqmx help]
        name                           % Alias - name used in MATLAB
    end

    methods(Access=private)
        function check(obj)
            lineparts = strsplit(obj.line,'/');
            lname = lineparts{end};
            if numel(lname)>2&&strcmp(lname(1:3),'CTR')
                % Counters are ok, and should not go through test below.
                return
            end
            task = obj.dev.CreateTask('InTest');
            try
                if obj.type(1) == 'd'
                    task.CreateChannels('DAQmxCreateDIChan',obj,'',obj.dev.DAQmx_Val_ChanPerLine);
                else
                    task.CreateChannels('DAQmxCreateAIVoltageChan',obj,'',obj.dev.DAQmx_Val_Cfg_Default,0, 1,obj.dev.DAQmx_Val_Volts ,[]);
                end
            catch err
                task.Clear;
                rethrow(err)
            end
            task.Clear;
        end
    end
    
    methods(Access={?Drivers.NIDAQ.dev})
        function obj = in(dev,line,name)
            assert(length(name)>=1,'Must have a line name')
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
            obj.check;
        end
        function str = text(obj)
            ch = strsplit(obj.line,'/');
            ch = strjoin(ch(3:end),'/');
            str = [obj.name ': ' ch];
        end
    end
    
end

