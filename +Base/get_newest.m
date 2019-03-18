function [newest_f,newest_d] = get_newest(path,filter,thresh,assert_not_empty)
% GET_NEWEST Get the newest file at the specified path
    % Path can be relative or full.
    % Filter is a filter spec that dir can take (e.g. '*.spe') or the full
    % file name
    % Optional thresh argument will only return files with a newer datenum
    % Optional assert_not_empty will only return files with nonzero bytes
    % Note, this can be slow if large number of files returned by dir!
    %
    % If no file found or file not found newer than thresh, return empty 
    % string for newest_f and same thresh for newest_d
    
if nargin < 3
    thresh = -Inf;
end
if nargin < 4
    assert_not_empty = true;
end

newest_f = '';
newest_d = thresh;

d = dir(fullfile(path,filter));
[~, dx] = sort([d.datenum],'descend');

if ~isempty(dx) && d(dx(1)).datenum > thresh && (~assert_not_empty || d(dx(1)).bytes)
    newest_f = fullfile(d(dx(1)).folder,d(dx(1)).name);
    newest_d = d(dx(1)).datenum;
end
end
