function SlackNotification( url, varargin )
%SLACKNOTIFICATION Send message to a slack API
%   Uses python helper to take care of the http POST
%   USE: SlackNotification(url, msg, <channel, icon_emoji, username>)
%        SlackNotification(url, slack_struct)
%            See slack documentation to understand the struct (each option
%            referenced in their documentation should be a struct field
%            here)
%
%   Channel: public channel: '#channel_name'
%            Direct Message: '@username'
%   icon_emoji: ':snowman:'
%   username: cRoMi
%
%   NOTE: it is fine to leave any field blank
%   NOTE: msg should already be formatted!! aka no '\n' as two characters
%
%   Example use (note defaults are based on slack config with given hook):
%   SlackNotification('https://hooks.slack.com/services/...','It''s getting hot in here!><&')
%   SlackNotification('https://hooks.slack.com/services/...','It''s getting hot in here!><&','@mpwalsh')
%   SlackNotification('https://hooks.slack.com/services/...','It''s getting hot in here!><&','@mpwalsh',':snowman:')
%   SlackNotification('https://hooks.slack.com/services/...','It''s getting hot in here!><&','@mpwalsh',':snowman:','cRoMi')

if isstruct(varargin{1}) % Struct supplied directly
    payload = varargin{1};
else % msg, <channel, icon_emoji, username>
    payload.text = varargin{1};
    if length(varargin) > 1
        payload.channel = varargin{2};
    end
    if length(varargin) > 2
        payload.icon_emoji = varargin{3};
    end
    if length(varargin) > 2
        payload.username = varargin{4};
    end
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

[~,err] = system(sprintf('python "%s" %s %s',script_path,url,matlab.net.base64encode(payload)));
if ~isempty(err)
    ME = MException([mfilename ':requestError'],'%s',err);  % Takes sprintf like arguments
    throwAsCaller(ME)
end
end

