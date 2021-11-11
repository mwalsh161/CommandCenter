function [pos,errs,candidates] = NVposition3D(im,NVsize,sensitivity,spatial_filter,ax)
    % Takes filtered and cropped image and returns position of NVs
    % Position is in pixels (pos is 3*N)
    % Candidates are the approximate peaks found
    % errs are the adjusted rsquared values (use to filter pos)
    %
    % Optional fitBox is the box size in pixels to perform the fit [x,y]
    %   Should include about 2 standard dev. around spot center
    % Optional varargin goes directly to NVfilt(im,varargin{:})
    %
    % spatial_filter is a set of coordinates defining a surrounding polygon
    %   where the vertices will be connected in order.

if nargin < 3
    sensitivity = 3.5;
end
if nargin < 4
    x = size(im,2);
    y = size(im,1);
    spatial_filter = [0 0,x 0;x y;0 y];
end

fitBox = NVsize*2;
fitBox = floor(fitBox/2)*2;  % Make sure even integer
assert(size(im,1)>fitBox(2)*2 && size(im,2)>fitBox(1)*2,'Image is too small for given fitBox.')

% Quickly find approximate peak location (don't search in edge)
im_filt = imgaussfilt3(im,NVsize*3/8) - imgaussfilt3(im,NVsize*3);  % BP filter: LP-HP
if nargin == 5 && ishandle(ax) && isvalid(ax)
    hold(ax,'off');
    imagesc(im_filt(:,:,1),'parent',ax);
    axis(ax,'image');
    set(ax,'ydir','normal')
    colormap(ax,'gray');
    hold(ax,'on');
    patch('Faces',1:size(spatial_filter,1),'vertices',spatial_filter,'facecolor','none','parent',ax,'edgecolor','b');
end

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

candidates = FastPeakFind3D(im_filt,thresh);
candidates = [candidates(1:3:end) candidates(2:3:end) candidates(3:3:end)];
if isempty(candidates)  % Null case
    pos = NaN(0,3);
    errs = NaN(0);
    candidates = pos;
    return
end
% Shift (undo crop) and format nicely (the -1 is because it is indexed from 1)
candidates(:,1) = round(candidates(:,1));
candidates(:,2) = round(candidates(:,2));
candidates(:,3) = round(candidates(:,3));

% Apply spatial filter
in = inpolygon(candidates(:,1),candidates(:,2),spatial_filter(:,1),spatial_filter(:,2));
candidates = candidates(in,:);
if nargin == 5 && ishandle(ax) && isvalid(ax)
    plot(ax,candidates(:,1),candidates(:,2),'r.'); axis(ax,'image');
    drawnow;
end
pos = candidates;
errs = NaN(size(candidates,1),1);
return
% Prepare fit
g=fittype('a*exp(-(x1-b1)^2/2/c1^2)*exp(-(x2-b2)^2/2/c1^2)+d',...
    'independent',{'x1','x2'},'dependent',{'y'},...
    'coefficients',{'a','b1','c1','b2','d'});

% Pre-dividing image results in much less data transfer overhead to workers
patches = cell(1,size(candidates,1));
for i = 1:size(candidates,1)
    row = (-fitBox(2)/2:fitBox(2)/2) + candidates(i,2);  % y
    col = (-fitBox(1)/2:fitBox(1)/2) + candidates(i,1);  % x
    patches{i} = double(im(row,col));
end

SigAmp = NaN(size(candidates,1),1);
NoisAmp = NaN(size(candidates,1),1);
Width = NaN(size(candidates,1),1);
errs = NaN(size(candidates,1),1);

PositionX = NaN(size(candidates,1),1);
PositionY = NaN(size(candidates,1),1);

lower_a = 0.05;
lower_b1 = -3;
lower_c1 = 1;
lower_b2 = -3;
lower_d = 0.5;

upper_a = 0.5;
upper_b1 = 3;
upper_c1 = 10;
upper_b2 = 3;
upper_d = 0.95;

% Should only have one broadcast variable: fitBox
%f = figure; ax = axes('parent',f);
parfor i=1:size(candidates,1)
    % Background is the mean of the border
    segment = patches{i};
    background = mean([segment(1,2:end-1) segment(end,2:end-1) segment(:,1)' segment(:,end)']);
    
    patch_norm = segment/max(segment(:));
    backgroundLevel = background/max(segment(:));
    
    % This needs to be in here, so each worker has an actual fitoptions
    % object rather than just a struct
    opt = fitoptions('METHOD','NonlinearLeastSquares');
    opt.MaxFunEvals = 150;
    %                  a      b1    c1   b2    d
    opt.StartPoint = [ 1-backgroundLevel      0     4    0     backgroundLevel];
    opt.Lower =      [lower_a lower_b1 lower_c1 lower_b2 lower_d];
    opt.Upper =      [upper_a upper_b1 upper_c1 upper_b2 upper_d];
    
    [x,y] = meshgrid(-fitBox(1)/2:fitBox(1)/2,-fitBox(2)/2:fitBox(2)/2);
    [f, err]=fit([x(:),y(:)],patch_norm(:),g,opt);

    errs(i) = err.rmse;
    SigAmp(i) = f.a*max(segment(:));
    NoisAmp(i) = f.d*max(segment(:));
    Width(i) = f.c1;

    PositionX(i) = f.b1;
    PositionY(i) = f.b2;

end

mean_Sig = mean(SigAmp);
std_Sig = std(SigAmp);

%upper_Sig = mean_Sig+1.8*std_Sig;
%lower_Sig = mean_Sig-1.2*std_Sig;

upper_Sig = 4096;
%lower_Sig = 0;

%lower_Sig = mean_Sig+std_Sig;  %%works well
%lower_Sig = mean_Sig+0.5*std_Sig;  %%works better
%lower_Sig = mean_Sig;              %% works well in high exp, x know low
lower_Sig = mean_Sig-std_Sig;



mean_Nois = mean(NoisAmp);
std_Nois = std(NoisAmp);

%upper_Nois = mean_Nois+1.6*std_Nois;
%lower_Nois = mean_Nois-1.2*std_Nois;  %% works best, original

lower_Nois = mean_Nois-0.8*std_Nois;  %% works best, original

%lower_Nois = mean_Nois;    %% works well

upper_Nois = 4096;
%lower_Nois = 0;

mean_Width = mean(Width);
mode_Width = mode(floor(Width*20))/20;
std_Width = std(Width);

upper_Width = 4.15;    %works well, original
%lower_Width = 2.17;    %works well, original

lower_Width = 2.8;


if upper_Width>upper_c1
    upper_Width=upper_c1;
end

if lower_Width>lower_c1
    lower_Width=lower_c1;
end

upper_PositionX = 1;
lower_PositionX = -1;

upper_PositionY = 1;
lower_PositionY = -1;

mean_err = mean(errs);
std_err = std(errs);

%upper_err = 0.05;   %works well
upper_err = 0.06;

%upper_err = 1000;

indexTrue = (SigAmp<upper_Sig)&(SigAmp>lower_Sig)&...
            (NoisAmp<upper_Nois)&(NoisAmp>lower_Nois)&...
            (Width<upper_Width)&(Width>lower_Width)&...
            (errs<upper_err)&...
            (PositionX<upper_PositionX)&(PositionX>lower_PositionX)&...
            (PositionY>lower_PositionY)&(PositionY<upper_PositionY);
if isempty(find(indexTrue,1))
    errs = NaN(0,1);
    pos = NaN(0,2);
    return
end
NVx = candidates(indexTrue,1)+PositionX(indexTrue);
NVy = candidates(indexTrue,2)+PositionY(indexTrue);
errs = errs(indexTrue);
pos = [NVx NVy];
if nargin == 5 && ishandle(ax) && isvalid(ax)
    plot(ax,NVx,NVy,'g.'); axis(ax,'image');
end