function [readInfo,debug] = hone(im,readInfo)
%HONE From readInfo from READER make a better estimate of tform
%   INPUT:
%     im: a SmartImage info struct (reader uses the "image" and
%         "ROI" fields
%     readInfo: output readInfo struct of READER using same im
%   OUTPUT:
%     readInfo: see READER help. qrInfo not altered.
%     debug: diagnostic data to visualize what hone did for debugging purposes.

%NOTE: lab refers to image coords and sample refers to QR coords
xlim = im.ROI(1,:);
ylim = im.ROI(2,:);
im = im.image;
scale = sqrt(readInfo.tform.T(1,1)^2 + readInfo.tform.T(2,1)^2); % lab -> sample (~1 if ROI calibrated)

% Constuct enough QRs that if any part of them is in the frame, we get it
bboxLab = [xlim(1), ylim(1);xlim(1), ylim(2);xlim(2), ylim(2);xlim(2), ylim(1)]; % frame bounding box
bboxSample = transformPointsForward(readInfo.tform,bboxLab);
xlimQRind = [min(bboxSample(:,1)),max(bboxSample(:,1))]/Base.QR.spacing_between;
ylimQRind = [min(bboxSample(:,2)),max(bboxSample(:,2))]/Base.QR.spacing_between;
xlimQRind = max(0,round(xlimQRind(1))):round(xlimQRind(2));
ylimQRind = max(0,round(ylimQRind(1))):round(ylimQRind(2));
[Xind,Yind] = meshgrid(xlimQRind,ylimQRind);
sampleQRind = [Xind(:), Yind(:)];
nQRs = size(sampleQRind,1);
sampleC = NaN(3+2*Base.QR.NSecondary,2,nQRs);
sampleR = NaN(3+2*Base.QR.NSecondary,nQRs);
for i = 1:size(sampleQRind,1)
    [c,r] = Base.QR.BasicBlock();
    sampleC(:,:,i) = c + sampleQRind(i,:)*Base.QR.spacing_between;
    sampleR(:,i) = r;
end
sampleC = reshape(shiftdim(sampleC,1),2,[])'; % See logic in Base.QR.reader
sampleR = reshape(shiftdim(sampleR,1),1,[])';
in = inpolygon(sampleC(:,1),sampleC(:,2),bboxSample(:,1),bboxSample(:,2));
sampleC = sampleC(in,:);
sampleR = sampleR(in);

% Try to fit circles with high accuracy using the tform for an initial guess
labC = transformPointsInverse(readInfo.tform,sampleC);
labR = sampleR/scale;
honedC = NaN(size(labC));
honedR = NaN(size(labR));
outstruct = struct('f',[],'gof',[],'output',cell(size(labR)));
im = double(imcomplement(im));  % Use this for GaussFit2D (fits positive (bright) things)

x = linspace(xlim(1),xlim(2),size(im,2));
y = linspace(ylim(1),ylim(2),size(im,1));
n_radius_crop = 2;

pp = gcp('nocreate'); % If no pool, do not create new one.
if isempty(pp)
    nworkers = 0;
else
    nworkers = pp.NumWorkers;
end
parfor (i = 1:size(labC,1), nworkers)
    xIND = NaN(1,2); yIND = NaN(1,2);
    [~,xIND(1)] = min(abs(x-(labC(i,1)-labR(i)*n_radius_crop)));
    [~,xIND(2)] = min(abs(x-(labC(i,1)+labR(i)*n_radius_crop)));
    [~,yIND(1)] = min(abs(y-(labC(i,2)-labR(i)*n_radius_crop)));
    [~,yIND(2)] = min(abs(y-(labC(i,2)+labR(i)*n_radius_crop)));
    % Fit
    [honedC(i,:),honedR(i),outstruct(i)] = gaussfit2D(x(xIND(1):xIND(2)),...
                                   y(yIND(1):yIND(2)),...
                                   im(yIND(1):yIND(2),xIND(1):xIND(2)),labR(i)/2);
end
% moved less than object radius (QR coords)
stayedclose = sqrt((honedC(:,1)-labC(:,1)).^2+(honedC(:,2)-labC(:,2)).^2) < sampleR;
% decent rsquare (*depending on resolution, circles could have flat top*)
goodfit_thresh = 0.8;
rsquare = arrayfun(@(a)a.gof.rsquare,outstruct);
goodfit = rsquare > goodfit_thresh;
mask = stayedclose & goodfit;

% Grab some debug data before we crop for transform calc
debug.labC = labC;
debug.labR = labR;
debug.honedC = honedC;
debug.honedR = honedR;
debug.stayedclose = stayedclose;
debug.goodfit_thresh = goodfit_thresh;
debug.rsquare = rsquare;
debug.n_radius_crop = n_radius_crop;

% Calculate transform
honedC = honedC(mask,:);
sampleC = sampleC(mask,:);
im2QRT = fitgeotrans(honedC,sampleC,'nonreflectivesimilarity');
% Calculate position and error in control points
markers_theory = transformPointsForward(im2QRT, honedC);
err = sqrt(mean((markers_theory-sampleC).^2)); % std in x and y
npoints = size(markers_theory,1);

readInfo.tform = im2QRT;
readInfo.std = err;
readInfo.npoints = npoints;
end

