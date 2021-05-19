classdef MAX302motors < Modules.Stage
    %MAX302 Control the motors of this stage.
    %   Uses 3 instances of APTMotor for x,y,z.
    %
    %   All values are in microns. It is good practice to home after
    %   construction.
    %
    %   Home is -2,-2,-2
    
    properties
        prefs = {'X_Motor','Y_Motor','Z_Motor','direction'};
    end
    properties(SetObservable,AbortSet)
        X_Motor = @Drivers.APTMotor.getAvailMotors;  % Motor serial number
        Y_Motor = @Drivers.APTMotor.getAvailMotors;  % Motor serial number
        Z_Motor = @Drivers.APTMotor.getAvailMotors;  % Motor serial number
        direction = [1 1 1];
    end
    properties(SetAccess=private,SetObservable,AbortSet)
        % Default here will only matter if motors aren't set
        Homed = false;
        Moving = false;              % Track this to update position
    end
    properties(SetAccess=private)
        position
        motors = cell(1,3); % A cell array for the 3 motors {X,Y,Z} (list would require having "null" objects)
    end
    properties(Constant)
        xRange = [-2 2]*1000;
        yRange = [-2 2]*1000;
        zRange = [-2 2]*1000;
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Stages.MAX302motors();
            end
            obj = Object;
        end
        
    end
    methods(Access=private)
        function obj = MAX302motors()
            '1'
            obj.loadPrefs;
            '2'
        end
    end
    % Callback functions for APTMotor
    methods(Access=?APTMotor)
        function homedCallback(obj,varargin)
            homed = false(1,3);
            for i = 1:length(obj.motors)
                if ~isempty(obj.motors{i})&&isobject(obj.motors{i}) && isvalid(obj.motors{i})
                    homed(i) = obj.motors{i}.Homed;
                end
            end
            obj.Homed = all(homed);
        end
        function movingCallback(obj,varargin)
            moving = false(1,3);
            for i = 1:length(obj.motors)
                if ~isempty(obj.motors{i})&&isobject(obj.motors{i}) && isvalid(obj.motors{i})
                    moving(i) = obj.motors{i}.Moving;
                end
            end
            obj.Moving = any(moving);
        end
    end
    methods
        function delete(obj)
            cellfun(@delete,obj.motors);
            % No need to delete APTSystem
        end
        function pos = get.position(obj)
            % This function takes a long time to execute.
            pos = NaN(1,3);
            range = [obj.xRange;obj.yRange;obj.zRange];
            for i = 1:length(obj.motors)
                if ~isempty(obj.motors{i})&&isobject(obj.motors{i}) && isvalid(obj.motors{i})
                    pos(i) = obj.motors{i}.read()*1000+min(range(i,:));
                end
            end
            pos = pos.*obj.direction;
        end
        function move(obj,x,y,z)
            pos = obj.position;
            range = [obj.xRange;obj.yRange;obj.zRange];
            new_pos = {x,y,z}; % Allow for empty inputs in for loop below
            for i = 1:length(obj.motors)
                if ~isempty(new_pos{i}) && new_pos{i}~=pos(i) && ~isnan(new_pos{i})
                    if ~isempty(obj.motors{i})&&isobject(obj.motors{i}) && isvalid(obj.motors{i})
                        new_pos{i} = (new_pos{i}*obj.direction(1) - min(range(i,:)))/1000;
                        obj.motors{i}.move(new_pos{i})
                    else
                        error('Tried to move axis without motor loaded!');
                    end
                end
            end
        end

        function enable(obj)
            %Method to enable motors drive
            for i = 1:length(obj.motors)
                if ~isempty(obj.motors{i})&&isobject(obj.motors{i}) && isvalid(obj.motors{i})
                    obj.motors{i}.enable();
                end
            end
            drawnow; % Flush callback queue
        end
        function disable(obj)
            %Method to disable motors drive
            for i = 1:length(obj.motors)
                if ~isempty(obj.motors{i})&&isobject(obj.motors{i}) && isvalid(obj.motors{i})
                    obj.motors{i}.disable();
                end
            end
            drawnow; % Flush callback queue
        end
        function home(obj)
            %Method to home/zero the motors
            for i = 1:length(obj.motors)
                if ~isempty(obj.motors{i})&&isobject(obj.motors{i}) && isvalid(obj.motors{i})
                    obj.motors{i}.home();
                end
            end
            drawnow; % Flush callback queue
        end
        function abort(obj,varargin)
            %Method to try and stop the motors
            for i = 1:length(obj.motors)
                if ~isempty(obj.motors{i})&&isobject(obj.motors{i}) && isvalid(obj.motors{i})
                    obj.motors{i}.abort(varargin{:});
                end
            end
            drawnow; % Flush callback queue
        end
        
        % Settings and Callback
        function  settings(obj,panelH,varargin)
            settings@Modules.Stage(obj,panelH,varargin{:}); % Add in prefs
            % Adjust for pref space usage (use character units)
            start = 0;
            children = allchild(panelH);
            set(children,'units','characters');
            for i = 1:length(children)
                h = sum(children(i).Position([2 4]));
                if h > start
                    start = h;
                end
            end
            start = start + 1; % Give a bit of space between
            spacing = 1.5;
            num_lines = 3;
            line = 1;
            uicontrol(panelH,'style','PushButton','string','X Settings','callback',@obj.motorSettings,...
                'units','characters','position',[0 start+spacing*(num_lines-line) 18 1.25],'UserData',1);
            line = 2;
            uicontrol(panelH,'style','PushButton','string','Y Settings','callback',@obj.motorSettings,...
                'units','characters','position',[0 start+spacing*(num_lines-line) 18 1.25],'UserData',2);
            line = 3;
            uicontrol(panelH,'style','PushButton','string','Z Settings','callback',@obj.motorSettings,...
                'units','characters','position',[0 start+spacing*(num_lines-line) 18 1.25],'UserData',3);
        end
        function motorSettings(obj,hObj,~,~)
            axis = hObj.UserData;
            if ~isempty(obj.motors{axis})&&isobject(obj.motors{axis}) && isvalid(obj.motors{axis})
                obj.motors{axis}.settings;
            else
                error('No motor is loaded for this axis!')
            end
        end
        
        % Motor construction callbacks
        function setMotor(obj,val,axis)
            val
            axis
            
            if ischar(val)
                val = str2double(val);
            end
            assert(~isnan(val), 'Motor SN must be a valid number.')
            if val == 0
                return % Short circuit
            end
            % Remove old motor if not loaded by other axis
            motorOld = obj.motors{axis}; % Either motor obj or empty
            obj.motors{axis} = [];
            inuse = false;
            for i = 1:length(obj.motors)
                if ~isempty(obj.motors{i})&&isobject(obj.motors{i}) && isvalid(obj.motors{i})
                    if obj.motors{i} == motorOld
                        inuse = true; break
                    end
                end
            end
            if ~inuse
                delete(motorOld) % Fine deleting []
                drawnow;
            end
            % Add new motor
            obj.motors{axis} = Drivers.APTMotor.instance(val, [0 10]);
            % Trick to update position
            obj.Moving = true;
            obj.Moving = false;
            % Listeners will follow lifecycle of their motor
            addlistener(obj.motors{axis},'Moving','PostSet',@obj.movingCallback);
            addlistener(obj.motors{axis},'Homed','PostSet',@obj.homedCallback);
            % Intialize values
            obj.homedCallback;
            obj.movingCallback;
        end
        function set.X_Motor(obj,val)
            try
                obj.setMotor(val,1); %#ok<*MCSUP>
                obj.X_Motor = val;
                obj.get_homed();
            catch err
                obj.X_Motor = '0';
            end
        end
        function set.Y_Motor(obj,val)
            try
                obj.setMotor(val,2);
                obj.Y_Motor = val;
                obj.get_homed();
            catch err
                obj.Y_Motor = '0';
            end
        end
        function set.Z_Motor(obj,val)
            try
                obj.setMotor(val,3);
                obj.Z_Motor = val;
                obj.get_homed();
            catch err
                obj.Z_Motor = '0';
            end
        end
        function tf = get_homed(obj)
            try
                obj.Homed = obj.X_Motor.Homed && obj.Y_Motor.Homed && obj.Z_Motor.Homed;
            end 
            tf = obj.Homed;
        end
    end
end

