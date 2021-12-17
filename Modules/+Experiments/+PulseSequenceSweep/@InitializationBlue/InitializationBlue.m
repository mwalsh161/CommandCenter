classdef InitializationBlue < Experiments.PulseSequenceSweep.PulseSequenceSweep_invisible
    % Study the probability of initialization as a function of blue laser power with blue repump

    properties(SetObservable,GetObservable, AbortSet)
        resLaser = Modules.Source.empty(1,0); % Allow selection of source
        repumpLaser = Modules.Source.empty(1,0);
        
        keithley = Drivers.Keithley2400.instance(0,16);
        arduino = Drivers.ArduinoServo.instance('localhost', 2);
        
        % KeithleyVolatge = 3; % Voltage for keithley to control the laser power
        APDline = 3;
        repumpTime_us = 1000; %us
        resOffset_us = 0.1;
        resTime_us = 10000;
        
        est_CountsPerSecond_cps = 20000;
        
        resLaserPower_ang = 0; % angle on filter wheel, might need to calibrate the corresponding laser power
        repumpLaserPower_mW = 1;
        
        resLaserPower_range = 'linspace(0,180,101)'; 
        repumpLaserPower_range = 'linspace(0.1,10,101)'; % voltage for keithley
        
    end
    properties
        placeHolderVariable = 1; %all APD bins are acquired in one shot, no variable is swept
        counterDuration = 0; %calculated in set.resTime_us
    end
    properties(Constant)
        nCounterBins = 20; %number of APD bins for this pulse sequence (with more than 20 the PB errors)
        counterSpacing = 0.1; %spacing between APD bins
        vars = {'resLaserPower_range', 'repumpLaserPower_range'}; %names of variables to be swept
        
    end
    methods(Static)
        obj = instance()
    end
    methods(Access=private)
        function obj = InitializationBlue()
            obj.prefs = [obj.prefs,{'resLaser','APDline','repumpTime_us','repumpLaser','resOffset_us',...
            'resTime_us', 'resLaserPower_ang', 'repumpLaserPower_mW', 'resLaserPower_range', 'repumpLaserPower_range'}]; %additional preferences not in superclass
            obj.loadPrefs;
        end
    end

    methods
        pulseSeq = BuildPulseSequence(obj) %Defined in separate file
        
        function PreRun(obj,~,~,ax)
%             obj.repumpLaser.on

            obj.arduino.angle = obj.resLaserPower_ang; % initialize the resonant laser power
            obj.keithley.set_voltage(0) % set the voltage level for keithley for blue laser
            obj.keithley.set_output(1) % turn on keithley
            %prepare axes for plotting
            hold(ax,'on');
% %             colors = lines(2);
%             %plot data bin 1
%             imagesc(obj.data.probability(:,:))
            for i = 1 : length(eval(obj.resLaserPower_range))
                plotH{i} = plot(eval(obj.repumpLaserPower_range),obj.data.probability(:, i),'parent',ax);
            end
            ylabel(ax,'Probability of initialization');
            xlabel(ax,'Resonant Laser Power/angle');

%             % Store for UpdateRun
            ax.UserData.plots = plotH;
            hold(ax,'off');
            set(ax,'xlimmode','auto','ylimmode','auto','ytickmode','auto')
        end
        function UpdateRun(obj,~,~,ax,~,~)
%             if obj.averages > 1
%                 averagedData = squeeze(nanmean(obj.data.sumCounts,1))';
%                 meanError = squeeze(nanmean(obj.data.stdCounts,1))'*sqrt(obj.samples);
%             else
%             averagedData = obj.data.sumCounts;
%             meanError = obj.data.stdCounts;
%             end

            %grab handles to data from axes plotted in PreRun  
            for i = 1 : length(eval(obj.resLaserPower_range))
                ax.UserData.plots{i}.YData = obj.data.probability(:, i);
                drawnow limitrate;
            end        
        end
        
%         function PostRun(obj,~,~,~)
%             obj.keithley.delete
%             obj.arduino.delete
%         end
        
        function set.resTime_us(obj,val)
            obj.resTime_us = val;
            obj.counterDuration = obj.resTime_us / obj.nCounterBins - obj.counterSpacing;
        end
    end
end
