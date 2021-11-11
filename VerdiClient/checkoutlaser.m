function checkoutlaser(in_use,secret_key_path)
%CHECKOUTLASER Summary of this function goes here
%   Detailed explanation goes here

path = mfilename('fullpath');
path = fileparts(path);
script_path = fullfile(path,'checkout.py');
[~,cmdout] = system(sprintf('python "%s" %s %i "%s"',script_path,'verdi',in_use,secret_key_path));
if ~strcmp(cmdout(1:end-1),'True')
    if strcmp(cmdout(1:end-1),'False')
        warndlg('Authetnication Failed.')
    else
        warndlg(sprintf('Laser checkout error: %s',cmdout(1:end-1)))
    end
end
end

