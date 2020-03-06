classdef WidefieldSlowScan_invisible < Modules.Experiment
    % subclasses must create:
    % prep_plot(ax) [called in PreRun]:
    %   Populates the supplied axes (already held) and adds axes labels
    % update_plot(ydata) [called in UpdateRun]
    %   Given the calculated ydata, update plots generated in prep_plot

    properties(GetObservable, SetObservable,AbortSet)
        resLaser = Modules.Source.empty(1,0); % Allow selection of source
        repumpLaser = Modules.Source.empty(1,0);
        imaging = Modules.Imaging.empty(1,0);
        
        repump_always_on = Prefs.Boolean(false);
    end
    properties
        prefs = {};
        scan_points = []; %frequency points, either in THz or in percents
    end
    properties(Constant)
        % Required by PulseSequenceSweep_invisible
        vars = {'scan_points'}; %names of variables to be swept
    end
    properties(SetAccess=protected,Hidden)
        data = [] % subclasses should not set this; it can be manipulated in GetData if necessary
        meta = [] % Store experimental settings
        abort_request = false; % Flag that will be set to true upon abort. Used in run method.
        pbH;    % Handle to pulseblaster
        nidaqH; % Handle to NIDAQ
    end
    
    methods
        function obj = WidefieldSlowScan_invisible()
            obj.prefs = [obj.prefs,{'resLaser','repumpLaser','imaging'}]; %additional preferences not in superclass
        end
        
        function run( obj,status,managers,ax)
            % Main run method (callback for CC run button)
            obj.abort_request = false;
            status.String = 'Experiment started';
            drawnow;

            obj.data.images = NaN([obj.imaging.width, obj.imaging.height, length(obj.scan_points)]);

            obj.meta.prefs = obj.prefs2struct;
            for i = 1:length(obj.vars)
                obj.meta.vars(i).name = obj.vars{i};
                obj.meta.vars(i).vals = obj.(obj.vars{i});
            end
            obj.meta.position = managers.Stages.position; % Stage position

            try
                obj.PreRun(status,managers,ax);
                
                for freqIndex = 1:length(obj.scan_points)
                    obj.repumpLaser.on
                    
                    obj.resLaser.TuneSetpoint(obj.scan_points(freqIndex));
                    obj.data.freqs_measured(freqIndex) = obj.resLaser.getFrequency();
                    
                    if ~obj.repump_always_on
                        obj.repumpLaser.off
                    end
                    
                    status.String = sprintf('Progress (%i/%i pts):\n  ', freqIndex, length(obj.scan_points));
                    
                    img = obj.imaging.snapImage;
                    
                    ax.UserData.CData = img;
                    
                    obj.data.images(:,:,freqIndex) = img;
                    
                    if obj.abort_request
                        return;
                    end
                end

            catch err
            end
            
            if exist('err','var')
                rethrow(err)
            end
        end
        
        function abort(obj)
            % Callback for when user presses abort in CC
            obj.abort_request = true;
        end
        
        function dat = GetData(obj,~,~)
            % Callback for saving methods (note, lots more info in the two managers input!)
            dat.data = obj.data;
            dat.meta = obj.meta;
        end
        
        function PreRun(obj,~,managers,ax)
            obj.data.freqs_measured = NaN(1, length(obj.scan_points));
            
            w = obj.imaging.width;
            h = obj.imaging.height;
            
            ax.UserData = imagesc(ax, 1:w, 1:h, NaN(h, w));
            set(ax,'DataAspectRatio',[1 1 1])
            
            xlabel(ax, '$x$ [pix]', 'interpreter', 'latex');
            ylabel(ax, '$y$ [pix]', 'interpreter', 'latex');
            
            obj.repumpLaser.on
            obj.resLaser.on
        end
    end
end
