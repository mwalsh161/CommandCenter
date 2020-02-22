function [tform,aborted,altered,f] = uifitgeotrans(movingPoints,fixedPoints,transformationType,varargin)
%UIFITGEOTRANS Manually pair up points to apply FITGEOTRANS
%   See FITGEOTRANS help for documentation; inputs/outputs match.
%   Inputs; brackets indicate name,value optional pair
%   (additional to that of FITGEOTRANS):
%       movingPoints: Nx2 numeric array of points that undergo tform
%           transformPointsForward.
%       fixedPoints: Nx2 numeric array of fixed points
%       transformationType: string describing transform type. See FITGEOTRANS.
%       [Parent]: (new ax) The parent axes to display scatter plots. Note
%           that default operation is to delete the figure when done.
%       [movingLineParams]: (struct()) Name,value pairs stored as field: value
%           in a struct that will be passed to LINE() for moving points.
%       [fixedLineParams]: (struct()) Same as movingLineParams, but for fixed points.
%       [connectorLineParams]: (struct('linestyle','--','color',[0,0,0]))
%           Same as movingLineParams, but for connector lines on paired points.
%       [PreserveFig]: (false) Specify to true to avoid deleting figure.
%           Note the user can still "abort" and delete the figure. Also,
%           note that axes will be held if preserved.
%       [varargin]: All unmatched name,value pairs are piped to FITGEOTRANS

assert(isnumeric(movingPoints),'movingPoints must be numeric.');
assert(isnumeric(fixedPoints),'fixedPoints must be numeric.');
assert(size(movingPoints,2)==2,'movingPoints must be an Nx2 numeric array.');
assert(size(fixedPoints,2)==2,'fixedPoints must be an Nx2 numeric array.');
assert(size(movingPoints,1)>0,'Need at least one movingPoints.');
assert(size(fixedPoints,1)>0,'Need at least one fixedPoints.');
assert(ismember(transformationType,{'nonreflectivesimilarity', 'similarity', 'affine', 'projective'}),...
    'transformationType can be ''nonreflectivesimilarity'', ''similarity'', ''affine'', or ''projective''.');

p = inputParser();
p.KeepUnmatched = true;
addParameter(p,'Parent',[],@(x) isa(x,'matlab.graphics.axis.Axes')&&isvalid(x));
addParameter(p,'movingLineParams',struct(),@(x) isstruct(x));
addParameter(p,'fixedLineParams',struct(),@(x) isstruct(x));
addParameter(p,'connectorLineParams',struct('linestyle','--','color',[0,0,0]),@(x) isstruct(x));
addParameter(p,'PreserveFig',false,@(a)validateattributes(a,{'logical'},{'scalar'}));

parse(p,varargin{:});
% Re-pack varargin
params = fieldnames(p.Unmatched);
varargin = cell(1,2*length(params));
for i = 1:length(params)
    varargin((i-1)*2 + 1:i*2) = {params{i}, p.Unmatched.(params{i})};
end
p = p.Results;

% Prepare vars
aborted = true;
altered = false;
tform = affine2d(); % identity tform
state = 0; % 0: Moving Points active; 1: Fixed Points active;
cs = lines(2);
base_width = [0.5, 0.5];
point_types = {'Moving','Fixed'};
nMoving = size(movingPoints,1);
nFixed = size(fixedPoints,1);
points = {gobjects(1,nMoving), gobjects(1,nFixed)};  % {Moving, Fixed}; Moving -> array
paired = {false(1,nMoving), false(1,nFixed)}; % Index into points
active_points = gobjects(1,2);
paired_points = gobjects(0,2); % [moving, fixed] handles
paired_lines = gobjects(0); % Store handles to paired lines (between points)
% Pack movingLineParams
allowed = {'color','linewidth'};
params = fieldnames(p.movingLineParams);
movingLineParams = cell(1,0);
for i = 1:length(params)
    assert(ismember(lower(params{i}),allowed),sprintf('Currently only supports %s',strjoin(allowed,', ')));
    if strcmpi(params{i},'color')
        assert(isequsl(size(p.movingLineParams.(params{i})),[1,3]),'Color should be row vector of length 3');
        cs(1,:) = p.movingLineParams.(params{i});
    elseif strcmpi(params{i},'linewidth')
        val = p.movingLineParams.(params{i});
        assert(isnumeric(val) && isscalar(val), 'linewidth must be a numeric scalar.');
        base_width(1) = val;
    else
        movingLineParams(end+1:end+2) = {params{i}, p.movingLineParams.(params{i})};
    end
