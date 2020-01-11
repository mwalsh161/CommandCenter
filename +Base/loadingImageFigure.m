function [fig, t] = loadingImageFigure(image_file, figName, varargin)
    %LOADIM Creates loading figure with text handle at the bottom.
    im = imread(image_file);
    xlim = size(im,2);
    ymax = size(im,1);
    
    fig = figure('numbertitle', 'off', 'name', figName, 'Pointer', 'watch', 'MenuBar', 'None',...
                 'toolbar', 'None', 'resize', 'off', 'Visible', 'off', 'KeyPressFcn', '', 'CloseRequestFcn', '');

    fig.Position(4) = fig.Position(3)*ymax/xlim;        % Make the same aspect ratio.
             
    axes('Units', 'Normalized', 'Position', [0 0 1 1]); % Maximize axes to this aspect ratio
             
    imshow(image_file, varargin{:})
    
    t = text(xlim/2, ymax*0.975, 'Initializing GUI',...
                'VerticalAlignment', 'middle', 'HorizontalAlignment','center','Color','w');
            
    fig.Visible = 'on'; drawnow;
end
