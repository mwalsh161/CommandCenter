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

numresLaserPowers = length(eval(obj.resLaserPower_range));
numrepumpLaserPower = length(eval(obj.repumpLaserPower_range));
obj.data.APDCounts = NaN([numrepumpLaserPower, numresLaserPowers, obj.samples, obj.nCounterBins]); 
obj.data.probability = NaN([numrepumpLaserPower, numresLaserPowers]);
try
    obj.PreRun(status,managers,ax);
    % Construct APDPulseSequence once, and update apdPS.seq
    % Not only will this be faster than constructing many times,
    % APDPulseSequence upon deletion closes PulseBlaster connection
    apdPS = APDPulseSequence(obj.nidaqH,obj.pbH,sequence('placeholder')); %create an instance of apdpulsesequence to avoid recreating in loop
%     drawnow('limitrate'); assert(~obj.abort_request,'User aborted.');
    % BuildPulseSequence must take in vars in the order listed
    pulseSeq = obj.BuildPulseSequence;
    n_repump_p = 1;
    n_res_p = 1;
    
    for repumpPower = eval(obj.repumpLaserPower_range) % Looping over the range of repump power measurements
        obj.keithley.set_voltage(repumpPower);
        obj.data.repumpLaserPower(n_repump_p) = obj.keithley.get_voltage * obj.keithley.measureCurrent;
        obj.keithley.set_voltage(0);
        for resLaserPower = eval(obj.resLaserPower_range) % Looping over the range of resonant power measurements
            obj.arduino.angle = resLaserPower;
            if pulseSeq ~= false % Interpret a return of false as skip this one (leaving in NaN)
                pulseSeq.repeat = 1; %obj.samples;
                apdPS.seq = pulseSeq;
                success = 0;
                for i = 1 : obj.samples
                    drawnow('limitrate'); assert(~obj.abort_request,'User aborted.');
                    obj.keithley.set_voltage(repumpPower);
                    pause(obj.repumpTime_us/1e6) % 
                    obj.keithley.set_voltage(0);
                    % run resonant laser pulse sequence
                    apdPS.start(1000); % hard coded
                    apdPS.stream(p);
                    obj.data.APDCounts(n_repump_p, n_res_p, i, :) = reshape(p.YData,obj.nCounterBins,[])';
                    % Whether there is counts in the initial bin
                    if obj.data.APDCounts(n_repump_p, n_res_p, i, 1) > obj.counterDuration/2*obj.est_CountsPerSecond_cps % initialized successfully if bright for the first half of the bin
                        success = success  + 1; 
                    end

                end
                obj.data.probability(n_repump_p, n_res_p) = success/obj.samples;
            end
            obj.UpdateRun(status,managers,ax);
            n_res_p = n_res_p + 1;
        end
        n_repump_p = n_repump_p + 1;
    end
        
    obj.PostRun(status,managers,ax);
    
catch err
end
delete(f);
if exist('err','var')
    rethrow(err)
end
end
