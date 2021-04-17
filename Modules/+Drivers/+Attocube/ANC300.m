classdef ANC300 < Modules.Driver
    %ATTOS
    %
    % * == implemented in MATLAB interface.
    % - == no plans to implement.
    %
    %-help                       - help
    %-echo    [on|off]           - enable/disable console echo  [This one is specifically disabled.]
    %*ver                        - version
    % setm    <AID> <AMODE>      - set mode
    % getm    <AID>              - get mode
    %-setaci  <AID> [on|off]     - set acin
    %-getaci  <AID>              - get acin
    %*setdci  <AID> [on|off]     - set dcin
    %*getdci  <AID>              - get dcin
    %-setfil  <AID> [off|16|160] - set filter
    %-getfil  <AID>              - get filter
    %-stop    <AID>              - stop
    %*stepu   <AID> [<C>]        - step up
    %*stepd   <AID> [<C>]        - step down
    %*setf    <AID> <FRQ>        - set frequency
    %*setv    <AID> <VOL>        - set voltage
    %*seta    <AID> <VOL>        - set offset
    %-settu   <AID> [1-16|off]   - set trigger up number or off
    %-settd   <AID> [1-16|off]   - set trigger down number or off
    %-setpu   <AID> [0-255] ...  - set step up pattern (256 bytes)
    %-setpd   <AID> [0-255] ...  - set step down pattern (256 bytes)
    %-setto   <TNUM> [0|1]       - set output trigger
    %*getf    <AID>              - get frequency
    %*getv    <AID>              - get voltage
    %*geta    <AID>              - get offset
    %-gettu   <AID>              - get trigger up number
    %-gettd   <AID>              - get trigger down number
    %-getpu   <AID>              - get step up pattern
    %-getpd   <AID>              - get step down pattern
    %-getto   <TNUM>             - get output trigger
    %-geto    <AID>              - get output voltage
    %*getc    <AID>              - get capacitance
    %-stepw   <AID>              - wait for axis to finish stepping
    %-capw    <AID>              - wait for axis to finish capacitance measurement
    %*getser  <AID>              - get serial number
    %*getcser                    - get controller board serial number
    %-setfc   <CODE>             - set feature code
    % 
    % <AID>   : axis id     (1, 2, 3, 4, 5, 6, 7)
    % <AMODE> : axis mode   (gnd, inp, cap, stp, off, stp+, stp-)
    % <C>     : run mode    (c - (cont), 1..N - (num of steps))
    % <TNUM>  : trigger num (1, 2, 3, 4)
    
    properties (Constant)
        maxsteps = 100;
    end
    properties (SetAccess=immutable)
        port;
    end
    properties
        lines;
    end
    properties (Access=private)
        s;
    end
    properties (GetObservable, SetObservable)
        version = Prefs.String('', 'readonly', true);
        serial =  Prefs.String('', 'readonly', true);
    end
    methods(Static)
        function obj = instance(port)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.Attocubes.ANC300.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(port, Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.Attocubes.ANC300(port);
            obj.singleton_id = port;
            Objects(end+1) = obj;
        end
    end
    methods (Access=private)
        function obj = ANC300(port)
            assert(~isempty(port));
            assert(ischar(port));
            
            obj.port = port;
            obj.s = serial(port);
            obj.s.Timeout = 1;
            fopen(obj.s);
            
            obj.getInfo();
            obj.spawnLines();
        end
        function spawnLines(obj)
            for ii = 1:7    % Max number of possible lines according to manual
                try         % Try to make a line; an expected error will occur if the line does not exist.
                    obj.lines = [obj.lines Drivers.Attocubes.ANC300.Line.instance(obj, ii)];
                catch        % Do something error-specfic?
                    % Do nothing.
                end
            end
            
            if isempty(obj.lines)
                warning(['Could not find any lines in Drivers.Attocubes.ANC300(''' obj.port ''').'])
            end
        end
        function killLines(obj)
            delete(obj.lines);
        end
    end
    methods
        function [response, numeric] = com(obj, command, varargin)
            % Prohibit dangerous commands.
            if strcmp(command, 'stepu') || strcmp(command, 'stepd')
                assert(length(varargin) == 2)
                if ischar(varargin{2}) && strcmp(varargin{2}, 'c')
                    warning('Continuous mode is dangerous and disabled in this MATLAB interface. Truncating to maxsteps.')
                    varargin{2} = Drivers.Attocubes.ANC300.maxsteps;
                elseif isnumeric(varargin{2}) 
                    assert(varargin{2} > 0, ['Expected positive integer steps. Received ' num2str(varargin{2})])
                    if varargin{2} > Drivers.Attocubes.ANC300.maxsteps
                        warning([num2str(varargin{2}) ' steps is greater than maxsteps = ' num2str(Drivers.Attocubes.ANC300.maxsteps) '. Truncating to maxsteps.'])
                        varargin{2} = Drivers.Attocubes.ANC300.maxsteps;
                    end
                end
            end
            
            % Turn the cell array of arguments into a space-padded string.
            for arg = varargin
                if ischar(arg{1})
                    command = [command ' ' arg{1}]; %#ok<AGROW>
                elseif isnumeric(arg{1}) || islogical(arg{1})
                    command = [command ' ' num2str(arg{1})]; %#ok<AGROW>
                else
                    disp(arg{1})
                    error('Could not parse argument. Arguments to Drivers.Atto must be string or numeric.')
                end
            end
            
            % Send the command
            fprintf(obj.s, command);
            
            % Read the response.
            response = '';
            
            endcode = sprintf('OK\r\n');
            errcode = sprintf('ERROR\r\n');
            
            echo = fscanf(obj.s);   % First line is echo. Turn echo off? This will break if echo is turned off.
            line = fscanf(obj.s);
            
            while ~isempty(line) && ~strcmp(line, endcode) && ~strcmp(line, errcode)
                response = [response line]; %#ok<AGROW>
                line = fscanf(obj.s);
            end
            
            if ~isempty(response)
                response(end-1:end) = [];
            end
            
            % Decide if the command succeeded and error otherwise.
            if ~isempty(line) && strcmp(line, endcode)
                % Do nothing.
            else
                error([echo response])
            end
            
            % If the user wants a numeric values also
            if nargout > 1  
                rlines = split(response, newline);
                
                result = split(rlines{end}, ' ');
                
                switch length(result)
                    case 3  % 'NAME = LOGICAL'
                        switch result{3}
                            case {'0', 'off'}
                                numeric = false;
                            case {'1', 'on'}
                                numeric = true;
                            otherwise
                                numeric = NaN;
                                warning(['Logical value string not recognized in "' rlines{end} '"'])
                        end
                    case 4  % 'NAME = NUMERIC UNIT'
                        numeric = str2double(result{3});
                    otherwise
                        numeric = NaN;
                        warning(['Value string not recognized in "' rlines{end} '"'])
                end
            end
        end
    end
    methods
        function delete(obj)
            obj.killLines();
            fclose(obj.s);
            delete(obj.s);
        end
        function getInfo(obj)
            obj.version = obj.com('ver');
            obj.serial = obj.com('getcser');
        end
    end
end