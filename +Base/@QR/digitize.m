function [codeOut] = digitize(im,offset,R,ax)
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
code = zeros(1,(sqrt(Base.QR.length)+2)^2);
rawVals = zeros(1,size(pos,1)*n^2);
avgVals = zeros(1,size(pos,1));
for i = 1:size(pos,1)
    val = zeros(1,n^2+1);
    val(1) = double(im(pos(i,2),pos(i,1)));
    for j = 1:size(posMod,1)
        val(j+1) = im(posMod(j,2)+pos(i,2),posMod(j,1)+pos(i,1));
    end
    rawVals((i-1)*(n^2+1)+1:(i)*(n^2+1)) = val;
    val = sort(val);
    avgVals(i) = mean(val(1:round(end/2))); % Weight to dark
end
high = max(avgVals);               % Bright
low = min(avgVals);                % Dark
threshs = NaN(1,numel(avgVals));
for i = 1:numel(avgVals)
    valAvg = avgVals(i);
    threshs(i) = 0.6*high+0.4*low; % Weight to dark
    if valAvg > threshs(i)
        high = 0.1*high + 0.9*valAvg;
        code(i) = false;
    else
        low = 0.1*low + 0.9*valAvg;
        code(i) = true;
    end
end
%figure; plot(avgVals);hold on; plot(threshs,'r');
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
    color = 'b';
    err = [];
    assert(~(sum(valCol(:))+sum(valRow(:))),'Border is nonzero.')
    
    assert(logical(sum(codeOut(:)))||sum(codeOut(:))==numel(codeOut),'All bits are the same.')
catch err
    color = 'r';
end
if isa(ax,'matlab.graphics.axis.Axes')&&isvalid(ax)
    allpos = [pos;markers];
    xlim = round([min(allpos(:,1))*0.95 max(allpos(:,1))*1.05]);
    ylim = round([min(allpos(:,2))*0.95 max(allpos(:,2))*1.05]);
    plot(ax,pos(1,1),pos(1,2),'r*')
    plot(ax,markers(:,1),markers(:,2),[color 'o'])
    if color=='b'  % Only plot bits if it was successful
        for i = 1:numel(code)
            if code(i)
                %        for j = 1:size(posMod,1)
                %            plot(posMod(j,1)+pos(i+1,1),posMod(j,2)+pos(i+1,2),'w.')
                %        end
                plot(ax,pos(i,1),pos(i,2),'wo')
            else
                %        for j = 1:size(posMod,1)
                %            plot(posMod(j,1)+pos(i+1,1),posMod(j,2)+pos(i+1,2),'k.')
                %        end
                plot(ax,pos(i,1),pos(i,2),'ko')
            end
        end
    end
    drawnow nocallbacks
end
if ~isempty(err)
    rethrow(err)
end
end

