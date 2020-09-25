classdef Imaging < Base.Module & Base.Measurement
    %MODULE Abstract Class for Modules.
    %   Simply enforces required properties. For future use.

    properties(GetObservable,SetObservable)
        calibration = Prefs.Double(1, 'unit', 'um/pix'); % Calibration set and used by CommandCenter (um/#)
        % When saving, instructs CommandCenter to ignore the last stage (finest moving)
        %   This can be useful for confocal setups, where the stage is also
        %   used for scanning.
    end
    properties
        uses_stage = '';
        path = '';
    end
    properties(Constant,Hidden)
        modules_package = 'Imaging';
    end
    properties(Abstract,SetObservable)
        % Region of Interest. Set and Get methods should be used to make sure this works well!!!
        %   Format should be [xMin xMax; yMin yMax]
        %   Note, pixels are the unit for a CCD, voltage for galvos
        ROI
        % Resolution in pixels (used to reset ROI)
        %   Format should be [x y]
        resolution
        continuous      % Boolean specifiying if continuous acquisition is active
    end
    properties(Abstract)
        maxROI
    end

    methods
        function obj = Imaging()
            if ispref(obj.namespace,'calibration')
                obj.calibration = getpref(obj.namespace,'calibration');
            end
        end
        function delete(obj)
            % Manually make calibration a pref

            % if namespace isn't set, means error in constructor
            if isempty(obj.namespace)
                return
            end
            assert(ischar(obj.namespace),'Namespace must be a string!')
            setpref(obj.namespace,'calibration',obj.calibration)
        end
    end

    methods(Abstract)
        % Focus the image using the stageHandle.  See <a href="matlab:doc('Modules.Stage')">Modules.Stage</a>.
        metric = focus(obj,ax,stageHandle)

        % Take a snapshot, and populate cdata of imHandle
        snap(obj,imHandle)

        % Begin previewing continuous frames update the image cdata
        startVideo(obj,imHandle)

        % Stop previewing frames
        stopVideo(obj)
    end

end
