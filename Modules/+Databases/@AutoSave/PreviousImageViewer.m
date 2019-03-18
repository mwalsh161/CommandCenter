function PreviousImageViewer(obj,hObj,varargin)
%PREVIOUSIMAGEVIEWER Summary of this function goes here
%   Parse the image database (note a0 is a placeholder and not useful).

if obj.nImages < 1
    error('No images taken yet!')
end

[~,CC] = gcbo;
% Build Simple GUI
fig = figure('numbertitle','off');
fig.UserData.obj = obj;
fig.UserData.n = obj.nImages;
fig.UserData.nImages = obj.nImages;
fig.UserData.Managers = CC.UserData;
set(fig,'KeyPressFcn',@arrowCallback)
% Configure settings for save
db = fig.UserData.Managers.DB;
delete(findall(fig,'tag','figMenuFileSaveAs'))
set(findall(fig,'tag','figMenuFileSave'),'callback',@(hObj,eventdata)db.imSave(false,hObj,eventdata))
set(findall(fig,'tag','Standard.SaveFigure'),'ClickedCallback',@(hObj,eventdata)db.imSave(false,hObj,eventdata))
% Make the open icon open file location
if ispc
    set(findall(fig,'tag','Standard.FileOpen'),'tooltipstring','Open file location','enable','off')
    % Have open_im set the callback
else
    set(findall(fig,'tag','Standard.FileOpen'),'tooltipstring','Open file location available on PC only','enable','off')
end
open_im(fig)
end

function arrowCallback(fig,eventdata)
switch eventdata.Key
    case {'rightarrow','uparrow'}
        fig.UserData.n = min(fig.UserData.n+1,fig.UserData.nImages);
    case {'leftarrow','downarrow'}
        fig.UserData.n = max(fig.UserData.n-1,1);
end
open_im(fig)
end

function open_im(fig)
% Need to get ImagingManger to get colormap
obj = fig.UserData.obj;
if ~isvalid(obj) % Means autosave destroyed
    set(fig,'KeyPressFcn','')
    obj.error('Standalone mode - KeyPressFcn removed.')
end
path = obj.previousImagesDB.old(1,fig.UserData.n);
path = path{1};
clf(fig)
[folder,fname,ext] = fileparts(path); fname = [fname ext];
set(fig,'name',sprintf('SmartImage %i: %s',fig.UserData.n,fname))
NewAx = axes('parent',fig);
title(NewAx,sprintf('Left/right keys to navigate %i/%i image.',fig.UserData.n,obj.nImages))
if isempty(path)
    return
end
if ispc
    set(findall(fig,'tag','Standard.FileOpen'),'ClickedCallback',@(~,~)winopen(folder),'enable','on')
end
try
    im = load(path);
    im = im.image;
catch err
    obj.previousImagesDB.old(1,fig.UserData.n) = {''};
    error('Marked for deletion (clean up at destruction).\n%s',err.message)
end
CC = findall(0,'name','CommandCenter');
x = [im.ROI(1,1) im.ROI(1,2)];
y = [im.ROI(2,1) im.ROI(2,2)];
if isempty(CC)
    imagesc(x,y,im.image)
    return
end
Managers = CC.UserData;
colormap(fig,Managers.Imaging.set_colormap)
try
    Base.SmartImage(im,NewAx,Managers.Stages,Managers.Imaging);
    title(NewAx,sprintf('Left/right keys to navigate %i/%i image.',fig.UserData.n,obj.nImages))
catch err
    obj.error('SmartImage could not open %s:\n%s',path,err.message)
end
if isfield(im,'notes')
    xlabel(im.notes);
end
end