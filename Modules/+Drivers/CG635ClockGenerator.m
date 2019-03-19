classdef CG635ClockGenerator < Modules.Driver 
    % Matlab Object Class implementing control for CG635ClockGenerator
    %
    %
    % One instance controls 1 physical device. Multiple instances can exist
    % simultaneously for different hardware channels. If you need two
    % devices to work together, a new class should be designed.
    %
    % State information of the machine is stored on the SG. Can be obtained
    % using the get methods.
    
    properties 
        prefs = {'comObjectInfo'};
        comObjectInfo = struct('comType','','comAddress','','comProperties','') %this property stores comInformation
        %to change comport information after instantiation call instance of
        %this class and change using comObject property. To make sure it is
        %permanant you can call Connect Devices again and set outputs to
        %the appropriate fields of comObjectInfo
        comObject;     % Serial/GPIB/Prologix
    end
  
    methods(Static)
        
        function obj = instance(name)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.CG635ClockGenerator.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(name,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.CG635ClockGenerator;
            obj.singleton_id = name;
            Objects(end+1) = obj;
        end
    end
    
    methods(Access=private)
        function [obj] = CG635ClockGenerator()
            obj.loadPrefs;
            display('setting comInfo for CG635ClockGenerator.')
            if isempty(obj.comObjectInfo.comType)&& isempty(obj.comObjectInfo.comAddress)&& isempty(obj.comObjectInfo.comProperties)
                %first time connecting should run the helperfunction
                %Connect_Device to establish your connection
                [obj.comObject,obj.comObjectInfo.comType,obj.comObjectInfo.comAddress,obj.comObjectInfo.comProperties] = Connect_Device;
            else
                try
                    %this is used for connecting every time after the first
                    %time
                    [obj.comObject,obj.comObjectInfo.comType,obj.comObjectInfo.comAddress,obj.comObjectInfo.comProperties] = ...
                        Connect_Device(obj.comObjectInfo.comType,obj.comObjectInfo.comAddress,obj.comObjectInfo.comProperties);
                catch
                    %this is only called if you change a device property
                    %after the intiial connection (ex: change GPIB
                    %address). This allows you to establish a new
                    %connection.
                    [obj.comObject,obj.comObjectInfo.comType,obj.comObjectInfo.comAddress,obj.comObjectInfo.comProperties] ...
                        = Connect_Device;
                end
            end
            fopen(obj.comObject);
        end
    end
    
    methods (Access=private)
        
        function writeOnly(obj,string)
            fprintf(obj.comObject,string);
        end
        
        function [output] = writeRead(obj,string)
            output = query(obj.comObject,string);
        end
        
    end
    %see superclass for a description of what the methods do. 
    methods
      
        %% set commands
        
        function setOutputClockFrequency(obj,frequency)
            assert(isnumeric(frequency),'frequency must be numeric')
            string = sprintf('FREQ %d',frequency);
            obj.writeOnly(string);
        end
        
        function setCMOSOutput(obj,mode)
            %             Set (query) the ith component of the CMOS output {to j}.
            %             The parameter i selects the CMOS component.
            %             i Value
            %             0 CMOS low voltage
            %             1 CMOS high voltage
            if ischar(mode)
                mode = lower(mode);
            end
            switch mode
                case {0,'low'}
                    index = 0;
                case {1,'high'}
                    index = 1;
                otherwise
                    error('Unknown mode. Acceptable modes are low and high.')
            end
            string = sprintf('CMOS %d',index);
            obj.writeOnly(string);
        end
        
        function setOutputVoltage(obj,voltage)
            % Set (query) the CMOS output {to i}.
            % The parameter i selects the standard level.
            % i Standard CMOS Level
            % 0 1.2 V standard CMOS
            % 1 1.8 V standard CMOS
            % 2 2.5 V standard CMOS
            % 3 3.3 V standard CMOS
            % 4 5.0 V standard CMOS
            % The query form returns –1 if the current levels do not correspond to one of the
            % standard levels. This indicates that the VAR LED is on.
            
            switch voltage
                case {1.2,0,'1.2'}
                    index = 0;
                case {1.8,1,'1.8'}
                    index = 1;
                case {2.5,2,'2.5'}
                    index = 2;
                case {3.3,3,'3.3'}
                    index = 3;
                case {5,4,'5'}
                    index = 4;
                otherwise
                    error(' Unknown voltage state.Possible voltages options are 1.2,1.8,2.5,3.3,5')
            end
            string = sprintf('STDC %d',index);
            obj.writeOnly(string);
         end
        
        function setPhase(obj,phase)
            %Set (query) the phase {to i}. Note that this command is executed as an
            %overlapped operation. If necessary, use *OPC or *WAI to determine when the
            %operation is complete.
            assert(isnumeric(phase),'phase must be numeric')
            string = sprintf('PHASE %d',phase);
            obj.writeOnly(string);
        end
        %% get commands
        function frequency = getOutputClockFrequency(obj)
            string = sprintf('FREQ?');
            s = obj.writeRead(string);
            frequency = str2num(s(1:end-1));
        end
        
        function mode = getCMOSOutput(obj)
            %             Set (query) the ith component of the CMOS output {to j}.
            %             The parameter i selects the CMOS component.
            %             i Value
            %             0 CMOS low voltage
            %             1 CMOS high voltage
          
            switch mode
                case {0,'low'}
                    index = 0;
                case {1,'high'}
                    index = 1;
                otherwise
                    error('Unknown mode. Acceptable modes are low and high.')
            end
            string = sprintf('CMOS?');
            s = obj.writeRead(string);
            index = str2num(s(1:end-1));
            options = {'low','high'};
            mode = options{index + 1};
        end
        
        function voltage = getOutputVoltage(obj)
            % Set (query) the CMOS output {to i}.
            % The parameter i selects the standard level.
            % i Standard CMOS Level
            % 0 1.2 V standard CMOS
            % 1 1.8 V standard CMOS
            % 2 2.5 V standard CMOS
            % 3 3.3 V standard CMOS
            % 4 5.0 V standard CMOS
            % The query form returns –1 if the current levels do not correspond to one of the
            % standard levels. This indicates that the VAR LED is on.
            string = sprintf('STDC?');
            s = obj.writeRead(string);
            index = str2num(s(1:end-1));
            options = [1.2,1.8,2.5,3.3,5];
            voltage = options(index+1);
         end
        
        function phase = getPhase(obj)
            %Set (query) the phase {to i}. Note that this command is executed as an
            %overlapped operation. If necessary, use *OPC or *WAI to determine when the
            %operation is complete.
            string = sprintf('PHASE?');
            s = obj.writeRead(string);
            phase = str2num(s(1:end-1));
        end
        %% general 
        
        function delete(obj)
            obj.off;
            fclose(obj.comObject);
            delete(obj.comObject);
        end
        
        function on(obj)
            string = sprintf('RUNS 1');
            obj.writeOnly(string);
        end
        
        function off(obj)
            string = sprintf('RUNS 0');
            obj.writeOnly(string);
        end
        
        function  reset(obj)
            string = sprintf('*RST');
            obj.writeOnly(string);
        end
        
    end
end