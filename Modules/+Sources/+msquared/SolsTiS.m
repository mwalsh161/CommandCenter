classdef SolsTiS < Sources.msquared.common_invisible
    %SOLSTIS Control parts of SolsTis (msquared) laser
    %   Talks via the hwserver (via the driver)
    %   All methods go through a set.method to perform operation
    %
    % Similar to the EMM, this cannot load if the EMM is loaded
    % already. It will error in loading the solstis driver.
    %
    % A few notes:
    %   - updateStatus will set showprefs to NaN if no server
    %   - The range of this laser is updated upon successful connection to
    %       Drivers.msquared.solstis
    %   - The etalon lock removal resets resonator percentage/voltage and
    %       is not updated in this source
    %   - tune and WavelengthLock will try and track frequency as tuning
    %       (both use a pause(1) to wait for msquared to begin tuning)
    %   - updateStatus at the end of the set methods may be executed before
    %       the operation on the laser has finished (setting outdated values)

    properties(SetAccess=protected)
        range = Sources.TunableLaser_invisible.c./[700,1000]; %tunable range in THz
    end
    
    methods(Access=private)
        function obj = SolsTiS()
            obj.init();
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.msquared.SolsTiS();
            end
            obj = Object;
        end
    end
    methods(Hidden)
        function host = loadLaser(obj)
            host = obj.hwserver_host;
            modName = obj.moduleName;
            if isempty(host)||strcmp(host,obj.no_server)||isempty(modName); return; end
            err = obj.connect_driver('solstisHandle','msquared.solstis',host,modName);
            if ~isempty(err)
                obj.hwserver_host = obj.no_server;
                obj.updateStatus();
                if contains(err.message,'driver is already instantiated')
                    error('solstis driver already instantiated. Likely due to an active EMM source; please close it and retry.')
                end
                rethrow(err)
            end
            range = obj.solstisHandle.get_wavelength_range; %#ok<*PROP> % solstis hardware handle
            obj.range = obj.c./[range.minimum_wavelength, range.maximum_wavelength];
            obj.updateStatus();
        end
    end
    methods
        function delete(obj)
            if ~isempty(obj.solstisHandle)
                delete(obj.solstisHandle);
            end
        end

        function tune(obj,target)
            % This is the tuning method that interacts with hardware
            % target in nm
            assert(~isempty(obj.solstisHandle)&&isobject(obj.solstisHandle) && isvalid(obj.solstisHandle),'no solstisHandle, check hwserver_host')
            assert(target>obj.c/max(obj.range)&&target<obj.c/min(obj.range),sprintf('Wavelength must be in range [%g, %g] nm!!',obj.c./obj.range))
            obj.solstisHandle.set_target_wavelength(target);
            obj.updatingVal = true;
                obj.target_wavelength = target;
                obj.tuning = true;
            obj.updatingVal = false;
            pause(1) % Wait for msquared to start tuning
            obj.trackFrequency(obj.c/target); % Will block until obj.tuning = false (calling obj.getFrequency)
            obj.updateStatus();
        end
    end
end

