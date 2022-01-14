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

numrepumpLaserPowers = length(eval(obj.repumpLaserPower_range));
obj.data.APDCounts = NaN([obj.APD_buffer_s/obj.dwell_ms*1000-1, numrepumpLaserPowers]); % what is the number of APD bins obj.APDbins
try
    n = 1;
    for repumpLaserPower = eval(obj.repumpLaserPower_range)
        obj.repumpLaser.power = repumpLaserPower;
        drawnow('limitrate'); assert(~obj.abort_request,'User aborted.');
        obj.PreRun(status,managers,ax);
        obj.nidaqH.ClearAllTasks();
        % Start APD
        PulseTrainH = obj.nidaqH.CreateTask('Counter PulseTrain');
        try
            PulseTrainH.ConfigurePulseTrainOut('CounterSync',1/obj.dwell_ms*1000);
        catch err
            rethrow(err)
        end
        CounterH = obj.nidaqH.CreateTask('Counter CounterObj');
        try
            continuous = false;
            buffer = obj.APD_buffer_s/obj.dwell_ms*1000;
            CounterH.ConfigureCounterIn('APD1',buffer,PulseTrainH,continuous)
        catch err
            rethrow(err)
        end
        CounterH.Start;
        PulseTrainH.Start;


        % Directly start the laser pulses with pulseblaster
        overrideMinDuration = false;
        try
            [program, ~, ~, ~] = obj.BuildPulseSequence.compile(overrideMinDuration);
            obj.pbH.load(program);
            obj.pbH.start;
        catch err
            rethrow(err)
        end

        while ~CounterH.IsTaskDone 
            pause(0.1)
        end

        % Record APD
        nsamples = CounterH.AvailableSamples;
        %obj.data.APDCounts(:,1) = ones([obj.APD_buffer_s/obj.dwell_ms*1000-1, numresLaserPowers]);
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
