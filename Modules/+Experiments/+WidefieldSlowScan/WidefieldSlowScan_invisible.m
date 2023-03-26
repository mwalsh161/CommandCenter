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
        wl = Modules.Source.empty(1,0);
        
        wavemeter_override = false;
        wavemeter_channel = 6;
        
        repump_always_on = Prefs.Boolean(false);
        
        only_get_freq = Prefs.Boolean(false);
        save_freq_before = Prefs.Boolean(false);
        save_freq_after = Prefs.Boolean(true);
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
            obj.prefs = [obj.prefs, ...
                {'resLaser', 'repumpLaser', 'wl', 'imaging', 'repump_always_on', 'wavemeter_override', 'wavemeter_channel', ...
                'save_freq_before', 'save_freq_after', 'only_get_freq'}]; %additional preferences not in superclass
        end
        
        function run( obj,status,managers,ax)
            % Main run method (callback for CC run button)
            obj.abort_request = false;
            status.String = 'Experiment started';
            drawnow;
            
            hw = [];
            if obj.wavemeter_override
                hw = hwserver('qplab-hwserver.mit.edu');
            end
            
            last_freq = NaN;

            try
                obj.PreRun(status,managers,ax);
                if obj.wavemeter_override
                    hw.com('wavemeter', 'SetSwitcherSignalStates', obj.wavemeter_channel, 1, 1);
                end
                
                for freqIndex = 1:length(obj.scan_points)
%                     'frame'
%                     tic
                    obj.data.experiment_time(freqIndex) = now;
            
                    status.String = sprintf('Progress (%i/%i pts):\n  Setting laser', freqIndex, length(obj.scan_points));
%                     toc
                    
                    if ~obj.only_get_freq
                        drawnow
                        if ~obj.repump_always_on
                            obj.repumpLaser.on
                        end
                    end
                    
                    try
                        if obj.abort_request
                            break;
                        end
                    
                        obj.setLaser(obj.scan_points(freqIndex));
                        obj.data.freqs_time(freqIndex) = toc;
                        
                        if obj.save_freq_before
                            if obj.wavemeter_override
                                obj.data.freqs_measured(freqIndex) = hw.com('wavemeter', 'GetWavelengthNum', obj.wavemeter_channel, 0);
                            else
                                obj.data.freqs_measured(freqIndex) = obj.resLaser.getFrequency();
                            end
                            
                            last_freq = obj.data.freqs_measured(freqIndex);
                        end
                        
                        if obj.abort_request
                            break;
                        end

                        if obj.only_get_freq
                            status.String = sprintf('Progress (%i/%i pts):\n  Laser set %f (laser at %f)', freqIndex, length(obj.scan_points), obj.scan_points(freqIndex), last_freq);
                            drawnow
                        else
                            if ~obj.repump_always_on
                                obj.repumpLaser.off
                            end

                            if ~isnan(last_freq)
                                status.String = sprintf('Progress (%i/%i pts):\n  Snapping image (laser at %f)', freqIndex, length(obj.scan_points), last_freq);
                            else
                                status.String = sprintf('Progress (%i/%i pts):\n  Snapping image', freqIndex, length(obj.scan_points));
                            end
                            drawnow
                            
                            %%cropping image
                            rawImage = obj.imaging.snapImage;
%                             croppedImaged = rawImage(200:600,250:550);
%                             croppedImaged = rawImage(300:700,300:600);
                            obj.data.images(:,:,freqIndex) = rawImage;
