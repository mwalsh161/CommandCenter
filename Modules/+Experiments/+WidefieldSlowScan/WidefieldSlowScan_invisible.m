classdef WidefieldSlowScan_invisible < Modules.Experiment
    % subclasses must create:
    % prep_plot(ax) [called in PreRun]:
    %   Populates the supplied axes (already held) and adds axes labels
    % update_plot(ydata) [called in UpdateRun]
    %   Given the calculated ydata, update plots generated in prep_plot

    properties(GetObservable, SetObservable, AbortSet)
        resLaser = Modules.Source.empty(1,0); % Allow selection of source
        repumpLaser = Modules.Source.empty(1,0);
        imaging = Modules.Imaging.empty(1,0);
        
        repump_always_on = Prefs.Boolean(false);
        
        only_get_freq = Prefs.Boolean(false);
        save_freq = Prefs.Boolean(true);
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
            obj.prefs = [obj.prefs,{'resLaser', 'repumpLaser', 'imaging', 'repump_always_on', 'save_freq', 'only_get_freq'}]; %additional preferences not in superclass
        end
        
        function run( obj,status,managers,ax)
            % Main run method (callback for CC run button)
            obj.abort_request = false;
            status.String = 'Experiment started';
            drawnow;

            if ~obj.only_get_freq
                obj.data.images = zeros([obj.imaging.width, obj.imaging.height, length(obj.scan_points)], 'int16');
            end

            obj.meta.prefs = obj.prefs2struct;
            for i = 1:length(obj.vars)
                obj.meta.vars(i).name = obj.vars{i};
                obj.meta.vars(i).vals = obj.(obj.vars{i});
            end
            obj.meta.position = managers.Stages.position; % Stage position

            try
                obj.PreRun(status,managers,ax);
                
                for freqIndex = 1:length(obj.scan_points)
%                     'frame'
%                     tic
                    status.String = sprintf('Progress (%i/%i pts):\n  Setting laser', freqIndex, length(obj.scan_points));
                    drawnow
%                     toc
                    
                    if ~obj.only_get_freq
                        if ~obj.repump_always_on
                            obj.repumpLaser.on
                        end
                    end
                    
%                     tic
                    obj.setLaser(obj.scan_points(freqIndex));
%                     toc
                    
%                     tic
                    if obj.save_freq
                        obj.data.freqs_measured(freqIndex) = obj.resLaser.getFrequency();
                    end
%                     toc
                    
                    
                    
                    if ~obj.only_get_freq
                        if ~obj.repump_always_on
                            obj.repumpLaser.off
                        end
                        
%                         tic
                        status.String = sprintf('Progress (%i/%i pts):\n  Snapping image', freqIndex, length(obj.scan_points));
                        drawnow
%                         toc

%                         tic
                        obj.data.images(:,:,freqIndex) = obj.imaging.snapImage;
                        ax.UserData.CData = obj.data.images(:,:,freqIndex);
%                         toc
                    end
                    
                    if obj.abort_request
                        break;
                    end
                end

            catch err
            end
            
            obj.setLaser(0);
            
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
        
        function setLaser(obj, scan_point)
            if scan_point ~= 0  % Intentional for ClosedDAQ overload
                obj.resLaser.TuneSetpoint(scan_point);
            end
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
