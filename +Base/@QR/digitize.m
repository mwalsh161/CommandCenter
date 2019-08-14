function [code,p,estimate,posPxs] = digitize(im,unit2pxT,significance,posMarkers)
modSize = Base.QR.module_size;  % um
numMods = sqrt(Base.QR.length)+2; % including border "bits"
posMarkers = round(posMarkers); % round to px

% Generate coordinates QR bits
[X,Y] = meshgrid(0:numMods-1, numMods-1:-1:0);
posU = [X(:), Y(:)].*modSize + Base.QR.d - modSize/2;
posBits = round(transformPointsForward(unit2pxT,posU));

% Generate relative coordinates for pixels in a bit
bpolyU = [-1, -1;-1, 1;1, 1;1, -1].*modSize/2/2; % relative bounding box for bit
bpolyPX = fix(bpolyU*unit2pxT.T(1:2,1:2)); % fix chops off decimal
[Ymod,Xmod] = meshgrid(min(bpolyPX(:,2)):max(bpolyPX(:,2)),...
                       min(bpolyPX(:,1)):max(bpolyPX(:,1)));
posPxs = [Xmod(:), Ymod(:)];
posPxs = posPxs(inpolygon(posPxs(:,1),posPxs(:,2),bpolyPX(:,1),bpolyPX(:,2)),:);
nPx = size(posPxs,1);
assert(nPx>1, 'Need more than 1 reference pixel per bit!');

% Extract pixel values from image
pxsVals = NaN(numMods,numMods,nPx);
for i = 1:size(posBits,1)
    temp = posBits(i,:) + posPxs;
    [row,col] = ind2sub([numMods,numMods],i);
    pxsVals(row,col,:) = im(sub2ind(size(im),temp(:,2),temp(:,1)));
end
markerVals = NaN(3,nPx);
for i = 1:size(posMarkers,1)
    temp = posMarkers(i,:) + posPxs;
    markerVals(i,:) = im(sub2ind(size(im),temp(:,2),temp(:,1)));
end

% For this version of digitization, we will use the markers as logical 1
% values, and the border as logical 0. If there is not enough of a
% difference, we will error.
valCol = pxsVals([1,end],1:end,:);
valRow = pxsVals(1:end,[1,end],:);
ref0 = [valCol(:); valRow(:)];
pxsVals = pxsVals(2:end-1,2:end-1,:); % Crop out border
ref1 = markerVals(:);
assert(numel(ref0)>1 && numel(ref1)>1, 'Need more than one reference pixel for both 0 and 1 values.')
% Perform tests (numMods-2 is the actual size of code without the border)
[h,p] = ttest2(ref0,ref1,'Alpha',significance,'vartype','unequal');
assert(h==1,'Not enough significance between logical 0 and logical 1 pixels.');
code = false(numMods-2);
estimate = NaN(numMods-2);
for row = 1:numMods-2
    for col = 1:numMods-2
        sample = squeeze(pxsVals(row,col,:));
        [code(row,col), ~, estimate(row,col)] = BinaryUnkownDistTest(ref0, ref1, sample);
    end
end

% ** Remember, we are working with a "transposed" matrix given how MATLAB
% indexes it (e.g. indexes a column first).
code = code';
code = code(:);
estimate = estimate';
estimate = estimate(:);
end