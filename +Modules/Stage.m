classdef Stage < Base.Module
    %MODULE Abstract Class for Modules.
    %   Stages should be calibrated as possible when coming in.
    %   Stages should not require input arguments.
    
    properties
        % Calibration set and used by CommandCenter when imaging device has uses_stage=true (um/#).
        %   Will only update x and y.
        calibration = [1 1 1];
    end
    properties(Abstract,SetAccess=private)
        position                % Current position of the stage in um
    end
    properties(Abstract,SetAccess=private,SetObservable)
        Moving                  % Boolean specifying whether stage in motion
    end
    properties(Abstract,Constant)
        xRange                  % Range in um of x axis
        yRange                  % Range in um of x axis
        zRange                  % Range in um of x axis
    end
    properties(Access=private)
        namespace
    end
    properties(Constant,Hidden)
        modules_package = 'Stages';
    end
    
    methods(Abstract)
        % Move to position x,y,z (note this is different call syntax than the manager)
        % The method should be callable with any of x,y,z as an empty array
        move(obj,x,y,z)
        
        % Return stage to its home. This also resets tracking for many stages.
        home(obj)
        
        % Stop motion.
        %   If immediate is true, force stop. Otherwise, stop in a
        %   controlled way (to maintain knowledge of locatin)
        abort(obj,immediate)
    end
    methods
        function obj = Stage()
%             d = dbstack('-completenames');
%             if numel(d) > 1
%                 name = strsplit(d(2).name,'.');
%                 name = name{1};
%             else
%                 name = mfilename;
%             end
            obj.namespace = strrep(class(obj),'.','_');
            if ispref(obj.namespace,'calibration')
                obj.calibration = getpref(obj.namespace,'calibration');
            end
        end
        function delete(obj)
            setpref(obj.namespace,'calibration',obj.calibration)
        end
        function pos = getCalibratedPosition(obj)
            if isnumeric(obj.calibration)&&~sum(isnan(obj.calibration))
                cal = obj.calibration;
            else
                err = sprintf('%s calibration property is not numeric (or is NaN). Please fix this. Using 1 for now',class(mod));
                obj.error(err)
                cal = 1;
            end
            pos = obj.position.*cal;
        end
    end
end