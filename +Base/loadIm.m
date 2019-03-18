function [ fig,t ] = loadIm(image_file,figName,varargin)
%LOAD Creates loading figure with text handle at the bottom.
fig = figure('numbertitle','off','name',figName,'MenuBar','None',...
    'toolbar','None','resize','off');
imshow(image_file,varargin{:})
im = imread(image_file);
xlim = size(im,2);
ymax = size(im,1);
t = text(xlim/2,ymax*0.99,'Initializing GUI','verticalalignment','bottom','HorizontalAlignment','center','color','w');
end

