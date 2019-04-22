function [comObject,comProperties]=Connect_Device(varargin)
%% Expected Inputs/Behavior:
%if no input is supplied then connect device asks the user to pick a
%communication type( ex: serial, prologix, etc). The user will be prompted
%to submit the needed information to connect to the device,

%ex: [comObject,comProperties]=Connect_Device
%ex: [comObject,comProperties]=Connect_Device(comProperties)

%% Input arguments (defaults exist):
% comProperties - desired settings of comObject

%% Output arguments
% comObject - handle to device

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Expected Outputs:

%first output is the comObject for your communication object.

%second output is a structure of comProperties. Field names are the name of
%the settable properties of comObject. Field values are the current
%property setting.
%% Note:
% if any of the input variable are an empty matrix [] then it is treated as
% not a valid input and it is ignored. Thus
%Connect_Device([]) is equal to  Connect_Device()

%Note:
%UserData property of ComObjects has been reserved to store the ComObjects'
%comAddress. Do comObject.UserData to query comAddress info.

%Connect_Device does not handle debugging on comObject

%supported communication objects: 'serial', 'gpib', 'TCP',and 'prologix'
%%

%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Handle Input Args %%%
%%%%%%%%%%%%%%%%%%%%%%%%%
narginchk(0,1); %should have no more than one inputs

comObject = [];
comProperties = struct();
numInputs = nargin;

if numInputs == 1
    if  ~isempty(varargin{1})
        assert(isstruct(varargin{1}),'comProperties must be a struct.')
    else
        varargin(1) = [];
        numInputs = 0;
    end
end

%% see if any input is entered if not then prompt user to select com object
dlgOptions = [{'gpib'},{'TCP'},{'serial'},{'prologix'}]; %add additional choices here
if numInputs == 0 %no information supplied
    dlgTitle = 'communication options';
    defOption = [];
    qStr ='Select comType';
    choice = buttonChoiceDialog(dlgOptions, dlgTitle, defOption, qStr);
    
    if isempty(choice)
        %user has elected to not select a comType exit the function
        comObject = []; %return an empty bracket to match how inputdlg returns
        return
    end
    
    comObject = selectConnection(choice);
    comProperties =  displayProperties(comObject);
    
    %% set all comProperties
    
    if ~isempty(fields(comProperties))
        testComObject(comObject,dlgOptions); %check comObject
        comProperties = setAllProperties(comObject,comProperties);
    else
        delete(comObject);
        comObject = [];
    end
    
end
%% if one inputs is given

if numInputs == 1 % Assume if handed arguments, we don't need to modify
    comType = determineComType(comProperties);
    comAddress = determineComAddress(comProperties);
    comObject = selectConnection(choice);
end

end

function comType = determineComType(comProperties)


end

function comAddress = determineComAddress(comProperties)

end

function [comObject] = selectConnection(varargin)
comObject = [];
choice = varargin{1};
num_lines = 1;
switch lower(choice)
    case 'gpib'
        InputArg={'Adaptor_Type','GPIBboard_Number','GPIBnum'};
        dlg_title = ['GPIB Communication Setting'];
        comType = @(x) gpib(x{1},force_double(x{2}),force_double(x{3}),varargin{3:end});
    case 'serial'
        InputArg={'comPortNum'};
        dlg_title = ['Serial Communication Setting'];
        comType = @(x) serial(x{:},varargin{3:end});
    case {'tcp','tcp/ip','tcpip'}
        InputArg ={'Address','Port'};
        dlg_title = ['TCP Communication Setting'];
        comType = @(x) tcpip(x{1},force_double(x{2}),varargin{3:end});
    case 'prologix'
        InputArg={'comPortNum','GPIBnum'};
        dlg_title = ['Prologix Communication Setting'];
        comType = @(x) prologix(x{1},force_double(x{2}),varargin{3:end});
    otherwise
        error([choice,' is not a supported com object.'])
end

if nargin == 1
    %user supplied only comType so query user to provide comInformation
    answer = inputdlg(InputArg,dlg_title,num_lines)';
    if isempty(answer)
        return
    end
end

if nargin > 1
    %user supplied comtype and comAddress
    answer = varargin{2};
    if ~iscell(answer)
        %if the address is not a cell, ex: com5 instead of {com5}, then make it a cell. Be nice if
        %they make a mistake.
        answer = {answer};
    end
end

comObject = comType(answer(:)); %majority of error handling happens here
comObject.UserData = answer; %save comAddress
end

function x = force_double(x)
if ~isnumeric(x)
    x = str2double(x);
end
end

function comProperties = displayProperties(comObject)
default_ans = [];
delete_index = [];
properties = set(comObject);
field_names = fields(properties);
for index = 1:numel(field_names)
    if ~isempty(findstr(field_names{index}, 'Fcn'))
        delete_index = [delete_index,index];
        continue
    end
    name = field_names{index};
    value = getfield(properties,name);
    poss_ans = comObject.(name);
    if numel(value) == 0
        if isnumeric(poss_ans)
            poss_ans = num2str(poss_ans);
        end
        default_ans{index} = poss_ans;
    else
        currentIndex = contains(value,poss_ans);
        value = [value(currentIndex);value(~currentIndex)];  %reorganize cell array so the default option is first
        default_ans{index} = value;
        choices = [];
    end
end
field_names(delete_index) = [];
default_ans(delete_index) = [];
Index_list = strfind(field_names, 'UserData');
Index = find(~cellfun(@isempty,Index_list));
field_names(Index)=[];
default_ans(Index)=[];
dlg_title = 'Set Communication Properties';

answers = UserInputDialog(field_names,dlg_title,default_ans);
comProperties = struct();
if isempty(answers)
    return
end
for index = 1:length(answers)
    comProperties.(field_names{index}) = answers{index};
end
end

function comProperties = setAllProperties(comObject,comProperties)
assert(isstruct(comProperties),['Input to setComProperties must be a '...
    'structure with fields specifying property name and value as desired set value.'])
try
    %attempt to set all the properties
    set(comObject,comProperties);%set all the properties; this also handles debugging
catch
    %should only hit this catch if it is your first time establish
    %comProperties. Some of the properties are the wrong dataType for the
    %set method. So go through and change numbers to datatype double from strings.
    field_names = fields(comProperties);
    for index = 1:numel(field_names)
        val = comProperties.(field_names{index});
        val = str2num(val);
        if ~isempty(val)
            comProperties.(field_names{index}) =  val;
        end
    end
    set(comObject,comProperties);%set all the properties; this also handles debugging
end
end

function testComObject(comObject,comOptions)
%this function does some tests on comObject to check if it a connection
%will be established
assert(isvalid(comObject),'error comObject is not a valid comObject');
assert(ismember(lower(class(comObject)),lower(comOptions)),'error comObject is not a comType');
end
