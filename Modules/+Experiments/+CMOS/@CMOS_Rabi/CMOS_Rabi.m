classdef CMOS_Rabi < Experiments.PulseSequenceSweep.PulseSequenceSweep_invisible
    % CMOS_Rabi Performs a rabi measurement with a MW drive, and a
    % single laser to initialize and readout

    properties(SetObservable,AbortSet)
        % These should be preferences you want set in default settings method
        Laser = Modules.Source.empty(0,1);
        Laser_Time_us = 10;
        
        APD_line = 'APD1';
        APD_Gate_line = 1; % Indexed from 1
        APD_Time_us = 0.2;
        APD_Offset_us = 0;

        % Turn on biasing
        assert(obj.PowerSupply.power_supply_connected, 'Power supply not connected') % Do not proceed if power supply disconnected
        if ~obj.keep_bias_on
            obj.PowerSupply.on();
        end

        SignalGenerator = Modules.Source.empty(0,1);
        MW_freq_GHz = 2.87;
        MW_Power_dBm = -30;
        MW_Times_us = 'linspace(1,100,101)';
        MW_Pad_us = 1;

        % CMOS MW control properties
        ip = 'No Server';         % ip of host computer (with PB)

        % CMOS bias properties
        PowerSupply = Modules.Source.empty(0,1); % Power supply source object
        keep_bias_on = false; % Boolean whether to keep bias on in between experiments
        VDD_VCO = 1; % Number representing VCO voltage (volts)
        VDD_Driver = 1; % Double representing river voltage (volts)
        Driver_Bias_1 = 1; % Double representing driver bias 1 (volts)
        Driver_Bias_2 = 1; % Double representing driver bias 2 (volts)
        VDD_VCO_Channel = ''; % String channel for VCO; no channel if empty
        VDD_Driver_Channel = ''; % String channel for Driver voltage; no channel if empty
        Driver_Bias_1_Channel = ''; % String channel for bias 1; no channel if empty
        Driver_Bias_2_Channel = ''; % String channel for bias 2; no channel if empty
    end
    properties
        MW_Times = linspace(0,100,101); % Internal, set using MW_Times_us
    end
    properties(Constant)
        nCounterBins = 2; %number of APD bins for this pulse sequence
        vars = {'MW_Times'}; %names of variables to be swept
    end
    methods(Static)
        obj = instance()
    end
    methods(Access=private)
        function obj = CMOS_Rabi()
            obj.prefs = [... %additional preferences not in superclass
                {'MW_Times_us','MW_freq_GHz','MW_Power_dBm','Laser_Time_us'}...
                {'APD_Time_us','APD_Offset_us','MW_Pad_us'},...
                obj.prefs, {'APD_line','Laser','SignalGenerator','APD_Gate_line','PowerSupply','keep_bias_on','VDD_VCO','VDD_Driver','Driver_Bias_1','Driver_Bias_2','APD_Sync_line','VDD_VCO_Channel','VDD_Driver_Channel','Driver_Bias_1_Channel','Driver_Bias_2_Channel'}...
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
            obj.SignalGenerator.MWFrequency = obj.MW_freq_GHz*1e9;
            obj.SignalGenerator.MWPower = obj.MW_Power_dBm;
            obj.SignalGenerator.on;
            
            % Prepare axes for plotting
            y = NaN(1,size(obj.data.sumCounts(1,:,1),2));
            hold(ax,'on');
            
            plotH(1) = plot(obj.MW_Times, y,'color', 'k','parent',ax);
            ylabel(ax,'Rabi (normalized)');
            
            yyaxis(ax, 'right')
            cs = lines(2);
            plotH(2) = plot(obj.MW_Times, y,...
                'color', cs(1,:),'linestyle','-','parent',ax);
            plotH(3) = plot(obj.MW_Times, y,...
                'color', cs(2,:),'linestyle','-','parent',ax);
            legend(plotH,{'Normalized (left)','Signal (right)','Normalization (right)'})
            ylabel(ax,'Sum Counts');
            
            ax.UserData.plots = plotH;
            
            xlabel(ax,'\tau (\mus)');
            hold(ax,'off');
            set(ax,'xlimmode','auto','ylimmode','auto','ytickmode','auto');
            drawnow;
        end
        
        function postRun(obj,~,~,~)
            % Turn off biasing
            if ~obj.keep_bias_on
                obj.PowerSupply.off();
            end
        end

        function UpdateRun(obj,~,~,ax,~,~)
            if obj.averages > 1
                averagedData = squeeze(nanmean(obj.data.sumCounts,1));
            else
                averagedData = squeeze(obj.data.sumCounts);
            end
            
            norm   = averagedData(:, 1);
            signal = averagedData(:, 2);
            data = 2 * signal ./ (signal + norm);
           
            ax.UserData.plots(1).YData = data;
            ax.UserData.plots(2).YData = signal;
            ax.UserData.plots(3).YData = norm;

            drawnow;
        end
        
        function abort(obj)
            % Callback for when user presses abort in CC
            obj.abort_request = true;
        end
        
        function set.MW_Times_us(obj,val)
            %Note that order matters here; setting tauTimes first is
            %important in case of error
            tempvals = eval(val);
            obj.MW_Times = tempvals;
            obj.MW_Times_us = val;
        end

        function set.PowerSupply(obj,val)
            val.Channel = val.ChannelNames(1); % Ensure that channel is set
            obj.PowerSupply = val;
        end
    
        function set.keep_bias_on(obj,val)
            % Turn on/off power supply on changing keep_bias_on
            if val
                obj.PowerSupply.on();
            else
                obj.PowerSupply.off();
            end
            obj.keep_bias_on = val;
        end
    
        function set.VDD_VCO(obj,val)
            if ~isempty(obj.PowerSupply.Channel) % if channel is set
                % Change power supply settings when changing bias voltage
                obj.PowerSupply.Channel = obj.VDD_VCO_Channel;
                obj.PowerSupply.Voltage = val;
                obj.PowerSupply.Source_Mode = 'Voltage';
            end
            obj.VDD_VCO = val;
        end
    
        function set.VDD_CTRL(obj,val)
            obj.volt_list = str2num(val);
            obj.VDD_CTRL = val;
        end
    
        function set.VDD_CTRL_voltage(obj,val)
            if ~isempty(obj.PowerSupply.Channel) % if channel is set
                % Change power supply settings when changing bias voltage
                obj.PowerSupply.Channel = obj.VDD_CTRL_Channel;
                obj.PowerSupply.Voltage = val;
                obj.PowerSupply.Source_Mode = 'Voltage';
            end
            obj.VDD_CTRL_voltage = val;
        end
        
        function set.VDD_IND(obj,val)
            if ~isempty(obj.PowerSupply.Channel)
                obj.PowerSupply.Channel = obj.VDD_IND_Channel;
                obj.PowerSupply.Voltage = val;
                obj.PowerSupply.Source_Mode = 'Voltage';
            end
            obj.VDD_IND = val;
        end
    
        function set.IND_BIAS (obj,val)
            if ~isempty(obj.PowerSupply.Channel)
                obj.PowerSupply.Channel = obj.IND_BIAS_Channel;
                obj.PowerSupply.Voltage = val;
                obj.PowerSupply.Source_Mode = 'Voltage';
            end
            obj.IND_BIAS = val;
        end
    
        function set.VDD_VCO_Channel(obj,val)
            % Check that channel exists and is different from other channels before changing
            if ~isempty(val) && ~isempty(obj.PowerSupply) % Just set if channel/PowerSupply is not empty
                assert(~strcmp(val,obj.VDD_CTRL_Channel) && ~strcmp(val,obj.VDD_IND_Channel) && ~strcmp(val,obj.IND_BIAS_Channel), 'Channel already assigned')
                obj.PowerSupply.checkChannel(val)
                % Get power supply voltage
                voltage = obj.PowerSupply.Voltages( obj.PowerSupply.getHWIndex(val));
                obj.VDD_VCO = voltage;
            end
            obj.VDD_VCO_Channel = val;
        end
    
        function set.VDD_CTRL_Channel(obj,val)
            if ~isempty(val) && ~isempty(obj.PowerSupply)
                assert(~strcmp(val,obj.VDD_VCO_Channel) && ~strcmp(val,obj.VDD_IND_Channel) && ~strcmp(val,obj.IND_BIAS_Channel), 'Channel already assigned')
                obj.PowerSupply.checkChannel(val)
                voltage = obj.PowerSupply.Voltages( obj.PowerSupply.getHWIndex(val));
                obj.VDD_CTRL_voltage = voltage;
            end
            obj.VDD_CTRL_Channel = val;
        end
    
        function set.VDD_IND_Channel(obj,val)
            if ~isempty(val) && ~isempty(obj.PowerSupply)
                assert(~strcmp(val,obj.VDD_VCO_Channel) && ~strcmp(val,obj.VDD_CTRL_Channel) && ~strcmp(val,obj.IND_BIAS_Channel), 'Channel already assigned')
                obj.PowerSupply.checkChannel(val)
                voltage = obj.PowerSupply.Voltages( obj.PowerSupply.getHWIndex(val));
                obj.VDD_IND = voltage;
            end
            obj.VDD_IND_Channel = val;
        end
        
        function set.IND_BIAS_Channel(obj,val)
            if ~isempty(val) && ~isempty(obj.PowerSupply)
                assert(~strcmp(val,obj.VDD_VCO_Channel) && ~strcmp(val,obj.VDD_CTRL_Channel) && ~strcmp(val,obj.VDD_IND_Channel), 'Channel already assigned')
                obj.PowerSupply.checkChannel(val)
                voltage = obj.PowerSupply.Voltages( obj.PowerSupply.getHWIndex(val));
                obj.IND_BIAS = voltage;
            end
            obj.IND_BIAS_Channel = val;
        end
    end
end
