function [ im_filt ] = BandFilt( im,hp,lp,n )
%NVFILT Filter image before doing peak detection
%   Smooth image then bandpass filter.
%   Highpass edge is defined by hp and lowpass by lp. They are defined in
%       spatial domain, so hp > lp.
%   The filters uses are both gaussian
if nargin < 2
    hp = 5;
    lp = 3;
    n = 3;
elseif nargin < 3
    lp = 3;
    n = 3;
elseif nargin < 4
    n = 3;
end
hp = round(hp);
lp = round(lp);
n = round(n);
assert(hp>lp||hp==0, 'The highpass frequency is greater than the lowpass.')
im = medfilt2(im,[n n]);
im_filt = imfilter(im,fspecial('Gaussian',lp*5,lp));
if hp
    im_filt = im_filt-imfilter(im,fspecial('Gaussian',hp*5,hp));
end

% Get rid of high intenisty border (use highpass since it will be the lower
% frequency, thus the larger spatial kenerl)
edge = round(hp*5/2);
im_filt(1:edge,:) = 0;
im_filt(end-edge:end,:) = 0;
im_filt(:,1:edge) = 0;
im_filt(:,end-edge:end) = 0;
end