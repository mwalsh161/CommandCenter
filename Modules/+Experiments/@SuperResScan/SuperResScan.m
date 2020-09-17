classdef SuperResScan < Experiments.PulseSequenceSweep.PulseSequenceSweep_invisible
    %SuperResScan Scan x and y in active stageManager, running resonant + repump
    %sequence at each point.
    %   This will use the active stageManager to set the position (via the
    %   manager)

    properties(SetObservable,GetObservable)
        resLaser = Prefs.ModuleInstance(Modules.Source.empty,'inherits',{'Sources.TunableLaser_invisible'});
        repumpLaser = Prefs.ModuleInstance(Modules.Source.empty,'inherits',{'Modules.Source'});
        APD_line = Prefs.Integer(1,'min',1,'help_text','PulseBlaster line that gates APD. Indexed from 1');
        repump_time = Prefs.Double(1,'units','us','help_text','Time spent repumping emitter');
        res_offset = Prefs.Double(0.1,'units','us','help_text','Time spent resonantly addressing and reading out emitter');
        res_time = Prefs.Double(0.1,'units','us','help_text','Time spent resonantly addressing and reading out emitter');
        x_points = Prefs.String('0','units','um','help_text','Valid MATLAB expression evaluating to list of x points to scan.','set','set_points');
        y_points = Prefs.String('0','units','um','help_text','Valid MATLAB expression evaluating to list of y points to scan.','set','set_points');
        frequency = Prefs.Double(470.5,'allow_nan',false,'units','THz','help_text','Resonant frequency to park resLaser at for scan.')
    end
    properties
        x = 0; % x positions
        y = 0; % y positions
        sequence; %for keeping same sequence from step to step
    end
    properties(Constant)
        % Required by PulseSequenceSweep_invisible
        nCounterBins = 2; %number of APD bins for this pulse sequence
        vars = {'x','y'}; %names of variables to be swept
    end
    properties(Access=private)
        stageManager % Add in pre run to be used in BuildPulseSequence
    end

    methods(Static)
        % Static instance method is how to call this experiment
        % This is a separate file
        obj = instance()
    end
    methods(Access=private)
        function obj = SuperResScan()
            obj.prefs = [{'frequency','x_points','y_points'},obj.prefs,{'resLaser','repumpLaser','APD_line','repump_time','res_time','res_offset'}];
            obj.path = 'APD1';
            % Constructor (should not be accessible to command line!)
            obj.loadPrefs; % Load prefs specified as obj.prefs
        end
    end

    methods
        function PreRun(obj,~,managers,ax)
            obj.stageManager = managers.Stages;
            obj.resLaser.arm;
            obj.repumpLaser.arm;
            obj.resLaser.TuneSetpoint(obj.frequency);
            subplot(1,2,1,ax);
            ax(2) = subplot(1,2,2,'parent',ax.Parent);
            imH(1) = imagesc(ax(1),obj.x,obj.y,NaN(length(obj.y),length(obj.x)));
            title(ax(1),'Repump Bin');
            imH(2) = imagesc(ax(2),obj.x,obj.y,NaN(length(obj.y),length(obj.x)));
            title(ax(2),'Resonant Bin');
            set(ax,'ydir','normal');
            axis(ax(1),'image');
            axis(ax(2),'image');
            ax(1).UserData = imH;
        end
        function UpdateRun(obj,~,~,ax,~,~,~)
            % UpdateRun(obj,status,managers,ax,average,xInd,yInd)
            ax.UserData(1).CData = squeeze(nanmean(obj.data.sumCounts(:,:,:,1),1))';
            ax.UserData(2).CData = squeeze(nanmean(obj.data.sumCounts(:,:,:,2),1))';
        end
        function s = BuildPulseSequence(obj,xInd,yInd)
            %BuildPulseSequence Builds pulse sequence for repump pulse followed by APD
            %collection during resonant driving
            if xInd > 1 || yInd > 1
                s = obj.sequence;
            else
                s = sequence('SuperResScan'); %#ok<CPROPLC> Calling HelperFunction
                repumpChannel = channel('Repump','color','g','hardware',obj.repumpLaser.PB_line-1);
                resChannel = channel('Resonant','color','r','hardware',obj.resLaser.PB_line-1);
                APDchannel = channel('APDgate','color','b','hardware',obj.APD_line-1,'counter','APD1');
                s.channelOrder = [repumpChannel, resChannel, APDchannel];
                g = node(s.StartNode,repumpChannel,'units','us','delta',0);
                node(g,APDchannel,'delta',0);
                g = node(g,repumpChannel,'units','us','delta',obj.repump_time);
                node(g,APDchannel,'delta',0);
                r = node(g,resChannel,'units','us','delta',obj.res_offset);
                node(r,APDchannel,'units','us','delta',0);
                r = node(r,resChannel,'units','us','delta',obj.res_time);
                node(r,APDchannel,'units','us','delta',0);
                
                obj.sequence = s;
            end
            % Update stage position
            obj.stageManager.move([obj.x(xInd),obj.y(yInd),NaN]);
            obj.meta.freqs(yInd,xInd) = obj.resLaser.getFrequency();
        end
        
        function val = set_points(obj,val,mp)
            vals = str2num(val); %#ok<ST2NM> str2num is basically eval
            assert(~isempty(vals),'Must specify valid MATLAB expression that returns non-empty vector.')
            obj.(mp.property_name(1)) = vals; % Use first char of property_name; "x"(_points) or "y"(_points)
        end
    end
end
