function [codeOut] = digitize(im,offset,R,ax,ax_debug)
modSize = Base.QR.module_size;  % um
numMods = sqrt(Base.QR.length);
spacing = Base.QR.spacing;
d = Base.QR.d;
if nargin < 4
    ax = false;
end

% Generate coordinates for center of module
[Y,X] = meshgrid(linspace(modSize*(numMods+1),0,numMods+2),...
                 linspace(0,modSize*(numMods+1),numMods+2)); % Starts from top left and rasters down
% Generate coordinates for each square (will need to be translated)
n = 10;
[Ymod,Xmod] = meshgrid(linspace(-modSize/4,modSize/4,n));
for i = 1:numMods/2
    X(:,i*2) = flipud(X(:,i*2));
end
X = X(:)+d-modSize/2;
Y = Y(:)+d-modSize/2;
posMod = [Xmod(:) Ymod(:)]*R;                 % Centered at zero
pos = [X Y]*R;
pos(:,1) = pos(:,1)+offset(1);
pos(:,2) = pos(:,2)+offset(2);

% Markers location
markers = [0,0;0,spacing;spacing,0];
markers = markers*R;
markers(:,1) = markers(:,1)+offset(1);
markers(:,2) = markers(:,2)+offset(2);

% Find Sequence
pos = round(pos);       % Convert to pixel index
posMod = round(posMod);
markers = round(markers);

rawVals = zeros(n^2+1,size(pos,1));
for i = 1:size(pos,1)
    temp = [pos(i,:); pos(i,:)+posMod];
    rawVals(:,i) = im(sub2ind(size(im),temp(:,2),temp(:,1)));
end
bin = reshape(kmeans(rawVals(:),2)-1,size(rawVals));
% kmeans will randomly select clusters, so make sure dark is 1, bright is 0
mask = bin(:) == 0;
if median(rawVals(mask)) < median(rawVals(~mask))
    bin = 1 - bin;
end
code_median = median(bin);
code = logical(round(code_median));

% Reshape
codeOut = reshape(code,[numMods+2 numMods+2])';
for i = 1:numMods/2
    codeOut(i*2,:) = fliplr(codeOut(i*2,:));
end
% Make sure border is all 0
valCol = codeOut([1,end],1:end);
valRow = codeOut(1:end,[1,end]);
codeOut = codeOut(2:end-1,2:end-1);
codeOut = codeOut';
codeOut = reshape(codeOut,[1 Base.QR.length]);
% Look for errors
try
    color = 'g';
    err = [];
    assert(~(sum(valCol(:))+sum(valRow(:))),'Border is nonzero.')
catch err
    color = 'r';
end
add_to_plot(ax_debug,true);
add_to_plot(ax,false);
if ~isempty(err)
    rethrow(err)
end

function add_to_plot(ax,debug)
if isa(ax,'matlab.graphics.axis.Axes')&&isvalid(ax)
    plot(ax,pos(1,1),pos(1,2),'m*');
    plot(ax,markers(:,1),markers(:,2),[color 'o'],'LineWidth',2);
    scatter(ax,pos(:,1),pos(:,2),36,ones(size(code,1),3).*code_median',...
        'LineWidth',1.5);
    if debug
        title(ax,[ax.Title.String newline 'Datacursor for bits contains median value before digitization']);
        dcm_obj = datacursormode(ax.Parent);
        set(dcm_obj,'UpdateFcn',@tooltip_fn)
    end
end
end

end

function txt = tooltip_fn(~,event_obj)
pos = get(event_obj,'Position');
txt = {['X: ',num2str(pos(1))],...
       ['Y: ',num2str(pos(2))]};
if isa(event_obj.Target,'matlab.graphics.chart.primitive.Scatter')
    I = get(event_obj, 'DataIndex');
    txt{end+1} = ['C: ',num2str(event_obj.Target.CData(I))];
end
end