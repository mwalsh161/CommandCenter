classdef AQ4321D < Modules.Driver
    % Interface to Ando AQ4321D L-Band laser
    % Instantiation takes a port name string as an input argument, then
    % attempts to connect to that port. Private access com function handles 
    % communication with device, and is accessed by public access functions
    % as commented below
    %
    % Note that driver only deals in frequency, not wavelength, so any
    % code dealing directly with this driver must convert to THz
    
    properties
        connection
        power_mW_max
        power_mW_min
        freq_max
        freq_min
    end
    properties(SetObservable, SetAccess=private, AbortSet)
        frequency
        power_mW
    end
    properties(Constant)
        ID = 'ANDO-ELECTRIC/AQ4321D'; %beginning of response to '*IDN?'
    end
    methods(Access=private)
        function obj = AQ4321D(port)
            obj.connection = serial(port);
            set(obj.connection,'BaudRate',9600);
            set(obj.connection,'Terminator','CR/LF');
            set(obj.connection,'Timeout',1);
            fopen(obj.connection);
            %check hardware ID to verify correct instrument
            try
                warning('off','MATLAB:serial:fscanf:unsuccessfulRead');
                ID = obj.GetID; 
            	assert(strcmpi(obj.ID,ID(1:length(obj.ID))),'Hardware ID not recognized')
            catch
                %this will catch errors in either asking for the ID 
                % (if command is unrecognized) or if assert throws error
                fclose(obj.connection);
                warning('on','MATLAB:serial:fscanf:unsuccessfulRead');
                error('Hardware ID not recognized')
            end
            warning('on','MATLAB:serial:fscanf:unsuccessfulRead');
            %get setting limits and current values
            obj.power_mW_max = obj.GetPowerMax('mw');
            obj.power_mW_min = obj.GetPowerMin('mw');
            obj.freq_max = obj.GetFrequencyMax;
            obj.freq_min = obj.GetFrequencyMin;
            obj.frequency = obj.GetFrequency;
            obj.power_mW = obj.GetPower('mw');
        end
        function response = com(obj,call)
            % Takes a string as a call and responds with hardware response
            % If system errors, will throw response as error
            if ~strcmpi(obj.connection.Status,'open')
                fopen(obj.connection);
                warning('Connection was closed; opening now')
            end
            assert(ischar(call),'Commands to AQ4321D must be strings.');
            fprintf(obj.connection,call);
            response = fscanf(obj.connection);
            response = strtrim(response); %remove trailing newlines
            assert(isempty(strfind(response,'error')),response); %if response has error message, throw response as error
        end
    end
    
    methods(Static)
        function obj = instance(port)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.AQ4321D.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(port,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.AQ4321D(port);
            %port string is singleton ID, allowing multiple instances to be connected to the same computer
            obj.singleton_id = port; 
            Objects(end+1) = obj;
        end
    end
    
    methods
        function delete(obj)
            %closes and deletes connection
            if strcmp(obj.connection.status,'open')
                fclose(obj.connection);
            end
            delete(obj.connection)
        end
        function out = GetID(obj)
            %retrieves ID number
            out = obj.com('*IDN?');
        end
        function out = GetFrequency(obj)
            %Retrieves frequency in THz
            out = obj.com('TFR?');
            out = str2double(out);
        end
        function out = GetPower(obj,unit)
            %Takes case-independent input of unit (dBbm or mW) and returns
            %power setpoint
            if strcmpi(unit,'dbm')
                out = obj.com('TPDB?');
            elseif strcmpi(unit,'mw')
                out = obj.com('TPMW?');
            else
                error('power unit must be dBm or mW (case insensitive)')
            end
            out = str2double(out);
        end
        function out = GetEmission(obj)
            %returns 0 if emission is off, 1 if emission on
            out = obj.com('L?');
            out = str2double(out);
        end
        function out = SetEmission(obj,val)
            %turns laser on or off with boolean input
            if strcmpi(val,'true') || isequal(val,true)
                val = 1;
            elseif strcmpi(val,'false') || isequal(val,false)
                val = 0;
            else
                error('SetEmission takes either logical or string true/false (case insensitive)')
            end
            out = obj.com(sprintf('L%i',val));
            if ~strcmpi(out,'OK')
                error('Unexpected hardware response in SetEmission: %s',out)
            end
        end
        function SetFrequency(obj,val)
            %takes input in THz and sets frequency
            obj.frequency = val;
        end
        function SetPower(obj,val,unit)
            %sets power; first input is value, second is unit (mW or dBm)
            if strcmpi(unit,'mw')
                obj.power_mW = val;
            elseif strcmpi(unit,'dbm')
                obj.power_mW = 10^(val/10);
            else
                error('power unit must be dBm or mW (case insensitive)')
            end
        end
        function out = GetFrequencyMax(obj)
            %returns maximum setable frequency in THz
            out = obj.com('FRMAX?');
            out = str2double(out);
        end
        function out = GetFrequencyMin(obj)
            %returns minimum setable frequency in THz
            out = obj.com('FRMIN?');
            out = str2double(out);
        end
        function out = GetPowerMax(obj,unit)
            %returns maximum setable power in unit specified by input
            if strcmpi(unit,'dbm')
                out = obj.com('PDBMAX?');
            elseif strcmpi(unit,'mw')
                out = obj.com('PMWMAX?');
            else
                error('power unit must be dBm or mW (case insensitive)')
            end
            out = str2double(out);
        end
        function out = GetPowerMin(obj,unit)
            %returns minimum setable power in unit specified by input
            if strcmpi(unit,'dbm')
                out = obj.com('PDBMIN?');
            elseif strcmpi(unit,'mw')
                out = obj.com('PMWMIN?');
            else
                error('power unit must be dBm or mW (case insensitive)')
            end
            out = str2double(out);
        end
        function set.frequency(obj,val)
            %sets frequency, handling all range checks
            assert(isnumeric(val),'frequency must be numeric')
            assert(val >= obj.freq_min,sprintf('frequency must be >= %g',obj.freq_min))
            assert(val <= obj.freq_max,sprintf('frequency must be <= than %g',obj.freq_max))
            out = obj.com(['TFR',num2str(val)]);
            if ~strcmpi(out,'OK')
                error('Unexpected hardware response in SetFrequency: %s',out)
            end
            obj.frequency = val;
        end
        function set.power_mW(obj,val)
            %sets power, handling all range checks
            assert(isnumeric(val),'power must be numeric')
            assert(val >= obj.power_mW_min && val <= obj.power_mW_max,...
                sprintf('power must be between %g and %g mW',obj.power_mW_min,obj.power_mW_max))
            out = obj.com(['TPMW',num2str(val)]);
            if ~strcmpi(out,'OK')
                error('Unexpected hardware response in SetPower: %s',out)
            end
            obj.power_mW = val;
        end
    end
end

