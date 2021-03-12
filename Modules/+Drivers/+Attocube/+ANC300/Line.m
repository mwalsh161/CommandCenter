classdef Line < Modules.Driver
    %Drivers.Attos.Line is a wrapper for the knobs contained in an attocube axis
    
    properties(SetObservable, GetObservable)
        % Note: Maximum values are from manual. Might be hardware-dependent.
        serial =    Prefs.String('', 'readonly', true, 'display_only', true, ...
                                            'help', 'Serial number for this attocube stepper.')
        
        % Modes other than 'stp+' are currently NotImplemented. Leaving this line in as a note that it is possible.
%         mode =      Prefs.MultipleChoice('stp+', 'choices', {'gnd', 'inp', 'cap', 'stp', 'off', 'stp+', 'stp-'},...
%                                             'help', 'Various operation modes available to each line. See manual for details.');

        % Stepping-related prefs.
        step =      Prefs.Integer(0,    'min', -Drivers.Attos.maxsteps, 'max', Drivers.Attos.maxsteps, ...
                                            'set', 'set_step', 'display_only', true,    'units', '#',...
                                            'help', ['The core of the class. Setting step to X will cause the atto to step '...
                                                    'abs(X) steps in the sign(X) direction. Then, it will revert back to zero.']);
        frequency = Prefs.Integer(0,    'min', 0, 'max', 1e4, 'set', 'set_frequency',   'units', 'Hz',...
                                            'help', 'Frequency at which steps occur for multi-step operations. This is the freqeuncy of the sawtooth.');
        amplitude = Prefs.Double(0,     'min', 0, 'max', 150, 'set', 'set_amplitude',   'units', 'V',...
                                            'help', 'Voltage amplitude for stepping sawtooth.');
        
        % UI stuff to allow the user to step up and down. Future: replace with pref-based metastage.
        steps =     Prefs.Integer(Drivers.Attos.maxsteps, 'max', Drivers.Attos.maxsteps, 'units', '#',...
                                            'help', 'Number of steps to use when using the Step Up and Step Down buttons.');
        step_up =   Prefs.Boolean(false, 'set', 'set_step_up',...
                                            'help', 'Button to command the atto to step up by `steps` steps.');
        step_down = Prefs.Boolean(false, 'set', 'set_step_down',...
                                            'help', 'Button to command the atto to step down by `steps` steps.');
        
        % Fine-adjustment-related prefs.
        offset =    Prefs.Double(0,     'min', 0, 'max', 150, 'set', 'set_offset',      'units', 'V',...
                                            'help', 'Voltage that is added to the step waveform for a fine offset on the piezo.');
        dc_in =     Prefs.Boolean(false, 'set', 'set_dc_in', ...
                                            'help', 'Whether an external voltage is enabled on the DC-IN port. This maps directly onto `offset`.')
    end
    properties(SetAccess=immutable, Hidden)
        parent; % Handle to Drivers.Attos parent
    end
    properties(SetAccess=immutable)
        line;   % Index of the physical line of the parent that this D.A.Line controls.
    end
    
    methods(Static)
        function obj = instance(parent, line)
            parent.com('getser', line); % Error if the parent does not possess this line.
            
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.Attos.Line.empty(1,0);
            end
            id = [parent.port '_line' num2str(line)];
            for ii = 1:length(Objects)
                if isvalid(Objects(ii)) && isvalid(Objects(ii).parent) && isequal(id, Objects(ii).singleton_id)
                    obj = Objects(ii);
                    return
                end
            end
            obj = Drivers.Attos.Line(parent, line);
            obj.singleton_id = id;
            Objects(end+1) = obj;
        end
    end
    
    methods(Access=private)
        function obj = Line(parent, line)
            obj.parent = parent;
            obj.line = line;
            
            obj.com('setm', 'stp+');   % Default; eventually change this to give the user more freedom.
            
            obj.getInfo();

            addlistener(obj.parent,'ObjectBeingDestroyed',@(~,~)obj.delete);
        end
    end
    
    methods
        function [response, numeric] = com(obj, command, varargin)
            if nargout == 2
                [response, numeric] = obj.parent.com(command, obj.line, varargin{:});
            else
                response = obj.parent.com(command, obj.line, varargin{:});
            end
        end
        function delete(~)
            % Do nothing.
        end
    end
    
    methods(Hidden)
        function stepu(obj, steps)
            obj.com('stepu', steps);
        end
        function stepd(obj, steps)
            obj.com('stepd', steps);
        end
        function val = set_step(obj, val, ~)
            val = round(val);   % Only integer steps. (change to clean?)
            
            if val < 0
                obj.stepu(abs(val));
            elseif val > 0
                obj.stepd(abs(val));
            end
            
            val = 0;
        end
        function val = set_step_up(obj, ~, ~)
            obj.step = obj.steps;
            val = false;    % Turn button back off.
        end
        function val = set_step_down(obj, ~, ~)
            obj.step = -obj.steps;
            val = false;    % Turn button back off.
        end
    end
    
    methods(Hidden)
        function val = set_frequency(obj, val, ~)
            obj.com('setf', val);
        end
        function val = set_amplitude(obj, val, ~)
            obj.com('setv', val);
        end
        function val = set_offset(obj, val, ~)
            obj.com('seta', val);
        end
        function val = set_dc_in(obj, val, ~)
            if val
                obj.com('setdci', 'on');
            else
                obj.com('setdci', 'off');
            end
        end
        
        function getInfo(obj)
            obj.serial =            obj.com('getser');
            [~, obj.frequency] =    obj.com('getf');
            [~, obj.amplitude] =    obj.com('getv');
            [~, obj.offset] =       obj.com('geta');
            [~, obj.dc_in] =        obj.com('getdci');
        end
        
        function val = get_capacitance(obj, ~)
            [~, val] = obj.com('getc');
            obj.com('setm', 'stp+');
        end
    end
end

