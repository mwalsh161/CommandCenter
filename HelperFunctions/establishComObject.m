classdef establishComObject < handle
    
    properties
        deviceID = []; %name of device
    end
    
    properties(SetAccess = private)
        comObjectInfo = [];
        % comObjectInfo - comInformation has three fields. One is class type of
        % connection. Two is comAddress (ex: {'ni','1','1'}. Three is comProperties which are the editable fields of comObject.)
        
        comObject = [];
        % comObject - handle to device
    end
    
    methods(Static)
        function obj = instance(name)
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = establishComObject();
            end
            obj = Object;
            if isempty(obj.comObjectInfo)
                obj.establishInitialConnection();
            end
            obj.Connect_Driver()
            obj.deviceID = name;
        end
    end
    
    methods(Access=private)
        function obj = establishComObject()
            
        end
    end
       
    methods
          
        function establishInitialConnection(obj)
            %UserData property of ComObjects has been reserved to store the ComObjects'
            %comAddress. Do comObject.UserData to query comAddress info.
            
            
            %supported communication objects: 'serial', 'gpib', 'TCP',and 'prologix'
            
            %% see if any input is entered if not then prompt user to select com object
            dlgOptions = [{'gpib'},{'TCP'},{'serial'},{'prologix'}]; %add additional choices here
            dlgTitle = 'communication options';
            defOption = [];
            qStr ='Select comType';
            choice = buttonChoiceDialog(dlgOptions, dlgTitle, defOption, qStr);
            
            if isempty(choice)
                %user has elected to not select a comType exit the function
                obj.comObject = []; %return an empty bracket to match how inputdlg returns
                return
            end
            
            obj.selectConnection(choice);
            comProperties =  obj.displayProperties();
            
            obj.comObjectInfo.comProperties = comProperties; %editable fields of comOject and values
            obj.comObjectInfo.comType = class(obj.comObject); %comType
            obj.comObjectInfo.comAddress = obj.comObject.userData; %comAddress
            
            %% set all comProperties
            
            if ~isempty(fields(obj.comObjectInfo.comProperties))
                obj.testComObject(dlgOptions); %check comObject
                obj.setAllProperties();
            else        %??
                delete(obj.comObject);
                obj.comObject = [];
            end
            
        end
        
        function Connect_Driver(obj)
            %% Description
            %  Helper function that handles connecting to your driver. Uses the helper
            %  function Connect_Device. The handle to your device will be returned and
            %  it will be open and ready to use.
            
            
            %% try opening your device
            
            %first see if there is already an open hardware line of the same name
            obj.openHandle();
            
            %now try opening the line
            ME = [];
            try
                if strcmpi(obj.comObject.Status,'closed') %if closed then open
                    fopen(obj.comObject); %open connection to your device
                end
            catch ME
                %ask user if they want to enter in a new comm address
                [obj.comObject,obj.comObjectInfo] = obj.messageUser();
                if ~isempty(obj.comObject)
                    obj.openHandle();
                    if strcmpi(obj.comObject.Status,'closed') %if closed then open
                        fopen(obj.comObject); %open connection to your device
                    end
                    ME = []; %clear errors
                end
                
            end
            
            %% rethrow errors
            
            if ~isempty(ME)
                message = sprintf('Failed to open device. Error message: %s',ME.identifier);
                f = msgbox(message);
                rethrow(ME)
            end
        end
        
        function messageUser(obj)
            %this is only called if you failed to connect to your device(ex: change GPIB
            %address). This allows you to establish a new
            %connection.
            
            line1 = 'Problem connecting to your device. ';
            
            if ~isempty(obj.deviceID)
                line2 = sprintf('Device name: %s. ',obj.deviceID);
            else
                line2 = [];
            end
            
            line3 = sprintf('Connection was of type %s. ',class(obj.comObject));
            
            for index = 1:numel(obj.comObject.UserData)
                if numel(obj.comObject.UserData) > 1 %handles gpib, prologix and TCP
                    if index == 1
                        line4 = sprintf('No device found on input address %s',string(obj.comObject.UserData{index}));
                    elseif index == numel(obj.comObject.UserData)
                        line4 = [line4,sprintf(', and %s. ',string(obj.comObject.UserData{index}))];
                    else
                        line4 = [line4,sprintf(', %s',string(obj.comObject.UserData{index}))];
                    end
                end
                
                if  numel(obj.comObject.UserData) == 1% handles serial
                    line4 = sprintf('No device found on input address %s. ',string(obj.comObject.UserData{index}));
                end
            end
            
            line5 = 'Do you wish to re-enter your communication address?';
            question = [line1,line2,line3,line4,line5];
            title = 'Communication Failure';
            defbtn = [{'yes'},{'no'}];
            answer = questdlg(question, title,defbtn);
            if strcmpi(answer,'yes')
                [obj.comObject,obj.comObjectInfo] = obj.establishInitialConnection; %try to establish connection again
            end
        end
        
        function openHandle(obj)
            
            handles = instrfindall;
            for index =  1 : numel(handles)
                fieldName = handles(index).name;
                if strcmpi(fieldName,obj.comObject.name)
                    if strcmpi(handles(index).status,'open')
                        obj.comObject =  handles(index); %if a hardware line of the same name exists that is open take that handle
                    end
                end
            end
        end
        
        
        function selectConnection(obj,choice)
            num_lines = 1;
            switch lower(choice)
                case 'gpib'
                    InputArg={'Adaptor_Type','GPIBboard_Number','GPIBnum'};
                    dlg_title = ['GPIB Communication Setting'];
                    comType = @(x) gpib(x{1},obj.force_double(x{2}),obj.force_double(x{3}));
                case 'serial'
                    InputArg={'comPortNum'};
                    dlg_title = ['Serial Communication Setting'];
                    comType = @(x) serial(x{:});
                case {'tcp','tcp/ip','tcpip'}
                    InputArg ={'Address','Port'};
                    dlg_title = ['TCP Communication Setting'];
                    comType = @(x) tcpip(x{1},obj.force_double(x{2}));
                case 'prologix'
                    InputArg={'comPortNum','GPIBnum'};
                    dlg_title = ['Prologix Communication Setting'];
                    comType = @(x) prologix(x{1},obj.force_double(x{2}));
                otherwise
                    error([choice,' is not a supported com object.'])
            end
            
            answer = inputdlg(InputArg,dlg_title,num_lines)';
            if isempty(answer)
                return
            end
            
            obj.comObject = comType(answer(:)); %majority of error handling happens here
            obj.comObject.UserData = answer; %save comAddress
        end
        
        function x = force_double(obj,x)
            if ~isnumeric(x)
                x = str2double(x);
            end
        end
        
        function comProperties = displayProperties(obj)
            default_ans = [];
            delete_index = [];
            properties = set(obj.comObject);
            field_names = fields(properties);
            for index = 1:numel(field_names)
                if ~isempty(findstr(field_names{index}, 'Fcn'))
                    delete_index = [delete_index,index];
                    continue
                end
                fieldName = field_names{index};
                value = getfield(properties,fieldName);
                poss_ans = obj.comObject.(fieldName);
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
        
        function setAllProperties(obj)
            ME = [];
            try
                %attempt to set all the properties
                set(obj.comObject,obj.comObjectInfo.comProperties);%set all the properties; this also handles debugging
            catch ME
                %should only hit this catch if it is your first time establish
                %comProperties. Some of the properties are the wrong dataType for the
                %set method. So go through and change numbers to datatype double from strings.
                field_names = fields(obj.comObjectInfo.comProperties);
                for index = 1:numel(field_names)
                    val = obj.comObjectInfo.comProperties.(field_names{index});
                    val = str2num(val);
                    if ~isempty(val)
                        obj.comObjectInfo.comProperties.(field_names{index}) =  val;
                    end
                end
                set(obj.comObject,obj.comObjectInfo.comProperties);%set all the properties; this also handles debugging
                ME = [];
            end
            %% rethrow error
            if ~isempty(ME)
                rethrow(ME)
            end
        end
        
        function testComObject(obj,comOptions)
            %this function does some tests on comObject to check if it a connection
            %will be established
            assert(isvalid(obj.comObject),'error comObject is not a valid comObject');
            assert(ismember(lower(class(obj.comObject)),lower(comOptions)),'error comObject is not a comType');
        end
        
        
    end
end