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
        setpoint = Prefs.Double(NaN,'readonly',true,'unit','THz');
    end
    properties(SetObservable,GetObservable)
        locked = Prefs.Boolean(false,'readonly',true,'allow_nan',true);
    end
    properties(Abstract,SetAccess=protected)
        range
    end
    properties(Constant,Hidden)
        c = 299792; %speed of light in nm*Thz
    end
    methods
        function trackFrequency(obj,varargin)
            target = NaN;
            timeout = Inf;
            
            if nargin > 1
                target = varargin{1};
            end
            if nargin > 2
                timeout = varargin{2};
            end
            
            t = tic; % Start clock
            
            [f,new] = UseFigure('TunableLaser.trackFrequency');
            if new % Prepare axes
                set(f,'name','TunableLaser.trackFrequency','NumberTitle','off');
                f.UserData.ax(1) = subplot(2,1,1,'parent',f);
                f.UserData.ax(2) = subplot(2,1,2,'parent',f);
                hold(f.UserData.ax(1),'on'); hold(f.UserData.ax(2),'on');
                title(f.UserData.ax(1),'');
                xlabel(f.UserData.ax(1),'Time (s)');
                ylabel(f.UserData.ax(1),'Frequency (THz)');
                xlabel(f.UserData.ax(2),'Time (s)');
                ylabel(f.UserData.ax(2),'|dF| (dTHz)');
                set(f.UserData.ax(2),'yscale','log');
            end
            
            ax = f.UserData.ax;
            ax(1).Title.String = sprintf('Tuning %s',class(obj));
            delete(ax(1).Children); % Clean up from last time
            delete(ax(2).Children);
            setpointH = plot(ax(1),[0 1],[0 0]+target,'--k','DisplayName','Setpoint');
            freqH = plot(ax(1),NaN,NaN,'r-o','DisplayName','Current Frequency');
            dfreqH = plot(ax(2),NaN,NaN,'r-o');
            legend(ax(1),'show');
            
            obj.getFrequency;   % Refresh obj.tuning
            n = 0;
            while obj.tuning && toc(t) < timeout
                freq = obj.getFrequency;
                n = n + 1;
                dt = toc(t);
                setpointH.XData(2) = dt; % Extend dashed line
                freqH.XData(end+1) = dt;
                freqH.YData(end+1) = freq;
                if n > 1
                    dfreqH.XData(end+1) = dt;
                    dfreqH.YData = abs(diff(freqH.YData));
                end
                drawnow limitrate;
            end
            
            freqH.Color = lines(1);
            dfreqH.Color = lines(1);
            ax(1).Title.String = class(obj);
        end
        function obj = TunableLaser_invisible()
            obj.show_prefs = [{'setpoint'},obj.show_prefs];
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
