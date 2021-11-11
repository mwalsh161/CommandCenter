function dbquit(varargin)
%DBQUIT Wrapper to confirm
% The only thing this file does it overload dbquit and rename itself if
% called twice within 1 second.
% Note, you cant call builtin('dbquit') here because this function is not
% in debug mode when called
persistent tlast
title = [mfilename ' override'];
cont = false;
if ~isempty(tlast)
    if toc(tlast) < 1
        cont = true;
    end
end
if cont % Delete to disable (only way to allow call to builtin dbquit)
    % Note, this will only execute when filename is dbquit.m
    delete([mfilename('fullpath') '.m']);
    delete(findall(0,'name',title))
else
    if isempty(findall(0,'name',title))
        msgbox(sprintf(['CommandCenter blocked a call to dbquit to prevent potentially fatal errors.\n\n',...
            'For advanced users, to override this fail-safe, repeat attempt to quit debugging 3 times in rapid succession\n\n',...
            'NOTE Leave this dlg box open while performing the attempts.']),title,'replace');
    end
end
tlast = tic;
end
