classdef Line < Modules.Driver
    %Drivers.Attos.Line is a wrapper for the knobs contained in an attocube axis
    
    properties(SetObservable, GetObservable)
        serial =    Prefs.String('', 'readonly', true);
        
%         mode =      Prefs.MultipleChoice('gnd', 'choices', {'gnd', 'inp', 'cap', 'stp', 'off', 'stp+', 'stp-'},...
%                                             'help', 'Various operation modes available to each line. See manual for details.');
        
        % Maximum values are from manual. Might be hardware-dependent.
        frequency = Prefs.Integer(0,    'min', 0, 'max', 1e4, 'set', 'set_frequency',   'units', 'Hz',...
                                            'help', 'Frequency at which steps occur for multi-step operations.');
        amplitude = Prefs.Double(0,     'min', 0, 'max', 150, 'set', 'set_amplitude',   'units', 'V',...
                                            'help', 'Step edge voltage.');
        steps =     Prefs.Integer(1,    'min', 1, 'max', Drivers.Attos.maxsteps,        'units', '#',...
                                            'help', 'Default number of steps for a multi-step operation.');
        
        offset =    Prefs.Double(0,     'min', 0, 'max', 150, 'set', 'set_offset',      'units', 'V',...
                                            'help', 'Voltage that is added to the step waveform for a fine offset.');
        dc_in =     Prefs.Boolean(false, 'set', 'set_dc_in',    'help', 'Whether an external voltage is enabled on the DC-IN port.')
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
        function delete(obj)
            % Do nothing.
        end
        function step_p(obj, steps)
            obj.com('stepu', steps);
        end
        function step_m(obj, steps)
            obj.com('stepd', steps);
        end
        function step(obj, steps)
            steps = round(steps);
            if steps < 0
                obj.step_m(abs(steps));
            elseif steps > 0
                obj.step_p(abs(steps));
            end
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
        end
    end
end

