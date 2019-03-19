classdef Galvos_Axiovert200 < Modules.Stage
    %GALVOS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        calibration = [1 1 1];
    end
    
    properties(SetAccess=private)
        position
    end
    properties(SetAccess=private,SetObservable)
        Moving = false;
    end
    properties(SetAccess=immutable,Hidden)
        galvoDriver
        ZeissDriver
    end
    properties(Constant)
        xRange = [-3 3];
        yRange = [-3 3];
        zRange = [-1000 1000];
    end
    methods(Access=private)
        function obj = Galvos_Axiovert200()
            obj.galvoDriver = Drivers.NIDAQ.stage.instance('X','Y','Z','APD1','GalvoScanSync');
            
            obj.ZeissDriver = Drivers.Zeiss_Axiovert200.instance;
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Stages.Galvos_Axiovert200();
            end
            obj = Object;
        end
    end
    methods

        
        function val = get.position(obj)
            val = obj.galvoDriver.voltage;
            val(3) = obj.ZeissDriver.getZpos;
        end
        
        function move(obj,x,y,z)
            obj.Moving = 1;
            try
                obj.galvoDriver.SetCursor(x,y)
            catch err  % Ignore already moving error
                if ~strcmp(err.message,'Galvos are currently moving!')
                    rethrow(err)
                end
            end
            obj.ZeissDriver.setZpos(z);
            obj.Moving = 0;
        end
        function home(obj)
            obj.move(0,0,obj.ZhomePos) 
        end
        function abort(obj,immediate)
            % Action is basically instant!
        end
        
        function settings(obj,panelH)
            
        end
    end
    
end

