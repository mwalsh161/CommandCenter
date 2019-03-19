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
    
    properties(Abstract,SetObservable,AbortSet)
        % User must define even if empty cell array!
        show_prefs
        readonly_prefs
        tuning  % True/false if laser is actively tuning (used in trackWavelength)
    end
    properties(SetAccess=protected,SetObservable)
        setpoint
    end
    properties(SetObservable,AbortSet)
        locked = false;
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
            obj.readonly_prefs = [{'setpoint','locked'},obj.readonly_prefs];
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
    end
    methods(Abstract)
        freq = getFrequency(~,varargin)
    end
end

