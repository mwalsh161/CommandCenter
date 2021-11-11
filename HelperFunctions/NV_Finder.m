function [varargout] = NV_Finder(im,NVsize)
sensitivity = 2; %number of STD's above the noise
scaley = (size(im.image,1)-1)/diff(im.ROI(2,:));
scalex = (size(im.image,2)-1)/diff(im.ROI(1,:));
NVsize = scaley*NVsize;
lp = NVsize/2*0.5;  % Wants sigma (NVsize was originaly a diameter)
hp = NVsize/2*1.5;
% Assume im is the image matrix
im_filt = imgaussfilt(im.image,lp) - imgaussfilt(im.image,hp);  % BP filter: LP-HP

% Calculate threshold
temp = im_filt;
temp(temp==0)= [];  % NVfilt leaves a border with 0s that skew the data
[N,edges] = histcounts(temp(:));
dx = diff(edges);
x = edges(1:end-1)+dx;
g = fittype('gauss1');
opt = fitoptions(g);
opt.StartPoint = [max(N),nanmean(temp(:)),nanstd(temp(:))];
opt.Lower = [0,0,0];
f = fit(x',N',g,opt);
%figure; plot(x,N); hold on; plot(f);
thresh = f.b1 + f.c1*sensitivity;

candidates = FastPeakFind(im_filt,thresh);
candidates = [(candidates(1:2:end)-1)/scalex+im.ROI(1,1) (candidates(2:2:end)-1)/scaley+im.ROI(2,1)];
if isempty(candidates)
    candidates = NaN(0,2);
end
varargout = {candidates,im_filt,[lp hp]};
varargout = varargout(1:nargout);
end