end
% Pack fixedLineParams
params = fieldnames(p.fixedLineParams);
fixedLineParams = cell(1,0);
for i = 1:length(params)
    assert(ismember(lower(params{i}),allowed),sprintf('Currently only supports %s',strjoin(allowed,', ')));
    if strcmpi(params{i},'color')
        assert(isequsl(size(p.fixedLineParams.(params{i})),[1,3]),'Color should be row vector of length 3');
        cs(2,:) = p.fixedLineParams.(params{i});
    elseif strcmpi(params{i},'linewidth')
        val = p.fixedLineParams.(params{i});
        assert(isnumeric(val) && isscalar(val), 'linewidth must be a numeric scalar.');
        base_width(2) = val;
    else
        fixedLineParams(end+1:end+2) = {params{i}, p.fixedLineParams.(params{i})};
    end
end
% Pack connectorLineParams
allowed = {'color','linewidth','linestyle'};
params = fieldnames(p.connectorLineParams);
connectorLineParams = cell(1,0);
for i = 1:length(params)
    assert(ismember(lower(params{i}),allowed),sprintf('Currently only supports %s',strjoin(allowed,', ')));
    connectorLineParams(end+1:end+2) = {params{i}, p.connectorLineParams.(params{i})};
end

% Test varargin on fitgeotrans
n = min([nFixed,nMoving]);
fitgeotrans(movingPoints(1:n,:),fixedPoints(1:n,:),transformationType,varargin{:});

lastCloseRequestFcn = 'closereq'; % default
lastWindowKeyPressFcn = '';
lastButtonDownFcn = '';
lastTitle = '';
if ~isempty(p.Parent)
    ax = p.Parent;
    f = Base.getParentFigure(ax);
    lastCloseRequestFcn = f.CloseRequestFcn;
    lastWindowKeyPressFcn = f.WindowKeyPressFcn;
    lastButtonDownFcn = ax.ButtonDownFcn;
    
    lastTitle = ax.Title.String;
else
    f = figure();
    ax = axes('parent',f);
end
f.CloseRequestFcn = @confirm_close;
f.WindowKeyPressFcn = @keyPressed;
ax.ButtonDownFcn = @clicked;
hold(ax,'on');
try
    for i = 1:nMoving
        points{1}(i) = line(ax, movingPoints(i,1), movingPoints(i,2),...
            'marker','x','linestyle','none','color',cs(1,:),'tag','point',...
            'UserData',struct('type',1,'ind',i,'origPos',movingPoints(i,:)),...
            movingLineParams{:});
    end
    for i = 1:nFixed
        points{2}(i) = line(ax, fixedPoints(i,1), fixedPoints(i,2),...
            'marker','o','linestyle','none','color',cs(2,:),'tag','point',...
            'UserData',struct('type',2,'ind',i),...
            fixedLineParams{:});
    end
catch err
     if isempty(p.Parent) % We generated, so clean up
         delete(f);
     else
        delete(points{1}); delete(points{2});
        f.CloseRequestFcn = lastCloseRequestFcn;
     end
     rethrow(err);
end
leg = legend([points{1}(1),points{2}(1)],point_types,...
    'Orientation','horizontal','location','northoutside');

% Add context menu
cm = uicontextmenu(f);
% UserData is effectively zero-indexed into "points" cell array and menu
% list. Identical to "state"
menu(1) = uimenu(cm,'label','Select moving point','callback',@selectPointType,'UserData',0);
menu(2) = uimenu(cm,'label','Select fixed point','callback',@selectPointType,'UserData',1);
uimenu(cm,'label','Finished','callback',@finished,'separator','on');
f.UIContextMenu = cm;
ax.UIContextMenu = cm;
set(points{1},'UIContextMenu',cm,'ButtonDownFcn',@clicked);
set(points{2},'UIContextMenu',cm,'ButtonDownFcn',@clicked);
% Context menu to remove selected ones
cm_remove = uicontextmenu(f);
uimenu(cm_remove,'label','Remove from paired points','callback',@removePointPair);

% Set up default behavior
selectPointType(menu(state+1)); % "Activates" moving points
title('Select active moving point.');
uiwait(f);
if ~isvalid(f)
    return;
end
aborted = false;
if p.PreserveFig
    remove_interactivity();
else
    delete(f);
