function [varargout] = imagesc(varargin)
%IMAGESC Wraps MATLAB's imagesc to accept a CC image struct
%   Specifically, CC image struct is the "info" property of Base.SmartImage
%   Adds support for calling imagesc(ax,imCC,___) or imagesc(imCC,___)

func_path = fullfile(matlabroot, 'toolbox','matlab','specgraph');

i = 1; % imagesc(imCC,...)
if ~isempty(varargin) && isa(varargin{1},'matlab.graphics.axis.Axes')
    i = 2; % imagesc(ax, imCC,...)
end
imCC_used = false;
if nargin >= i && isstruct(varargin{i}) % Replace imCC with {x, y, C}
    varargin = [varargin(1:i-1),...
                varargin{i}.ROI(1,:),...
                varargin{i}.ROI(2,:),...
                varargin{i}.image, varargin(i+1:end)];
	imCC_used = true;
end

wrn = warning('off','MATLAB:dispatcher:nameConflict');
oldPath = cd(func_path);
try
    im = imagesc(varargin{:});
    if imCC_used && isa(im.Parent,'matlab.graphics.axis.Axes')
        set(im.Parent,'ydir','normal');
        axis(im.Parent,'image');
    end
catch err
end
cd(oldPath)
warning(wrn.state,'MATLAB:dispatcher:nameConflict');

if exist('err','var')
    rethrow(err)
end

varargout = {};
if nargout == 1
    varargout = {im};
end
end

    
