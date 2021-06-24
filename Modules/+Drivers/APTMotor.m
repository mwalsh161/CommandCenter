classdef (Sealed) APTMotor < Drivers.APT & Modules.Driver
    % APTMOTOR A subclass to handle things specific to the motor controller
    %   All positions are in mm
    %
    %	Singleton based off serial number
    %
    %	Settings are unique to the MATLAB version. It will save all settings
    %	as mfilename (still unique for different serial numbers). Loads the
    %	settings from last time upon initialization.
    
    properties
        name
    end
    properties(GetObservable,SetObservable)
        Position =  Prefs.Double(NaN,  'set', 'set_position', 'get', 'get_position', 'allow_nan', true);
        
        Moving =    false; % Prefs.Boolean(NaN, 'get', 'get_moving', 'readonly', true, 'allow_nan', true);
        Homed =     false; % Prefs.Boolean(NaN, 'get', 'get_homed',  'readonly', true, 'allow_nan', true);
    end
    properties(SetAccess=private,SetObservable,AbortSet)
        % Flag to determine moving
        %   See WAITFOR
%         Moving = false;
% %         Position           % Current Position. 0 corresponds to mean(Travel)
%         Homed              % Flag specifying home status
        Travel             % Restrictions on the travel distance. 2x1 vector
    end
    properties(Access=private)
        newPosition = true;    % Used to speed up position querry
        lastPosition            % If newPosition, this is set
    end

    methods (Static)
        function devices = getAvailMotors()
            % 0 means no motor
%             f = msgbox('Loading APTSystem',mfilename,'modal');    % This was taking more than a second upon startup; disabling. 
            APTSystem = Drivers.APTSystem.instance;
            devices = APTSystem.getDevices;
            devices = num2cell(double(devices.USB_STEPPER_DRIVE));
            devices = [{'0'},cellfun(@num2str,devices,'uniformoutput',false)];
