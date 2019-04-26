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
%     - Clicking and dragging will create a rectangle to select everything
%       in the rectangle.
%     - Right clicking for either of the above actions will modify to
%       perform an xor on the new selection and old selection.
%
%   EXAMPLES:
%     - Make the linewidth 10 times larger
%       linkScatter(scatterObjs,'linewidth_factor',10)
%     - Fill the circle (note this also changes linewidth)
%       linkScatter(scatterObjs,'MarkerFaceColor','flat')
%     - Same as above, but keeping linewidth the same
%       linkScatter(scatterObjs,'MarkerFaceColor','flat','linewidth_factor',1)

persistent p
if isempty(p) % Avoid having to rebuild on each function call
    p = inputParser();
    p.KeepUnmatched = true;
    addOptional(p,'reset','',@(x)any(validatestring(x,{'reset'})));
    addParameter(p,'linewidth_factor',5,@(x) isnumeric(x) && numel(x)==1);
end
parse(p,varargin{:});
assert(isa(scatterObjs,'matlab.graphics.chart.primitive.Scatter'),'scatterObjs must be array of scatter plot handles');
assert(all(isvalid(scatterObjs)),'One or more scatterObjs invalid.')
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
input_keys = fields(p.Unmatched);
user_settings = cell(1,length(input_keys)*2);
for i = 1:length(input_keys)
    user_settings{i*2-1} = input_keys{i};
    user_settings{i*2} = p.Unmatched.(input_keys{i});
end

% Link up interactivity
scatterObjs(1).UserData.linkScatter.selected = []; % This will be the master list
for i = 1:length(scatterObjs)
    % For each scatter obj, we will keep the list of all scatter objs, and
    % just know in the callbacks that the first one in the list is the master
    scatterObjs(i).UserData.linkScatter.others = scatterObjs;
    % Make another scatter object that is not clickable but is the "mask"
    ax(i) = get_axes(scatterObjs(i));
    held = ishold(ax(i)); hold(ax(i),'on');
    sc = scatter(scatterObjs(i).Parent,[],[],'hittest','off','pickableparts','none','HandleVisibility','off');
    if ~held; hold(ax(i),'off'); end
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
    scatterObjs(i).UserData.linkScatter.AxButtonDownFcn = ax(i).ButtonDownFcn;
    % If any of scatter objs get deleted; clean up everything
    addlistener(scatterObjs(i),'ObjectBeingDestroyed',@clean_up);
end
set(scatterObjs,'ButtonDownFcn',@point_clicked_callback,'BusyAction','cancel');
% Use mouseTrack to draw selection rectangles (keep in mind this won't
% hinder click callbacks on the objects above the axis (any scatter plot
% data point, for example).
[ax,~,ic] = unique(ax);
errs = MException.empty(1,0);
for i = 1:length(ax)
    try
    mouseTrack(ax(i),'UserData',scatterObjs(ic==i),'n',Inf,...
        'start_fcn',@axes_down_callback,...
        'update_fcn',@mouse_move_callback,...
        'stop_fcn',@(~,~,UserData)delete(UserData.rect)); % simply deletes the rectangle we draw
    catch err
        % Surpress errors here because they are likely releated to already
        % having mouseTrack on one of the target axes; will issue warning
        % at end.
        errs(end+1) = err;
    end
end
if ~isempty(errs)
    msgs = unique({errs.message});
    warning('LINKSCATTER:mouseTrack',...
        'Error(s) occurred attaching mouseTrack to axes:\n%s',...
        strjoin(msgs,newline));
end
end

%%% Helpers
function clean_up(sc,varargin)
try % Allow this to work on objects being deleted (note isvalid = false in that case)
    if isstruct(sc.UserData) && isfield(sc.UserData,'linkScatter')
        sc.ButtonDownFcn = sc.UserData.linkScatter.ButtonDownFcn;
        sc.BusyAction = sc.UserData.linkScatter.BusyAction;
        delete(sc.UserData.linkScatter.highlighter);
        ax = get_axes(sc);
        ax.ButtonDownFcn = sc.UserData.linkScatter.AxButtonDownFcn;
        % Grab it before we clean the field, but delete after the field is
        % cleaned to avoid recursion (see next comment)
        others = sc.UserData.linkScatter.others;
        sc.UserData = rmfield(sc.UserData,'linkScatter');
        % Clean up all in this set; note this may be redundant with the
        % original call to linkScatter(...,'reset'), but the if statement at
        % the beginning of this method will allow it.
        arrayfun(@clean_up,others);
    end
catch err
    if ~strcmp(err,'Invalid or deleted object.')
        rethrow(err);
    end
end
end

function obj = get_axes(obj)
% Given a descendant of an axes, return the axes
while ~isempty(obj) && ~strcmp('axes', get(obj,'type'))
  obj = get(obj,'parent');
end
if ~strcmp('axes', get(obj,'type'))
    obj = [];
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
function UserData = axes_down_callback(ax,eventdata,scs)
    pos = eventdata.AxisPositions(1,:);
    UserData.scs = scs; % scatter objs associated with this axis
    for i = 1:length(scs)
        scatterObjs = scs(i).UserData.linkScatter.others;
        UserData.init_inds{i} = scatterObjs(1).UserData.linkScatter.selected;
    end
    UserData.rect = patch(ax,'vertices',[pos;pos;pos;pos],...
        'faces',[1,2,3,4],'facealpha',0,'HandleVisibility','off');
end
function mouse_move_callback(~,eventdata,UserData)
    pos = eventdata.AxisPositions(end,:);
    % Rail on axes limits to avoid axes auto scaling
    ax = eventdata.TargetObj;
    pos = [min([max([pos(1),min(ax.XLim)]),max(ax.XLim)]),...
           min([max([pos(2),min(ax.YLim)]),max(ax.YLim)])];
    UserData.rect.Vertices(2:4,:) = [eventdata.AxisPositions(1,1), pos(2);...
                            pos;...
                            pos(1), eventdata.AxisPositions(1,2)];
    for i = 1:length(UserData.scs)
        scatterObjs = UserData.scs(i).UserData.linkScatter.others;
        new_inds = find(inpolygon(UserData.scs(i).XData,UserData.scs(i).YData,...
            UserData.rect.Vertices(:,1),UserData.rect.Vertices(:,2)));
        switch eventdata.Button
            case 1
                inds = new_inds;
            case 3
                inds = setxor(UserData.init_inds{i},new_inds);
        end
        scatterObjs(1).UserData.linkScatter.selected = inds;
        highlight(scatterObjs,inds);
    end
end

function point_clicked_callback(hObj,eventdata)
scatterObjs = hObj.UserData.linkScatter.others;
[~,D] = knnsearch(eventdata.IntersectionPoint(1:2),[hObj.XData; hObj.YData]','K',1);
[~,this_ind] = min(D);
% See if it is already in selected set
inds = scatterObjs(1).UserData.linkScatter.selected;
switch eventdata.Button
    case 1
        inds = this_ind;
    case 3
        inds = setxor(inds,this_ind);
end
scatterObjs(1).UserData.linkScatter.selected = inds;
highlight(scatterObjs,inds);
end