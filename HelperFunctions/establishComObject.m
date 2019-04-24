classdef establishComObject < handle
    
    properties
        deviceID = []; %name of device
    end
    
    properties(SetAccess = private)
        comObjectInfo = [];
        % comObjectInfo - comInformation has three fields. One is class type of
        % connection. Two is comAddress (ex: {'ni','1','1'} for gpib or {'COM8'} for serial. Three is comProperties which are the editable fields of comObject.)
        
        comObject = [];
        % comObject - handle to device
    end
    
    
    methods
        function obj = establishComObject(name)
             if isempty(obj.comObjectInfo)
                obj.establishInitialConnection();
            end
            obj.connectDriver()
            obj.deviceID = name;
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
            comProperties =  obj.displayPropertiesDialog();
            
            obj.comObjectInfo.comProperties = comProperties; %editable fields of comOject and values
            obj.comObjectInfo.comType = class(obj.comObject); %comType
            obj.comObjectInfo.comAddress = obj.comObject.userData; %comAddress
            
            %% set all comProperties
            
            if ~isempty(fields(obj.comObjectInfo.comProperties))
                obj.testComObject(dlgOptions); %check comObject
                obj.setAllProperties();
            else 
                delete(obj.comObject);
                obj.comObject = [];
            end
            
        end
        
        function connectDriver(obj)
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
            numLines = 1;
            switch lower(choice)
                case 'gpib'
                    inputArg={'Adaptor_Type','GPIBboard_Number','GPIBnum'};
                    dlgTitle = ['GPIB Communication Setting'];
                    comType = @(x) gpib(x{1},obj.forceDouble(x{2}),obj.forceDouble(x{3}));
                case 'serial'
                    inputArg={'comPortNum'};
                    dlgTitle = ['Serial Communication Setting'];
                    comType = @(x) serial(x{:});
                case {'tcp','tcp/ip','tcpip'}
                    inputArg ={'Address','Port'};
                    dlgTitle = ['TCP Communication Setting'];
                    comType = @(x) tcpip(x{1},obj.forceDouble(x{2}));
                case 'prologix'
                    inputArg={'comPortNum','GPIBnum'};
                    dlgTitle = ['Prologix Communication Setting'];
                    comType = @(x) prologix(x{1},obj.forceDouble(x{2}));
                otherwise
                    error([choice,' is not a supported com object.'])
            end
            
            answer = inputdlg(inputArg,dlgTitle,numLines)';
            if isempty(answer)
                return
            end
            
            obj.comObject = comType(answer(:)); %Populates comObject using majority of error handling happens here
            obj.comObject.UserData = answer; %save comAddress
        end
        
        function x = forceDouble(obj,x)
            if ~isnumeric(x)
                x = str2double(x);
            end
        end
        
        function comProperties = displayPropertiesDialog(obj)
            % Description:
            %  Composes list of settable properties for the comObject and
            %  creates dialog box with the options for the user to populate
            %  (default answers are provided)
            %
            % Outputs:
            %  comProperties - List of all settable properties associated with
            %  comObject
            
            
            defaultAns = [];
            deleteIndex = [];
            properties = set(obj.comObject);
            fieldNames = fields(properties);
            for index = 1:numel(fieldNames)
                % Removes callback function settings from properties list
                if ~isempty(findstr(fieldNames{index}, 'Fcn'))
                    deleteIndex = [deleteIndex,index];
                    continue
                end
                % Sets default answers for comProperties
                fieldName = fieldNames{index};
                value = getfield(properties,fieldName);
                possAns = obj.comObject.(fieldName);
                if numel(value) == 0
                    if isnumeric(possAns)
                        possAns = num2str(possAns);
                    end
                    defaultAns{index} = possAns;
                else
                    currentIndex = contains(value,possAns);
                    value = [value(currentIndex);value(~currentIndex)];  %reorganize cell array so the default option is first
                    defaultAns{index} = value;
                    choices = [];
                end
            end
            fieldNames(deleteIndex) = [];
            defaultAns(deleteIndex) = [];
            indexList = strfind(fieldNames, 'UserData');
            Index = find(~cellfun(@isempty,indexList));
            fieldNames(Index)=[];
            defaultAns(Index)=[];
            dlgTitle = 'Set Communication Properties';
            answers = UserInputDialog(fieldNames,dlgTitle,defaultAns);
            comProperties = struct();
            if isempty(answers)
                return
            end
            for index = 1:length(answers)
                comProperties.(fieldNames{index}) = answers{index};
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
                fieldNames = fields(obj.comObjectInfo.comProperties);
                for index = 1:numel(fieldNames)
                    val = obj.comObjectInfo.comProperties.(fieldNames{index});
                    val = str2num(val);
                    if ~isempty(val)
                        obj.comObjectInfo.comProperties.(fieldNames{index}) =  val;
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