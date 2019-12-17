classdef SuperResScan < Experiments.PulseSequenceSweep.PulseSequenceSweep_invisible
    %SuperResScan Scan x and y in active stageManager, running resonant + repump
    %sequence at each point.
    %   This will use the active stageManager to set the position (via the
    %   manager)

    properties(SetObservable,GetObservable)
        resLaser = Prefs.ModuleInstance('inherits',{'Modules.Source.empty','Sources.TunableLaser_invisible'});
        repumpLaser = Prefs.ModuleInstance('inherits',{'Modules.Source.empty'});
        APD_line = Prefs.Integer(1,'min',1,'help_text','PulseBlaster line that gates APD. Indexed from 1');
        repump_time = Prefs.Double(1,'units','us','help_text','Time spent repumping emitter');
        res_offset = Prefs.Double(0.1,'units','us','help_text','Time spent resonantly addressing and reading out emitter');
        res_time = Prefs.Double(0.1,'units','us','help_text','Time spent resonantly addressing and reading out emitter');
        x_points = Prefs.String('[]','units','um','help_text','Valid MATLAB expression evaluating to list of x points to scan.','set','set_points');
        y_points = Prefs.String('[]','units','um','help_text','Valid MATLAB expression evaluating to list of y points to scan.','set','set_points');
    end
    properties
        x = []; % x positions
        y = []; % y positions
        sequence; %for keeping same sequence from step to step
    end
    properties(Constant)
        % Required by PulseSequenceSweep_invisible
        nCounterBins = 1; %number of APD bins for this pulse sequence
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
            obj.prefs = [{'x_points','y_points'},obj.prefs,{'resLaser','repumpLaser','APD_line','repump_time','res_time','res_offset'}];
            obj.path = 'APD1';
            % Constructor (should not be accessible to command line!)
            obj.loadPrefs; % Load prefs specified as obj.prefs
        end
    end

    methods
        function PreRun(obj,~,managers,ax)
            obj.stageManager = obj.managers.Stages;
        end
        function UpdateRun(obj,~,~,ax,average,xInd,yInd)
            
        end
        function s = BuildPulseSequence(obj,xInd,yInd)
            %BuildPulseSequence Builds pulse sequence for repump pulse followed by APD
            %collection during resonant driving
            if xInd > 1 || yInd > 1
                s = obj.sequence;
            else
                s = sequence('SuperResScan'); %#ok<CPROPLC> Calling HelperFunction
                repumpChannel = channel('Repump','color','g','hardware',obj.repumpLaser.PBline-1);
                resChannel = channel('Resonant','color','r','hardware',obj.resLaser.PBline-1);
                APDchannel = channel('APDgate','color','b','hardware',obj.APD_line-1,'counter','APD1');
                s.channelOrder = [repumpChannel, resChannel, APDchannel];
                g = node(s.StartNode,repumpChannel,'units','us','delta',0);
                g = node(g,repumpChannel,'units','us','delta',obj.repump_time);
                r = node(g,resChannel,'units','us','delta',obj.res_offset);
                node(r,APDchannel,'units','us','delta',0);
                r = node(r,resChannel,'units','us','delta',obj.res_time);
                node(r,APDchannel,'units','us','delta',0);
                
                obj.sequence = s;
            end
            % Update stage position
            obj.stageManager.move([obj.x(xInd),obj.y(yInd),NaN])
        end
        
        function val = set_points(obj,val,mp)
            vals = str2num(val); %#ok<ST2NM> str2num is basically eval
            assert(~isempty(vals),'Must specify valid MATLAB expression that returns non-empty vector.')
            obj.(mp.property_name(1)) = vals; % Use first char of property_name; "x"(_points) or "y"(_points)
        end
    end
end
