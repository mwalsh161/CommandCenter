function NVqueue = NVstatus(obj,NVindex,NVqueue,NVscatH)
%NVstatus Updates the status of an NV (by index)
%   Given an NV index and a scatterplot handle, NVstatus will update the
%   NV status, the NV queue, and change the color on the scatterplot accordingly:
%   orange = unexamined
%   red = bad spot (no spectral peak)
%   magenta = spectral peak, but no slow scan
%   teal = shelved for further examination
%   green = completed, successful
%   blue = current NV

queuePos = find(NVqueue == NVindex); %find the position of the NV in the queue;
NV = obj.scan(end).NV(NVindex); %grab NV handle
if ~isempty(NV.err)
    NV.status = ['Error: ', NV.err.message];
    NVscatH.CData(NVindex,:) = [1, 0, 0]; %red
    obj.logger.log([sprintf('Error on NV %i: ',NVindex), NV.err.message])
    NVqueue(queuePos) = [];
elseif isempty(NV.spec)
    NV.status = 'Unexamined';
    NVscatH.CData(NVindex,:) = [1, 0.5, 0]; %orange
elseif isempty(NV.spec.specloc)
    NV.status = 'No spectral peak';
    NVscatH.CData(NVindex,:) = [1, 0, 0]; %red
    obj.logger.log(sprintf('NV %i popped from queue (no spectra peak).',NVindex))
    NVqueue(queuePos) = [];
elseif strcmp(NV.status, 'Could not move laser')
    NVscatH.CData(NVindex,:) = [1, 0, 0]; %red
    obj.logger.log(sprintf('NV %i popped from queue (could not move laser).',NVindex))
    NVqueue(queuePos) = [];
elseif isempty(NV.survey)
    NV.status = 'Waiting for survey scans';
    NVscatH.CData(NVindex,:) = [0, 1, 1]; %cyan
elseif isempty(NV.region)
    NV.status = 'No peaks in survey scans'; %no regions, must've been no peaks
    NVscatH.CData(NVindex,:) = [1, 0, 1]; %magenta
    obj.logger.log(sprintf('NV %i popped from queue (no survey peaks).',NVindex))
    NVqueue(queuePos) = [];
elseif isempty(NV.region(1).err) && isempty(NV.region(1).slow) %no error, no slow scans
    NV.status = 'Waiting for regional scans';
    NVscatH.CData(NVindex,:) = [1, 1, 0]; %yellow
else
    num_regions = length(NV.region);
    cStat = [1,1,0];
    left_regions = 0;
    good_regions = 0;
    bad_regions = 0;
    for reg=1:num_regions
        if ~isempty(NV.region(reg).err)
            obj.logger.log([sprintf('Error on NV %i, reg %i: ',NVindex,reg), NV.region(reg).err.message])
            NV.region(reg).done = true;
            cStat = cStat + [0,-1,0]/num_regions; %shift towards red
            bad_regions = bad_regions+1;
        elseif ~isempty(NV.region(reg).slow) %if we've taken slow scans
            if min(NV.region(reg).slow(end).ScanFit.snrs) > obj.SNRThresh
                NV.region(reg).done = true;
                cStat = cStat + [-1,0,0]/num_regions; %shift towards green
                good_regions = good_regions+1;
            elseif isempty(NV.region(reg).slow(end).ScanFit.locs) || NV.region(reg).slow(end).averages >= obj.maxAverages
                NV.region(reg).done = true;
                cStat = cStat + [0,-1,0]/num_regions; %shift towards red
                bad_regions = bad_regions+1;
            else
                left_regions = left_regions+1;
            end
        else
            %haven't taken any slow scans
            left_regions = left_regions+1;
        end
    end
    NVscatH.CData(NVindex,:) = cStat; %something between cyan, red, and green
    msg = sprintf('%i Regions: %i succeeded, %i failed, %i left',num_regions,good_regions,bad_regions,left_regions);
    NV.status = msg;
    obj.logger.log([sprintf('NV %i, ',NVindex), msg]);
    if left_regions == 0;
        NVqueue(queuePos) = [];
        obj.logger.log(sprintf('NV %i popped from queue (regional scans complete)',NVindex));
    else
        NVqueue = circshift(NVqueue,[0,-1]); %shift to end of queue
        obj.logger.log(sprintf('NV %i shifted to end of queue.',NVindex));
    end
end
drawnow;
end

