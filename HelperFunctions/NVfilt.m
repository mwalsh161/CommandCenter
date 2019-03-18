function [ im_filt ] = NVfilt( im,hp,lp,n )
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
assert(hp>lp, 'The highpass frequency is greater than the lowpass.')
im = medfilt2(im,[n n]);
if hp == Inf
   im_filt = imgaussfilt(im,lp);
else
   im_filt = imgaussfilt(im,lp) - imgaussfilt(im,hp);
end
     
end