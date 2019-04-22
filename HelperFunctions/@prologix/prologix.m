classdef prologix < handle
    %PROLOGIX prologix gpib 
    %   Prologix adaptors show up as SERIAL objects
    %   This class takes care of communicating with the controller, so you
    %   can just worry about communicating with the device.
    %
    %   PROLOGIX(com,address)
    %   PROLOGIX(com,address,SERIAL OPTIONS)
    %
    %   This will read the full transmission from the GPIB device into the
    %   serial buffer. The function used (fgets, fgetl etc) determines how
    %   data is read from the serial buffer.
    %
    %   NOTE: Only supports CR or LF termination due to restriction of
    %   ++eot_char and ++read.
    %
    %   NOTE: obj.BytesAvailable will be 0 after a write no matter what
    %   because the prologix doesn't read until instructed to. You are
    %   better off only using termination characters for reading.
    %
    %   NOTE: All non-newline prologix special characters are escaped, 
    %   meaning you cannot send commands to the prologix unit directly
    %
    %   NOTE: Use dot notation to set/get properties. Exception: use A =
    %   set(obj) to get a list of all settable properties and A = get(obj)
    %   to get all readable properties.
    %
    %   NOTE: beccause of "function" calling notation (instead of dot
    %   notation), we need to explicitly specify methods
    %       function notation: method(obj,args)
    %       dot notation: obj.method(args)
    %
    %   NOTE: difference between fprintf and serial/fprintf!!!!
    %       prologix/fprintf behaves like serial/fprintf
    %
    %   NOTE: commands sent to prologix need to terminate with CR or LF
    % http://prologix.biz/downloads/PrologixGpibUsbManual-6.0.pdf
    
    properties % Nx1 cells to specify value options
        PrimaryAddress
        SecondaryAddress = 0;
        Terminator = {'LF';'CF'};  % Limited by prologix ++read and ++eot_char
        Timeout                    % Normal serial timeout, GPIB timeout between received chars is half this
        EOIMode = {'on';'off'};    % If on, will declare EOI on write, and use EOI on read [default on]
        EOTEnable = {'on';'off'};  % EOTEnable to on will translate instrument EOI to Terminator [default off]
    end
    properties(Constant)
        Type = 'Prologix';
    end
    properties(Access=private)
        serial
    end
    
    methods(Access=protected)
        function setTerm(obj)
            % Sets to and from device
            if ~strcmp(obj.serial.Status,'open')
                err = MException('instrument:set:opfailed','Termination cannot be set while OBJ is closed.');
                throwAsCaller(err)
            end
            switch obj.Terminator
                case 'CR'
                    fprintf(obj.serial,'++eot_char 13');
                case 'LF'
                    fprintf(obj.serial,'++eot_char 10');
                otherwise
                    err = MException('instrument:gpib:opfailed','Only CR or LF terminators supported.');
                    throwAsCaller(err)
            end
        end
        function setRead(obj)
            if ~strcmp(obj.serial.Status,'open')
                err = MException('instrument:set:opfailed','Read cannot be performed while OBJ is closed.');
                throwAsCaller(err)
            end
            if strcmp(obj.EOIMode,'on')
                fprintf(obj.serial,'++read eoi');
            else
                switch obj.Terminator
                    case 'CR'
                        fprintf(obj.serial,'++read 13');
                    case 'LF'
                        fprintf(obj.serial,'++read 10');
                    otherwise
                        error('Unexpected terminator trying to be set!')
                end
            end
        end
    end
    methods(Static)
        function string = escapeString(string)
            % escape character: ESC (ASCII 27)
            % special characters: CR (ASCII 13), LF (ASCII 10), ESC (ASCII 27), ‘+’ (ASCII 43)
            % For strings, we don't want to escape newline characters
            for s = [27 43]  % ESC has to be first!
                string = strrep(string,char(s),[char(27) char(s)]);
            end
        end
        function A = escapeBinary(A)
            % escape character: ESC (ASCII 27)
            % special characters: CR (ASCII 13), LF (ASCII 10), ESC (ASCII 27), ‘+’ (ASCII 43)
            
            % Need to consider: obj.ByteOrder
            % How matlab converts to precision (especially ones that 32 or 64 bit, like long)
            % Also does it cap if the data is larger than the precision or overflow
            warning('PROLOGIX:write:NotImplemented','Binary escape not implemented.')
        end
    end
    methods
        function obj = prologix(com,PrimaryAddress,varargin)
            obj.serial = serial(com,varargin{:});
            obj.EOIMode = 'on';
            obj.EOTEnable = 'off';
            try
                obj.PrimaryAddress = PrimaryAddress;
            catch err
                delete(obj)  % Need to manually remove the serial object
                throwAsCaller(err)
            end
            if obj.serial.Timeout > 3 % Above max timeout for GPIB
                v = varargin(1:2:end);  % Get property names only
                v = cellfun(@lower,v,'uniformoutput',false);
                if ismember('timeout',v) % This means user set it
                    warning('GPIB timeout cannot be larger than 3. Setting to maximum.')
                end % Don't need warning if default was used
                obj.serial.Timeout = 0.5;
            end
            obj.serial.name = sprintf('%s-%d',obj.Type,obj.PrimaryAddress);
        end
        function disp(obj)
            % This is called when no semicolon is used (overloading matlab builtin)
            fprintf('%s GPIB on %s\nPrimaryAddress: %i\nSecondaryAddress: %i\n',...
                mfilename,obj.serial.port,obj.PrimaryAddress,obj.SecondaryAddress);
            disp(obj.serial);
        end
        function delete(obj)
            delete(obj.serial)
        end
        function B = subsref(obj,S)
            % This is a dot notation dispatching method - called when
            % "obj.something" is executed
            if length(S)==1 && S.type == '.' && ismember(S.subs,properties(obj))
                B = obj.(S.subs);
            else
                B = subsref(obj.serial,S);
            end
        end
        function pro_set(obj,prop,val)
            if isprop(obj,prop)
                obj.(prop) = val;
            else
                obj.serial.(prop) = val;
            end
        end
        function varargout = set(obj,varargin)
            varargout = {};
            if ~nargout
                if length(varargin) == 2 && iscell(varargin{1}) && iscell(varargin{2})
                    % set(obj,PN,PV)
                    PN = varargin{1};
                    PV = varargin{2};
                    assert(length(PN)==length(PV),'Missing property value.')
                    for i = 1:length(PN)
                        obj.pro_set(PN{i},PV{i});
                    end
                elseif length(varargin) == 1 && isstruct(varargin{1})
                    % set(obj,S)
                    S = varargin{1};
                    props = fieldnames(S);
                    for i = 1:length(props)
                        obj.pro_set(props{i},S.(props{i}));
                    end
                else
                    % set(obj,'PropertyName',PropertyValue,...)
                    assert(~mod(length(varargin),2),'Missing property value.')
                    for i = 1:2:length(varargin)
                        obj.pro_set(varargin{i},varargin{2});
                    end
                end
            else
                % props = set(obj)
                A = set(obj.serial);
                % Add in prologix settable properties
                mc = metaclass(obj);
                props = mc.PropertyList(cellfun(@(a)strcmp(a,'public'),{mc.PropertyList.SetAccess}));
                for i = 1:length(props)
                    % Only add if it doesn't exist, or more strict default
                    % options (this is to prevent clobbering existing options)
                    if ~isfield(A,props(i).Name)
                        A.(props(i).Name) = {};
                    end
                    if (props(i).HasDefault && iscell(props(i).DefaultValue))
                        % Override value options
                        A.(props(i).Name) = props(i).DefaultValue;
                    end
                end
                % props = set(obj,'PropertyName')
                if length(varargin) == 1
                    A = A.(varargin{1});
                end
                varargout{1} = A;
            end
        end
        function A = get(obj)
            A = get(obj.serial);
            % Add in prologix settable properties
            mc = metaclass(obj);
            props = mc.PropertyList(cellfun(@(a)strcmp(a,'public'),{mc.PropertyList.GetAccess}));
            for i = 1:length(props)
                % Overwrite all "overloaded" properties
                A.(props(i).Name) = obj.(props(i).Name);
            end
        end
        function obj = subsasgn(obj,S,B)
            % This is a dot notation dispatching method - called when
            % "obj.something=value" is executed
            try
                if length(S)==1 && S.type == '.' && ismember(S.subs,properties(obj))
                    obj.(S.subs) = B;
                else
                    % Wrap serial properties
                    subsasgn(obj.serial,S,B); %#ok<SUBSASGN>
                end
            catch err
                throwAsCaller(err)
            end
        end
        function set.EOTEnable(obj,mode)
            if strcmp(obj.serial.Status,'open') %#ok<*MCSUP>
                err = MException('instrument:set:opfailed','EOTEnable cannot be set while OBJ is open.');
                throwAsCaller(err)
            end
            if ~ischar(mode)
                err = MException('instrument:set:opfailed','EOTEnable must be a string: "on" or "off".');
                throwAsCaller(err)
            end
            mode = lower(mode);
            if ~ismember(mode,{'on','off'})  % Additional GPIB-specific error handling
                err = MException('instrument:set:opfailed','EOTEnable must be on or off.');
                throwAsCaller(err)
            end
            obj.EOTEnable = mode;
        end
        function set.EOIMode(obj,mode)
            if strcmp(obj.serial.Status,'open') %#ok<*MCSUP>
                err = MException('instrument:set:opfailed','EOIMode cannot be set while OBJ is open.');
                throwAsCaller(err)
            end
            if ~ischar(mode)
                err = MException('instrument:set:opfailed','EOIMode must be a string: "on" or "off".');
                throwAsCaller(err)
            end
            mode = lower(mode);
            if ~ismember(mode,{'on','off'})  % Additional GPIB-specific error handling
                err = MException('instrument:set:opfailed','EOIMode must be on or off.');
                throwAsCaller(err)
            end
            obj.EOIMode = mode;
        end
        function set.Terminator(obj,term)
            last = obj.serial.Terminator;
            try
                obj.serial.Terminator = term;  % This line does most of error handling
            catch err
                throwAsCaller(err)
            end
            if ~ismember(term,{'LF','CR'})  % Additional GPIB-specific error handling
                obj.serial.Terminator = last;
                err = MException('instrument:set:opfailed','Terminator must be LF or CR.');
                throwAsCaller(err)
            end
            if strcmp(obj.serial.Status,'open') %#ok<*MCSUP>
                obj.setTerm;
            end
        end
        function out = get.Terminator(obj)
            out = obj.serial.Terminator;
        end
        function set.Timeout(obj,timeout)
            last = obj.serial.Timeout;
            try
                obj.serial.Timeout = timeout;
            catch err
                throwAsCaller(err)
            end
            if timeout > 3 || timeout < 0.002
                obj.serial.Timeout = last;
                err = MException('instrument:set:opfailed','Timeout cannot be less than 0.002 or greater than 3.');
                throwAsCaller(err)
            end
            if strcmp(obj.serial.Status,'open')
                fprintf(obj.serial,sprintf('++read_tmo_ms %i\n',obj.Timeout*1000/2)); % Timeout in ms
            end
        end
        function out = get.Timeout(obj)
            out = obj.serial.Timeout;
        end
        function set.PrimaryAddress(obj,primAdrs)
            if strcmp(obj.serial.Status,'open')
                err = MException('instrument:set:opfailed','PrimaryAddress cannot be set while OBJ is open.');
                throwAsCaller(err)
            end
            if ~isa(primAdrs, 'double') || isempty(primAdrs)
                err = MException('instrument:gpib:invalidPRIMARYADDRESSDoubleRange','The PRIMARYADDRESS must be a double ranging between 0 and 30.');
                throwAsCaller(err)
            end
            if (primAdrs < 0) || (primAdrs > 30)
                err = MException('instrument:gpib:invalidPRIMARYADDRESSRange','The PRIMARYADDRESS must range between 0 and 30.');
                throwAsCaller(err)
            end
            obj.PrimaryAddress = primAdrs;
        end
        function set.SecondaryAddress(obj,secondAdrs)
            if strcmp(obj.serial.Status,'open')
                err = MException('instrument:set:opfailed','SecondaryAddress cannot be set while OBJ is open.');
                throwAsCaller(err)
            end
            if ~isa(secondAdrs, 'double') || isempty(secondAdrs)
                err = MException('instrument:gpib:invalidSECONDARYADDRESSDoubleRange','The SECONDARYADDRESS must be a double ranging between 0 and 30.');
                throwAsCaller(err)
            end
            if (secondAdrs < 0) || (secondAdrs > 30)
                err = MException('instrument:gpib:invalidSECONDARYADDRESSRange','The SECONDARYADDRESS must range between 0 and 30.');
                throwAsCaller(err)
            end
            obj.SecondaryAddress = secondAdrs;
        end
        
        function avail = availableAddresses(obj)
            % This will open the serial port because it is only talking to
            % the GPIB controller (not the specified device)
            % NOTE: This will leave closed!!
            % NOTE: This is an expensive function, and not guranteed to
            % return all connected devices
            if ~strcmp(obj.serial.Status,'open')
                fopen(obj.serial);
            end
            % Returns list of available PrimaryAddresses
            old_timeout = obj.Timeout;
            obj.Timeout = 0.01;
            avail = false(1,31);
            try
            for i = 0:30
                % Spoll address to see if something is there (gets status register)
                fprintf(obj.serial,sprintf('++spoll %i',i));
                fprintf(obj.serial,'++read'); % Read to timeout
                pause(0.05);  % Needs to be longer than obj.Timeout
                if obj.serial.BytesAvailable
                    flushinput(obj.serial);
                    avail(i+1) = true;
                end
            end
            catch err
                warning('Failed to complete spoll at addr %i: %s',i,err.message);
            end
            obj.Timeout = old_timeout;
            % Report back addresses
            avail = (find(avail))-1; % -1 because address start from 0, but MATLAB indexes from 1
            fclose(obj.serial);
        end
        
        % Wrapper methods to emulate serial
        function close(obj)
            close(obj.serial);
        end
        function fclose(obj)
            fclose(obj.serial);
        end
        function tline = fgetl(obj)  % Special behavior
            obj.setRead;
            tline = fgetl(obj.serial);
        end
        function tline = fgets(obj,varargin)  % Special behavior
            obj.setRead;
            tline = fgets(obj.serial,varargin{:});
        end
        function flushinput(obj)
            flushinput(obj.serial);
        end
        function flushoutput(obj)
            flushoutput(obj.serial);
        end
        function fopen(obj,spoll)  % Special behavior
            % spoll: if true [default], perform spoll. false ignores spoll (much faster)
            if nargin < 2
                spoll = true;
            end
            fopen(obj.serial);
            % Configure GPIB
            try
                fprintf(obj.serial,'++mode 1');                     % Set to controller mode
                fprintf(obj.serial,'++eos 3');                      % No USB -> GPIB char subs.
                fprintf(obj.serial,sprintf('++addr %i %i',...
                    obj.PrimaryAddress,96+obj.SecondaryAddress));   % Set GPIB address
                fprintf(obj.serial,'++auto 0');                     % Auto read after write off
                if strcmp(obj.EOIMode,'on')
                    fprintf(obj.serial,'++eoi 1');                  % Assert EOI after writing
                else
                    fprintf(obj.serial,'++eoi 0');                  % No EOI after write
                end
                if strcmp(obj.EOTEnable,'on')
                    fprintf(obj.serial,'++eot_enable 1');           % Append termination from GPIB to serial on EOI
                else
                    fprintf(obj.serial,'++eot_enable 0');
                end
                obj.Terminator = obj.serial.Terminator;             % This will address the GPIB controller now the port is open
                obj.Timeout = obj.serial.Timeout;                   % This will address the GPIB controller now the port is open
                if spoll
                    % Spoll address to see if something is there (gets status register)
                    fprintf(obj.serial,'++spoll');
                    fprintf(obj.serial,'++read');
                    [~,status,~] = fread(obj.serial,1);
                    if ~status  % Go through and find available addresses for the error message
                        fclose(obj.serial);  % WTF. Works only 60% of the time without this line
                        avail = obj.availableAddresses;  % This leaves serial closed
                        if isempty(avail)  % Format for error
                            avail = 'none';
                        else
                            avail = num2str(avail);
                        end
                        err = MException('MATLAB:gpib:fopen:opfailed',sprintf('Open failed: Address: %i is not available. Available PrimaryAddresses: %s',obj.PrimaryAddress,avail));
                        throw(err)
                    end
                end
            catch err
                fclose(obj.serial);
                throwAsCaller(err)
            end
            % Reset ValuesReceived and ValuesSent
            fclose(obj.serial);
            fopen(obj.serial);
        end
        function varargout = fread(obj,varargin)  % Special behavior
            obj.setRead;
            [A,count] = fread(obj.serial,varargin{:});
            varargout = {A,count};
        end
        function varargout = fscanf(obj,varargin)  % Special behavior
            obj.setRead;
            [A,count] = fscanf(obj.serial,varargin{:});
            varargout = {A,count};
        end
        function varargout = query(obj,varargin)  % Special behavior
            fprintf(obj.serial,'++auto 1');tic
            [out,count,err] = query(obj.serial,varargin{:});
            fprintf(obj.serial,'++auto 0');toc
            varargout = {out,count,err};
        end
        function varargout = scanstr(obj,varargin)  % Special behavior
            obj.setRead;
            [A,count,msg] = scanstr(obj.serial,varargin{:});
            varargout = {A,count,msg};
        end
        function readasync(obj,varargin)
            readasync(obj.serial,varargin{:});
        end
        function stopasync(obj)
            stopasync(obj.serial);
        end
    end
    
end

