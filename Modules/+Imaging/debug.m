classdef debug < Modules.Imaging
    %DEBUG Creates random pixels (no hardware needed)
    
    properties
        maxROI = [-1 1; -1 1];
        prefs = {'new_style','resolution','continuous'};
     %   show_prefs = {'resolution','continuous','driver','source','database','imager','stage'};
    end
    properties(GetObservable,SetObservable)
        new_style = Prefs.Integer('min',0);
 %       driver = Modules.Driver.empty(1,0); % Will only work without inputs
 %       source = Modules.Source.empty(1,0);
 %       database = Modules.Database.empty(0); % Should never do this
 %       imager = Modules.Imaging.empty;
 %       stage = Modules.Stage.empty;
        resolution = [120 120];                 % Pixels
        ROI = [-1 1;-1 1];
        continuous = false;
    end
    
    methods(Access=private)
        function obj = debug()
            obj.loadPrefs;
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Imaging.debug();
            end
            obj = Object;
        end
    end
    methods
        function set.ROI(obj,val)
            % Update ROI without going outside maxROI
            val(1,1) = max(obj.maxROI(1,1),val(1,1)); %#ok<*MCSUP>
            val(1,2) = min(obj.maxROI(1,2),val(1,2));
            val(2,1) = max(obj.maxROI(2,1),val(2,1));
            val(2,2) = min(obj.maxROI(2,2),val(2,2));
            % Now make sure no cross over
            val(1,2) = max(val(1,1),val(1,2));
            val(2,2) = max(val(2,1),val(2,2));
            obj.ROI = val;
        end
        function focus(obj,ax,stageHandle)
        end
        function snap(obj,im,continuous)
            tempim = zeros(obj.resolution(1),obj.resolution(2));
            [tempx,tempy] = meshgrid(1:obj.resolution(1),1:obj.resolution(2));
            for i=1:randi([5,20]) %pick a random number of spots
                loc = (obj.resolution(1)-1).*rand(1,2)-1;
                gaussim = exp((-(tempx-loc(1)).^2-(tempy-loc(2)).^2)/(2*(mean(obj.resolution)/50)^2)); %make a gaussian with width of 1/50 the resolution
                tempim = tempim + gaussim;
            end
            set(im,'cdata',tempim);
        end
        function startVideo(obj,im)
            obj.continuous = true;
            while obj.continuous
                obj.snap(im,true);
                drawnow;
            end
        end
        function stopVideo(obj)
            obj.continuous = false;
        end
        
    end
    
end

