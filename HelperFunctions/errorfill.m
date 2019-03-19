function varargout = errorfill(x,y,err,varargin)
%errorfill Plots in errorbar-style, but with filled in regions instead of
%with bars
%   Usage is like that of errorbar, with first three inputs specifying x, 
%   y, and error shading size in analog with errorbar. After that, properties
%   of both the central data line (of type 'plot') and the shading object
%   (of type 'fill') can be specified pairwise.

props = varargin(1:2:end);
vals = varargin(2:2:end);
assert(length(props)==length(vals),'Property specifications must be pairwise');
assert(length(unique(props))==length(props),'Duplicate property specifications');

LIA = ismember(lower(props),'parent'); %find if a parent axes was specified
if sum(LIA)==0
    ax = gca;
else
    ax = vals{LIA};
    props(LIA) = [];
    vals(LIA) = [];
end
held = ishold(ax); %determine if the axes are being held
if ~held
    cla(ax,'reset'); %to emulate the 'replace' behavior
end
if isempty(props) || ~ismember('edgealpha',lower(props))
    props{end+1} =  'EdgeAlpha';
    vals{end+1} = 0; %default transparent edges
end
if isempty(props) || ~ismember('facealpha',lower(props))
    props{end+1} =  'FaceAlpha';
    vals{end+1} = 0.35; %default transparency
end
out = hggroup(ax,'Tag',mfilename);
    
upperbounds = y(:)+err(:);
lowerbounds = y(:)-err(:);

bounds = vertcat([x(:),upperbounds(:)],flipud([x(:),lowerbounds(:)]));

p = plot(out,x,y);
validplotprops = ismember(lower(props),lower(fieldnames(set(p))));
propcell = [props(validplotprops);vals(validplotprops)];
if ~isempty(propcell)
    [~] = set(p,propcell{:});
end


if sum(isnan([x(:);y(:);err(:)])) == 0
    held = ishold(ax);
    hold(ax,'on');
    f = fill(out,bounds(:,1),bounds(:,2),p.Color);
    validfillprops = ismember(lower(props),lower(fieldnames(set(f))));
    propcell = [props(validfillprops);vals(validfillprops)];
    [~] = set(f,propcell{:}); %there will always be at least FaceAlpha already
    if ~held
        hold(ax,'off');
    end
    uistack(p); %bring plot aline ahead of fill
else
    warning('NaNs in data prevent errorfilling; please remove before inputting')
end

if nargout
    varargout = {out};
end

end

