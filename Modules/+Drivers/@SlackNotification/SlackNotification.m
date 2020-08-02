classdef SlackNotification < Modules.Driver
    properties (SetAccess=immutable)
        identifier
    end
    properties (GetObservable, SetObservable)
        hook =      Prefs.String('', 'help', 'https://hooks.slack.com/services/<HOOK>.');
        channel =   Prefs.String('', 'help', 'The <@USER> or public <#CHANNEL> to send a message to.');
        emoji =     Prefs.String('', 'help', '(Optional) The <:EMOJI:> that the message should be send from.');
        name =      Prefs.String('', 'help', '(Optional) The <NAME> that the message should be send from.');
        
        message =   Prefs.String('', 'help', 'The message that should be sent.');
    end
    methods(Static)
        function obj = instance(identifier)
            assert(ischar(identifier) && ~isempty(identifier), 'Identifier must be a non-empty string.')
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.SlackNotification.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(identifier, Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.SlackNotification(identifier);
            obj.singleton_id = identifier;
            Objects(end+1) = obj;
        end
    end
    methods(Access=private)
        function obj = SlackNotification(identifier)
            obj.identifier = identifier;
        end
    end
    methods
        function success = notify(obj, varargin)
            success = true;
            try
                msg = obj.message;
                if nargin == 2 && ischar(varargin)
                    msg = varargin;
                end
                assert(~isempty(obj.channel))
                assert(~isempty(obj.hook))

                % msg, <channel, icon_emoji, username>
                payload.text = msg;
                payload.channel = obj.channel;
                if ~isempty(obj.emoji)
                    payload.icon_emoji = obj.emoji;
                end
                if ~isempty(obj.name)
                    payload.username = obj.name;
                end

                if ~isempty(strfind(payload.text,'\n'))
                    warning([mfilename ':unformattedString'],...
                    'Found "\\n" in what should be a formatted string. If this is intentional, ignore this message.')
                end

                % Prepare payload
                payload = jsonencode(payload);
                %payload = char(strrep(payload,"'","\'"));

                % Get fullpath; assume slackAPI.py is in the same folder as this file
                % Don't assume pwd is the same folder as this file
                path = mfilename('fullpath');
                path = fileparts(path);
                script_path = fullfile(path,'slackAPI.py');
                
                url = ['https://hooks.slack.com/services/' obj.hook];

                [~,err] = system(sprintf('python "%s" %s %s', script_path, url, matlab.net.base64encode(payload)));
                if ~isempty(err)
                    ME = MException([mfilename ':requestError'], '%s', err);  % Takes sprintf like arguments
                    throwAsCaller(ME)
                end
            catch err2
                warning(err2.message);
                success = false;
            end
        end
    end
end