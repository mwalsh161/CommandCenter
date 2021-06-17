classdef Rabi_singleLaser < Experiments.PulseSequenceSweep.PulseSequenceSweep_invisible
    % Rabi_singleLaser Performs a rabi measurement with a MW drive, and a
    % single laser to initialize and readout

    properties(SetObservable,GetObservable,AbortSet)
        % These should be preferences you want set in default settings method
        Laser =  Prefs.ModuleInstance('help_text','PulseBlaster enabled laser');
        Laser_Time = Prefs.Double(10.,'min',0,'units','us','help_text','Time that the laser is on during readout/initialisation');
        
        APD_line = Prefs.String('APD1','help_text','NIDAQ APD Line');
        APD_Gate_line = Prefs.Integer(1,'help_text','PulseBlaster APDGate output line (1 index)','min',1);
        APD_Time = Prefs.Double(0.2, 'help_text', 'APD exposure time', 'units', 'us','min',0);
        APD_Offset = Prefs.Double(0, 'help_text', 'Delay between laser on and start of APD exposure', 'units', 'us');
        
        SignalGenerator = Prefs.ModuleInstance('help_text','Signal generator used for experiment');
        MW_freq = Prefs.Double(2.87,'units','GHz','help_text','MW frequency that the signal generator outputs');
        MW_Power = Prefs.Double(-30,'units','dBm','help_text','MW power that the signal generator outputs');
        MW_Times = Prefs.String('linspace(1,100,101)','help_text', 'List of times that MW power will be on at','set','set_MW_Times','units','us');
        MW_Pad = Prefs.Double(1,'min',0,'units','us','help_text','Time between laser off and MW on');

        detailed_plot = Prefs.Boolean(0,'help_text','Boolean whether to do detailed plot, separating out normalised signal, counts, & FFT, or simplified plot showing only normalised signal & counts on same plot')
    end
    properties
        MW_Times_vals = linspace(0,100,101); % Internal, set using MW_Times
        freqs = [] % Internal, frequencies of FFT of Rabi signal
    end
    properties(Constant)
        nCounterBins = 2; %number of APD bins for this pulse sequence
        vars = {'MW_Times_vals'}; %names of variables to be swept
    end
    methods(Static)
        obj = instance()
    end
    methods(Access=private)
        function obj = Rabi_singleLaser()
            obj.prefs = [... %additional preferences not in superclass
                {'MW_Times','MW_freq','MW_Power','Laser_Time'}...
                {'APD_Time','APD_Offset','MW_Pad'},...
                obj.prefs, {'APD_line','Laser','SignalGenerator','APD_Gate_line','detailed_plot'}...
            ];
            obj.loadPrefs;
        end
    end

    methods
        pulseSeq = BuildPulseSequence(obj,tauIndex) %Defined in separate file
        
        function PreRun(obj,~,~,ax)
            % Save laser frequency at the beginning, if this is an option
            if ismethod(obj.Laser, 'getFrequency')
                obj.meta.preFreq = obj.Laser.getFrequency;
            end
            
            % Set SignalGenerator
            obj.SignalGenerator.MWFrequency = obj.MW_freq*1e9;
            obj.SignalGenerator.MWPower = obj.MW_Power;
            obj.SignalGenerator.on;
            
            % Prepare axes for plotting
            y = NaN(1,size(obj.data.sumCounts(1,:,1),2));
            hold(ax,'on');
            
            if obj.detailed_plot
                % Plot as three subplots
                panel = ax.Parent;
                subplot(3,20,[1 21 41],ax,'Visible','off') % Dummy axis to interface with PulseSequenceSweep_invisible

                % Normalised rabi signal
                subax(1) = subplot(3,20,2:20,'parent',panel);
                plotH{1} = errorbar(obj.MW_Times_vals, y, y,'.k','parent',subax(1),'MarkerSize',15);
                plotH{4} = xline(0, 'r--','parent',subax(1));
                legend(subax(1),{'Normalized','Current MW Time'})
                ylabel(subax(1),'Rabi (normalized)');
                set(subax(1),'xlimmode','auto','ylimmode','auto','ytickmode','auto');

                % Signal showing signal/normalisation counts
                subax(2) = subplot(3,20,22:40,'parent',panel);
                hold(subax(2),'on');
                cs = lines(2);
                plotH{2} = plot(obj.MW_Times_vals, y,...
                    'color', cs(1,:),'linestyle','-','parent',subax(2));
                plotH{3} = plot(obj.MW_Times_vals, y,...
                    'color', cs(2,:),'linestyle','-','parent',subax(2));
                plotH{5} = xline(0, 'r--','parent',subax(2));
                legend(subax(2),{'Signal','Normalization'})
                ylabel(subax(2),'Sum Counts');  
                xlabel(subax(2),'\tau (\mus)');
                set(subax(2),'xlimmode','auto','ylimmode','auto','ytickmode','auto');
                hold(subax(2),'off');

                % FFT of signal
                subax(3) = subplot(3,20,42:60,'parent',panel);
                hold(subax(3),'on');
                obj.freqs = (0:length(obj.MW_Times_vals)-1)/(obj.MW_Times_vals(2)-obj.MW_Times_vals(1))/(length(obj.MW_Times_vals)-1); % Frequencies assume that MW_Times_vals are evenly spaced
                obj.freqs = obj.freqs(2:int8(length(obj.freqs)/2)); % Remove aliased negative frequencies
                plotH{6} = stem(obj.freqs,y(2:length(obj.freqs)+1),'parent',subax(3));
                ylabel(subax(3),'|FFT|');  
                xlabel(subax(3),'Frequency (MHz)');
                set(subax(3),'xlimmode','auto','ylimmode','auto','ytickmode','auto');
                hold(subax(3),'off');
                
            else
                plotH{4} = xline(0, 'r--','parent',ax);
                plotH{1} = errorbar(obj.MW_Times_vals, y, y,'-ok','parent',ax, 'MarkerFaceColor','k','MarkerSize',5);
                ylabel(ax,'Rabi (normalized)');

                yyaxis(ax, 'right')
                cs = lines(2);
                plotH{2} = plot(obj.MW_Times_vals, y,...
                    'color', cs(1,:),'linestyle','-','parent',ax);
                plotH{3} = plot(obj.MW_Times_vals, y,...
                    'color', cs(2,:),'linestyle','-','parent',ax);
                
                legend(ax,{'Current MW Time','Normalized (left)','Signal (right)','Normalization (right)'})
                ylabel(ax,'Sum Counts');
                            
                xlabel(ax,'\tau (\mus)');
                hold(ax,'off');
                set(ax,'xlimmode','auto','ylimmode','auto','ytickmode','auto');
                
            end
            hold(ax,'off');
            ax.UserData.plots = plotH;
            drawnow;
        end
        
        function UpdateRun(obj,~,~,ax,j,i)
            
            norm   = obj.data.sumCounts(:,:,1);
            signal = obj.data.sumCounts(:,:,2);
            data = signal ./ norm;
           
            ax.UserData.plots{1}.YData = nanmean(data,1);
            ax.UserData.plots{1}.YNegativeDelta = std(data,0,1,'omitnan')/sqrt(j);
            ax.UserData.plots{1}.YPositiveDelta = std(data,0,1,'omitnan')/sqrt(j);
            ax.UserData.plots{2}.YData = nanmean(signal,1);
            ax.UserData.plots{3}.YData = nanmean(norm,1);
            ax.UserData.plots{4}.Value = obj.MW_Times_vals(i);

            if obj.detailed_plot
                ax.UserData.plots{5}.Value = obj.MW_Times_vals(i);
                rabi_f = abs(fft(mean(data,1,'omitnan')-mean(data,'all','omitnan')));
                ax.UserData.plots{6}.YData = rabi_f(2:length(obj.freqs)+1);
            end

            drawnow;
        end

        function CleanUp(obj,~,~,ax)
            obj.SignalGenerator.off; % Ensure signal generator is off
            if obj.detailed_plot
                delete(ax); % Need to delete dummy axis so that CC cleans up the subplots correctly
            end
        end
        
        function abort(obj)
            % Callback for when user presses abort in CC
            obj.abort_request = true;
        end
        
        function val = set_MW_Times(obj,val,~)
            %Note that order matters here; setting tauTimes first is
            %important in case of error
            tempvals = eval(val);
            obj.MW_Times_vals = tempvals;
        end
    end
end
