function choice = buttonChoiceDialog(varargin)
%% buttonChoiceDialog
% Create and open a button dialog box with many buttons.
%
%% Syntax
%  buttonChoiceDialog(dlgOptions);
%  buttonChoiceDialog(dlgOptions, dlgTitle);
%  buttonChoiceDialog(dlgOptions, dlgTitle, defOption);
%  buttonChoiceDialog(dlgOptions,dlgTitle, defOption, qStr);
%
%% Description
% Create and open a push button dialog box, which is a generalized version of a question
%  dialog box (called by questdlg). User can enter any number of input options (buttons)
%  for one to choose from, as opposed to questdlg, where only 2 or 3 options are
%  supported.
%
%% Input arguments (defaults exist):
% dlgOptions- a cell array of strings, each of which is an option proposed to user as a
%     push button, for selection from.

% dlgTitle- a 'title' displayed in the figure's title bar. Expected to be a string. A
%     space by default.

% defOption- a default preset option, used if user makes no choice, and
% closes dialog. Should be either a string -one of the dlgOptions cell array elements.

% qStr- a string of the dialog question, instructing the user to choose among his options.
%     Expected to be a sting. Empty by default.

%% Output arguments
%	choice- index ot the user chosen (clicked) button.

%Note: Cancel returns []
%%

%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Handle Input Args %%%
%%%%%%%%%%%%%%%%%%%%%%%%%

narginchk(1,4); %make sure that there are no more than 4 inputs and at least 1 input

%check dataType of inputs and assign defaults if user does not supply

assert(iscell(varargin{1}),'First input must be a cell array of strings');
dlgOptions = varargin{1};

if nargin < 2 || isempty(varargin{2})
    dlgTitle = '';
else
    assert(ischar(varargin{2}),'Second input must be a string')
    dlgTitle = varargin{2};
end

if nargin < 3 || isempty(varargin{3})
    defOption = [];
else
    assert(ischar(varargin{3}),'Third input must be a string')
    assert(ismember(varargin{3},varargin{1}),'defOption must be one of the inputs of dlgOptions')
    defOption = varargin{3};
end

if nargin < 4 || isempty(varargin{4})
    qStr = 'Select One';
else
    assert(ischar(varargin{4}),'Fourth input must be a string')
    qStr = varargin{4};
end

%% set default output

choice = defOption;

%% define size of figure
%units of pixels
numOptions = numel(dlgOptions);
Pos(1) = 900;
Pos(2) = 500;
Pos(3) = 200;
Pos(4) = (numOptions - 1)*55;
maxHeight = 500;
minHeight = 270;
if Pos(4) > maxHeight
   Pos(4) = maxHeight;
end
if  Pos(4) < minHeight
    Pos(4) = minHeight;
end
%%  create figure window

figWindow = figure('Visible','off','Units','pixels');
figWindow.Position = Pos;
figWindow.Name = dlgTitle;
figWindow.MenuBar ='none';
figWindow.ToolBar ='none';
figWindow.Resize = 'off';

%% add scroll bar
scroll = uipanel(figWindow);
scroll = Base.UIscrollPanel(scroll);  % This determines the size
%% create panel
p = uipanel(figWindow,'BorderType','none','units','characters');  % parent doesn't matter here
p.Position(3) = scroll.content.Position(3);

%% 
dlgOptions = flip(dlgOptions); %flip so that they are shown in the right order.
Callback = @choiceSelection;
pad = 1;
edge = 1.5;
buttonSize = 3;
vertHeight = edge;
scrollwheelbuffer = 6;
maxChars = 20;
textWidth = floor(p.Position(3) - scrollwheelbuffer - edge) ;

for option = 1:numOptions
    ui = uicontrol(p,'style','pushbutton','units','characters');
    ui.Callback = Callback;
    string = dlgOptions{option};
    ui.String = string; %if too does not show complete option
    ui.Position(3) = textWidth; 
    ui.Position(4) =  max(ui.Extent(4),buttonSize);
    ui.Position(2) = vertHeight;
    ui.FontWeight = 'normal';
    ui.FontSize = 11;
    vertHeight = vertHeight + ui.Position(4) + pad ;
end
%% place question
ui = uicontrol(p);
ui.Units = 'characters';
[text,newPos] = textwrap(ui,{qStr},maxChars);
ui.Style = 'text';
ui.String = text;
vertHeight = vertHeight  ;
ui.Position(2) = vertHeight ;
ui.Position(3) = textWidth;
if numel(text) > 1
    ui.Position(4) = newPos(4) + 1;
end
ui.FontSize = 10;
ui.HorizontalAlignment = 'center';

% 
%% 
p.Position(4) = sum(ui.Position([2,4])); % Make sure p is large enough for everything
%% 
scroll.addPanel(p,'Content')
figWindow.Visible = 'on';
figWindow.CloseRequestFcn = @cancelCallback;
uiwait;


    function choiceSelection(source,event)
        choice = source.String;
        delete(figWindow);
    end

    function cancelCallback(~,~)
        choice = [];
        delete(figWindow)
        return
    end
end

