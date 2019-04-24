function linkScatter(scatterObjs,varargin)
%LINKSCATTER Link highlighting of scatter plots
%   Given a set of scatter plots with the same number of points, link the
%   datasets in a way that selecting points on any of them will highlight
%   those points on all of them.
%   Input:
%     - scatterObjs: the array of scatter plot handles to link
%     - [linewidth_factor]: factor to change linewidth by (default 2)
%     - [all others]: piped to the overlaid (hittest off) highlighted
%       scatter. This is applied after the default setting, so it can
%       override it and/or complement it. The default is to multiply
%       linewidth by linewidth_factor
%   NOTE: LINKSCATTER will use UserData of each of the scatter objects to
%   store the previous state. Specifically, it will use a struct field
%   named linkScatter. If UserData is not a struct and is not empty, it
%   will error.
%   Interactivity:
%     - Clicking on a data point will select it
%     - Drawing a box by clicking and dragging on the axes will select
%       anything in that box.
%     - Holding shift while clicking or drawing a box will make a new
%       selection that includes the old selection as well. If a point was
%       in the old selection and in the new selection it will be
%       unselected.
%   NOTE: This does not clean up callbackfcn's set

persistent p
if isempty(p) % Avoid having to rebuild on each function call
    p = inputParser();
    p.KeepUnmatched = true;
    addParameter(p,'linewidth_factor',2,@(x) isnumeric(x) && numel(x)==1);
end
parse(p,varargin{:});
assert(isa(scatterObjs,'matlab.graphics.chart.primitive.Scatter'),'scatterObjs must be array of scatter plot handles');

% Check that data is same length in all of scatterObjs and that it is >0
data_lengths = arrayfun(@(x)length(x.XData),scatterObjs);
assert(~any(data_lengths==0),'One or more scatterObjs has no data.')
assert(all(data_lengths==data_lengths(1)),'Not all scatterObjs have the same Data length.')
% Check that UserData is available in all scatterObjs
for i = 1:length(scatterObjs)
    if isstruct(scatterObjs(i).UserData) && isfield(scatterObjs(i).UserData,'linkScatter')
        error('One or more of scatterObjs already has a linkScatter field in UserData.')
    elseif ~isstruct(scatterObjs(i).UserData) && ~isempty(scatterObjs(i).UserData)
        error('One or more of scatterObjs UserData is not a struct and is not empty.')
    end
end

% Link up interactivity
set(scatterObjs,'ButtonDownFcn',@clicked_callback);
scatterObjs(1).UserData.linkScatter.selected = []; % This will be the master list
for i = 1:length(scatterObjs)
    % For each scatter obj, we will keep the list of all scatter objs, and
    % just know in the callbacks that the first one in the list is the master
    scatterObjs(i).UserData.linkScatter.others = scatterObjs;
    % Make another scatter object that is not clickable but is the "mask"
    sc = scatter(scatterObjs(i).Parent,[],[]);
    set(sc,'CData',scatterObjs(i).CData(:,1),... % Grab first row only [if multiple rows, updated in highlight]
           'LineWidth',p.Results.linewidth_factor*scatterObjs(i).LineWidth,...
           'Marker',scatterObjs(i).Marker,...
           'MarkerEdgeAlpha',scatterObjs(i).MarkerEdgeAlpha,...
           'MarkerEdgeColor',scatterObjs(i).MarkerEdgeColor,...
           'MarkerFaceAlpha',scatterObjs(i).MarkerEdgeAlpha,...
           'MarkerFaceColor',scatterObjs(i).MarkerEdgeColor)
    set(sc,p.Unmatched{:}); % This will also serve as a validation on varargin
    sc.UserData = p.Unmatched;
    scatterObjs(i).UserData.linkScatter.highlighter = sc;
end

end
%%% Helpers
function highlight(scatterObjs,inds)
for i = 1:length(scatterObjs)
    hl = scatterObjs(i).UserData.linkScatter.highlighter;
    % Update XData, YData, CData, SizeData then user supplied settings
    set(hl,'XData', scatterObjs(i).XData(inds),...
           'YData', scatterObjs(i).YData(inds));
    if size(scatterObjs(i).CData,1)>1
        hl.CData = scatterObjs(i).CData(inds,:);
    end
    if length(scatterObjs(i).SizeData)>1
        hl.SizeData = scatterObjs(i).SizeData(inds);
    end
    set(hl,hl.UserData{:});
end
end

%%% Callbacks
function clicked_callback(hObj,eventdata)
scatterObjs = hObj.UserData.linkScatter.others;
this_ind = NaN;
if length(eventdata.Modifier)==1 && strcmp(eventdata.Modifier{1},'shift')
    inds = scatterObjs(1).UserData.linkScatter.selected;
    already_selected = this_ind==inds;
    if any(already_selected) % Then remove them
        inds(already_selected) = [];
    else % Add this one to the list
        inds(end+1) = this_ind;
    end
else % Only this one
    inds = this_ind;
end
scatterObjs(1).UserData.linkScatter.selected = inds;
highlight(scatterObjs,inds);
end