classdef TunableLaser_invisible < handle
    %TUNABLELASER_INVISIBLE Superclass for all lasers that can have their
    %frequency tuned. 
    %Properties:
    %   tuning: flag indicating laser is still tuning (should be updated on
    %       getFrequency calls)
    %   setpoint: frequency in THz where the laser was last told to be set
    %   locked: true if laser is in a closed-loop state, false otherwise
    %   range: the tunable range of the laser in THz
    %Methods:
    %   TuneCoarse: Tune coarse tuning method to a unit-value
    %   TunePercent: Tune percentage (0,100) of presumed fine-tuning
    %   TuneSetpoint: Tuning with feedback to a unit-value
    %   getFrequency: Should return a real-time readout of laser frequency (NOT just setpoint, but where the laser ACTUALLY is)
    
    properties(Abstract,SetObservable)
        % User must define even if empty cell array!
        show_prefs
        tuning  % True/false if laser is actively tuning (used in trackWavelength)
    end
    properties(SetObservable,GetObservable)
        setpoint = Prefs.Double(NaN,'readonly',true,'units','THz');
    end
    properties(SetObservable,GetObservable)
        locked = Prefs.Boolean(false,'readonly',true);
    end
    properties(Abstract,SetAccess=protected)
        range
    end
    properties(Constant,Hidden)
        c = 299792; %speed of light in nm*Thz
    end
    methods
        function trackFrequency(obj)
            fprintf('Tuning: %i\n',obj.tuning);
            while obj.tuning
                freq = obj.getFrequency;
                fprintf('Tuning: %i\n',obj.tuning);
                fprintf('%g THz\n',freq);
            end
        end
        function obj = TunableLaser_invisible()
            obj.show_prefs = [{'setpoint','locked'},obj.show_prefs];
        end
        function TuneCoarse(~,varargin)
            error('Method TuneCoarse not defined')
        end
        function TunePercent(~,varargin)
            error('Method TunePercent not defined')
        end
        function TuneSetpoint(~,varargin)
            error('Method TuneSetpoint not defined')
        end
        function percent = GetPercent(~,varargin)
            error('Method GetPercent not defined')
        end
        function SpecSafeMode(obj,danger_zone)
            %will tune the laser as far away as possible from the given
            %range; will error if the range covers the entirety of the
            %tunable range. This can be overwritten if a power-off method
            %exists, which may be safer
            assert(min(danger_zone)>min(obj.range)||max(danger_zone)<max(obj.range),'No safe tuning point for given range')
            try
                if min(danger_zone) <= obj.setpoint && max(danger_zone) >= obj.setpoint %check if currently in danger zone
                    if (min(danger_zone)-min(obj.range)) > (max(obj.range)-max(danger_zone))
                        obj.TuneCoarse(min(obj.range))
                    else
                        obj.TuneCoarse(max(obj.range))
                    end
                end
            catch err
                msg = sprintf('Error in making laser safe for spectra: %s. Laser may interfere with desired spectrum measurements in range [%g,%g]. Continue regardless?',err.message,min(danger_zone),max(danger_zone));
                answer = questdlg(msg, ...
                    'Laser unsafe for spectra', ...
                    'Yes','No','No');
                if strcmp(answer,'No')
                    rethrow(err)
                end
            end
        end
    end
    methods(Abstract)
        freq = getFrequency(~,varargin)
    end
end

