classdef LoadFile < Modules.Imaging
    %DEBUG Creates random pixels (no hardware needed)

    properties
        maxROI = [-Inf Inf; -Inf Inf];
        % NOTE: my_string should be added at end as setting, but not saved like pref
        %prefs = {'fyi','my_module','my_integer','my_double','old_style','my_logical','fn_based','cell_based','source','imager'};
        prefs = {'file', 'field'};
       % readonly_prefs = {''} % Should result in deprecation warning if used
    end
    properties(GetObservable,SetObservable)
        file =  Prefs.File('help_text', 'File to load into MATLAB upon snap.');
        field = Prefs.String('',    'allow_empty', true, ...
                                    'custom_validate', 'validate_field', ...
                                    'help_text', 'If a .mat file is loaded, this field of the struct contained in the .mat will be used.');
        
        resolution = [120 120];                 % Pixels
        ROI = [-1 1;-1 1];
        continuous = false;
        
        image = Base.Meas([120 120], 'name', 'Image', 'unit', 'cts');
    end

    methods(Access=private)
        function obj = LoadFile()
            obj.loadPrefs;
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Imaging.LoadFile();
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
        function tf = validate_field(obj, field, ~)
            tf = isempty(field) || isvarname(field);
        end
        function im = snapImage(obj)
            parts = split(obj.file, '.');
            extension = parts{end};
            
            formats = imformats;
            extensions = {};
            for format = formats
                extensions = [extensions format.ext]; %#ok<AGROW>
            end
            
            switch extension
                case extensions
                    im = imread(obj.file);
                case 'mat'
                    d = load(obj.file);
                    if isempty(obj.field)
                        assert(~isempty(d), 'Loaded .mat file was empty. Sad.')
                        fn = fieldnames(d);
                        im = d.(fn{1});         % Default to first field.
                    else
                        im = d.(obj.field);
                    end
                otherwise
                    error(['Image format ' extension ' not recognized'])
            end
            
            assert(~isempty(im),    'Image cannot be empty');
            assert(isnumeric(im),   'Image must be numeric');
            
            s = size(im);
            
            assert(~sum(s == 1),    ['Image may not contain singleton dimensions received image with size [' num2str(s) ']'])
            
            if length(s) == 3       % Color image
                im = sum(im, 3);    % Convert to grayscale
            elseif length(s) == 2
                % All good
            else
                error(['Not sure how to interpret image with size [' num2str(s) ']'])
            end
            
            obj.resolution = s;
            obj.ROI = [1, s(1); 1, s(2)];
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