%                             obj.data.images(:,:,freqIndex) = obj.imaging.snapImage;
                            ax.UserData.CData = obj.data.images(:,:,freqIndex);
                        end
                    
                        if obj.save_freq_after
                            if obj.wavemeter_override
                                obj.data.freqs_measured_after(freqIndex) = hw.com('wavemeter', 'GetWavelengthNum', obj.wavemeter_channel, 0);
                            else
                                obj.data.freqs_measured_after(freqIndex) = obj.resLaser.getFrequency();
                            end
                            
                            last_freq = obj.data.freqs_measured_after(freqIndex);
                        end
                    catch err
                        warning(err.message)
                    end
                    
                    if obj.abort_request
                        break;
                    end
                end

            catch err
                warning(err.message)
            end
            
            if obj.wavemeter_override
                hw.com('wavemeter', 'SetSwitcherSignalStates', obj.wavemeter_channel, 0, 0);
            end
            
            obj.PostRun();
            
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
                tries = 3;
                while tries > 0
                    try
                        obj.resLaser.TuneSetpoint(scan_point);
                        break;
                    catch
                        warning(['Laser failed to tune to ' num2str(scan_point) ' THz.'])
                    end
                    tries = tries - 1;
                end
                if tries == 0
                    error(['Laser failed thrice to tune to ' num2str(scan_point) ' THz. Stopping run.'])
                end
            end
        end
        
        function PreRun(obj,~,managers,ax)
%             w = obj.imaging.width;
%             h = obj.imaging.height;
%             
            img = obj.imaging.snapImage;
            
            w = size(img, 1);
            h = size(img, 2);
            
            % hack for viewing 7/30/22
%             w = 401;
%             h = 301;
            
            ax.UserData = imagesc(ax, 1:w, 1:h, NaN(h, w));
            set(ax,'DataAspectRatio',[1 1 1])
            
            xlabel(ax, '$x$ [pix]', 'interpreter', 'latex');
            ylabel(ax, '$y$ [pix]', 'interpreter', 'latex');
%             freqPk = [406.69, 406.699,406.701, 406.708,406.71, 406.712, 406.713, 406.714,  406.721,406.729, 406.732, 406.733, 406.748,406.751, 406.793];
%             freqPk = [406.707, 406.7095];%,406.7125, 406.717,406.7223];
%             obj.scan_points = [];
%             for i = 1:2
%                 for k = 1:size(freqPk,2)
%                 for j = 1:3
%                     obj.scan_points = [obj.scan_points, freqPk(k)];
%                 end
%                 end
%             end
            
            if ~obj.only_get_freq
                obj.data.images = zeros([w, h, length(obj.scan_points)], 'int16');
            end

            obj.meta.prefs = obj.prefs2struct;
            for i = 1:length(obj.vars)
                obj.meta.vars(i).name = obj.vars{i};
                obj.meta.vars(i).vals = obj.(obj.vars{i});
            end
            obj.data.repumpPower = obj.repumpLaser.power;
            obj.meta.exposure = obj.imaging.exposure;
            obj.meta.position = managers.Stages.position; % Stage position
            
            obj.data.scan_points = obj.scan_points;
            
            obj.data.freqs_measured = NaN(1, length(obj.scan_points));
            obj.data.freqs_measured_after = NaN(1, length(obj.scan_points));
            obj.data.freqs_time = NaN(1, length(obj.scan_points));
            
            obj.data.experiment_time = NaN(1, length(obj.scan_points));
            
%             pm = Drivers.PM100.instance();
%             wheel = Drivers.ArduinoServo.instance('localhost', 2);
            
%             obj.meta.resAngle = wheel.angle;
            
            obj.resLaser.on
            obj.repumpLaser.off
            
%             obj.setLaser(0);
%             pause(1)
%             obj.data.freq_center = obj.resLaser.getFrequency();
% %             [obj.data.resPowerCenter, obj.data.resPowerStdCenter] =    pm.get_power('units', 'mW', 'samples', 10);
%             
%             obj.setLaser(obj.scan_points(1));
%             pause(1)
%             [obj.data.resPowerStart, obj.data.resPowerStdStart] =      pm.get_power('units', 'mW', 'samples', 10);
            
            obj.data.resPowerAfter = NaN;
            obj.data.resPowerStdAfter = NaN;
            
            obj.repumpLaser.on
        end
        
        function PostRun(obj)
            obj.repumpLaser.off
            
%             pm = Drivers.PM100.instance();
            
            pause(.25)
%             [obj.data.resPowerAfter, obj.data.resPowerStdAfter] =   pm.get_power('units', 'mW', 'samples', 10);
            
%             obj.setLaser(0);
            obj.resLaser.off
        end
    end
end
