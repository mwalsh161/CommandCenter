function f = UseFigure( tag,varargin )
%USEFIGURE Grab or make, if necessary figure with given tag
%   Grabs all figures of given tag and returns them. If none exist, makes
%   figure with given tag and returns handle.
%   Remaining inputs used in set(fig,...)

f = findall(0,'tag',tag);
if isempty(f)
    f = figure('tag',tag);
end
if ~isempty(varargin)
    set(f,varargin{:});
end
figure(f); % Bring to foreground

end

