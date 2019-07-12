function [ClusterNums, I, H] = clusterTrace(Traces, varargin)
%CLUSTETRACE Groups unkown traces by similarity
%   Takes a set of traces (e.g. spectra) and tries to group them together
%   based on their similarity. Does not try to fit peaks, so may be better
%   for comparing spectra when number or location of peaks is not known a
%   priori. This is essentially a wrapper for pdist, linkage and
%   dendrogram.
% Inputs: brackets indicate name, value optional pair:
%   Traces: MxN matrix of M traces (e.g. spectra), each with N pixel
%            intensities
%   [Vals]: 1xN values (e.g. wavelenghts) corresponding to each pixel for
%           plotting
%   [Smoothing]: Scalar value of blurring applied to traces in pixels.
%                For comparing spectra, recommended 2 to 3x inhomogeneous
%                linewidth of spectra.
%       Default: 5
%   [Thr]: Scalar threshold to define clusters
%       Default: 0.5
%   [Limits]: 1x2 array of wavelength range to focus on
%       Default: [min(Vals) max(Vals)]
%   [DistMetric]: Metric used to calculate distance between traces. Can be
%                 either a default for pdist or a function handle to a
%                 custom function
%       Default: 'correlation'
%   [ClustMethod]: String specifying the clustering method used. Can be
%                  any of the 'method' strings from linkage function.
%       Default: 'complete'
%   [Show]: String indicating what to plot after the calculation
%       'all' (default): plot dendrogram along with corresponding traces
%       'allBlurred': plot dendrogram and blurred traces
%       'spec': plot only clustered traces
%       'specBlurred': plot only clustered blurred traces
%       'clusters': plot dendrogram, corresponding traces and mean traces
%                 for each cluster.
%       'None': plot nothing
%   [Parent]: Parent figure handle
% Outputs:
%   ClusterNums: Mx1 array listing index of cluster each spectrum is
%                associated with.
%   I: Mx1 array listing order of traces in dendrogram
%   H: Struct containing the graphical handles in the figure, axes, and
%      lines fields

% Input validation
% Find number of traces and pixel intensities
inp = inputParser;
addRequired( inp, 'Traces', @(x) isnumeric(x) && ismatrix(x) )
parse( inp, Traces );
[Ntraces, Npixel] = size(Traces);

%Find wavelengths
addParameter( inp, 'Vals', linspace(1,Npixel,Npixel), @(x) isnumeric(x) ...
    && ismatrix(x) && size(x,1)==1 && size(x,2)==Npixel);
inp.KeepUnmatched = true;
parse( inp, Traces, varargin{:})
inpTmp = inp.Results;

%Parse rest of inputs
addParameter( inp, 'Smoothing', 5, @(x) isscalar(x) && (x>=0) );
addParameter( inp, 'Thr', 0.5, @(x) isscalar(x) && (x>=0) );
addParameter( inp, 'Limits', [min(inpTmp.Vals) max(inpTmp.Vals)], @(x) ...
    ismatrix(x) && size(x,1)==1 && size(x,2)==2)
addParameter( inp, 'DistMetric', 'correlation', @(x) any(isstring(x), ...
    ischar(x), isa(x,'function_handle')))
addParameter( inp, 'ClustMethod', 'complete', @(x) any(isstring(x), ...
    ischar(x) ))
addParameter( inp, 'Show', 'all', @(x) any(validatestring(x, ...
    {'all','allBlurred','spec','specBlurred','clusters','None'})))
addParameter( inp, 'Parent', false, @(f) ...
    any([isa(f,'matlab.ui.container.Panel') isa(f,'matlab.ui.Figure')]) )
inp.KeepUnmatched = false;
parse( inp, Traces, varargin{:});

createFigure = ismember('Parent',inp.UsingDefaults);
inp = inp.Results;
if createFigure
    inp.Parent = figure();
end

H.figure = inp.Parent;
H.axes = [];
H.lines = [];

% Apply smoothing and wavelength limits to input traces
filtTraces = NaN(Ntraces,  sum(inp.Vals>inp.Limits(1) & ...
    inp.Vals<inp.Limits(2)) );
