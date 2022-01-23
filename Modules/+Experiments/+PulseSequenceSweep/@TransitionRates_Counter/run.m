function run( obj,status,managers,ax)
% Main run method (callback for CC run button)
obj.abort_request = false;
status.String = 'Experiment started';
drawnow;
% Edit here down (save data to obj.data)
% Tips:
% - If using a loop, it is good practice to call:
%     drawnow; assert(~obj.abort_request,'User aborted.');
%     as frequently as possible
% - try/catch/end statements useful for cleaning up
% - You can get a figure-like object (to create subplots) by:
%     panel = ax.Parent; delete(ax);
%     ax(1) = subplot(1,2,1,'parent',panel);
% - drawnow can be used to update status box message and any plots

% Assert user implemented abstract properties correctly
% assert(iscell(obj.vars)&&~isempty(obj.vars)&&min(size(obj.vars))==1,'Property "vars" should be a 1D cell array with at least one value!');
% assert(all(cellfun(@ischar,obj.vars)),'Property "vars" should only contain strings');
% check_prop_exists = cellfun(@(a)isprop(obj,a),obj.vars);
% assert(all(check_prop_exists),sprintf('Properties not found in obj that are listed in "vars":\n%s',...
%     strjoin(obj.vars(check_prop_exists),newline)));
% assert(numel(obj.nCounterBins)==1 && isnumeric(obj.nCounterBins) && floor(obj.nCounterBins)==obj.nCounterBins,...
%     'Property "nCounterBins" should be a single integer');

obj.meta.prefs = obj.prefs2struct;
    
for i = 1:length(obj.vars)
    obj.meta.vars(i).name = obj.vars{i};
    obj.meta.vars(i).vals = obj.(obj.vars{i});
end
obj.meta.position = managers.Stages.position; % Stage position

f = figure('visible','off','name',mfilename);
a = axes('Parent',f);
p = plot(NaN,'Parent',a);

ard = Drivers.ArduinoServo.instance('localhost', 2);

MeasSync = 'CounterSync';
RepumpLine = 'RepumpTrigger';
ResLine = 'EMMTrigger';
APD_line = 'APD1';
cycle_ms = obj.repumpOff_ms + obj.repumpTime_ms + obj.repumpOff_ms;
total_time = cycle_ms * obj.repeats; %ms
nsamples_APD = ceil(total_time / obj.dwell_ms);
nsamples_cycle = ceil(cycle_ms / obj.dwell_ms);
off_sample = ceil(obj.repumpOff_ms/obj.dwell_ms);
on_sample = ceil(nsamples_cycle - off_sample * 2);


pulseUnit = NaN(1, nsamples_cycle);
pulseUnit(1 : off_sample) = zeros(1, length(1 : off_sample));
pulseUnit(off_sample + 1 : off_sample + on_sample) = ones(1, length(1 : on_sample));
pulseUnit(off_sample + on_sample + 1 : off_sample + on_sample + off_sample) = zeros(1, length(1 : off_sample));
pulseTotal = repmat(pulseUnit, 1, obj.repeats)';

numrepumpLaserPowers = length(eval(obj.repumpLaserPower_range));
obj.data.APDCounts = NaN([ceil(total_time/obj.dwell_ms)-1, numrepumpLaserPowers]); % what is the number of APD bins obj.APDbins
try
    n = 1;
    for repumpLaserPower = eval(obj.repumpLaserPower_range)
        obj.repumpLaser.power = repumpLaserPower;
        drawnow('limitrate'); assert(~obj.abort_request,'User aborted.');
        obj.PreRun(status,managers,ax);
        obj.nidaqH.ClearAllTasks();
        % Start APD
%         PulseTrainH = obj.nidaqH.CreateTask('Counter PulseTrain');
%         try
%             PulseTrainH.ConfigurePulseTrainOut('CounterSync',1/obj.dwell_ms*1000);
%         catch err
%             rethrow(err)
%         end
%         CounterH = obj.nidaqH.CreateTask('Counter CounterObj');
%         try
%             continuous = false;
%             buffer = obj.cycle_s/obj.dwell_ms*1000;
%             CounterH.ConfigureCounterIn('APD1',buffer,PulseTrainH,continuous)
%         catch err
%             rethrow(err)
%         end
%         CounterH.Start;
%         PulseTrainH.Start;
        try
            %(Code block, trigger green laser pulsing with DAQ)
            PulseTrainH = obj.nidaqH.CreateTask('Measurement PT');
            PulseTrainH.ConfigurePulseTrainOut(MeasSync,1/obj.dwell_ms,nsamples_APD);

            CounterH = obj.nidaqH.CreateTask('Counter');
            CounterH.ConfigureCounterIn(APD_line,nsamples_APD,PulseTrainH);

            laser = obj.nidaqH.CreateTask('LaserPulse');
            laser.ConfigureDigitalOut({RepumpLine},pulseTotal,PulseTrainH);

            % Arm tasks (CLKs will wait for trigger)
            PulseTrainH.Start; CounterH.Start; laser.Start;
        catch err
            rethrow(err)
        end


        % Directly start the laser pulses with pulseblaster
%         overrideMinDuration = false;
%         try
%             [program, ~, ~, ~] = obj.BuildPulseSequence.compile(overrideMinDuration);
%             obj.pbH.load(program);
%             obj.pbH.start;
%         catch err
%             rethrow(err)
%         end
% 
        while ~CounterH.IsTaskDone 
            pause(0.1)
        end

        % Record APD
        nsamples = CounterH.AvailableSamples;
        %obj.data.APDCounts(:,1) = ones([obj.cycle_s/obj.dwell_ms*1000-1, numresLaserPowers]);
        if nsamples
            obj.data.APDCounts(:,n) = diff(CounterH.ReadCounter(nsamples));
        end
        obj.UpdateRun(status,managers,ax);
        n = n + 1;
        if ~isempty(CounterH)&&isvalid(CounterH)
            CounterH.Clear;
        end
        if ~isempty(PulseTrainH)&&isvalid(PulseTrainH)
            PulseTrainH.Clear
        end
    end
    
%     apdPS = APDPulseSequence(obj.nidaqH,obj.pbH,sequence('placeholder')); %create an instance of apdpulsesequence to avoid recreating in loop
%     n = 1;
%     for resLaserPower = eval(obj.resLaserPower_range)
%         ard.angle = resLaserPower;
%         drawnow('limitrate'); assert(~obj.abort_request,'User aborted.');
%         % BuildPulseSequence must take in vars in the order listed
%         pulseSeq = obj.BuildPulseSequence;
% 
%         if pulseSeq ~= false % Interpret a return of false as skip this one (leaving in NaN)
%             pulseSeq.repeat = obj.samples;
%             apdPS.seq = pulseSeq;
% 
%             apdPS.start(1000); % hard coded
%             apdPS.stream(p);
%             dat = p.YData;
%             obj.data.APDCounts(:,n) = dat';
%         end
%             obj.UpdateRun(status,managers,ax,n,n);
%             n = n + 1;
%     end
        
%     obj.PostRun(status,managers,ax);
    
catch err
end
delete(f);
if exist('err','var')
    rethrow(err)
end
end
