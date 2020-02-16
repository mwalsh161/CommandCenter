classdef ANC300 < handle
    
    properties(SetAccess=protected)
        Port                % Serial Port
        SerialHandle        % Handle of the serial object
        Databits
        Stopbits
        Axes
        Baudrate
    end
    methods%(Access=private)
        function initializeConnection(obj)
            %set offset mode for all 3 axes
            for axis = obj.Axes
                obj.set_mode(axis, "off");
            end
        end
        function closeConnection(obj)
            % stop all axes
            for axis = obj.Axes
                obj.stop(axis);
                %obj.set_mode(axis, "gnd");
            end
        end
        function cmd(obj, msg)
            writeline(obj.SerialHandle, msg);
        end
        function out = query(obj, msg)
            flush(obj.SerialHandle);
            writeline(obj.SerialHandle, msg);
            out = readline(obj.SerialHandle);
            out = readline(obj.SerialHandle);
        end
    end
    methods
        function obj = ANC300(Port, Axes)
            obj.Port = Port;
            obj.Baudrate = 38400;
            obj.Databits = 8; % Default value for serialport
            obj.Stopbits = 1; % Default value for serialport
            obj.SerialHandle = serialport(obj.Port, obj.Baudrate);
            obj.Axes = Axes;
            obj.initializeConnection();
        end
        function delete(obj)
            obj.closeConnection();
            delete(obj.SerialHandle);
        end
        %% Basic control functions
        function set_mode(obj, axis, mode)
            assert(any(obj.Axes == axis), 'Unspecified axis');
            obj.cmd(sprintf("setm %i %s", axis, mode));
        end
        function set_offset_voltage(obj, axis, voltage)
            assert(any(obj.Axes == axis), 'Unspecified axis');
            assert(voltage < 0, 'Negative Offset Voltage');
            assert(voltage > 150, 'Offset Voltage too big');
            obj.cmd(sprintf("seta %i %.6f", axis, voltage));
        end
        function voltage = get_offset_voltage(obj, axis)
            assert(any(obj.Axes == axis), 'Unspecified axis');
            voltage_txt = obj.query(sprintf("geta %i", axis));
            split_voltage = voltage_txt.split();
            voltage = str2double(split_voltage(3));
        end
        function step_up(obj, axis, steps)
            assert(any(obj.Axes == axis), 'Unspecified axis');
            obj.cmd(sprintf("stepu %i %i", axis, steps));
        end
        function step_down(obj, axis, steps)
            assert(any(obj.Axes == axis), 'Unspecified axis');
            obj.cmd(sprintf("stepd %i %i", axis, steps));
        end
        function stop(obj, axis)
            assert(any(obj.Axes == axis), 'Unspecified axis');
            obj.cmd(sprintf("stop %i", axis));
        end
        function set_stepping_frequency(obj, axis, frequency)
            assert(any(obj.Axes == axis), 'Unspecified axis');
            obj.cmd(sprintf("setf %i %i", axis, frequency));
        end
        function set_stepping_voltage(obj, axis, voltage)
            assert(any(obj.Axes == axis), 'Unspecified axis');
            obj.cmd(sprintf("setf %i %.6f", axis, voltage));
        end
    end
end