for i = 1:Ntraces
    filtTraces(i,:) = imgaussfilt(Traces(i, inp.Vals>inp.Limits(1) & ...
        inp.Vals<inp.Limits(2)), inp.Smoothing);
end

%Create linkage
Z = linkage( filtTraces, inp.ClustMethod, inp.DistMetric );

%Define clusters
ClusterNums = cluster(Z, 'Cutoff', inp.Thr, 'criterion', 'distance');

%Create plots
switch inp.Show
    case 'all'
        ax = subplot(2,1,1,'Parent',inp.Parent);
        H.axes(end+1) = ax;
        [H.lines,~,I] = dendrogram(Z, Ntraces, 'ColorThreshold', inp.Thr);
        ylabel(ax, 'Distance')
        ax = subplot(2,1,2,'Parent',inp.Parent);
        H.axes(end+1) = ax;
        imagesc(ax, 1:Ntraces, inp.Vals, Traces(I,:)' )
        ylabel(ax, 'Wavelength')
        xlabel(ax, 'Site #')
    case 'allBlurred'
        ax = subplot(2,1,1,'Parent',inp.Parent);
        H.axes(end+1) = ax;
        [H.lines,~,I] = dendrogram( Z, Ntraces, 'ColorThreshold', inp.Thr);
        ylabel(ax, 'Distance')
        ax = subplot(2,1,2,'Parent',inp.Parent);
        H.axes(end+1) = ax;
        imagesc( ax, 1:Ntraces, inp.Vals, filtTraces(I,:)' )
        ylabel(ax, 'Wavelength')
        xlabel(ax, 'Site #')
    case 'spec'
        ax = subplot(1,1,1,'Parent',inp.Parent);
        H.axes(end+1) = ax;
        [H.lines,~,I] = dendrogram( Z, Ntraces, 'ColorThreshold', inp.Thr);
        imagesc(ax, 1:Ntraces, inp.Vals, Traces(I,:)' )
        ylabel(ax, 'Wavelength')
        xlabel(ax, 'Site #')
    case 'specBlurred'
        ax = subplot(1,1,1,'Parent',inp.Parent);
        H.axes(end+1) = ax;
        [H.lines,~,I] = dendrogram( Z, Ntraces, 'ColorThreshold', inp.Thr);
        imagesc(ax, 1:Ntraces, inp.Vals, Traces(I,:)' )
        ylabel(ax, 'Wavelength')
        xlabel(ax, 'Site #')
    case 'clusters'
        Nclus = max(ClusterNums);
        NrowPlots = max( [Nclus 2] );
        
        span = @(x) ceil(x/2)*2-1;
        
        ax = subplot(NrowPlots,2,[1 span(NrowPlots)]);
        H.axes(end+1) = ax;
        [H.lines,~,I] = dendrogram( Z, Ntraces, 'ColorThreshold', inp.Thr);
        ylabel(ax, 'Distance')
        ax = subplot(NrowPlots,2,[span(NrowPlots)+2 2*NrowPlots-1]);
        H.axes(end+1) = ax;
        imagesc(ax, 1:Ntraces, inp.Vals, Traces(I,:)' )
        ylabel(ax, 'Wavelength')
        xlabel(ax, 'Site #')
        
        
        if NrowPlots > 2
            for i = 1:Nclus
                ax = subplot( NrowPlots,2, 2*i);
                H.axes(end+1) = ax;
                plot(ax, inp.Vals, mean( Traces( ClusterNums==i,:),1) )
                ylabel(ax, strcat( num2str(sum(ClusterNums==i)), ' sites'))
            end
        elseif NrowPlots == 2
           ax = subplot( NrowPlots,2,[2 4] );
           H.axes(end+1) = ax;
           plot(ax, inp.Vals, mean( Traces( ClusterNums==1,:),1) )
           ylabel(ax, strcat( num2str(sum(ClusterNums==1)), ' sites') )
        end
        xlabel( 'Wavelength' )
    case 'None'
end
end

