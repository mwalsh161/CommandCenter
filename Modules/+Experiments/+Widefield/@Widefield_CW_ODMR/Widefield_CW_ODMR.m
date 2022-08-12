classdef Widefield_CW_ODMR < Experiments.Widefield.Widefield_invisible
%CW_ODMR Description of experiment
    % Useful to list any dependencies here too

    properties(GetObservable,SetObservable,AbortSet)
        Exposure = Prefs.Double(100, 'min', 0, 'help_text', 'Camera exposure to use during experiment', 'units', 'ms');
        SignalGenerator = Prefs.ModuleInstance('help_text','Signal generator used to produce ODMR MW frequency');
        MW_freqs_GHz = Prefs.String('linspace(2.85,2.91,101)', 'help_text','List of MW frequencies to be used in ODMR experiment specified as a Matlab evaluatable string', 'units','GHz', 'set','set_MW_freqs_GHz');
        MW_Power = Prefs.Double(-30, 'help_text', 'Signal generator MW power', 'units', 'dBm');
        MW_freq_norm = Prefs.Double(2, 'help_text', 'Frequency used to normalise fluorescence. Should be far off resonance. If set to <=0, MW will be turned off for normalisation period', 'units', 'GHz');

    end
    properties(SetAccess=private,Hidden)
        % Internal properties that should not be accessible by command line
        freq_list = linspace(2.85,2.91,101)*1e9; % Internal, set using MW_freqs
    end

    methods(Static)
        % Static instance method is how to call this experiment
        % This is a separate file
        obj = instance()

        function [plotH, ax_data] = setup_plotting(panel, freq_list, varargin)
            % Setup display of plotting
            % [plotH, ax_data] = setup_plotting(panel, ax_im, freq_list)
            % [plotH, ax_data] = setup_plotting(panel, ax_im, freq_list, pixel_x, pixel_y)
            % ======
            % Inputs
            % ======
            % panel: panel for plot
            % freq_list: list of frequencies used for the CW ODMR
            % pixel_x, pixel_y: x and y coordinates of pixels of interest
            % =======
            % Outputs
            % =======
            % ax_data: ax for data
            % plotH: plot objects

            if nargin>2
                pixel_x = varargin{1};
                pixel_y = varargin{2};
                n_pixels_of_interest = numel(pixel_x);
            else
                n_pixels_of_interest = 0;
            end

            % Given a panel and frequencies, set up plots of ODMR
            n = numel(freq_list);
            y = NaN(1,n);
            ax_data = subplot(1,2,2,'parent',panel);
            hold(ax_data,'on');
            plotH(1) = errorbar(freq_list/1e9, y, y, '.k', 'MarkerSize', 15, 'parent',ax_data);
            ylabel(ax_data,'ODMR (normalized)');
            yyaxis(ax_data, 'right')
            plotH(2) = plot(freq_list/1e9, y,...
                'color', 'k','linestyle','--','parent',ax_data);
            plotH(3) = plot(freq_list/1e9, y,...
                'color', 'k','linestyle',':','parent',ax_data);
            legend([plotH(1), plotH(2), plotH(3)],{'Normalized (left)','Signal (right)','Normalization (right)'}, 'AutoUpdate','off');
            ylabel(ax_data,'Counts (cps)');
            xlabel(ax_data,'Frequency (GHz)');
            yyaxis(ax_data, 'left');
            
            % Plot points of interest
            cs = lines(n_pixels_of_interest);
            for i = 1:n_pixels_of_interest
                hold(ax_data, 'on')
                plotH(1+3*i) = plot(freq_list/1e9, y, '-', 'Linewidth', 3, 'color',cs(i,:), 'parent',ax_data);
                yyaxis(ax_data, 'right');
                plotH(2+3*i) = plot(freq_list/1e9, y,':', 'color',cs(i,:), 'parent',ax_data);
                plotH(3+3*i) = plot(freq_list/1e9,y,'--', 'color',cs(i,:), 'parent',ax_data);
                yyaxis(ax_data, 'left');
            end
            hold(ax_data, 'off')
        end

        function update_graphics(ax_im, plotH, data, im, varargin)
            % Plot data
            % update_graphics(ax_im, plotH, data, im)
            % update_graphics(ax_im, plotH, data, im, pixels_of_interest)
            % ======
            % Inputs
            % ======
            % ax_im: ax for widefield image
            % plotH: plot objects
            % data: data to plot
            % im: image to use
            % pixels_of_interest: data from pixels of interest

            if nargin>4
                pixels_of_interest = varargin{1};
                n_pixels_of_interest = size(pixels_of_interest, 3);
            else
                n_pixels_of_interest = 0;
            end
                
            
            % Intensity-weighted average of odmr signal
            norm = squeeze( data(:,:,1,:,:) );
            signal = squeeze( data(:,:,2,:,:) );
            odmr = signal ./ norm;
            odmr = sum( norm .* odmr, [3 4], 'omitnan' ) ./ sum( norm, [3 4], 'omitnan');
            odmr_err = squeeze( std( odmr, [], 1, 'omitnan') );
            odmr = squeeze( mean( odmr, 1, 'omitnan') );
            norm   = squeeze(mean( data(:,:,1,:,:), [1 4 5], 'omitnan'));
            signal = squeeze(mean( data(:,:,2,:,:), [1 4 5], 'omitnan'));
            
            plotH(1).YData = odmr;
            plotH(1).YPositiveDelta = odmr_err;
            plotH(1).YNegativeDelta = odmr_err;
            plotH(2).YData = signal;
            plotH(3).YData = norm;
            
            for k = 1:n_pixels_of_interest
                plotH(1+3*k).YData = squeeze(mean( pixels_of_interest(:,:,k,2) ./ pixels_of_interest(:,:,k,1), 1, 'omitnan'));
                plotH(2+3*k).YData = squeeze(mean( pixels_of_interest(:,:,k,2), 1, 'omitnan'));
                plotH(3+3*k).YData = squeeze(mean( pixels_of_interest(:,:,k,1), 1, 'omitnan'));
            end
            
            % Update image
            set(ax_im.Children(end), 'CData', im);
        end
    end
    methods(Access=private)
        function obj = Widefield_CW_ODMR()
            % Constructor (should not be accessible to command line!)
            obj.prefs = [{'MW_freqs_GHz','MW_freq_norm','MW_Power','Exposure'}, obj.prefs, {'SignalGenerator'}];
            obj.loadPrefs('-update'); % Load prefs specified as obj.prefs; don't load update ROI to avoid calling ROI update method
        end
    end

    methods
        run(obj,status,managers,ax) % Main run method in separate file

        function abort(obj)
            % Callback for when user presses abort in CC
            obj.abort_request = true;
        end

        function dat = GetData(obj,~,~)
            % Callback for saving methods
            dat.data = obj.data;
            dat.meta = obj.meta;
        end

        % Set methods allow validating property/pref set values
        function val = set_MW_freqs_GHz(obj,val,~)
            obj.freq_list = str2num(val)*1e9;
        end
    end
end