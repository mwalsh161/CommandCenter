function [pos,readInfo,f_debug] = reader(im,varargin)
% READER Returns QR info if the 3 larger markers are found
%   The image should be corrected for flat illumination already.
% Inputs; brackets indicate name,value optional pair:
%   im: a SmartImage info struct (reader uses the "image" and
%       "ROI" fields
%   [sensitivity]: (5) n standard deviations above median when
%       choosing the binary threshold for finding QR markers
%   [significance]: (0.05) used to assert enough contrast in
%       logical 1 and logical 0 pixel values. It is the 'Alpha'
%       input to ttest2.
%   [leg_len_thresh]: (0.05) 1 - ratio of length of each leg
%   [angle_thresh]: (0.1) Error from pi/2 between legs
%   [invert]: (0) Invert around specified axis. 0: dont invert, 1: x, 2: y
%       Note, the axis should not matter for decoding correctly - simply
%       supplying true here will work just fine.
%   [debug]: (false) Creates a figure with relevant graphics at each step
% Outputs:
%   pos: The estimated position of the image's (0,0) coordinate in
%       the QR frame. Based on all QRs detected.
%   readInfo: The details about the result. Fields:
%       qrInfo*: an array of structs
%       tform: image coords -> QR coords. This can be thought
%           of as the inverted "average" of the qrInfo.QR2imT.
%       std: 1x2 double. std in [x,y] resutling from tform. The units are
%           in the QR coords. This should be same as image if calibrated well.
%       npoints: n points used to calculate tform. Always zero
%           for this function. Reserved for enhancedReader.
%   f_debug: either gobjects(1) or the figure handle if debug is true
%   *qrInfo includes:
%       row, col and version: the encoded QR info. If error is
%           not empty, row and col are empty doubles and
%           version is NaN.
%       code: 1xN char (binarystring). Depending on what/if the
%           error is, this may be empty.
%       estimate: 1xN double. Estimated value of code as a
%       double. abs(code - estimate) is ~p(success)
%       significance: the p value from a ttest between the
%       reference for logical 0 bits and 1 bits.
%       error: An empty MException, or the MException if one
%           occured during decoding
%       legacy_err: If correct interpretation of code required
%           assuming the legacy error in the python GDS generator.
%       QR2imT: Affine transform QR(x,y)[um] -> image(x,y)[um].*
%       * If error is not empty, these will be from the root
%       (0,0) QR code instead of the one encoded.

% There will be 3 coordinate systems used throughout this function:
%   Pixel: corresponding to resized image pixel locations
%       (resized image is a concept entirely internal to this
%       method)
%   Image: The "lab" coordinates. Units used in image.ROI.
%   QR: The "sample" coordinates. Generated from decoding QR
%       code and knowledge of QR positioning.
assert(size(im.image,3)==1,'Image must be gray scale.')
assert(isequal(size(im.ROI),[2,2]),'ROI must be 2x2!');

p = inputParser;
addParameter(p,'sensitivity',5,@(a)validateattributes(a,{'numeric'},{'scalar','nonnegative'}));
addParameter(p,'significance',0.05,@(a)validateattributes(a,{'numeric'},{'scalar','>',0,'<',1}));
addParameter(p,'leg_len_thresh',0.05,@(a)validateattributes(a,{'numeric'},{'scalar','nonnegative'}));
addParameter(p,'angle_thresh',0.1,@(a)validateattributes(a,{'numeric'},{'scalar','nonnegative'}));
addParameter(p,'invert',false,@(a)validateattributes(a,{'numeric','logical'},{'scalar','nonnegative','<=',2}));
addParameter(p,'debug',false,@(a)validateattributes(a,{'logical'},{'scalar'}));
parse(p,varargin{:});
p = p.Results;

if p.invert
    im.ROI(p.invert,:) = -im.ROI(p.invert,:);
end

% Fix inversions
if im.ROI(1,1) > im.ROI(1,2) % invert in x
    im.ROI(1,:) = [im.ROI(1,2) im.ROI(1,1)];
    im.image = fliplr(im.image);
end
if im.ROI(2,1) > im.ROI(2,2) % invert in y
    im.ROI(2,:) = [im.ROI(2,2) im.ROI(2,1)];
    im.image = flipud(im.image);
end
x = im.ROI(1,:);
y = im.ROI(2,:);
im = double(im.image); % Necessary for some filter operations

ax_debug = gobjects(1,4);
f_debug = gobjects(1);
if p.debug
    f_debug = UseFigure('QR.reader','name','QR.reader',...
        'units','normalized','position',[0 0 1 1],true);
    iptPointerManager(f_debug, 'enable');
    addlistener(f_debug,'ObjectBeingDestroyed',@(~,~)delete(findall(0,'tag','Base.QR.reader_bit')));
    figure(f_debug);
    colormap(f_debug,'gray');
    for i = 1:length(ax_debug)
        ax_debug(i) = subplot(2,2,i,'parent',f_debug);
        hold(ax_debug(i),'on');
        axis(ax_debug(i),'image');
    end
    set(ax_debug,'ydir','normal');
    imagesc(ax_debug(1),x,y,im);
    if p.invert
        title(ax_debug(1),sprintf('Original (%i x %i)\nInverted %i axis.',size(im,2),size(im,1),p.invert))
    else
        title(ax_debug(1),sprintf('Original (%i x %i)',size(im,2),size(im,1)))
    end
end

% Resize to square px
conv = [diff(x)/(size(im,2)-1),diff(y)/(size(im,1)-1)]; % um/pixel
conv = max(conv); % Reduce to worst resolution
im = imresize(im,round([diff(y),diff(x)]/conv)+1);
if p.debug
    imagesc(ax_debug(2),im);
    title(ax_debug(2),sprintf('Square px (%i x %i)',size(im,2),size(im,1)))
end

% Find all relevent QRs
marker_cands = Base.QR.findMarkers(im,conv,p.sensitivity,ax_debug(3:4)); % Nx2 double
markersBase = [0,0;Base.QR.spacing,0;0,Base.QR.spacing]; % Markers base location (root QR)
[QR2pxT,markersPx_act] = Base.QR.findQR(marker_cands,conv,markersBase,...
                        p.leg_len_thresh,p.angle_thresh,...
                        ax_debug(3:4)); % 1xN affine2d, 3x2xN px points (3 markers,[x,y],qr ind)
% Note, QR2pxT is not returned because it refers to the resized image (square pixels)
% markersPx_act are the actual locations from findMarkers
% corresponding to the QR codes.

% Use markers*Act for final image alignment on all observed QRs
markersImAct = (markersPx_act - 1).*conv + [x(1), y(1)]; % Translate to image coords
markersQRAct = NaN(size(markersImAct)); % Filled in as analyzed

% Go through and attempt to decode QR codes
nQRs = length(QR2pxT);
qrInfo = struct('row',[],'col',[],'version',[],'code',[],...
                'QR2imT',[],'legacy_err',[],'error',cell(1,nQRs));
for i = 1:nQRs
    qrInfo(i).code = false(0);
    qrInfo(i).estimate = false(0);
    qrInfo(i).legacy_err = false;
    debug = struct('posPxs',NaN(0,2)); % posPxs only so we can add posPxsIms for plotQRinfo
    try
        % Calculated theoretical marker position and use for digitization
        markersPx = transformPointsForward(QR2pxT(i), markersBase);
        [code,pVal,estimate,debug] = Base.QR.digitize(im,QR2pxT(i),p.significance,markersPx);
        qrInfo(i).code = code;
        qrInfo(i).estimate = estimate;
        qrInfo(i).significance = pVal;

        [row,col,ver,legacy_error] = Base.QR.analyze(code);
        qrInfo(i).row = row;
        qrInfo(i).col = col;
        qrInfo(i).version = ver;
        qrInfo(i).legacy_err = legacy_error;
        qrInfo(i).error = MException.empty();
        % Calculate QR2imT in real coords (no more pixel references)
        markersQRAct(:,:,i) = markersBase + [col, row].*Base.QR.spacing_between;
        qrInfo(i).QR2imT = fitgeotrans(markersQRAct(:,:,i), markersImAct(:,:,i),'nonreflectivesimilarity');
        markers_c = 'g';
    catch err
        qrInfo(i).version = NaN;
        qrInfo(i).error = err;
        % Note this is the QR at (0,0)
        qrInfo(i).QR2imT = fitgeotrans(markersBase, markersImAct(:,:,i),'nonreflectivesimilarity');
        markers_c = 'r';
    end
    if p.debug
        debug.posPxsIm = debug.posPxs*conv; % relative coords; thus only scale matters
        handles = Base.QR.plotQRinfo(ax_debug(1),qrInfo(i),debug);
        iptSetPointerBehavior(handles.bits, @(hFigure, ~)set(hFigure, 'Pointer', 'cross'));
        handles.bits.ButtonDownFcn = @more_data;
        plot(ax_debug(2),markersPx(:,1),markersPx(:,2),[markers_c 'o'],'LineWidth',2);
    end
end
% Get overall image transform
mask = ~isnan(markersQRAct(1,1,:));
npoints = 0;
im2QRT = affine2d.empty();
pos = NaN(1,2);
err = NaN(1,2);
if any(mask(:))
    % Remvoing instead of keeping retains array shape (3x2xN)
    markersImAct = markersImAct(:,:,mask);
    markersQRAct = markersQRAct(:,:,mask);
    % 1) shiftdim:  2xNx3; to get x,y dim first
    % 2) reshape:   2x3N ; grouped by marker first, then QR index
    % 3) transpose: 3Nx2 ; dim fitgeotrans wants
    markersImAct = reshape(shiftdim(markersImAct,1),2,[])';
    markersQRAct = reshape(shiftdim(markersQRAct,1),2,[])';
    im2QRT = fitgeotrans(markersImAct,markersQRAct,'nonreflectivesimilarity');
    % Calculate position and error in control points
    pos = transformPointsForward(im2QRT, [0,0]);
    markers_theory = transformPointsForward(im2QRT, markersImAct);
    err = sqrt(mean((markers_theory-markersQRAct).^2)); % std in x and y
    npoints = size(markersImAct,1);
