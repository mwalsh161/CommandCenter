classdef CollectionGalvos < Modules.Stage
    %GALVOS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(SetAccess=private)
        position
    end
    properties(SetAccess=private,SetObservable)
        Moving = false;
    end
    properties(SetAccess=immutable,Hidden)
        galvoDriver
    end
    properties(Constant)
        xRange = [-3 3];
        yRange = [-3 3];
        zRange = [-10 10];
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Stages.CollectionGalvos();
            end
            obj = Object;
        end
    end
    methods(Access=private)
        function obj = CollectionGalvos()
            obj.galvoDriver = Drivers.NIDAQ.stage.instance('Xc','Yc','','APD1','GalvoScanSync');
            addlistener(obj.galvoDriver,'moving','PostSet',@obj.update_Moving);
        end
    end
    methods
        function update_Moving(obj,varargin)
            if isvalid(obj)  % I tried for a good day trying to figure this shit out. Shouldn't need this if statement!
                obj.Moving = obj.galvoDriver.moving;
            end
        end
        function val = get.position(obj)
            val = obj.galvoDriver.voltage;
        end
        
        function move(obj,x,y,~)
            try
                obj.galvoDriver.SetCursor(x,y)
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

