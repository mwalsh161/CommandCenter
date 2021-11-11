classdef Line < Modules.Driver
    %Drivers.PulseBlaster.LINE(pb, i) is a wrapper for a Prefs.Boolean to keep track the state of the ith
    %   line of a Drivers.PulseBlaster.

    properties(SetObservable,GetObservable)
        state = Prefs.Boolean(false, 'set', 'set', 'help', 'A line of a PulseBlaster.')
    end
    properties(SetAccess=immutable,Hidden)
        pb;     % Handle to Drivers.PulseBlaster parent
        line;   % Index of the physical line of the parent that this D.PB.Line controls.
    end

    methods(Static)
        function obj = instance(parent, line)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.PulseBlaster.Line.empty(1,0);
            end
            [~,host_resolved] = resolvehost(parent.host);
            id = [host_resolved '_line' num2str(line)];
            for ii = 1:length(Objects)
                if isvalid(Objects(ii)) && isvalid(Objects(ii).pb) && isequal(id, Objects(ii).singleton_id)
                    obj = Objects(ii);
                    return
                end
            end
            obj = Drivers.PulseBlaster.Line(parent, line);
            obj.singleton_id = id;
            Objects(end+1) = obj;
        end
    end
    methods(Access=private)
        function obj = Line(parent, line)
            obj.pb = parent;
            obj.line = line;

            p = obj.get_meta_pref('state');
            p.help_text = ['Line ' num2str(line) ' of the PulseBlaster at ' parent.host];
            obj.set_meta_pref('state', p);

            addlistener(obj.pb,'ObjectBeingDestroyed',@(~,~)obj.delete);
        end
    end
    methods
        function delete(~)
            % Do nothing.
        end
        function val = get(obj, ~, ~)
            lines = obj.pb.getLines();
            val = lines(obj.line);
        end
        function val = set(obj, val, ~)
            if obj.pb.linesEnabled                  % If we should communicate with the hardware. If false, we already know the state of the hardware and are merely updating the values of prefs.
                obj.pb.setLines(obj.line, val);     % This will stop a currently-running program and revert to staticLines state.
            end
        end
    end
end
