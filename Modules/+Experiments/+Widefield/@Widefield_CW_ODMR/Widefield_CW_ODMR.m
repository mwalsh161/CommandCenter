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

        function [plotH, ax_data, ax_intensity] = setup_plotting(panel, freq_list, n_pix)
            % Given a panel and frequencies, set up plots of ODMR
            n = numel(freq_list);
            y = NaN(1,n);
            ax_data = subplot(1,2,2,'parent',panel);
            hold(ax_data,'on');
            plotH(1) = plot(freq_list/1e9, y, 'Linewidth', 3, 'color', 'k','parent',ax_data);
            current_freqH = plot(ax_data,NaN,NaN,'--r');
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
            for i = 1:n_pixels_of_interest
                plotH(1+3*i) = plot(freq_list/1e9, y, '-', 'Linewidth', 3, 'color',cs(i,:), 'parent',ax_data);
                yyaxis(ax_data, 'right');
                plotH(2+3*i) = plot(freq_list/1e9, y,':', 'color',cs(i,:), 'parent',ax_data);
                plotH(3+3*i) = plot(freq_list/1e9,y,'--', 'color',cs(i,:), 'parent',ax_data);
                yyaxis(ax_data, 'left');
                plot(pixel_x(i), pixel_y(i), 'o', 'color', cs(i,:), 'parent', ax_im)
            end
        end

        function update_graphics(ax_im, plotH, data, pixels_of_interest, im)

            averagedData = squeeze(nanmean(obj.data,1));
            norm   = squeeze(averagedData(:, 1,:,:));
            signal = squeeze(averagedData(:, 2,:,:));
            data = 2 * signal ./ (signal + norm);
            plotH(1).YData = nanmean(data, [2 3]);
            plotH(2).YData = nanmean(signal, [2 3]);
            plotH(3).YData = nanmean(norm, [2 3]);
            for k = 1:n_pixels_of_interest
                plotH(1+3*k).YData = data(:, obj.pixel_x(k), obj.pixel_y(k));
                plotH(2+3*k).YData = signal(:, obj.pixel_x(k), obj.pixel_y(k));
                plotH(3+3*k).YData = norm(:, obj.pixel_x(k), obj.pixel_y(k));
            end
        end
    end
    methods(Access=private)
        function obj = Widefield_CW_ODMR()
            % Constructor (should not be accessible to command line!)
            obj.prefs = [{'MW_freqs_GHz','MW_freq_norm','MW_Power','Exposure'}, obj.prefs, {'SignalGenerator'}]
            obj.loadPrefs; % Load prefs specified as obj.prefs
        end
    end

    methods
        run(obj,status,managers,ax) % Main run method in separate file

        function abort(obj)
            % Callback for when user presses abort in CC
            obj.abort_request = true;
        end

        function dat = GetData(obj,stageManager,imagingManager)
            % Callback for saving methods
            dat.data = obj.data;
            dat.meta = obj.meta;
        end

        % Set methods allow validating property/pref set values
        function val = set_MW_freqs_GHz(obj,val,pref)
            obj.freq_list = str2num(val)*1e9;
        end
    end
end