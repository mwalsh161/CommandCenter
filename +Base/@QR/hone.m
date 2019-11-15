function [readInfo,f_debug] = hone(im,readInfo,varargin)
%HONE From readInfo from READER make a better estimate of tform
%   Will take advantage of parallel pool if available (will not start one).
%   INPUT:
%     im: a SmartImage info struct (reader uses the "image" and
%     	"ROI" fields
%     readInfo: output readInfo struct of READER using same im
%     [n_crop]: (1.5) Limits when fitting gaussians: [-1 1]*n_crop*radius
%     [goodfit_thresh]: (0.5) adjrsquare threshold for eliminating control
%       points.
%     [r_move_thresh]: (1) distance from initial center guess threshold for
%       eliminating control points.
%     [min_radius]: (0.25) Smallest observable radius in um (e.g. diffraction limit)
%     [debug]: (false) Creates a figure with relevant graphics at each step
%   OUTPUT:
%     readInfo: see READER help. qrInfo not altered.
%     f_debug: either gobjects(1) or the figure handle if debug is true
assert(isequal(size(im.ROI),[2,2]),'ROI must be 2x2!');
assert(isstruct(readInfo)&&isfield(readInfo,'tform'),...
    'readInfo must be output struct from Base.QR.reader');
assert(~isempty(readInfo.tform),'Base.QR.reader did not find a QR (tform is empty).');
p = inputParser;
addParameter(p,'n_crop',1.5,@(a)validateattributes(a,{'numeric'},{'scalar','nonnegative'}));
addParameter(p,'goodfit_thresh',0.5,@(a)validateattributes(a,{'numeric'},{'scalar','nonnegative'}));
addParameter(p,'r_move_thresh',1,@(a)validateattributes(a,{'numeric'},{'scalar','nonnegative'}));
addParameter(p,'min_radius',0.25,@(a)validateattributes(a,{'numeric'},{'scalar','nonnegative'}));
addParameter(p,'debug',false,@(a)validateattributes(a,{'logical'},{'scalar'}));

parse(p,varargin{:});
p = p.Results;
% Fix inversions
if im.ROI(1,1) > im.ROI(1,2) % invert in x
    im.ROI(1,:) = [im.ROI(1,2) im.ROI(1,1)];
    im.image = fliplr(im.image);
end
if im.ROI(2,1) > im.ROI(2,2) % invert in y
    im.ROI(2,:) = [im.ROI(2,2) im.ROI(2,1)];
    im.image = flipud(im.image);
end

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
labR = max(p.min_radius,sampleR)/scale;  % Take into account min_radius when going to lab units
honedC = NaN(size(labC));
honedR = NaN(size(labR));
outstruct = struct('f',[],'gof',[],'output',cell(size(labR)));
imcomp = double(imcomplement(im));  % Use this for GaussFit2D (fits positive (bright) things)

x = linspace(xlim(1),xlim(2),size(im,2));
y = linspace(ylim(1),ylim(2),size(im,1));
n_radius_crop = p.n_crop; % Move to var so we don't broadcast all of p

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
                                   imcomp(yIND(1):yIND(2),xIND(1):xIND(2)),labR(i)/2);
end
% moved less than object radius (QR coords)
labRact = sampleR/scale; % Not including the min_radius
stayedclose = sqrt(sum((honedC - labC).^2,2)) < labRact*p.r_move_thresh;
% decent rsquare (*depending on resolution, circles could have flat top*)
adjrsquared = arrayfun(@(a)a.gof.adjrsquare,outstruct);
goodfit = adjrsquared > p.goodfit_thresh;

f_debug = gobjects(1);
if p.debug
    used_min_radius = p.min_radius > sampleR;
    f_debug = UseFigure('QR.hone','name','QR.hone',true); figure(f_debug);
    colormap(f_debug,'gray');
    ax_debug = axes('parent',f_debug);
    imagesc(ax_debug(1),xlim,ylim,im);
    axis(ax_debug,'image');
    hold(ax_debug,'on');
    set(ax_debug,'ydir','normal');
    if isempty(labC)
        title('Failed to find any!')
    else
        for i = 1:size(labC,1)
            % Draw initial points as black line with white border
            circle(labC(i,:),labR(i),'EdgeColor','w','LineWidth',2.5);
            circle(labC(i,:),labR(i),'EdgeColor','k');
            c = 'g';
            if ~stayedclose(i)
                c = 'm';
            elseif ~goodfit(i)
                c = 'y';
            elseif ~stayedclose(i) && ~goodfit(i)
                c = 'r';
            end
            h(i) = circle(honedC(i,:),honedR(i),'EdgeColor',c,...
                'UserData',struct('c',labC(i,:),'r',labR(i),'minRused',used_min_radius(i),'outstruct',outstruct(i),'distMoved',sqrt(sum((honedC(i,:) - labC(i,:)).^2,2))),...
                'ButtonDownFcn',{@more_data,x,y,imcomp,n_radius_crop,p.min_radius});
        end
        % Seemst to be bug where FaceColor needs to be RENDERED then unset
        set(h,'FaceColor', 'k'); drawnow nocallbacks;
        set(h,'FaceColor', 'none');
        plt(1) = plot(ax_debug,NaN,NaN,'ok'); plt(2) = plot(ax_debug,NaN,NaN,'og');
        plt(3) = plot(ax_debug,NaN,NaN,'om'); plt(4) = plot(ax_debug,NaN,NaN,'oy');
        plt(5) = plot(ax_debug,NaN,NaN,'or');
        set(plt,'linewidth',1.5);
        legend(plt,{'Initial Guess','Success',...
            sprintf('center moved > %g*r',p.r_move_thresh),...
            sprintf('adjrsquared < %g',p.goodfit_thresh),...
            'moved & poor fit'});
        iptPointerManager(f_debug, 'enable');
        iptSetPointerBehavior(h, @(hFigure, ~)set(hFigure, 'Pointer', 'cross'));
        addlistener(f_debug,'ObjectBeingDestroyed',@(~,~)delete(findall(0,'tag','Base.QR.hone_spot')));
    end
