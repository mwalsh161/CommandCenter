function [varargout] = UseFigure( tag,varargin )
%USEFIGURE Grab or make, if necessary figure with given tag
%   Grabs all figures of given tag and returns them. If none exist, makes
%   figure with given tag and returns handle.
%   Remaining inputs used in set(fig,...)
%   Last input optional: UseFigure(...,reset); (default is false)
%   The reset flag indicates if clf(fig,'reset') is called
%       This deletes ALL figure graphics objects and resets all figure
%       properties except Position, Units, PaperPosition, and PaperUnits

reset = false;
if ~mod(nargin,2)
    % Even inputs means odd varargin (last must be reset)
    reset = varargin{end};
    varargin(end) = [];
    assert(islogical(reset),...
        ['Incorrect call: if last argument supplied is stand-alone, '...
         'it should be the reset flag which is a boolean'])
end

f = findall(0,'tag',tag);
if isempty(f)
    f = figure('tag',tag);
elseif reset
    clf(f,'reset');
    f.Tag = tag;
end

if ~isempty(varargin)
    set(f,varargin{:});
end

if nargout
    varargout = {f};
end
end

