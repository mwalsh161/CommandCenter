function AWG = awgChirp()
    %UltraFastScan
    
%     properties
%         prefs = {'averages','samples','pb_IP','NIDAQ_dev', 'repumpLaser','resLaser', 'APDline','freq_start', 'freq_end', 'points','repump_type'};
%     end
%     properties(SetObservable,GetObservable)
%         averages =  Prefs.Integer(1,'min',1, ...
%                         'help_text','Number of times to perform entire sweep');
%         samples =   Prefs.Integer(1000,'min',1, ...
%                         'help_text','Number of samples per run. Setting this to be low will incur more overhead. Setting high will reduce feedback.');
%         pb_IP =     Prefs.String('None Set','set','set_pb_IP', ...
%                         'help_text','Hostname for computer running pulseblaster server');
%         NIDAQ_dev = Prefs.String('None Set','set','set_NIDAQ_dev', ...
%                         'help_text','Device name for NIDAQ (found/set in NI-MAX)');
%         
%         repumpLaser = Modules.Source.empty(1,0);
%         resLaser = Modules.Source.empty(1,0); % Allow selection of sektrource
%         APDline = Prefs.Integer(1,'min',1);
%         
%         freq_start =    Prefs.Double(2, 'units', 'GHz', 'help_text', 'Sweep start frequenecy. Used in linspace(s,e,p).');
%         freq_end =      Prefs.Double(4, 'units', 'GHz', 'help_text', 'Sweep start frequenecy. Used in linspace(s,e,p).');
%         points =        Prefs.Integer(1,'min',1,        'help_text', 'Number of points per frequency sweep. Used in linspace(s,e,p).');
%         
%         repumpTime =    Prefs.Double(1, 'units', 'us',  'help_text', 'Length of time to turn the repump laser on');
%         paddingTime =   Prefs.Double(1, 'units', 'us',  'help_text', 'Length of time inbetween laser pulses');
%         resTime =       Prefs.Double(10, 'units', 'us', 'help_text', 'Length of time to turn the resonant laser on');
%         
%         repump_type =   Prefs.MultipleChoice('Off', 'choices', {'Off', 'Once', 'Every Sweep', 'Every Point'}, ...
%                             'help_text', sprintf(   ['Where to put repump pulses.\n - Off ==> repump disabled.\n - Once ==> only at the very start (software-triggered).\n', ...
%                                                     ' - Every Sweep ==> before every frequency sweep. - Every Point ==> at every point in the frequency sweep.']));
%     end
%     properties(SetAccess=protected,Hidden)
%         data = [] % subclasses should not set this; it can be manipulated in GetData if necessary
%         meta = [] % Store experimental settings
%         abort_request = false; % Flag that will be set to true upon abort. Used in run method.
%         pbH;    % Handle to pulseblaster
%         nidaqH; % Handle to NIDAQ
%     end
%     properties(Hidden)
%         ctsbefore1 = NaN
%         ctsbefore2 = NaN
%     end
    
    obj.freq_start = 2.4;
    obj.freq_end = 5.1;
    obj.points = 2.71/.01;
    
%     obj.freq_start = 3.36;
%     obj.freq_end = 4.36;
%     obj.points = 11;
    
    [ffreqs, AWG] = loadAWG(obj, true);
    
    cam = Imaging.PVCAM.instance();
    cam.exposure = 10000; % 10 s
    wm = Drivers.Wavemeter.instance('qplab-hwserver.mit.edu',5);
    
    img = cam.snapImage();
    
    imgs = NaN(size(img, 1), size(img, 2), length(ffreqs));
    ts = NaN(1, length(ffreqs));
    freqs = NaN(1, length(ffreqs));
    
    for ii = 1:length(ffreqs)
        ii
        
        ts(ii) = now;
        imgs(:,:,ii) = cam.snapImage();
        freqs(ii) = wm.getFrequency();
        drawnow
        
        fprintf(AWG, sprintf('*TRG'));
    end
    

    fname = sprintf('X:\\Experiments\\Ian\\Current\\CSEM\\Round 1\\Wafer 1\\2022_02_18 mod.safe.v4.0+ M2 Cyro\\2022_05_31 SiV\\ple8awg.mat');
    save(fname, 'ffreqs', 'imgs', 'ts', 'freqs');

    fclose(AWG);
        
    function [freqs, AWG] = loadAWG(obj, reset)
        seq_name = sprintf('PLE_fs=%f_fe=%f_n=%i', obj.freq_start, obj.freq_end, obj.points);
        freqs = linspace(obj.freq_start, obj.freq_end, obj.points);

