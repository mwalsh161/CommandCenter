classdef debug < Modules.Imaging
    %DEBUG Creates random pixels (no hardware needed)
    
    properties
        maxROI = [-1 1; -1 1];
        % NOTE: my_string should be added at end as setting, but not saved like pref
        prefs = {'fyi','my_module','my_integer','my_double','old_style','my_logical','fn_based','cell_based'};
       % show_prefs = {'fyi','my_integer','my_double'};
       % readonly_prefs = {''} % Should result in deprecation warning if used
    end
    properties(GetObservable,SetObservable)
        fyi = Prefs.String('This is for your info',...
                           'help_text','This is a readonly string.',...
                           'readonly',true);
        my_integer = Prefs.Integer('min',0,'help_text','indexed from 0');
        my_double = Prefs.Double('units','um','min',-50,'max',50);
        my_string = Prefs.String('Enter value here','allow_empty',false);
        my_logical = Prefs.Boolean();
        options_1 = Prefs.MultipleChoice('help_text','sooo many options!','choices',{'foo',41,'bar'})
        options_2 = Prefs.MultipleChoice(42,'allow_empty',false,'choices',{'foo',42,'bar'})
        my_module = Prefs.ModuleInstance();
        old_style = 5;
        fn_based = @Imaging.debug.get_options;
        cell_based = {'options1','option2',6};
        % These are not implemented yet
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
        function options = get_options()
            options = {'opt1','opt2'};
        end
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

