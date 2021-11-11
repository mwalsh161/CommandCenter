function run( obj,status,managers,ax)
% Main run method (callback for CC run button) for EMCCD T1
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
%     ax(1) = subplot(1,2,1,'parent',panel);32
% - drawnow can be used to update status box message and any plots


ROI_EMCCD = obj.cameraEMCCD.ROI;
imgSize_EMCCD = ROI_EMCCD(:,2) - ROI_EMCCD(:,1);
obj.data.images_EMCCD = NaN(imgSize_EMCCD(1), imgSize_EMCCD(2), length(obj.vars));

% Assert user implemented abstract properties correctly
assert(iscell(obj.vars)&&~isempty(obj.vars)&&min(size(obj.vars))==1,'Property "vars" should be a 1D cell array with at least one value!');
assert(all(cellfun(@ischar,obj.vars)),'Property "vars" should only contain strings');
check_prop_exists = cellfun(@(a)isprop(obj,a),obj.vars);
assert(all(check_prop_exists),sprintf('Properties not found in obj that are listed in "vars":\n%s',...
    strjoin(obj.vars(check_prop_exists),newline)));
assert(numel(obj.nCounterBins)==1 && isnumeric(obj.nCounterBins) && floor(obj.nCounterBins)==obj.nCounterBins,...
    'Property "nCounterBins" should be a single integer');

numVars = length(obj.vars);
varLength = NaN(1,numVars);
for i = 1:numVars
    varLength(i) = length(obj.(obj.vars{i}));
end

obj.data.sumCounts = NaN([obj.averages,varLength,obj.nCounterBins]);
obj.data.stdCounts = NaN([obj.averages,varLength,obj.nCounterBins]);

obj.meta.prefs = obj.prefs2struct;
for i = 1:length(obj.vars)
    obj.meta.vars(i).name = obj.vars{i};
    obj.meta.vars(i).vals = obj.(obj.vars{i});
end
obj.meta.position = managers.Stages.position; % Stage position

f = figure('visible','off','name',mfilename);
a = axes('Parent',f);
p = plot(NaN,'Parent',a);

try
    obj.PreRun(status,managers,ax);
    
    % Construct APDPulseSequence once, and update apdPS.seq
    % Not only will this be faster than constructing many times,
    % APDPulseSequence upon deletion closes PulseBlaster connection
    indices = num2cell(ones(1,numVars));
    apdPS = APDPulseSequence(obj.nidaqH,obj.pbH,sequence('placeholder')); %create an instance of apdpulsesequence to avoid recreating in loop
    statusString = cell(1,numVars);
    for j = 1:obj.averages
        for i = 1:prod(varLength)
            drawnow('limitrate'); assert(~obj.abort_request,'User aborted.');
            [indices{:}] = ind2sub(varLength,i); % this does breadth-first
            for k=1:numVars
                statusString{k} = sprintf('%s = %g (%i/%i)',obj.vars{k},obj.(obj.vars{k})(indices{k}),indices{k},varLength(k));
            end
            status.String = [sprintf('Progress (%i/%i averages):\n  ',j,obj.averages),strjoin(statusString,'\n  ')];
            
            % BuildPulseSequence must take in vars in the order listed
            pulseSeq = obj.BuildPulseSequence(indices{:});
            if pulseSeq ~= false % Interpret a return of false as skip this one (leaving in NaN)
                pulseSeq.repeat = obj.samples;
                
                overrideMinDuration = false;
                [program, ~, ~, time] = pulseSeq.compile(overrideMinDuration);
                timeout = 1.5*time + 1;
                obj.pbH.load(program);
                obj.pbH.start;
                
%                 apdPS.seq = pulseSeq;
%                 
%                 apdPS.start(1000); % hard coded
%                 apdPS.stream(p);
%                 dat = reshape(p.YData,obj.nCounterBins,[])';
%                 obj.data.sumCounts(j,indices{:},:) = sum(dat);
%                 obj.data.stdCounts(j,indices{:},:) = std(dat);
            end
            %wait for buffer to have new camera image:
            img_ready = 0;
            timeout = 10;
            tic
            while (img_ready<1&toc<timeout)
                img_ready = obj.cameraEMCCD.core.getRemainingImageCount();
                %pause(obj.sequenceduration/1e3); %wait for camera readout?
                pause(0.1);
            end
            %acquire camera image
            obj.data.images_EMCCD(:,:,i) = obj.cameraEMCCD.popNextImage();
            imagesc(ax,obj.data.images_EMCCD(:,:,i));
            obj.UpdateRun(status,managers,ax,j,indices{:});
        end
    end
    obj.PostRun(status,managers,ax);
    
catch err
    obj.PostRun(status,managers,ax);
end
delete(f);
if exist('err','var')
    rethrow(err)
end
end