end

% Calculate transform
mask = stayedclose & goodfit;
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

function h = circle(c,r,varargin)
% Specifying any property again in varargin will override defaults here
d = r*2;
px = c(1)-r;
py = c(2)-r;
h = rectangle('Position',[px py d d],'Curvature',[1,1],...
    'linewidth',1.5,...
    'PickableParts','all',... % callback when clicking on transparent face
    varargin{:});
end

function more_data(obj,eventdata,x,y,im,n_radius_crop,min_radius)
if eventdata.Button == 1
dat = obj.UserData;
xIND = NaN(1,2); yIND = NaN(1,2);
[~,xIND(1)] = min(abs(x-(dat.c(1)-dat.r*n_radius_crop)));
[~,xIND(2)] = min(abs(x-(dat.c(1)+dat.r*n_radius_crop)));
[~,yIND(1)] = min(abs(y-(dat.c(2)-dat.r*n_radius_crop)));
[~,yIND(2)] = min(abs(y-(dat.c(2)+dat.r*n_radius_crop)));
[xsurf,ysurf] = meshgrid(x(xIND(1):xIND(2)),y(yIND(1):yIND(2)));
[xsurfDense,ysurfDense] = meshgrid(linspace(x(xIND(1)),x(xIND(2)),1001),...
                                   linspace(y(yIND(1)),y(yIND(2)),1001));
imcrop = im(yIND(1):yIND(2),xIND(1):xIND(2));
imfit = reshape(dat.outstruct.f([xsurf(:) ysurf(:)]),diff(yIND)+1,diff(xIND)+1);
imfit_dense = reshape(dat.outstruct.f([xsurfDense(:) ysurfDense(:)]),1001,1001);

[f,newf] = UseFigure('Base.QR.hone_spot','name','Base.QR.hone',true);
if newf % Only do once in case user prefers something else
    f.Position(1:2) = f.Position(1:2) - ([1750 480] - f.Position(3:4)).*[1/2 1];
    f.Position(3:4) = [1750 480];
end
colormap(f,'gray');
ax(1) = subplot(1,4,1,'parent',f); hold(ax(1),'on');
surf(ax(1),xsurf,ysurf,imcrop,'EdgeColor','none','facealpha',0.5);
scatter3(ax(1),xsurf(:),ysurf(:),imcrop(:),'filled');
surf(ax(1),xsurfDense,ysurfDense,imfit_dense,'FaceColor','r','EdgeColor','none','facealpha',0.25);
view(ax(1),22.5,45);
xlabel(ax(1),'x'); ylabel(ax(1),'y');
axis(ax(1),'square');axis(ax(1),'tight');
if dat.minRused
    title(ax(1),sprintf('Fit to Inverted Image\nMoved %.2f (using min radius: %g)',dat.distMoved,min_radius));
else
    title(ax(1),'Fit to Inverted Image');
end
ax(2) = subplot(1,4,2,'parent',f);
imagesc(ax(2),x(xIND),y(yIND),imcrop-imfit);
colorbar(ax(2));
axis(ax(2),'image');
title(ax(2),'Residuals')
set(ax,'ydir','normal');

ax = subplot(1,4,[3 4],'parent',f,'visible','off');
ax.Position(1) = 1/2;
summary = [strsplit(evalc('disp(dat.outstruct.f)'),newline)];
summary = [summary strsplit(evalc('disp(dat.outstruct.gof)'),newline)];
summary = [summary strsplit(evalc('disp(dat.outstruct.output)'),newline)];
summary = cellfun(@(a)a(4:end),summary,'uniformoutput',false);
text(ax,0,0.5,strjoin(summary,newline),'fontname','fixedwidth');
figure(f);
end
end
