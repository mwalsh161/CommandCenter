function [readInfo,debug] = hone(im,readInfo)
%HONE From readInfo from READER make a better estimate of tform
%   INPUT:
%     im: a SmartImage info struct (reader uses the "image" and
%         "ROI" fields
%     readInfo: output readInfo struct of READER using same im
%   OUTPUT:
%     readInfo: see READER help. qrInfo completely ignored.
%     meta: diagnostic data to visualize what hone did for debugging purposes.

%NOTE: lab refers to image coords and sample refers to QR coords
x = im.ROI(1,:);
y = im.ROI(2,:);
im = im.image;
scale = sqrt(readInfo.tform.T(1,1)^2 + readInfo.tform.T(2,1)^2);

% Constuct enough QRs that if any part of them is in the frame, we get it
bboxIm = [x(1), y(1);x(1), y(2);x(2), y(2);x(2), y(1)]; % frame bounding box
bboxQR = transformPointsForward(readInfo.tform,bboxIm);
xlimQRind = [min(bboxQR(:,1)),max(bboxQR(:,1))]/Base.QR.spacing_between;
ylimQRind = [min(bboxQR(:,2)),max(bboxQR(:,2))]/Base.QR.spacing_between;
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
in = inpolygon(sampleC(:,1),sampleC(:,2),bboxQR(:,1),bboxQR(:,2));
sampleC = sampleC(in,:);
sampleR = sampleR(in);

% Try to fit circles with high accuracy using the tform for an initial guess
labC = transformPointsInverse(readInfo.tform,sampleC);
labR = sampleR/scale;
toDelete = false(1,length(labR)); % If fit doesn't work out
im = double(imcomplement(im));  % Use this for GaussFit2D (fits positive (bright) things)
parfor i = 1:size(lab,1)
    row = round(labR(i)+[-1 1]*rs(i)*2); % Give 4r x 4r area around circle estimate
    col = round(labC(i)+[-1 1]*rs(i)*2);
    row(1) = max(1,row(1));
    row(2) = min(size(im,1),row(2));
    col(1) = max(1,col(1));
    col(2) = min(size(im,2),col(2));
%    [center,~] =imfindcircles(im(row(1):row(2),col(1):col(2)),rs(i),'objectpolarity','dark','sensitivity',0.999);
%    imagesc(im(row(1):row(2),col(1):col(2))); hold on;
    [center,~,gof] = GaussFit2D(im(row(1):row(2),col(1):col(2)),rs(i)*2);
    if gof.rsquare > 0.6
%        viscircles(center,width,'edgecolor','g'); hold off; drawnow; pause(0.1);
        labC(i) = center(1)+col(1)-1; % Undo shift from crop
        labR(i) = center(2)+row(1)-1;
    else
%        viscircles(center,width,'edgecolor','r'); hold off; drawnow; pause(0.1);
        toDelete(i) = true;
    end
end
lab = [labC labR];
lab(toDelete,:) = [];
sample(toDelete,:) = [];
rs(toDelete) = [];

% Take labframe back to ROI coords
%           zero frame      scale frame       apply offset
lab(:,1) = (lab(:,1)-1)*diff(x)/(size(im,2)-1) + x(1);
lab(:,2) = (lab(:,2)-1)*diff(y)/(size(im,1)-1) + y(1);
end

