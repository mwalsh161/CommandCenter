function [readInfo,meta] = hone(im,readInfo)
%HONE From readInfo from READER make a better estimate of tform
%   INPUT:
%     im: a SmartImage info struct (reader uses the "image" and
%         "ROI" fields
%     readInfo: output readInfo struct of READER using same im
%   OUTPUT:
%     readInfo: see READER help. qrInfo completely ignored.
%     meta: diagnostic data to visualize what hone did for debugging purposes.

x = im.ROI(1,:);
y = im.ROI(2,:);
im = im.image;
qrInfo = readInfo.qrInfo;

% Nearest neighbors
sample = [];
rs = [];
for xx = [0 -1 1]
    for yy = [0 -1 1]
        [c,r] = Base.QR.BasicBlock(qrInfo);
        c(:,1) = c(:,1)+xx*Base.QR.spacing_between;
        c(:,2) = c(:,2)+yy*Base.QR.spacing_between;
        sample(end+1:end+size(c,1),:) = c;
        rs(end+1:end+size(c,1)) = r;
    end
end

% Adjust to lab frame and see if they exist, remove if they don't
lab = sample*R*qrInfo.scaling;
rs=rs*qrInfo.scaling;
lab(:,1) = lab(:,1) + qrInfo.offset(1);
lab(:,2) = lab(:,2) + qrInfo.offset(2);
toDelete = [];
for i = 1:size(sample,1)
    if lab(i,2) > size(im,1) || lab(i,2) < 1 || ... 
       lab(i,1) > size(im,2) || lab(i,1) < 1
        toDelete(end+1) = i;
    end
end
lab(toDelete,:) = [];
sample(toDelete,:) = [];
rs(toDelete) = [];

% Try to fit remaining circles with high accuracy
labC = lab(:,1);        % Split apart for parfor loop
labR = lab(:,2);
toDelete = false(1,length(labR));
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

