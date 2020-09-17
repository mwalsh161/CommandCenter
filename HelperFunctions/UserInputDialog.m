function Answer = UserInputDialog(varargin)
%UserInputDialog Input dialog box.
%  ANSWER = UserInputDialog(PROMPT) creates a modal dialog box that returns user
%  input for multiple prompts in the cell array ANSWER. PROMPT is a cell
%  array containing the PROMPT strings.
%
%  UserInputDialog uses UIWAIT to suspend execution until the user responds.
%
%  ANSWER = UserInputDialog(PROMPT,NAME) specifies the title for the dialog.
%
%  ANSWER = UserInputDialog(PROMPT,NAME,DEFAULTANSWER) specifies the
%  default answer to display for each PROMPT. DEFAULTANSWER must contain
%  the same number of elements as PROMPT and must be a cell array of
%  strings or cell arrays. If a cell array is used an entry within DEFAULTANSWER
%  then it will be used as a multiple choice option.
%

%  Examples:
%
%  prompt={'Enter the matrix size for x^2:','Enter the colormap name:'};
%  name='Input for Peaks function';
%  defaultanswer={'20','hsv'};
%
%  answer=UserInputDialog(prompt,name,defaultanswer);
%
%  UserInputDialog is very similiar to inputdlg. Changes from matlab built in inputdlg: numoflines is always one.
%  Remove option input. Also figwidth is fixed now, so if a prompt extends
%  beyond the set figure width it is cut off. 
%
%  Note: if the user cancels out of the function a [] is returned.
%% Output arguments
%	Answer- cell array of answers.

%  See also DIALOG, ERRORDLG, HELPDLG, LISTDLG, MSGBOX,
%    QUESTDLG, TEXTWRAP, UIWAIT, WARNDLG .
%%
%%%%%%%%%%%%%%%%%%%%
%%% Nargin Check %%%
%%%%%%%%%%%%%%%%%%%%
narginchk(1,3) %make sure that there are no more than 3 inputs and at least 1 input

nargoutchk(0,1);

%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Handle Input Args %%%
%%%%%%%%%%%%%%%%%%%%%%%%%
%check dataType of inputs and assign defaults if user does not supply

assert(iscell(varargin{1}),'First input must be a cell array of strings');
Prompt = varargin{1};

if nargin < 2 || isempty(varargin{2})
    Title = '';
else
    assert(ischar(varargin{2}),'Second input must be a string')
    Title = varargin{2};
end

if nargin < 3 || isempty(varargin{3})
    DefAns = [];
else
    assert(iscell(varargin{3}),'Third input must be a cell array of strings')
    assert(numel(varargin{3}) == numel(Prompt),'DefAns must have the same number of elements as Prompt')
    DefAns = varargin{3};
end
%% set default answer
DefAns = flip(DefAns); %flip so in the right order from the top (1) to bottom (last)
Answer = DefAns;
%% define size of figure
%units of pixels
numPrompts = numel(Prompt);

Pos(1) = 800;
Pos(2) = 300;
Pos(3) = 250;
Pos(4) = (numPrompts - 1)*100;
maxHeight = 400;
minHeight = 250;
if Pos(4) > maxHeight
    Pos(4) = maxHeight;
end
if Pos(4) < minHeight
    Pos(4) = minHeight;
end
%%  create figure window

figWindow = figure('Visible','off','Units','pixels');
figWindow.Position = Pos;
figWindow.Name = Title;
figWindow.MenuBar ='none';
figWindow.ToolBar ='none';
figWindow.Resize = 'off';
%% add container for menu

menuContainer = uipanel(figWindow);
menuContainer.Position = [0, 0.2, 1,0.80];

%% add ok button
edgeOK = 10;
edgeWidth = Pos(3)/2-2*edgeOK;
edgeHeight = Pos(4)*menuContainer.Position(2)-2*edgeOK;
Callback = @returnAnswer;
%
ui = uicontrol(figWindow,'style','pushbutton','units','pixels');
ui.Callback = Callback;
ui.String = 'OK';
ui.Position(1) = edgeOK;
ui.Position(2) = edgeOK;
ui.Position(3) = edgeWidth; %if option is too large runs off figure.
ui.Position(4) = edgeHeight;

%% add cancel button
edgeWidth = Pos(3)/2-2*edgeOK;
edgeHeight = Pos(4)*menuContainer.Position(2)-2*edgeOK;
Callback = @cancelCallback;
%
ui = uicontrol(figWindow,'style','pushbutton','units','pixels');
ui.Callback = Callback;
ui.String = 'Cancel';
ui.Position(1) = 3*edgeOK + edgeWidth;
ui.Position(2) = edgeOK;
ui.Position(3) = edgeWidth; %if option is too large runs off figure.
ui.Position(4) = edgeHeight;

%% add scroll bar

scroll = uipanel('Parent',menuContainer);
scroll = Base.UIscrollPanel(scroll);  % This determines the size

%% create panel

p = uipanel(menuContainer,'BorderType','none','units','characters');  % parent doesn't matter here
p.Position(3) = scroll.content.Position(3);

%% assemble prompts
Prompt = flip(Prompt); %flip so that they are shown in the right order.
pad = 0.5;
edge = 1;
scrollwheelbuffer = 8;
textWidth = floor(p.Position(3) - scrollwheelbuffer - edge) ;
maxChars = 25;
vertHeight =  edge; %vertHeight keeps track of the vertical position of the items
answerHandle = {};
for index = 1:numPrompts
    
    %do query first
    answerHandle(index) = {uicontrol(p,'units','characters')};
    if ~isempty(DefAns)
        answerHandle{index}.String = DefAns{index};
    else
        answerHandle{index}.String = '';
    end
    if ~isempty(DefAns) && iscell(DefAns{index})
        %if it is a cell assume that they want a list of options
        answerHandle{index}.Style = 'popup';
    else
        answerHandle{index}.Style = 'edit';
    end
    answerHandle{index}.Position(3) = textWidth; %if option is too large runs off figure.
    answerHandle{index}.Position(2) = vertHeight;
    answerHandle{index}.Position(4) = max(answerHandle{index}.Extent(4),2.5);
    answerHandle{index}.HorizontalAlignment = 'left';
    
    vertHeight = vertHeight + pad + answerHandle{index}.Position(4);
    
    %do prompt
    ui = uicontrol(p,'units','characters');
    ui.Style = 'text';
    assert(~isempty(Prompt{index}),'prompt has an empty element')
    [text,newPos] = textwrap(ui,Prompt(index),maxChars);
    ui.String = text;
    ui.Position(3) = textWidth;
    ui.Position(2) = vertHeight;
    if numel(text) > 1
          ui.Position(4) = newPos(4) + 1;
    end
    ui.HorizontalAlignment = 'left';
    ui.FontSize = 10;
    
    vertHeight = vertHeight + pad +  ui.Position(4) ;
end

%%
p.Position(4) = sum(ui.Position([2,4])); % Make sure p is large enough for everything
%%
scroll.addPanel(p,'Content')
figWindow.CloseRequestFcn = Callback;
figWindow.Visible = 'on';
uiwait;

    function returnAnswer(~,~)
        Answer = {};
        for index = 1:numel(answerHandle)
            switch answerHandle{index}.Style
                case 'popupmenu'
                    UserSelection = answerHandle{index}.String{answerHandle{index}.Value};
                case 'edit'
                    UserSelection = answerHandle{index}.String;
            end
            Answer(index) =   {UserSelection};
        end
        Answer = flip(Answer);
        delete(figWindow)
        return
    end

    function cancelCallback(~,~)
        Answer = [];
        delete(figWindow)
        return
    end
end



