function [im,aborted,altered] = uimaskim(im,varargin)
%UIMASKIM Interactively mask/crop regions of CC image
%   im corresponds to the "info" property of Base.SmartImage
%   This function will read the "ROI" field and alter the "image" field by
%       replacing values with NaN that end up getting masked
%   Optionally, the user can specify a callback method as the second
%       argument: uimask(im,@draw). The draw method will have a single input,
%       the axes (which will already be held) in which the user can do anything
%       but delete the current image on it.
%   Clicking exit (the "X"), will abort the masking and return the original
%       image.

aborted = true;
altered = false;
f = figure('toolbar','none','closerequest',@confirm_close);
DRECT = [];
draw_callback = [];
if nargin == 2
    if isa(varargin{1},'function_handle')
        draw_callback = varargin{1};
    else
        error('Second (optional) argument must be a function handle.');
    end
end

%%%%%%%%% FOR UPGRADE IN FUTURE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% icon_path = fullfile(matlabroot, 'toolbox','images','icons');
% tb = uitoolbar(f);
% C = imread(fullfile(icon_path,'draw_assistedFreehand_24.png')); C(C==0) = 255;
% opt(1) = uitoggletool(tb,'CData',C,'TooltipString','Polygon',...
%     'State','on','OnCallback',[]);
% C = imread(fullfile(icon_path,'draw_rectangle_24.png')); C(C==0) = 255;
% opt(2) = uitoggletool(tb,'CData',C,'TooltipString','Rectangle',...
%     'OnCallback',[]);
% tool = opt(1);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

ax = axes('parent',f);
imH = imagesc(ax,im);

cm = uicontextmenu(f);
newR = uimenu(cm,'label','New Region','callback',@new_region,'enable','off');
keep(1) = uimenu(cm,'label','Keep Inside','callback',@keep_inside);
keep(2) = uimenu(cm,'label','Keep Outside','callback',@keep_outside);
uimenu(cm,'label','Finished','callback',@finished,'separator','on');
imH.UIContextMenu = cm;
f.UIContextMenu = cm;
if ~isempty(draw_callback)
    hold(ax,'on');
    try
        draw_callback(ax);
    catch err
        delete(f);
        rethrow(err);
    end
    assert(isvalid(imH),'Original image to be modified was deleted.');
end
new_region();

% When finished, grab new CData
if ~isvalid(f) % Catch any scenario user closes unexpectedly
    return % Aborts any masking already done
end
im.image = imH.CData;
aborted = false;
delete(f);

    % Update imH directly
    function finished(~,~)
        if ~altered
            resp = questdlg(['No changes have been made yet. Return original image?' newline,...
                'Cancel to use context menu to continue editing image.'],'uimaskim: No Changes Detected','Yes','Cancel','Cancel');
            if strcmp(resp,'Cancel')
                return
            end
        end
        delete(DRECT);
        uiresume(f);
    end
    function new_region(~,~)
        set(newR,'enable','off'); set(keep,'enable','on');
        title(ax,'Draw Rectangle');
        DRECT = drawrectangle(ax,'deletable',false,'rotatable',true);
        if isvalid(f) % Catch any scenario user closes unexpectedly
            title(ax,'When ready, make selection in context menu (right click)');
            uiwait(f);
        end
    end
    function keep_inside(~,~)
        mask = make_mask();
        imH.CData(~mask) = NaN;
        clean_region();
    end
    function keep_outside(~,~)
        mask = make_mask();
        imH.CData(mask) = NaN;
        clean_region();
    end
    function confirm_close(~,~)
        resp = questdlg('Abort image masking (original image will be returned)?','uimaskim: Abort','Yes','Cancel','Yes');
        if strcmp(resp,'Yes')
            delete(f);
        end
    end

    % Helpers
    function in_mask = make_mask(~,~)
        sz = size(imH.CData);
        [X,Y] = meshgrid(1:sz(2),1:sz(1));
        [X,Y] = sub2world(im, Y(:), X(:));
        in_mask = inpolygon(X(:), Y(:), DRECT.Vertices(:,1), DRECT.Vertices(:,2));
        in_mask = reshape(in_mask,sz);
    end
    function clean_region
        altered = true;
        delete(DRECT);
        set(newR,'enable','on'); set(keep,'enable','off');
        title(ax,'Make selection in context menu (right click)');
    end

end