classdef Conex_CC < Modules.Driver
    % Implements serial communication with a Newport CONEX-CC micrometer. API
    % documentation https://www.newport.com/mam/celum/celum_assets/resources/CONEX-CC_-_Controller_Documentation.pdf?1
    
    properties(SetObservable, GetObservable)
        host =          Prefs.String('COM?',    'set', 'set_host', 'readonly', true,      'help', 'COM (USB) port that is connected to the micrometer.');
        address =       1; %Prefs.Integer(1,        'set', 'set_address',   'help', 'COM (USB) port that is connected to the micrometer.');
        
        identifier =    Prefs.String('', 'readonly', true);
        state =         Prefs.String('UNKNOWN', 'readonly', true);
        
        position =      Prefs.Double(NaN, 'unit', 'um',     'min', 0, 'max', 1e3*25,        'allow_nan', true, 'set', 'set_position', 'get', 'get_position',       'help', 'Positon of the micrometer.');
        velocity =      Prefs.Double(NaN, 'unit', 'um/s',   'min', 0,        'allow_nan', true, 'set', 'set_velocity',       'help', 'Velocity of the micrometer.');
        acceleration =  Prefs.Double(NaN, 'unit', 'um/s^2', 'min', 1e3*1e-6, 'max', 1e3*1e12,   'allow_nan', true, 'set', 'set_acceleration',   'help', 'Acceleration of the micrometer.');
    end
    properties % (Access=private)
        s;      % Handle to serial connection
    end
    methods(Access=protected)
        function obj = Conex_CC(host)
            obj.host = host;
            obj.loadPrefs;
        end
    end
    methods(Static)
        function obj = instance(host)
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Drivers.Conex_CC(host);
            end
            obj = Object;
        end
    end
    methods
        function delete(obj)
            if ~isempty(obj.s)
                fclose(obj.s);
                delete(obj.s);
            end
        end

        function home(obj, ~)
            obj.com('OR');                  % Execute home search
            obj.get_state();
            
            t = tic;
            while strcmp(obj.get_raw_state(), '1E') && toc(t) < 60; pause(.01); end    % Wait while homing.
            
            obj.get_state();
        end

        function val = get_identifier(obj, ~)
            if obj.isConnected()
                obj.com('ID?');    % Get laser modulation power (mW)

                val = strip(fscanf(obj.s));
            else
                val = 'Not Connected';
            end
        end
        function val = get_position(obj, ~)
            if obj.isConnected()
                obj.com('TH');    % Current postion
                val = 1e3*obj.recv();
            else
                val = NaN;
            end
        end
        function val = get_setpoint(obj, ~)
            if obj.isConnected()
                obj.com('PA?');    % Setpoint postion
                val = 1e3*obj.recv();
            else
                val = NaN;
            end
        end
        function val = set_position(obj, val, pref)
            obj.com('ST');                  % Stop any current movement
            
            obj.get_state();
            
            t = tic;
            while strcmp(obj.get_raw_state(), '28') && toc(t) < 1; pause(.01); end    % Wait while decellerating.

            obj.get_state();
            
%             obj.com(['SE' num2str(val)]);   % Tell the axes to goto the desired position.
%             fprintf(obj.s, 'SE');               
            obj.com(['PA' num2str(val/1e3)]);   % Tell the axes to goto the desired position.
            
%             T = 
%             
%             t = tic;
%             while strcmp(obj.get_raw_state(), '28') && toc(t) < 1; pause(.01); end    % Wait while decellerating.

        end
        function val = set_velocity(obj, val, ~)
            obj.com(['VA' num2str(val/1e3)]);   % Tell the axes to goto the desired position.
            val = get_velocity(obj);
        end
        function val = get_velocity(obj, ~)
            if obj.isConnected()
                obj.com('VA?');  val = 1e3*obj.recv();
            else
                val = NaN;
            end
        end
        function val = set_acceleration(obj, val, ~)
            obj.com(['AC' num2str(val/1e3)]);   % Tell the axes to goto the desired position.
            val = get_acceleration(obj);
        end
        function val = get_acceleration(obj, ~)
            if obj.isConnected()
                obj.com('AC?'); val = 1e3*obj.recv();
            else
                val = NaN;
            end
        end
        
        function [state, err] = get_raw_state(obj, ~)
            obj.com('TS');   % Tell the axes to goto the desired position.
            str = fscanf(obj.s);