%         ip='18.25.28.240';
%         AWG=visa('tek', ['TCPIP0::' ip '::INSTR']);
        AWG = visa('ni', 'TCPIP0::18.25.28.214::inst0::INSTR');
        fopen(AWG);
        
        if reset
            disp('Reseting!')
            fprintf(AWG,sprintf('*RST'));
        end

        % Setting up frequency sweep via Sequence
        amplitude=0.25; % Vpp

        % AWG track parameters
        num_samples = 25e3; % DEFAULT
        res_time = 1e-6; % in sec, amount of time resonant laser is on
        sample_rate = num_samples/res_time; % e.g. for 25kSamples, 25GS/s corresponds to 1us on time
        trig_channel = 'ATR';

        % Channel 1 on
        fprintf(AWG,sprintf('CLOC:SRAT %f', sample_rate));
        fprintf(AWG,sprintf('OUTP1:STAT ON'));

        % initialize a new sequence
        fprintf(AWG,sprintf('SLIS:SIZE?')); seq_list_size=fscanf(AWG);
        seq_exists = 0;

        if false
            % Query length of sequence list
            for seq_list_ind=1:numel(seq_list_size)
                fprintf(AWG,sprintf('SLIS:NAME? %d',uint8(seq_list_ind))); s_name = fscanf(AWG)

                if strcmp(s_name(2:end-2),seq_name)
                    seq_exists = 1;
                    break
                end
            end
        else
            if str2double(seq_list_size) == 1
                fprintf(AWG,sprintf('SLIS:NAME? %d',uint8(1))); s_name = fscanf(AWG);
                seq_exists = strcmp(s_name(2:end-2),seq_name);
                if seq_exists
                    disp(['"' seq_name '" exists!'])
                end

%                     seq_exists = 0
            end
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%

        % SEQUENCE EXISTS ALREADY, LOAD EXISTING ONE
        if seq_exists
            % load existing sequence

        % SEQUENCE DOES NOT EXIST, CREATE NEW ONE
        else 
            fprintf(AWG,sprintf('SLIS:SEQ:DEL ALL'));
            pause(0.5);
            fprintf(AWG,sprintf('WLIS:WAV:DEL ALL'));
            pause(0.5);

            fprintf(AWG,sprintf('SLIS:SEQ:NEW "%s", %d',seq_name,obj.points));

            % Basic waveform compiling setting - change to compile only
            % otherwise, the for loop chokes up and errors
            fprintf(AWG,sprintf('BWAV:COMP:CASS 0'));
            fprintf(AWG,sprintf('BWAV:COMP:CHAN NONE'));

            fprintf('\nStep: ###');

            for ind = 1:numel(freqs) % create a track for each frequency
                fprintf('\b\b\b%03i', ind);

                % create sine wave using basic waveform plug-in
                fprintf(AWG,sprintf('BWAV:FUNC "sine"'));
                fprintf(AWG,sprintf('BWAV:FREQ %f',freqs(ind)*1e9));
                fprintf(AWG,sprintf('BWAV:AMPL %f',amplitude));
%                     fprintf(AWG,sprintf('BWAV:RES %f',sample_rate));
                fprintf(AWG,sprintf('BWAV:SRAT %f',sample_rate));

                % saves sine waveform at each frequency 
                wave_name = sprintf('f%f',freqs(ind));
                fprintf(AWG,sprintf('BWAV:COMP:NAME "%s"',wave_name));

                % compile waveform
                fprintf(AWG,sprintf('BWAV:COMP'));
                pause(0.5);
%                     fprintf(AWG,sprintf('AWGC:STOP')); % AWG starts running after compiling, so stopping here

                % setting each step in the sequence
                fprintf(AWG,sprintf('SLIS:SEQ:STEP%d:TASS%d:WAV "%s", "%s"',...
                    ind, 1, seq_name, wave_name));
                fprintf(AWG,sprintf('SLIS:SEQ:STEP%d:RCO "%s", INF',...
                    ind, seq_name));

                % Set wait behavior.
                fprintf(AWG,sprintf('SLIS:SEQ:STEP%d:WINP "%s", %s',...
                    ind, seq_name, 'OFF'));

                % set trigger channel
                fprintf(AWG,sprintf('SLIS:SEQ:STEP%d:EJIN "%s", %s',...
                    ind, seq_name, trig_channel));
                % set "Event jump to"
                fprintf(AWG,sprintf('SLIS:SEQ:STEP%d:GOTO "%s", %s',...
                    ind, seq_name, 'NEXT'));
                fprintf(AWG,sprintf('SLIS:SEQ:STEP%d:EJUM "%s", %s',...
                    ind, seq_name, 'NEXT'));
            end
            fprintf('\n');

            % writing the last step to jump to 1st step
            fprintf(AWG,sprintf('SLIS:SEQ:STEP%d:GOTO "%s", %s',...
                    ind, seq_name, 'FIRS'));
            fprintf(AWG,sprintf('SLIS:SEQ:STEP%d:EJUM "%s", %s',...
                    ind, seq_name, 'FIRS'));
        end

        fprintf(AWG,sprintf('SOUR1:CASS:SEQ "%s", %i', seq_name, 1));

        %%%%%%%%%% DO NOT USE; CRASHES AWG %%%%%%%%%%%
        % % save Seq list file ".seqx" 
        % filePath='C:\Users\OEM\Documents\';
        % fileName=seq_name;
        % fprintf(AWG,sprintf('MMEM:SAVE:SEQ "%s", "%s"',seq_name,[filePath fileName '.SEQX']));
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        % set in trigger mode and wait for trigger (press play)
        fprintf(AWG,sprintf('AWGC:RMOD TRIG'));
        fprintf(AWG,sprintf('AWGC:RUN:IMM'));
        pause(.5)
        
    end
end