%             delete(f);
        end
        % Use this to create/retrieve instance associated with serialNum
        function obj = instance(serialNum,travel,name)
            mlock;
            if nargin < 3
                name = serialNum;
            end
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.APTMotor.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(serialNum,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.APTMotor(serialNum,name,travel);
            obj.singleton_id = serialNum;
            Objects(end+1) = obj;
        end
    end    
    methods(Access=private)
        % Constructor should only be called by instance()
        function obj = APTMotor(serialNum,name,travel)
            obj.initialize('MGMOTOR.MGMotorCtrl.1',serialNum)
            
            obj.name = name;
            
            validateattributes( travel, {'numeric'}, {'vector', 'numel',2,'nonnan'} );
            travel = sort(travel);
            obj.Travel = travel;
            
            obj.Homed =  obj.get_homed;
            obj.Moving = obj.get_moving;
        end
        
        %Method to handle ActiveX events
        function eventHandler(obj,varargin)
            switch varargin{end}
                case {'MoveComplete', 'MoveStopped'}
                    obj.Moving = false;
                case 'HomeComplete'
                    obj.Homed = true;
                    obj.Moving = false;
                case 'HWResponse'
                    obj.LibraryFunction('ShowEventDlg');
                    error('APTMotorController Error.');
            end
        end
        
        %Method to determine if newPos is allowed (called by step and move)
        function tf = CheckMove(obj,newPos)
            % Check to make sure newPos is ok to execute
            %   Error if it is outside limits
            %   Error if stepsize too small, and returns false
            %   Otherwise returns true
            tf = true;
            assert(obj.Homed==1,'Motor %s is not homed!',obj.name)
            assert(newPos <=max(obj.Travel)&&newPos >= min(obj.Travel),...
                'Attempted to move motor %s to %f, but it is limited to %f, %f',obj.name,newPos,min(obj.Travel),max(obj.Travel))
        end
    end

    methods
        function delete(obj)
            try
                obj.LibraryFunction('SaveParamSet',mfilename);
            end
            try
                delete(obj.controlHandle)
            end
            try
                delete(obj.figureHandle)
            end
        end
        
        % Method to display settings dialog
        function settings(obj)
            obj.LibraryFunction('ShowSettingsDlg');
        end
        
        function enable(obj)    % Enable motor drive. This locks the stepper.
            obj.LibraryFunction('EnableHWChannel',0);
        end
        function disable(obj)   % Method to disable motor drive (allows to turn by hand). Assume home is lost.
            obj.LibraryFunction('DisableHWChannel',0);
            obj.Homed = false;
        end
        
        function val = set_position(obj,val,pref)
            if ~obj.Moving && obj.Homed
                obj.move(val);
                
                timeout = 10;
                t = tic;
                
                while (abs(val - obj.get_position()) > .01 || obj.Moving) && toc(t) < timeout
                    pause(.05);
                end
%                 waitfor(obj, 'Moving');
            else
                if obj.Moving
                    warning('Motor is moving.')
                end
                if ~obj.Homed
                    warning('Motor is not homed.')
                end
                val = pref.value;
            end
        end
        function val = get_position(obj,~)
            % This will get used alot, so it is nice to add some
            % intelligence so we only poll the expensive LibraryFunction
            % if we have to.
%            if obj.newPosition
           [~,val] = obj.LibraryFunction('GetPosition',0,0);
%                obj.lastPosition = val;
%            else
%                val = obj.lastPosition;
%            end
%            obj.newPosition = obj.Moving;
        end
        function val = read(obj)
            val = obj.get_position();
        end

        %Method to move the motor by a jog
        function step(obj,distance)
            direction = 1;
            if distance/abs(distance) == -1
                direction = 2;
            end
            obj.LibraryFunction('SetJogStepSize',0,abs(distance));
            
            %Get current position of motor
            [~,curPos] = obj.LibraryFunction('GetPosition',0,0);
            %Get jog step size
            [~,curStep] = obj.LibraryFunction('GetJogStepSize',0,0);
            
            newPos = curPos + distance/abs(distance)*curStep;
            
            if obj.CheckMove(newPos)
                obj.Moving = true;
                obj.newPosition = true;
                obj.LibraryFunction('MoveJog',0,direction);
            end
        end
                
        %Method to move to an absolute position in um
        function move(obj,position)
            % make sure the position is within bounds and that we are
            % actually moving
            if obj.CheckMove(position)
                %Set the position and move
                obj.newPosition = true;
                obj.Moving = true;   % This needs to be issued before the
                                     % stage is moving so the callbacks
                                     % ocur in the right order no matter
                                     % what. It is possible the
                                     % MoveComplete event happens before
                                     % this if it were placed after.
                obj.LibraryFunction('SetAbsMovePos',0,position);
                obj.LibraryFunction('MoveAbsolute',0,0);
            end
        end
        
        function abort(obj,immediate)       % Method to try and stop the motor
            obj.Moving = obj.isMoving;  % Just in case we missed an activeX listener callback somehow
            obj.LibraryFunction('StopProfiled',0); % Motor is still tracked
            if nargin > 1 && immediate
                obj.LibraryFunction('StopImmediate',0); % Will need to re-home
                obj.Homed = false;
            end
        end
        
        function setVelParams(obj,accelMax,velMax)
            obj.LibraryFunction('SetVelParams',0,0,accelMax,velMax);
        end
        function [accelMax,velMax] = getVelParams(obj)
            [~,~,accelMax,velMax] = obj.LibraryFunction('GetVelParams',0,0,0,0);
        end
        
        function val = get_moving(obj,~)
            val = obj.isMoving();
        end
        function tf = isMoving(obj)         % Method to test if motor moving
            tf = obj.getStatus(obj.MOVING_COUNTERCLOCKWISE) || obj.getStatus(obj.MOVING_CLOCKWISE);
        end
        
        function home(obj)                  % Method to home/zero the motor
            %Reset the flag
            obj.Homed = 0;
            %Send the command
            obj.Moving = true;
            obj.newPosition = true;
            obj.LibraryFunction('MoveHome',0,0);
        end
        function val = get_homed(obj,~)
            val = obj.getStatus(obj.HOMED);
        end
    end
    
    methods (Access = protected)
        function subInit(obj)               % Called by initialize (after APT class is constructed)
            try
                obj.LibraryFunction('LoadParamSet',mfilename);
            catch err
                warning(err.message)
            end
            obj.enable;
            obj.LibraryFunction('Identify');
            
            %Register an eventHandler for all APT events
            obj.registerAPTevent(@obj.eventHandler)

            %Check the home status from the status bits
            obj.Homed =     obj.get_homed();
            obj.Moving =    obj.get_moving();
            
            % Set jog mode to be steps not continuous (no joy stick)
            obj.LibraryFunction('SetJogMode',0,2,1);
        end
    end
end