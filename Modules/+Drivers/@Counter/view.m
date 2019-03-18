function view(obj)
%VIEW Creates view for Counter
obj.fig = figure('name','Counter','HandleVisibility','Callback','IntegerHandle','off',...
          'menu','none','numbertitle','off','closerequestfcn',@obj.closeReq);
obj.ax = axes('parent',obj.fig,'units','normalized','OuterPosition',[0 0.15 1 0.85]);
obj.plt = plot(obj.ax,0,NaN);
% Comment the following line to hide the text in the center of the axes
obj.textH = text(0.5,0.5,'NaN','Parent',obj.ax,'horizontalalignment','center',...
    'units','normalized','fontsize',50);
xlabel(obj.ax,'Time (s)')
ylabel(obj.ax,'CPS')
panelH = uipanel(obj.fig,'units','normalized','position',[0 0 1 0.15],'title','Settings');
% Control fields
uicontrol(panelH,'style','pushbutton','string','Start',...
    'units','characters','callback',@(~,~)obj.start,...
    'horizontalalignment','left','position',[.5 0.5 10 1.5]);
uicontrol(panelH,'style','pushbutton','string','Stop',...
    'units','characters','callback',@(~,~)obj.stop,...
    'horizontalalignment','left','position',[11 0.5 10 1.5]);
uicontrol(panelH,'style','pushbutton','string','Export','tooltipstring','Export line data to workspace',...
    'units','characters','callback',@export,'UserData',obj,...
    'horizontalalignment','left','position',[21.5 0.5 10 1.5]);

uicontrol(panelH,'style','text','string','Dwell (ms):','horizontalalignment','right',...
    'units','characters','position',[32 0.5 18 1.25]);
uicontrol(panelH,'style','edit','string',num2str(obj.dwell),...
    'units','characters','callback',@obj.updateDwellCallback,...
    'horizontalalignment','left','position',[51 0.5 10 1.5]);

uicontrol(panelH,'style','text','string','Update Rate (s):','horizontalalignment','right',...
    'units','characters','position',[61 0.5 18 1.25]);
uicontrol(panelH,'style','edit','string',num2str(obj.update_rate),...
    'units','characters','callback',@obj.updateRateCallback,...
    'horizontalalignment','left','position',[80 0.5 10 1.5]);

uicontrol(panelH,'style','text','string','Window Max (s):','horizontalalignment','right',...
    'units','characters','position',[91 0.5 18 1.25]);
uicontrol(panelH,'style','edit','string',num2str(obj.WindowMax),...
    'units','characters','callback',@obj.updateWindowMax,...
    'horizontalalignment','left','position',[110 0.5 10 1.5]);
obj.fig.Units = 'characters';
obj.fig.Position(3) = 121;
end

function export(hObj,~)
base_name = 'counterData';
% Get first free counterData variable
if ~isempty(evalin('base',sprintf('whos(''%s'')',base_name)))
    answer = questdlg(sprintf('Overwrite existing %s in workspace?',base_name),'Counter Export','Continue','Cancel','Continue');
    if strcmp('Cancel',answer)
        % Do not assign anything
        return
    end
end
counterData.x = hObj.UserData.plt.XData;
counterData.y = hObj.UserData.plt.YData;
assignin('base',base_name,counterData);
end