function [scatterH,f] = imfindpeaks( imH,varargin )
%IMFINDPEAKS Interactively adjust image contrast and filtering to find
%peaks. This does change imH.CData!
%   IMFINDPEAKS(imH)
%   IMFINDPEAKS(imH,default)
%   IMFINDPEAKS(imH,varargin)
%   IMFINDPEAKS(imH,default,varargin)
%   example input:
%       f = figure;
%       ax_temp = axes('parent',f); 
%       imH = imagesc(image,'parent',ax_temp);
%
%     - default is a struct with optional fields: sigmas, thresh, clim
%     - varargin is piped directly to scatter(__,varargin)
%   Modifies imcontrast figure to add gaussian bandpass filtering options.
%   Uses fastpeakfind to plot candidates on image.
%   varargin inputs piped directly to scatter (candidate locations)
%   Returns handle to candidate scatter plot. Scatter plot handle also
%   holds sigmas for lowpass and highpass filters respectively in
%   UserData.sigmas. UserData.thresh also stored here for completeness.
%       thresh has two values: [lower, thresh]
%       where anything below lower is railed to lower, second thresh goes
%         to FASTPEAKFIND
%
%   mean(CLim) is used as thresh to FASTPEAKFIND
%
%   Tips: Grab locations using scatterH.XData, scatterH.YData.
%         Once locations grabbed, safe to delete scatterH
%         Use UIWAIT(f) to make this blocking until IMFINDPEAKS is closed

assert(all(isa(imH.CData,'double')),'Image must be type double.')
% Parse input
default = [];
if ~isempty(varargin) && isstruct(varargin{1})
    default = varargin{1};
    varargin(1) = [];
end

% Get axes of image and build scatterH
ax = imH;
while ~isa(ax,'matlab.graphics.axis.Axes')
    ax = ax.Parent;
end
isheld = ishold(ax);
hold(ax,'on');
scatterH = scatter(ax,NaN,NaN,varargin{:});
if ~isheld
    hold(ax,'off');
end

% Build main control figure
f = imcontrast(imH);
f.Name = 'Adjust Contrast, Filter and Find Peaks';
f.Tag = mfilename;
container = findall(f,'tag','window clip panel');
panel = uipanel(container,'title','Bandpass Filter');
set(panel,'units','pixels','position',[6 6 550 50]);
uicontrol(panel,'style','text','string','Low Pass (spatial):',...
    'position',[6 6 100 20]);
bpH(1) = uicontrol(panel,'style','edit','string','NaN','tag','lowpass',...
    'position',[112 6 100 20],'callback',@(hObj,~)set_bppass(hObj,1));
uicontrol(panel,'style','text','string','High Pass (spatial):',...
    'position',[230 6 100 20]);
bpH(2) = uicontrol(panel,'style','edit','string','NaN','tag','highpass',...
    'position',[336 6 100 20],'callback',@(hObj,~)set_bppass(hObj,2));
uicontrol(panel,'style','text','string','Units are same as XData/YData.',...
    'position',[460 -15 85 50]);

% Setup listener for peakfinding
lis = addlistener(ax,'CLim','PostSet',@(~,~)peakfind(f));
lis.Enabled = false;

% All handles are handle objects, so never need to be "resaved"
scatterH.UserData.sigmas = [NaN,NaN];  % [lowpass,highpass] (allows user to grab values when done)
scatterH.UserData.thresh = NaN;
handles.bpH = bpH;           % Handles to low/high pass edit box
handles.im = imH;
handles.scatterH = scatterH;
handles.originalCData = imH.CData;
handles.lis = lis;
handles.panel = panel;       % Keep track of spots found in title of panel
guidata(f,handles);

% Setup defaults
if ~isempty(default)
    if isfield(default,'thresh');scatterH.UserData.thresh = default.thresh; end
    if isfield(default,'sigmas')
        scatterH.UserData.sigmas = default.sigmas;
        bpH(1).String = default.sigmas(1);
        set_bppass(bpH(1),1)
        bpH(2).String = default.sigmas(2);
        set_bppass(bpH(2),2)
    end
    if isfield(default,'clim'); set(ax,'clim',default.clim); end
end
lis.Enabled = true;
% Setup closing callbacks
addlistener(f,'ObjectBeingDestroyed',@(~,~)cleanUp(handles));

% Run
peakfind(f)
end

function cleanUp(handles)
delete(handles.lis)
end

function set_bppass(hObj,sigmaI)
handles = guidata(hObj);
sigmas = handles.scatterH.UserData.sigmas;
% Note: "sigmas" are the new values, "handles.scatterH.UserData.sigmas" are old values
sigmas(sigmaI) = str2double(get(hObj,'String'));

if sigmas(1) > sigmas(2)
    set(hObj,'String',handles.scatterH.UserData.sigmas(sigmaI)) % Set to old value
    error('Low pass value cannot go below high pass.')
end
try
    set(handles.bpH,'enable','off'); drawnow;
    perform_filter(sigmas(1),sigmas(2),handles.im,handles.originalCData)
catch err
    set(handles.bpH,'enable','on')
    set(hObj,'String',handles.scatterH.UserData.sigmas(sigmaI)) % Set to old value
    rethrow(err)
end
set(handles.bpH,'enable','on')
handles.scatterH.UserData.sigmas = sigmas; % Update handles to new value
guidata(hObj,handles)
end

function perform_filter(lp,hp,imH,original)
% Convert lp and hp to px
x = imH.XData([1 end]);
y = imH.YData([1 end]);
cal = mean((size(original)-1)./[diff(y) diff(x)]);
if lp > 0
    im_filt = imgaussfilt(original,lp*cal);
else
    im_filt = original;
end

if hp ~= 0 && isfinite(hp)
    im_filt = im_filt - imgaussfilt(im_filt,hp*cal);
end
imH.CData = im_filt;
drawnow limitrate;
end

function peakfind(hObj)
handles = guidata(hObj);
im = handles.im.CData;
clim = handles.im.Parent.CLim;
im(im<clim(1)) = clim(1);  % Cap the floor (capping peaks will hurt peak detection)
thresh = mean(clim);
handles.scatterH.UserData.thresh = [clim(1) thresh];
candidates = FastPeakFind(im,thresh);
if isempty(candidates)
    handles.scatterH.XData = NaN;
    handles.scatterH.YData = NaN;
else
    candidates = [candidates(1:2:end) candidates(2:2:end)];
    % Switch px -> units
    x = handles.im.XData([1 end]);
    y = handles.im.YData([1 end]);
    cal = (fliplr(size(handles.im.CData))-1)./[diff(x) diff(y)];
    candidates = (candidates-1)./cal + [x(1) y(1)];
    handles.scatterH.XData = candidates(:,1);
    handles.scatterH.YData = candidates(:,2);
end
handles.panel.Title = ['Bandpass Filter (' num2str(size(candidates,1)) ' peaks)'];
drawnow limitrate
end