%             str
%             err = str(1:4);
%             state = str(5:6);
            err = str(4:7);
            state = str(8:9);
            
            if ~strcmp(err, '0000')
                warning(['Error code: ' err]);
            end
        end
        function state = get_state(obj, ~)
            try
                [raw, ~] = get_raw_state(obj, 0);
            catch
                raw = '';
            end
            
%             switch raw
%                 case '0A'; state = 'RESET -> NOT REFERENCED';
%                 case '0B'; state = 'HOMING -> NOT REFERENCED';
%                 case '0C'; state = 'CONFIGURATION -> NOT REFERENCED';
%                 case '0D'; state = 'DISABLE -> NOT REFERENCED';
%                 case '0E'; state = 'READY -> NOT REFERENCED';
%                 case '0F'; state = 'MOVING -> NOT REFERENCED';
%                 case '10'; state = 'NO PARAMETERS IN MEMORY -> NOT REFERENCED';
%                 case '14'; state = 'CONFIGURATION';
%                 case '1E'; state = 'HOMING';
%                 case '28'; state = 'MOVING';
%                 case '32'; state = 'HOMING -> READY';
%                 case '33'; state = 'MOVING -> READY';
%                 case '34'; state = 'DISABLE -> READY';
%                 case '36'; state = 'READY -> READY T';
%                 case '37'; state = 'TRACKING -> READY T';
%                 case '38'; state = 'DISABLE T -> READY T';
%                 case '3C'; state = 'READY -> DISABLE';
%                 case '3D'; state = 'MOVING -> DISABLE';
%                 case '3E'; state = 'TRACKING -> DISABLE';
%                 case '3F'; state = 'READY T -> DISABLE';
%                 case '46'; state = 'READY T -> TRACKING';
%                 case '47'; state = 'TRACKING';
%                 otherwise; state = 'UNKNOWN';
%             end
            
            switch raw
                case {'0A','0B','0C','0D','0E','0F','10'}
%                     state = 'NOT REFERENCED';
                    state = 'NOT HOMED';
                case '14'
                    state = 'CONFIGURATION';
                case '1E'
                    state = 'HOMING';
                case '28'
                    state = 'MOVING';
                case {'32','33','34'}
                    state = 'READY';
                case {'36','37','38'}
                    state = 'READY T';
                case {'3C','3D','3E','3F'}
                    state = 'DISABLE';
                case {'46','47'}
                    state = 'TRACKING';
                otherwise
                    state = 'UNKNOWN';
            end
            
            obj.state = state;
        end
            
        function com(obj, str, varargin)
%             if obj.isConnected()
            fprintf(obj.s, [num2str(obj.address) str]);
%             else
%                 val = NaN;
%             end
        end
        function val = recv(obj)
            str = fscanf(obj.s);
            val = str2double(str(4:end));
        end
        
        function tf = isConnected(obj)
            tf = ~isempty(obj.s) && isvalid(obj.s);
        end
        
        function val = set_host(obj, val, ~) %this loads the hwserver driver
            delete(obj.s);
            
            if strcmp('COM?', val)
                obj.s = [];
                return
            end
            err = [];
            try
                obj.s = serial(val); %#ok<*MCSUP>
                set(obj.s, 'BaudRate', 921600, 'DataBits', 8, 'Parity', 'none', 'StopBits', 1, ...
                    'FlowControl', 'software', 'Terminator', 'CR/LF');
                fopen(obj.s);
                
                obj.identifier =    obj.get_identifier();
                obj.position =      obj.get_position();
                obj.velocity =      obj.get_velocity();
                obj.acceleration =  obj.get_acceleration();
            catch err
                obj.s = [];
                val = 'COM?';
            end
            if ~isempty(err)
                rethrow(err)
            end
        end
        
    end
end