end
% Prepare output
readInfo = struct('qrInfo',qrInfo,'tform',im2QRT,'std',err,'npoints',npoints);
if p.invert
    readInfo = Base.QR.invertReadInfo(readInfo,p.invert);
end
end


function more_data(obj,eventdata)
if eventdata.Button == 1
[~,D] = knnsearch(eventdata.IntersectionPoint(1:2),[obj.XData; obj.YData]','K',1);
[~,I] = min(D);

f = UseFigure('Base.QR.reader_bit','name','QR Pixel Values',true);
estimate = obj.CData(I);
ax = axes('parent',f); hold(ax,'on')
title(ax,sprintf('Bit Estimate: %g\n|Value - Estimate|: %g',estimate,abs(round(estimate)-estimate)));
histogram(ax,obj.UserData.debug.ref1,'FaceColor','k','EdgeColor','k');
histogram(ax,obj.UserData.debug.ref0,'FaceColor',[0.7 0.7 0.7],'EdgeColor','k');
sz = size(obj.UserData.debug.pxsVals);
[col,row] = ind2sub(sz(1:2),I); % Take into account transpose
histogram(ax,obj.UserData.debug.pxsVals(row,col,:),...
    'FaceColor',[0.8500 0.3250 0.0980],'EdgeColor',[0.8500 0.3250 0.0980]);
xlabel(ax,'Pixel Value');
legend(ax,{'Ref1','Ref0','Bit'},'Location','northwest');
figure(f);
end
end