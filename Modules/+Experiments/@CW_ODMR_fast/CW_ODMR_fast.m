classdef CW_ODMR_fast < Modules.Experiment
    %CW_ODMR_fast CW ODMR experiment that uses signal generator frequency sweep functionality to do CW ODMR faster
    % Useful to list any dependencies here too

    properties(SetObservable,GetObservable,AbortSet)
        Laser = Prefs.ModuleInstance('help_text','PulseBlaster enabled laser');

        APD_line = Prefs.String('APD1','help_text','NIDAQ APD Line');
        APD_Sync_line = Prefs.String('CounterSync','help_text','NIDAQ CounterSync Line');
        APD_Gate_line = Prefs.Integer(1,'help_text','PulseBlaster APDGate output line (1 index)','min',1);
        SG_Trigger_line = Prefs.Integer(2,'help_text','PulseBlaster signal generator trigger output line (1 index)','min',1);


        Trig_Time = Prefs.Double(1, 'help_text', 'Time that the trigger is on', 'units', 'ms','min',0);
        APD_Delay = Prefs.Double(1, 'help_text', 'Delay after trigger is turned off after which the APD gate is turned on', 'units', 'ms','min',0);
        Exposure = Prefs.Double(100, 'help_text', 'APD exposure time', 'units', 'ms','min',0);

        SignalGenerator = Prefs.ModuleInstance('help_text','Signal generator that has a frequency sweep function with each step triggered externally');
        %norm_freq = Prefs.Double(2000, 'help_text', 'Normalisation frequency. If not positive, will turn off during normalisation instead.', 'units', 'MHz');
        sweep_start_freq = Prefs.Double(2800, 'help_text', 'Sweep start frequency', 'units', 'MHz','min',0);
        sweep_end_freq = Prefs.Double(2900, 'help_text', 'Sweep end frequency', 'units', 'MHz','min',0);
        sweep_Npts = Prefs.Double(100, 'help_text', 'Number of points in sweep');
        MW_Power = Prefs.Double(-30, 'help_text', 'MW power', 'units', 'dBm');
        %MW_freq_norm_GHz = 2; % If set to -1, will turn off

        averages = Prefs.Integer(1,'min',1,'help_text','Number of times to perform entire sweep');
        pb_IP = Prefs.String('None Set','set','set_pb_IP','help_text','Hostname for computer running pulseblaster server');
        NIDAQ_dev = Prefs.String('None Set','set','set_NIDAQ_dev','help_text','Device name for NIDAQ (found/set in NI-MAX)');
    end
    properties
        freq_list = []; % Internal list of frequencies calculated from sweep_start_freq, sweep_end_freq, & sweep_Npts (MHz)
        prefs = {'sweep_start_freq','sweep_end_freq','sweep_Npts','averages','MW_Power','Exposure','APD_Delay','Trig_Time','Laser','SignalGenerator','APD_line','APD_Sync_line','SG_Trigger_line','APD_Gate_line','pb_IP','NIDAQ_dev'}
    end

    methods(Static)
        % Static instance method is how to call this experiment
        % This is a separate file
        obj = instance()
    end
    methods(Access=private)
        function obj = CW_ODMR_fast()
            % Constructor (should not be accessible to command line!)
            obj.path = 'APD1';
            obj.loadPrefs()
        end
    end
    properties(SetAccess=protected,Hidden)
        data = [] % subclasses should not set this; it can be manipulated in GetData if necessary
        meta = [] % Store experimental settings
        abort_request = false; % Flag that will be set to true upon abort. Used in run method.
        pbH;    % Handle to pulseblaster
        nidaqH; % Handle to NIDAQ
    end

    methods
        function s = BuildPulseSequence(obj)
            %BuildPulseSequence Builds pulse sequence for signal generator trig followed by APD with laser on the entire time
            s = sequence('CW_ODMR_Triggered'); % Calling HelperFunction

            laserChannel = channel('Laser','color','g','hardware',obj.Laser.PBline-1);
            triggerChannel = channel('Trigger','color','r','hardware',obj.SG_Trigger_line-1);
            APDchannel = channel('APDgate','color','k','hardware',obj.APD_Gate_line-1,'counter','APD1');
            s.channelOrder = [laserChannel, triggerChannel, APDchannel];
            
            g = node(s.StartNode,laserChannel,'units','us','delta',0); % Green on throughout
            a = node(g,APDchannel,'units','ms','delta',obj.APD_Delay); % APD comes on at after APD Delay
            a = node(a,APDchannel,'units','ms','delta',obj.Exposure); % APD turns off after exposure
            t = node(a,triggerChannel,'units','ms','delta',0); % Trigger for next frequency
            t = node(t,triggerChannel,'units','ms','delta',obj.Trig_Time); % Trigger turns off
            node(a,laserChannel,'delta',0);

        end
        run(obj,status,managers,ax) % Main run method in separate file
        
        function abort(obj)
            % Callback for when user presses abort in CC
            obj.abort_request = true;
        end
        
        function dat = GetData(obj,~,~)
            % Callback for saving methods (note, lots more info in the two managers input!)
            dat.data = obj.data;
            dat.meta = obj.meta;
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
        function val = set_NIDAQ_dev(obj,val,~)
            if strcmp(val,'None Set') % Short circuit
                obj.nidaqH = [];
            end
            try
                obj.nidaqH = Drivers.NIDAQ.dev.instance(val);
            catch err
                obj.nidaqH = [];
                obj.NIDAQ_dev = 'None Set';
                rethrow(err);
            end
        end

    end
end
