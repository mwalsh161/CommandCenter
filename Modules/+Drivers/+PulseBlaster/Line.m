classdef Line < Modules.Driver
    %Drivers.PulseBlaster.Line is a wrapper for a Prefs.Boolean
    
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
                if isvalid(Objects(ii)) && isvalid(Objects(ii).PB) && isequal(id, Objects(ii).singleton_id)
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
            %addlistener(obj.PB,'running','PostSet',@(~,~)obj.updateRunning);
        end
    end
    methods
        function delete(obj)
            % Do nothing.
        end
        function val = get(obj, ~, ~)
            lines = obj.pb.getLines();
            val = lines(obj.line);
        end
        function val = set(obj, val, ~)
            obj.pb.setLines(obj.line, val);     % This will stop a currently-running program and revert to staticLines state.
        end
    end
end

