classdef DiamondBase < Modules.Database
    %DiamondBase Save data to diamondbase.
    %   Grabs instance of AutoSave and uses last saved files!
    %       last_im_fname and last_exp_fname
    %   
    %   Make sure methods are the same name as the data_name and data_type
    %
    %   Note: This module requires a few properties in the data structure:
    %       diamondbase.data_name - The name of the data as used in DiamondBase
    %                   [Confocal, Spectrum, etc.]
    %       diamondbase.data_type - The type of data [General,Local,etc.]
    %       Individual save methods may require more (especially for any
    %       analysis - check there for more info.
    
    properties
        laser_power = 0;
        prefs = {'laser_power'};
    end
    properties(SetAccess=private)
        autosave = false;
        listeners               % Listener!
        experimentID            % Experiment ID from diamondbase
        parentID                % Parent ID from diamondbase
        delim                   % Delimiter used by diamondbase. Found in constructor.
        dataTypes               % DataIDs and datatypes
    end
    properties(Access=private)
        AutoSave                % Handle to AutoSave module
        ssh                     % Handle to SSH class
        expID                   % Handle to expID text field
        samples                 % local copy of samples
        pieces                  % local copy of pieces
        sampleMenu
        sampleVal = 1;          % index of current sample in menu
        pieceMenu
        pieceVal = 1;           % index of current piece in menu
        expBegin                % Handle to expBegin pushbutton
    end
    properties(Constant,Hidden)
        server = 'diamondbase.mit.edu';
        port = 22;
        user = 'dbssh';
        private_key='C:\Users\Experiment\.ssh\id_rsa';
        pswd='';
        proxy = 'proxy.py';
    end
    
    methods(Access=private)
        function obj = DiamondBase()
            obj.AutoSave = Databases.AutoSave.instance;
            obj.ssh = Base.SSH(obj.server,obj.user,obj.port,obj.private_key,obj.pswd);
            obj.delim = obj.issue('get_delim');
            obj.delim = obj.delim{1};
            obj.dataTypes = obj.get_data_types;
            obj.loadPrefs;
        end
        function notes = getNotes(obj)
            d = dbstack;
            notes=inputdlg('Notes:',d(2).name,[2 50]);
            if isempty(notes)
                error('User aborted save')
            else
                notes = cellstr(notes{1});
                notes = strjoin(notes,'\\r\\n');
            end
        end
        function path = formatFile(obj,fullpath)
            path = fullpath(4:end);
        end
    end
    methods(Static)
        function obj = instance()
            mlock
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Databases.DiamondBase();
            end
            obj = Object;
        end
    end
    methods
        function delete(obj)
            for i = 1:numel(obj.listeners)
                if ~isempty(obj.listeners(i))&&isvalid(obj.listeners(i))
                    delete(obj.listeners(i))
                end
            end
            delete(obj.ssh)
        end
        function ID = findDataID(obj,data_type)
            % Try with currently loaded datatypes, if not there, reload and
            % try one more time. Returns NaN if failed.
            ID = NaN;
            for j = 1:2
                for i = 1:numel(obj.dataTypes)
                    if strcmpi(obj.dataTypes{i}{2},data_type)
                        ID = obj.dataTypes{i}{1};
                        return
                    end
                end
                obj.dataTypes = obj.get_data_types;
            end
        end

        function Save(obj,data,parent,autoSavedfname,ax)
            % varargin has the option to be the axis handle (for images)
            assert(isa(data,'struct'),'DiamondBase requires data returned by experiment to be a struct.')
            assert(isfield(data,'diamondbase'),'Data object does not have diamondbase field')
            data_name = data.diamondbase.data_name;
            dataID = obj.findDataID(data_name);
            data_type = data.diamondbase.data_type;
            assert(~isnan(dataID),'%s, but it is not a valid data_name.  See diamondbase for help.',data_name)
            % Dispatch to appropriate save method
            if ~isfield(data,'notes')
                data.notes = obj.getNotes;
            end
            id = obj.(data_name)(data,autoSavedfname,parent,data_type,dataID,ax);
            tempID = str2double(id);
            assert(~isempty(tempID)&&~isnan(tempID),'Saving status is unknown, error occured in getting parent: %s.',id)
            if strcmpi(data_type,'general')
                obj.parentID = tempID;
            end
        end
        function SaveIm(obj,image,ax,module)
            % Saves image to experiment action ID
            assert(~isempty(obj.experimentID),'Need an experiment action ID from diamondbase to save an image.  Saving failed.')
            last_fname = obj.AutoSave.last_im_fname;
            image.diamondbase.data_name = image.ModuleInfo.data_name;
            image.diamondbase.data_type = image.ModuleInfo.data_type;
            obj.Save(image,obj.experimentID,last_fname,ax)
        end
        function SaveExp(obj,data,ax,module)
            % Saves image to module.data_type data ID
            assert(~isempty(obj.parentID),'Need a data ID from diamondbase to save an experiment.  Saving failed.')
            last_fname = obj.AutoSave.last_exp_fname;
            obj.Save(data,obj.parentID,last_fname,ax)
        end
        
        % Methods to talk to diamondbase
        function out = get_samples(obj,n)
            %n most recent samples
            %if not specified, all are retrieved
            if nargin > 1
                n=num2str(n);
                response=obj.issue(sprintf('get_samples %s',n));
                out=regexp(response,obj.delim,'split');
            else
                response=obj.issue('get_samples');
                out=regexp(response,obj.delim,'split');
            end
        end
        function out = get_diamonds(obj,sampleID)
            response=obj.issue(sprintf('get_diamonds %s',num2str(sampleID)));
            out=regexp(response,obj.delim,'split');
        end
        function out = get_experimentIDs(obj,diamondID)
            response=obj.issue(sprintf('get_experimentIDs %s',num2str(diamondID)));
            out=regexp(response,obj.delim,'split');
        end
        function out = get_data_types(obj)
            out=regexp(obj.issue('get_data_types'),obj.delim,'split');
        end 
        function out = new_experiment(obj,diamondIDs,notes)
            %Make sure diamondIDs are integers, not characters
            if isa(diamondIDs,'char')
                diamondIDs = str2num(diamondIDs);
            end
            diamonds='';
            for ID = diamondIDs
                diamonds = [diamonds ',' num2str(ID)];
            end
            msg=sprintf('new_experiment %s "%s"',diamonds(2:end),notes);
            out=obj.issue(msg);
            if isempty(out)
                out = '';
            else
                out = out{1};
            end
        end
        function out = add_data(obj, dat, parent,type,dataID)
            % See proxy for format!
            assert(iscell(dat),'Data needs to be cell format')
            available={'general','local','attachment'};
            type = lower(type);
            assert(ismember(type,available),'Not a proper data type')
            
            % Format File Paths here (first 2 arguments)
            dat{1} = obj.formatFile(dat{1});
            dat{2} = obj.formatFile(dat{2});
            dat = obj.data_format(dat);
            dat = urlencode(dat);
            msg = sprintf('add_%s %s %s "%s"',type,num2str(parent),num2str(dataID),dat);
            out = obj.issue(msg);
            if isempty(out)
                error('Error communicating to database; received no response!')
            end
            out=out{1};
        end
        function out = data_format(obj,data)
            out = '';
            for i = 1:numel(data);
                out = [out obj.delim num2str(data{i})];
            end
            out = out(2:end);
        end
        function [response] = issue(obj,msg)
            msg=sprintf('python %s %s',obj.proxy,msg);
            response = obj.ssh.issue(msg);
            if ~isempty(response)&&length(response{1})>5
                if strcmp(response{1}(1:5),'Error')
                    errordlg(response{1})
                    response = {};
                end
            end
        end
        
        % Settings and callback methods
        function settings(obj,panelH)
            spacing = 2.25;
            num_lines = 2;
            line = 1;
            obj.sampleMenu = uicontrol(panelH,'style','popupmenu','String','Samples',...
                'units','characters','position',[3 spacing*(num_lines-line) 20 2],...
                'callback',@obj.sampleCallback);
            line = 1;
            obj.pieceMenu = uicontrol(panelH,'style','popupmenu','String','Pieces',...
                'units','characters','position',[25 spacing*(num_lines-line) 20 2],...
                'callback',@obj.pieceCallback);
            line = 2;
            tip = 'Set Experiment ID manually or generate one by pressing New Experiment';
            obj.expBegin = uicontrol(panelH,'style','pushbutton','String','New Experiment','tooltipstring',tip,...
                'units','characters','position',[5 spacing*(num_lines-line) 18 1.75],...
                'callback',@obj.beginExpCallback);
            if ~isempty(obj.experimentID)
                str = num2str(obj.experimentID);
            else
                str = 'None';
            end
            obj.expID = uicontrol(panelH,'style','edit','String',str,'tooltipstring',tip,...
                'units','characters','position',[25 spacing*(num_lines-line) 15 1.75],...
                'callback',@obj.changeExpCallback);
            obj.updateSamples;
            set(obj.sampleMenu,'value',obj.sampleVal)
            obj.updatePieces;
            set(obj.pieceMenu,'value',obj.pieceVal)
            obj.updateUI;
        end
        
        function sampleCallback(obj,varargin)
            obj.sampleVal = get(obj.sampleMenu,'value');
            set(obj.pieceMenu,'value',1)
            obj.pieceVal = 1;
            obj.updatePieces;
        end
        function pieceCallback(obj,varargin)
            obj.pieceVal = get(obj.pieceMenu,'value');
            obj.experimentID = [];
            set(obj.expID,'string','None')
            obj.updateUI;
        end
        function beginExpCallback(obj,varargin)
            button = 'Yes';
            if ~isempty(obj.experimentID)
                button = questdlg('Are you sure you want to change experiments?','New Experiment','Yes','No','Yes');
            end
            if strcmp(button,'No')
                return
            end
            notes=inputdlg('Experiment Notes (goal maybe):','Begin Experiment',[2 50]);
            if isempty(notes)
                notes = '';
            else
                notes = cellstr(notes{1});
                notes = strjoin(notes,'\\r\\n');
            end
            experimentIDstr = obj.new_experiment(obj.pieces{obj.pieceVal-1}{1},notes);
            TEMPexperimentID = str2double(experimentIDstr);
            if ~isnan(TEMPexperimentID)
                set(obj.expID,'string',num2str(TEMPexperimentID,'%i'))
                obj.experimentID = TEMPexperimentID;
            else
                errordlg(sprintf('Error starting new experiment: %s',experimentIDstr))
            end
        end
        function changeExpCallback(obj,hObj,varargin)
            button = 'Yes';
            if ~isempty(obj.experimentID)
                button = questdlg('Are you sure you want to change experiments?','Change Experiment','Yes','No','Yes');
            end
            if strcmp(button,'Yes')
                temp = get(hObj,'string');
                try
                    obj.experimentID = str2double(temp);
                catch
                    errordlg('ExperimentID must be an integer.')
                    
                end
            end
            set(hObj,'string',num2str(obj.experimentID,'%i'))
        end
        
        function updateSamples(obj)
            obj.samples = obj.get_samples;
            menu=cell(1,numel(obj.samples)+1);
            temp=cellstr(get(obj.sampleMenu,'string'));
            menu{1}=temp{1};
            for i=1:numel(obj.samples)
                menu{i+1}=obj.samples{i}{2};
            end
            set(obj.sampleMenu,'string',menu)
            obj.updateUI;
        end
        function updatePieces(obj)
            if obj.sampleVal==1
                set(obj.pieceMenu,'value',1)
                obj.pieceVal = 1;
            else
                obj.pieces=obj.get_diamonds(obj.samples{get(obj.sampleMenu,'value')-1}{1});
                menu=cell(1,numel(obj.pieces)+1);
                temp=cellstr(get(obj.pieceMenu,'string'));
                menu{1}=temp{1};
                for i=1:numel(obj.pieces)
                    menu{i+1}=obj.pieces{i}{2};
                end
                set(obj.pieceMenu,'string',menu)
            end
            obj.updateUI;
        end
        function updateUI(obj)
            % Update UI elements based on values
            if obj.sampleVal == 1
                set(obj.pieceMenu,'enable','off')
            else
                set(obj.pieceMenu,'enable','on')
            end
            if obj.pieceVal == 1
                set(obj.expBegin,'enable','off')
            else
                set(obj.expBegin,'enable','on')
            end
        end
    end
    
end

