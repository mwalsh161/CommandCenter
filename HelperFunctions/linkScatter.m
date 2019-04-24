function linkScatter(scatterObjs,varargin)
%LINKSCATTER Link highlighting of scatter plots
%   Given a set of scatter plots with the same number of points, link the
%   datasets in a way that selecting points on any of them will highlight
%   those points on all of them.
%   Input *(arg) indicates optional positional; [arg] indicates name,value:
%     - scatterObjs: the array of scatter plot handles to link
%     - (reset): string "reset" to remove linkScatter functionality from
%       all supplied scatterObjs and restore state prior to initializing
%       linkScatter (specifically ButtonDownFcn and BusyAction). Resetting
%       any scatter plot in a link set results in resetting them all.
%     - [linewidth_factor]: factor to change linewidth by (default 5)
%     - [all others]: piped to the overlaid (hittest off) highlighted
%       scatter. This is applied after the default setting, so it can
%       override it and/or complement it. The default is to multiply
%       linewidth by linewidth_factor
%   NOTE: LINKSCATTER will use UserData of each of the scatter objects to
%   store the previous state. Specifically, it will use a struct field
%   named linkScatter. If UserData is not a struct and is not empty, it
%   will error.
%   Interactivity:
%     - Clicking on a data point will select it (removing all others)
%     - Right clicking will add/remove points to the selection
%
%   EXAMPLES:
%     - Make the linewidth 10 times larger
%       linkScatter(scatterObjs,'linewidth_factor',10)
%     - Fill the circle (note this also changes linewidth)
%       linkScatter(scatterObjs,'MarkerFaceColor','flat')
%     - Same as above, but keeping linewidth the same
%       linkScatter(scatterObjs,'MarkerFaceColor','flat','linewidth_factor',1)
%
%   ENHANCEMENTS: make box selection!

persistent p
if isempty(p) % Avoid having to rebuild on each function call
    p = inputParser();
    p.KeepUnmatched = true;
    addOptional(p,'reset','',@(x)any(validatestring(x,{'reset'})));
    addParameter(p,'linewidth_factor',5,@(x) isnumeric(x) && numel(x)==1);
end
parse(p,varargin{:});
assert(isa(scatterObjs,'matlab.graphics.chart.primitive.Scatter'),'scatterObjs must be array of scatter plot handles');
% We have validated all the necessary data here to reset
if ~isempty(p.Results.reset)
    arrayfun(@clean_up,scatterObjs);
    return
end
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
% Map a struct back into a cell aray of name, value pairs
user_settings = {};
input_keys = fields(p.Unmatched);
for i = 1:length(input_keys)
    user_settings{end+1} = input_keys{i};
    user_settings{end+1} = p.Unmatched.(input_keys{i});
end

% Link up interactivity
scatterObjs(1).UserData.linkScatter.selected = []; % This will be the master list
for i = 1:length(scatterObjs)
    % For each scatter obj, we will keep the list of all scatter objs, and
    % just know in the callbacks that the first one in the list is the master
    scatterObjs(i).UserData.linkScatter.others = scatterObjs;
    % Make another scatter object that is not clickable but is the "mask"
    ax = get_axes(scatterObjs(i));
    held = ishold(ax); hold(ax,'on');
    sc = scatter(scatterObjs(i).Parent,[],[],'hittest','off','pickableparts','none','HandleVisibility','off');
    if ~held; hold(ax,'off'); end
    set(sc,'CData',scatterObjs(i).CData(1,:),... % Grab first row only [if multiple rows, updated in highlight]
           'LineWidth',p.Results.linewidth_factor*scatterObjs(i).LineWidth,...
           'Marker',scatterObjs(i).Marker,...
           'MarkerEdgeAlpha',scatterObjs(i).MarkerEdgeAlpha,...
           'MarkerEdgeColor',scatterObjs(i).MarkerEdgeColor,...
           'MarkerFaceAlpha',scatterObjs(i).MarkerFaceAlpha,...
           'MarkerFaceColor',scatterObjs(i).MarkerFaceColor);
    if ~isempty(user_settings)
        set(sc,user_settings{:}); % This will also serve as a validation on varargin
    end
    sc.UserData = user_settings;
    scatterObjs(i).UserData.linkScatter.highlighter = sc;
    % Store state to use on reset
    scatterObjs(i).UserData.linkScatter.ButtonDownFcn = scatterObjs(i).ButtonDownFcn;
    scatterObjs(i).UserData.linkScatter.BusyAction = scatterObjs(i).BusyAction;
end
set(scatterObjs,'ButtonDownFcn',@point_clicked_callback,'BusyAction','cancel');
end

%%% Helpers
function clean_up(sc)
if isstruct(sc.UserData) && isfield(sc.UserData,'linkScatter')
    sc.ButtonDownFcn = sc.UserData.linkScatter.ButtonDownFcn;
    sc.BusyAction = sc.UserData.linkScatter.BusyAction;
    delete(sc.UserData.linkScatter.highlighter);
    % Grab it before we clean the field, but delete after the field is
    % cleaned to avoid recursion (see next comment)
    others = sc.UserData.linkScatter.others;
    sc.UserData = rmfield(sc.UserData,'linkScatter');
    % Clean up all in this set; note this may be redundant with the
    % original call to linkScatter(...,'reset'), but the if statement at
    % the beginning of this method will allow it.
    arrayfun(@clean_up,others);
end
end

function sc = get_axes(sc)
while ~isempty(sc) && ~strcmp('axes', get(sc,'type'))
  sc = get(sc,'parent');
end
end

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
    if ~isempty(hl.UserData)
        set(hl,hl.UserData{:});
    end
end
end

%%% Callbacks
function point_clicked_callback(hObj,eventdata)
scatterObjs = hObj.UserData.linkScatter.others;
[~,D] = knnsearch(eventdata.IntersectionPoint(1:2),[hObj.XData; hObj.YData]','K',1);
[~,this_ind] = min(D);
% See if it is already in selected set
inds = scatterObjs(1).UserData.linkScatter.selected;
already_selected = this_ind==inds;
switch eventdata.Button
    case 1
        inds = this_ind;
    case 3
        if any(already_selected) % Then remove them
            inds(already_selected) = [];
        else
            inds(end+1) = this_ind;
        end
end
scatterObjs(1).UserData.linkScatter.selected = inds;
highlight(scatterObjs,inds);
end