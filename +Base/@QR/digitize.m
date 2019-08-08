function [codeOut] = digitize(im,unit2pxT,ax_debug)
modSize = Base.QR.module_size;  % um
numMods = sqrt(Base.QR.length);
d = Base.QR.d;

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

pos = transformPointsForward(unit2pxT,[X Y]);
posMod = [Xmod(:) Ymod(:)]*unit2pxT.T(1:2,1:2); % Centered around zero

% Find Sequence
pos = round(pos);       % Convert to pixel index
posMod = unique(round(posMod),'row');

rawVals = zeros(size(posMod,1)+1,size(pos,1));
for i = 1:size(pos,1)
    temp = [pos(i,:); pos(i,:) + posMod];
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

if isvalidax(ax_debug)
    plot(ax_debug,pos(1,1),pos(1,2),'m*');
    scatter(ax_debug,pos(:,1),pos(:,2),36,ones(size(code,1),3).*code_median',...
        'LineWidth',1.5);
    scatter(ax_debug,pos(1,1)+posMod(:,1),pos(1,2)+posMod(:,2),10,[0 0 1]);
    if iscell(ax_debug.Title.String)
        line_one = ax_debug.Title.String{1};
    else
        line_one = ax_debug.Title.String;
    end
    line_one = [line_one newline];
    title(ax_debug,[line_one 'Datacursor for bits contains median value before digitization']);
    dcm_obj = datacursormode(ax_debug.Parent);
    set(dcm_obj,'UpdateFcn',@tooltip_fn)
end

% Make sure border is all 0
valCol = codeOut([1,end],1:end);
valRow = codeOut(1:end,[1,end]);
codeOut = codeOut(2:end-1,2:end-1);
codeOut = codeOut';
codeOut = reshape(codeOut,[1 Base.QR.length]);
assert(~(sum(valCol(:))+sum(valRow(:))),'Border is nonzero.')

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