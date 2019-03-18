function [c,R] = find_fast(im,conv)
%% Resize
factor = 2;  % Speeds up QR detection
im2 = imresize(im,1/factor);
f = fftshift(fft2(im2));
[X,Y] = meshgrid(linspace(-10,10,size(im2,2)),linspace(-10,10,size(im2,1)));
sigma = 0.2*factor;
sigma2 = 0.6*factor;
fmask = -exp((-X.^2-Y.^2)/sigma^2)+exp((-X.^2-Y.^2)/sigma2^2);
fmask = fmask/max(fmask(:));
im = abs(ifft2(f.*fmask));

%% Find Circles
% Convert to BW (logical)
BW = im;
lowest = min(min(im));
highest = max(max(im));
thresh = (1-Base.QR.BW_thresh)*lowest+Base.QR.BW_thresh*highest;
BW(BW<=thresh)=0;
BW = logical(BW);
st = regionprops(BW,'Area','Centroid','Eccentricity');
A = pi*(Base.QR.r/mean(conv))^2;
sel = [st.Area]>A*0.1;  % Filter for regions with area greater than
st = st(sel);
sel = [st.Area]<A*1.2;  % Filter for regions with area less than
st = st(sel);
%sel = [st.Eccentricity]<0.75; % Filter for eccentricity less than
%st = st(sel);
c = (cat(1,st.Centroid)-1)*factor+1;
R = NaN;
end