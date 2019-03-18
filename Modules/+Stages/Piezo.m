classdef Piezo < Modules.Stage
    %GALVOS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(SetAccess=private)
        position
    end
    properties(SetAccess=private,SetObservable)
        Moving = false;
    end
    properties(SetAccess=immutable,Hidden)
        piezoDriver
    end
    properties(Constant)
        xRange = [0 9];
        yRange = [0 9];
        zRange = [0 9];
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Stages.Piezo();
            end
            obj = Object;
        end
    end
    methods(Access=private)
        function obj = Piezo()
            obj.piezoDriver = Drivers.NIDAQ.stage.instance('X','Y','Z','APD1','ScanSync');
            addlistener(obj.piezoDriver,'moving','PostSet',@obj.update_Moving);
        end
    end
    methods
        function update_Moving(obj,varargin)
            if isvalid(obj)  % I tried for a good day trying to figure this shit out. Shouldn't need this if statement!
                obj.Moving = obj.piezoDriver.moving;
            end
        end
        function val = get.position(obj)
            val = obj.piezoDriver.voltage;
        end
        
        function move(obj,x,y,z)
            try
                obj.piezoDriver.SetCursor(x,y,z)
            catch err  % Ignore already moving error
                if ~strcmp(err.message,'Galvos are currently moving!')
                    rethrow(err)
                end
            end
        end
        function home(obj)
            obj.move(0,0,0)
        end
        function abort(obj,immediate)
            % Action is basically instant!
        end
        
        function settings(obj,panelH)
            
        end
    end
    
end

