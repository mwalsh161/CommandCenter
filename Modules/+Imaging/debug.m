classdef debug < Modules.Imaging
    %DEBUG Creates random pixels (no hardware needed)

    properties
        maxROI = [-1 1; -1 1];
        % NOTE: my_string should be added at end as setting, but not saved like pref
        %prefs = {'fyi','my_module','my_integer','my_double','old_style','my_logical','fn_based','cell_based','source','imager'};
        prefs = {'file','old_style','fyi','my_old_array','my_array','my_array2','my_module','my_integer','my_double','my_logical', 'reftest', 'reference'};
       show_prefs = {'fyi','my_integer','my_double'};
       % readonly_prefs = {''} % Should result in deprecation warning if used
    end
    properties(GetObservable,SetObservable)
        reference = Prefs.Reference();
        
        fyi = Prefs.String('This is for your info',...
                           'help_text','This is a readonly string.',...
                           'readonly',true);
        my_old_array = [1,2,3];
        file = Prefs.File();
        reftest = Prefs.Reference();
%         my_array = Prefs.DoubleArray([1,2;3,4],'allow_nan',false,'min',0,'set','testSet');
%         my_array2 = Prefs.DoubleArray([1,2;3,4],'hide_label',true,'props',{'RowName',{'this','that'},'ColumnName',{'foo','bar'}});
        my_integer = Prefs.Integer('min',0,'help_text','indexed from 0');
        my_double = Prefs.Double('name','This double has a super long name!','unit','um','min',-50,'max',50);
        my_string = Prefs.String('Enter value here','allow_empty',false);
        my_logical = Prefs.Boolean();
        options_1 = Prefs.MultipleChoice('help_text','sooo many options!','choices',{'foo',41,'bar'})
        options_2 = Prefs.MultipleChoice(42,'allow_empty',false,'choices',{'foo',42,'bar'})
        my_module = Prefs.ModuleInstance();
        old_style = 'abc';
        fn_based = @Imaging.debug.get_options;
        cell_based = {'options1','option2',6};
        source = Modules.Source.empty(1,0);
        imager = Modules.Imaging.empty;
        resolution = [120 120];                 % Pixels
        ROI = [-1 1;-1 1];
        continuous = false;
        
        image = Base.Meas([120 120], 'name', 'Image', 'unit', 'cts');
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
        function val = testSet(obj,val,pref)
            fprintf('Here!\n')
        end
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
        function im = snapImage(obj)
            im = zeros(obj.resolution(1),obj.resolution(2));
            [tempx,tempy] = meshgrid(1:obj.resolution(1),1:obj.resolution(2));
            for i=1:randi([5,20]) %pick a random number of spots
                loc = (obj.resolution(1)-1).*rand(1,2)-1;
                gaussim = exp((-(tempx-loc(1)).^2-(tempy-loc(2)).^2)/(2*(mean(obj.resolution)/50)^2)); %make a gaussian with width of 1/50 the resolution
                im = im + gaussim;
            end
        end
        function snap(obj,im,continuous)
            set(im,'cdata',obj.snapImage);
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
