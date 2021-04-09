classdef Keithley2400 < Modules.Driver
    %KEITHLEY2400 Interfaces with the eponymous signal generator.
    
    properties (SetAccess=protected, Hidden)
        GPIBAddr            % GPIB address
        RsrcName            % Resource name of the VISA instrument
        VisaHandle          % Handle of the VISA object
    end
    
    properties (GetObservable, SetObservable)
        output =    Prefs.Boolean(false, 'set', 'set_output', ...
                                                                'help_text', 'Whether the source is outputing voltage or current');
        mode =      Prefs.MultipleChoice('VOLT', 'set', 'set_mode', 'choices', {'VOLT', 'CURR'}, ...
                                                                'help_text', 'Output mode of the voltage/current source.');
        voltage =   Prefs.Double(0, 'set', 'set_voltage', ...
                                                                'help_text', 'Setpoint voltage of the source. This is different from measured voltage in the case the the source is operating in CURR mode.');
        current =   Prefs.Double(0, 'set', 'set_current', ...
                                                                'help_text', 'Setpoint current of the source. This is different from measured current in the case the the source is operating in VOLT mode.');
    end
    
    % Constructor functions
    methods (Static)
        function obj = instance(GPIBAddr)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.Keithley2400.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(GPIBAddr,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.Keithley2400(GPIBAddr);
            obj.singleton_id = GPIBAddr;
            Objects(end+1) = obj;
        end
    end
    methods (Access=private)
        function obj = Keithley2400(GPIBAddr)
            obj.GPIBAddr = GPIBAddr;
            obj.RsrcName = ['GPIB0::' num2str(obj.GPIBAddr) '::INSTR'];
            obj.VisaHandle = visa('ni',obj.RsrcName);
            obj.openConnection();
        end
    end
    
    % I/O functions
    methods
        function openConnection(obj)
            if strcmp(obj.VisaHandle.Status,'closed')
                fopen(obj.VisaHandle);
                obj.init();     % Read values from the source.
            end
        end
        function closeConnection(obj)
            if strcmp(obj.VisaHandle.Status,'open')
                fclose(obj.VisaHandle);
            end
        end
        function delete(obj)
            obj.closeConnection();
            delete(obj.VisaHandle);
        end
        function cmd(obj,msg)
            % open the port if closed
            if strcmp(obj.VisaHandle.Status,'closed')
                fopen(obj.VisaHandle);
                CloseOnDone = 1;
            else
                CloseOnDone = 0;
            end
            fprintf(obj.VisaHandle,msg);
            if CloseOnDone
                fclose(obj.VisaHandle);
            end
        end
        function out = query(obj,msg)
            % open the port if closed
            if strcmp(obj.VisaHandle.Status,'closed')
                fopen(obj.VisaHandle);
                CloseOnDone = 1;
            else
                CloseOnDone = 0;
            end
            fprintf(obj.VisaHandle,msg);
            out = fscanf(obj.VisaHandle);
            if CloseOnDone
                fclose(obj.VisaHandle);
            end
        end
        function init(obj)
            obj.output =    obj.get_output();
%             obj.mode =      obj.get_mode();
            obj.voltage =   obj.get_voltage();
            obj.current =   obj.get_current();
        end
    end
    
    % Basic control functions
    methods
        % Output
        function val = set_output(obj, val, ~)
            val = logical(val);
            obj.cmd(['outp:stat ' num2str(val)]);
        end
        function output = get_output(obj)
            output = str2double(obj.query('outp:stat?'));
            obj.output = output;
        end
        
        % Mode
        function val = set_mode(obj, val, ~)
            assert(strcmp(val, 'VOLT') || strcmp(val, 'CURR'), 'mode must be: ''VOLT'' or ''CURR''');
            obj.cmd(['sour:func:mode ' val]);
        end
%         function mode = get_mode(obj)
        
        % Setpoint voltage
        function val = set_voltage(obj, val, ~)
            obj.cmd(['sour:volt:lev:imm:ampl ' num2str(val)]);
        end
        function voltage = get_voltage(obj)
            voltage = str2double(obj.query('sour:volt?'));
        end
        
        % Setpoint current
        function val = set_current(obj, val, ~)
            obj.cmd(['sour:curr:lev:imm:ampl ' num2str(val)]);
        end
        function current = get_current(obj)
            current = str2double(obj.query('sour:curr?'));
        end
        
        % Measure voltage
        function voltage = measureVoltage(obj)
            voltage = str2double(strtok(obj.query('meas:VOLT:DC?'),','));  % returned measuremnet consists of 5 numbers, the first is voltage
        end
        
        % Measure current
        function current = measureCurrent(obj)
            queryOutput = obj.query('meas:CURR:DC?');
            [~,remain] = strtok(queryOutput,',');
            current = str2double(strtok(remain,','));  % Returned measurement consists of 5 numbers, the second one is current
        end
    end
end