end

    % Callbacks/helpers
    function finished(~,~)
        if ~altered
            resp = questdlg('No changes have been made yet. Return identity tform?',...
                            'uifitgeotrans: No Changes Detected','Yes','Cancel','Cancel');
            if strcmp(resp,'Cancel')
                return
            end
        end
        uiresume(f);
    end
    function clicked(~,eventdata)
        switch eventdata.Button
            case 1 % Select point
                if ~strcmp(eventdata.Source.Tag,'point'); return; end % Short circuit if not point
                type = eventdata.Source.UserData.type; % Synonymous to state+1
                if isgraphics(active_points(type))
                    active_points(type).LineWidth = base_width(type); % Reset
                end
                % Update
                eventdata.Source.LineWidth = base_width(type)*4;
                active_points(type) = eventdata.Source;
                % Switch to other state/population if not selected yet
                if any(~isgraphics(active_points))
                    selectPointType(menu(~state+1)); % "other state"
                    title(ax,'Select other active point.')
                else % Both selected; help user out a bit
                    title(ax,'Scrollwheel or Enter to pair.')
                end
            case 2 % Scroll wheel: confirm pair
                addPointPair();
        end
    end
    function keyPressed(~,eventdata)
        if strcmp(eventdata.Key,'return')
            addPointPair();
        end
    end
    function addPointPair()
        if ~all(isgraphics(active_points)); return; end % Short circuit unless both active_points ready
        if all(isgraphics(active_points))
            title('Select active point.');
            paired_points(end+1,:) = active_points; % [moving, fixed] handles
            paired_lines(end+1) = line(ax,[active_points(2).XData, active_points(1).XData],...
                [active_points(2).YData, active_points(1).YData],connectorLineParams{:},...
                'tag','connector','HandleVisibility','off','HitTest','Off',...
                'PickableParts','none','UserData',active_points(1).UserData.ind); % Index to moving point
            for j = [1,2] % [Moving, Fixed]
                active_points(j).LineWidth = base_width(j); % reset
                paired{j}(active_points(j).UserData.ind) = true;
                active_points(j).Color = cs(j,:) * 0.2;
                active_points(j).UIContextMenu = cm_remove;
                active_points(j).ButtonDownFcn = '';
                % Hit test allows right clicking
                active_points(j).HitTest = 'on'; % Technically only one will be off, but doesn't hurt to set both
            end
            active_points = gobjects(1,2); % Deactivate
            updateMovingPoints();
        else
            errordlg('Make sure there is an active point in both Moving and Fixed populations.');
        end
    end
    function removePointPair(~,~)
        % Clean up shared lists and restore interactivity
        [row,~] = find(f.CurrentObject == paired_points);
        % Clean up points
        for j = 1:2
            clean_points = paired_points(row,j);
            paired{clean_points.UserData.type}(clean_points.UserData.ind) = false;
            clean_points.UIContextMenu = cm;
            clean_points.ButtonDownFcn = @clicked;
            if j == state + 1
                clean_points.HitTest = 'on';
            else
                clean_points.HitTest = 'off';
            end
        end
        paired_points(row,:) = [];
        delete(paired_lines(row)); % Remove from plot
        paired_lines(row) = [];
        updateMovingPoints();
    end
    function updateMovingPoints()
        % Reset to original coordinates (useful if removing pairs)
        newMovingPoints = movingPoints;
        try
            if ~isempty(paired_points)
                moving = cell2mat(arrayfun(@(a)a.UserData.origPos,paired_points(:,1),'UniformOutput',false));
                fixed = [[paired_points(:,2).XData]', [paired_points(:,2).YData]'];
                tform = fitgeotrans(moving,fixed,transformationType,varargin{:});
                altered = true;
                newMovingPoints = transformPointsForward(tform,movingPoints);
            end
        catch update_err % Ignore too few points to fit geotrans
            if ~strcmp(update_err.identifier,'images:geotrans:requiredNonCollinearPoints')
                rethrow(update_err);
            end
        end
        for j = 1:nMoving
            points{1}(j).XData = newMovingPoints(j,1);
            points{1}(j).YData = newMovingPoints(j,2);
        end
        % Update connector lines
        for j = 1:length(paired_lines)
            paired_lines(j).XData(2) = points{1}(paired_lines(j).UserData).XData;
            paired_lines(j).YData(2) = points{1}(paired_lines(j).UserData).YData;
        end
        drawnow;
    end
    function selectPointType(hObj,~)
        state = NaN; % Unset until ready
        ind_not = ~hObj.UserData+1;
        ind = hObj.UserData+1;
        
        set(menu(ind_not),'Checked','off');
        set(points{ind_not}(~paired{ind_not}),...
            'HitTest','off','Color',cs(ind_not,:));
        leg.String{ind_not} = point_types{ind_not};
        
        set(menu(ind),'Checked','on');
        set(points{ind}(~paired{ind}),...
            'HitTest','on','Color',cs(ind,:)*0.65);
        leg.String{ind} = ['*' point_types{ind}];
        
        uistack(points{ind},'top');
        state = hObj.UserData;
    end
    function confirm_close(~,~)
        resp = questdlg('Abort fit geotrans (current tform will be returned)?','uifitgeotrans: Abort','Yes','Cancel','Yes');
        if strcmp(resp,'Yes')
            delete(f);
        end
    end

    function remove_interactivity()
        % Remove interactivity and any potential handle references in userdata
        f.CloseRequestFcn = lastCloseRequestFcn;
        f.WindowKeyPressFcn = lastWindowKeyPressFcn;
        ax.ButtonDownFcn = lastButtonDownFcn;
        ax.Title.String = lastTitle;
        delete(cm); delete(cm_remove);
        leg.String = point_types;
        set(points{1},'ButtonDownFcn','','color',cs(1,:),'linewidth',base_width(1),'UserData',[]);
        set(points{2},'ButtonDownFcn','','color',cs(2,:),'linewidth',base_width(2),'UserData',[]);
        set(paired_lines,'UserData',[]);
    end

end