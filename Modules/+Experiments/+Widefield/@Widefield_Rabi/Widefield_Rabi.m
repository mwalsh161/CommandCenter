classdef Widefield_Rabi < Experiments.Widefield.Widefield_invisible
    %Widefield_Rabi Performs widefield Rabi experiment using a triggered camera

    properties(GetObservable,SetObservable,AbortSet)
        SignalGenerator = Prefs.ModuleInstance('help_text','Signal generator used to produce ODMR MW frequency');
        MW_freq = Prefs.Double(2870, 'help_text','MW frequency used for Rabi experiment', 'units','MHz');
        MW_Power = Prefs.Double(-30, 'help_text', 'Signal generator MW power', 'units', 'dBm');

        Laser_Time = Prefs.Double(10.,'min',0,'units','us','help_text','Time that the laser is on during readout/initialisation');
        MW_Times = Prefs.String('linspace(1,100,101)','help_text', 'List of times that MW power will be on at','set','set_MW_Times','units','us');
        MW_Pad = Prefs.Double(1,'min',0,'units','us','help_text','Time between laser off and MW on');

        Cam_Trig_Line = Prefs.Integer(1,'help_text','PulseBlaster output line (1 index) for camera trigger','min',1);

        samples = Prefs.Integer(1000,'min',1,'help_text','Number of samples at each point in sweep');
        normalisation = Prefs.Boolean(true,'help_text','Whether to include a normalisation round exposing camera to identical number of AOM pulses')
        pb_IP = Prefs.String('None Set','set','set_pb_IP','help_text','Hostname for computer running pulseblaster server');
    end
    properties
        MW_Times_vals = linspace(0,100,101); % Internal, set using MW_Times
        camera_trig_delay = 10; % us, Internal delay between start of PB sequence and camera trigger
        camera_trig_time = 10; % us, Time camera trigger is on
    end
    properties(SetAccess=protected,Hidden)
        % Internal properties that should not be accessible by command line
        pbH;    % Handle to pulseblaster
    end
    methods(Static)
        % Static instance method is how to call this experiment
        % This is a separate file
        obj = instance()
        
        function [plotH, ax_rabi, ax_intensity] = setup_plotting(panel, times, n_pix)
            % Given a panel and microwave times, set up plots of Rabi

            n_MW_times = numel(times);
            y = NaN(1, n_MW_times);

            % Plot rabi for weighted average and pixels of interest
            ax_rabi = subplot(2,2,2, 'parent', panel);
            hold(ax_rabi, 'on');
            for i = 1:n_pix
                plotH{1,i} = errorbar(times, y, y, '.', 'parent', ax_rabi, 'MarkerSize', 10);
            end
            plotH{1,n_pix+1}  = errorbar(times, y, y, '.k', 'parent', ax_rabi, 'MarkerSize', 15);
            ylabel(ax_rabi, 'Rabi (normalized)')
            hold(ax_rabi, 'off');
        
            % Plot counts of normalisation & signal
            ax_intensity = subplot(2,2,4, 'parent', panel);
            hold(ax_intensity,'on')
            yyaxis(ax_intensity, 'right')
            ylabel(ax_intensity, 'Pixel of Interest (arb.)')
            
            cs = lines(n_pix);
            for i = 1:n_pix
                plotH{2,i} = plot(times, y, 'parent', ax_intensity, 'Color', cs(i,:));
                plotH{3,i} = plot(times, y, '--', 'parent', ax_intensity, 'Color', cs(i,:));
            end
        
            yyaxis(ax_intensity, 'left')
            ylabel(ax_intensity, 'Weighted Average (arb.)')
        
            plotH{2,n_pix+1}  = plot(times, y, 'k', 'parent', ax_intensity, 'LineWidth', 2);
            plotH{3,n_pix+1}  = plot(times, y, '--k', 'parent', ax_intensity, 'LineWidth', 2);
        
            xlabel(ax_intensity, 'MW Time (\mu s)')
            hold(ax_intensity,'off')
        end

        
        function update_graphics(ax_im, plotH, data, pixels_of_interest, im)
            
            % Calculate Rabi for ROI
            intensity = squeeze(data(:,:,:,:,2));

            rabi = squeeze( data(:,:,:,:,1) ./ data(:,:,:,:,2) );
            rabi = sum( intensity .* rabi, [3 4], 'omitnan') ./ sum(intensity, [3 4], 'omitnan');
            rabi_err = squeeze( std( rabi, [], 1, 'omitnan') );
            rabi = squeeze( mean( rabi, 1, 'omitnan' ) );

            % Calculate Rabi for pixels of interest
            rabi_pix = pixels_of_interest(:,:,:,1) ./ pixels_of_interest(:,:,:,2);
            rabi_pix_err = squeeze( std( rabi_pix, [], 1, 'omitnan') );
            rabi_pix = squeeze( mean( rabi_pix, 1, 'omitnan' ) );

            n_pix = size(pixels_of_interest);
            n_pix = n_pix(3);

            % Update image
            set(ax_im.Children(end), 'CData', im);
            for i = 1:n_pix
                % Update Rabi plot
                plotH{1,i}.YData = rabi_pix(:,i);
                plotH{1,i}.YPositiveDelta = rabi_pix_err(:,i);
                plotH{1,i}.YNegativeDelta = rabi_pix_err(:,i);

                % Update intensity plot
                plotH{2,i}.YData = squeeze(mean(pixels_of_interest(:,:,i,1),1,'omitnan'));
                plotH{3,i}.YData = squeeze(mean(pixels_of_interest(:,:,i,2),1,'omitnan'));
            end

            % Update average Rabi plot
            plotH{1,n_pix+1}.YData = rabi;
            plotH{1,n_pix+1}.YPositiveDelta = rabi_err;
            plotH{1,n_pix+1}.YNegativeDelta = rabi_err;

            % Update average intensity plot
            plotH{2,n_pix+1}.YData = squeeze(mean(data(:,:,:,:,1),[1,3,4],'omitnan'));
            plotH{3,n_pix+1}.YData = squeeze(mean(data(:,:,:,:,2),[1,3,4],'omitnan'));
        end
    end
    methods(Access=private)
        function obj = Widefield_Rabi()
            obj.prefs = [{'MW_Times','MW_freq','MW_Power','Laser_Time','MW_Pad', 'samples', 'normalisation'}, obj.prefs, {'Cam_Trig_Line','SignalGenerator','pb_IP'}];
            obj.loadPrefs; % Load prefs specified as obj.prefs
        end
    end

    methods
        run(obj,status,managers,ax) % Main run method in separate file

        pulseSeq = BuildPulseSequence(obj,MW_Time_us,normalisation) %Defined in separate file

        function abort(obj)
            % Callback for when user presses abort in CC
            obj.abort_request = true;
        end

        function dat = GetData(obj,stageManager,~)
            % Callback for saving methods
            meta = stageManager.position;
            dat.data = obj.data;
            dat.meta = obj.meta;
        end

        function val = set_MW_Times(obj,val,~)
            %Note that order matters here; setting tauTimes first is
            %important in case of error
            tempvals = eval(val);
            obj.MW_Times_vals = tempvals;
        end

        function val = set_pb_IP(obj,val,~)
            if strcmp(val,'None Set') % Short circuit
                obj.pbH = [];
            end
            try
                obj.pbH = Drivers.PulseBlaster.Remote.instance(val);
            catch err
                obj.pbH = [];
                obj.pb_IP = 'None Set';
                rethrow(err);
            end
        end
    end
end
