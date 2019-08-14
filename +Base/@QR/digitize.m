function [code,p,estimate,posPxs] = digitize(im,unit2pxT,alpha)
modSize = Base.QR.module_size;  % um
numMods = sqrt(Base.QR.length)+2;

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

rawVals = NaN(numMods,numMods,size(posPxs,1));
for i = 1:size(posBits,1)
    temp = posBits(i,:) + posPxs;
    [row,col] = ind2sub([numMods,numMods],i);
    rawVals(row,col,:) = im(sub2ind(size(im),temp(:,2),temp(:,1)));
end

% For this version of digitization, we will use the pad bits as logical 1
% values, and the border as logical 0. If there is not enough of a
% difference, we will error.
assert(all(Base.QR.padVal),'All pad values must be 1 to get reference pixel values.')
% Assume border is zero
valCol = rawVals([1,end],1:end,:);
valRow = rawVals(1:end,[1,end],:);
ref0 = [valCol(:); valRow(:)];

rawVals = rawVals(2:end-1,2:end-1,:); % Crop out border
[col,row] = ind2sub([numMods-2,numMods-2],Base.QR.pad); % ** (see below)
ref1 = NaN(length(col),nPx);
for i = 1:length(col)
    ref1(i,:) = reshape(rawVals(row(i),col(i),:),1,nPx);
end
ref1 = ref1(:);
assert(numel(ref0)>1 && numel(ref1)>1, 'Need more than one reference pixel for both 0 and 1 values.')
% Perform tests (numMods-2 is the actual size of code without the border)
[h,p] = ttest2(ref0,ref1,'Alpha',alpha,'vartype','unequal');
assert(h==1,'Not enough significance between logical 0 and logical 1 pixels.');
code = false(numMods-2);
estimate = NaN(numMods-2);
for row = 1:numMods-2
    for col = 1:numMods-2
        sample = squeeze(rawVals(row,col,:));
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