classdef Keithley2400 < handle
    
    properties(SetAccess=protected)
        GPIBAddr            % GPIB address
        RsrcName            % Resource name of the VISA instrument
        VisaHandle          % Handle of the VISA object
    end
    methods%(Access=private)
        function openConnection(obj)
            if strcmp(obj.VisaHandle.Status,'closed')
                fopen(obj.VisaHandle);
            end
        end
        function closeConnection(obj)
            if strcmp(obj.VisaHandle.Status,'open')
                fclose(obj.VisaHandle);
            end
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
    end
    methods
        function obj = Keithley2400(GPIBAddr)
            obj.GPIBAddr = GPIBAddr;
            obj.RsrcName = ['GPIB0::' num2str(obj.GPIBAddr) '::INSTR'];
            obj.VisaHandle = visa('ni',obj.RsrcName);
            obj.openConnection();
        end
        function delete(obj)
            obj.closeConnection();
            delete(obj.VisaHandle);
        end
        %% Basic control functions
        function outputOn(obj)
            obj.cmd('outp:stat 1');
        end
        function outputOff(obj)
            obj.cmd('outp:stat 0');
        end
        function output = outputState(obj)  % 1 for On, 0 for Off
            output = str2double(obj.query('outp:stat?'));
        end
        function setOutputMode(obj,mode)    % mode can be: 'VOLT' or 'CURR'
            obj.cmd(['sour:func:mode ' mode]);
        end
        function setComplianceCurrent(obj, amp)
           obj.cmd(['sens:curr:prot ' num2str(amp)])
        end
        function setComplianceVoltage(obj, volt)
           obj.cmd(['sens:volt:prot ' num2str(volt)])
        end
        function setOutputVoltage(obj,volt)
            obj.cmd(['sour:volt:lev:imm:ampl ' num2str(volt)]);
        end
        function voltOut = readOutputVoltage(obj) % gives set output voltage (output might be either on or off)
            voltOut = str2double(obj.query('sour:volt?'));
        end
        function setOutputCurrent(obj,curr)
            obj.cmd(['sour:curr:lev:imm:ampl ' num2str(curr)]); % gives set output current (output might be either on or off)
        end
        function currOut = readOutputCurrent(obj)
            currOut = str2double(obj.query('sour:curr?'));
        end
        %% Measurement functions
        % Measure voltage with an open circuit configuration (current = 0 A)
        function voltMeas = measureVoltage(obj)
            % turn I-source on (0 A: open circuit) and measure V
            obj.setOutputCurrent(0);
            obj.setOutputVoltage(0);
            obj.setOutputMode('CURR');
            obj.outputOn();
            voltMeas = str2double(strtok(obj.query('meas:VOLT:DC?'),','));  % returned measuremnet consists of 5 numbers, the first is voltage
        end
        % Measure current with a previously set voltage
        function currMeas = measureCurrent(obj)
            % query output mode and whether output is on
%             outputMode = obj.query('sour:func:mode?');
%             currOut = readOutputCurrent(obj);
%             outputOnDone = obj.outputState;
            % turn V-source on and measure I
%             obj.setOutputCurrent(0);
%             obj.setOutputMode('VOLT');
%             obj.outputOn();
            queryOutput = obj.query('meas:CURR:DC?');
            [~,remain] = strtok(queryOutput,',');
            currMeas = str2double(strtok(remain,','));  % returned measuremnet consists of 5 numbers, the second one is current
            % return Keithley to state before measurement
%             obj.setOutputCurrent(currOut);
%             obj.cmd(['sour:func:mode ' outputMode]);
%             obj.cmd(['outp:stat ' num2str(outputOnDone)]);  % return output to original state
        end
    end
end