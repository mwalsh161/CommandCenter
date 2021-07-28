classdef LaserSequenceOnly < Experiments.SlowScan.SlowScan_invisible
    %Open Open-loop laser sweep for slowscan
    % Set center freq_THz
    % Sweeps over percents (usually corresponding to a piezo in a resonator)
    %   - If tune_coarse = true, first moves laser to that frequency;
    %   otherwise scan is perfomed wherever the laser is
    %   - If center_scan = true, percents are relative to wherever the
    %   initial percentage is prior to starting sweep. This can be quite
    %   useful in combination with tune_coarse for lasers that don't leave
    %   the percent centered at 50 after tuning.
    %
    % NOTE: plotting averages over average loop, which might not be same
    % frequencies, or even close if laser mode hops. All averages are saved.

    properties(SetObservable,AbortSet)
        freq_THz = 470;
        tune_coarse = false;
        center_scan = false; % When true, percents will be shifted after tune_coarse completes to compensate position of percent
        percents = 'linspace(0,100,101)'; %eval(percents) will define percents for open-loop scan [scan_points]
        trigger_line = 3;
    end
    properties(SetAccess=private,Hidden)
        percentInitialPosition = 50; % used to center scan if user wants
    end
    properties(Constant)
        xlabel = 'Percent (%)';
    end
    methods(Static)
        % Static instance method is how to call this experiment
        % This is a separate file
        obj = instance()
    end
    methods(Access=private)
        function obj = LaserSequenceOnly()
            obj.scan_points = eval(obj.percents);
            obj.prefs = [{'freq_THz','center_scan','tune_coarse','percents'}, obj.prefs];
            obj.loadPrefs; % Load prefs specified as obj.prefs
        end
    end
    
    methods
        function s = BuildPulseSequence(obj,freqIndex)
            %BuildPulseSequence Builds pulse sequence for repump pulse followed by APD
            %collection during resonant driving
            if freqIndex > 1
                s = obj.sequence;
            else
                s = sequence('SlowScan'); %#ok<CPROPLC> Calling HelperFunction
                repumpChannel = channel('Repump','color','g','hardware',obj.repumpLaser.PB_line-1);
                resChannel = channel('Resonant','color','r','hardware',obj.resLaser.PBline-1);
                APDchannel = channel('APDgate','color','b','hardware',obj.APDline-1,'counter','APD1');
                s.channelOrder = [repumpChannel, resChannel, APDchannel];
                g = node(s.StartNode,repumpChannel,'units','us','delta',0);
                g = node(g,repumpChannel,'units','us','delta',obj.repumpTime_us);
                r = node(g,resChannel,'units','us','delta',obj.resOffset_us);
                node(r,APDchannel,'units','us','delta',0);
                r = node(r,resChannel,'units','us','delta',obj.resTime_us);
                node(r,APDchannel,'units','us','delta',0);
                
                obj.sequence = s;
            end
        end
        function PreRun(obj,~,managers,ax)
%             if obj.tune_coarse
%                 obj.resLaser.TuneCoarse(obj.freq_THz);
%             end
%             obj.percentInitialPosition = obj.resLaser.GetPercent;
%             PreRun@Experiments.SlowScan.SlowScan_invisible(obj,[],managers,ax);
        end  
        function set.percents(obj,val)
            numeric_vals = str2num(val); %#ok<ST2NM> str2num uses eval but is more robust for numeric input
            assert(~isempty(numeric_vals),'Must have at least one value for percents.');
            assert(min(numeric_vals)>=0&&max(numeric_vals)<=100,'Percents must be between 0 and 100 (inclusive).');
            obj.scan_points = numeric_vals;
            obj.percents = val;
        end
        function run( obj,status,managers,ax)
            % Main run method (callback for CC run button)
            obj.abort_request = false;
            status.String = 'Experiment started';
            drawnow;
            
             numVars = length(obj.vars);
 
             f = figure('visible','off','name',mfilename);
             a = axes('Parent',f);
             p = plot(NaN,'Parent',a);

            try
                apdPS = APDPulseSequence(obj.nidaqH,obj.pbH,sequence('placeholder')); %create an instance of apdpulsesequence to avoid recreating in loop
                pulseSeq = obj.BuildPulseSequence(1);
                if pulseSeq ~= false % Interpret a return of false as skip this one (leaving in NaN)
                    statusString = cell(1,numVars);
                    for j = 1:obj.averages
                        drawnow('limitrate'); assert(~obj.abort_request,'User aborted.');


                        pulseSeq.repeat = obj.samples;
                        apdPS.seq = pulseSeq;

                        apdPS.start(1); % hard coded
                        apdPS.stream(p);
                            %obj.UpdateRun(status,managers,ax,j,indices{:});
                    end
                end
                %obj.PostRun(status,managers,ax);

            catch err
            end
            delete(f);
            if exist('err','var')
                rethrow(err)
            end
            end
    end
end
