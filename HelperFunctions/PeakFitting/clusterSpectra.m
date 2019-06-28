function [ClusterNums, I] = clusterSpectra(Spectra, varargin)
%CLUSTESPECTRA Groups unkown spectra by similarity
%   Takes a set of spectra and tries to group them together based on
%   their similarity. Does not try to fit peaks, so may be better for
%   comparing spectra when number or location of peaks is not known a
%   priori. This is essentially a wrapper for pdist, linkage and
%   dendrogram.
% Inputs: brackets indicate name, value optional pair:
%   Spectra: MxN matrix of M spectra, each with N pixel intensities
%   [Wav]: 1xN wavelengths corresponding to each pixel for plotting
%   [Smoothing]: Scalar value of blurring applied to spectra in pixels.
%                Recommended 2 to 3x inhomogeneous linewidth of spectra.
%       Default: 5
%   [Thr]: Scalar threshold to define clusters
%       Default: 0.5
%   [Limits]: 1x2 array of wavelength range to focus on
%       Default: [min(Wav) max(Wav)]
%   [DistMetric]: Metric used to calculate distance between spectra. Can be
%                 either a default for pdist or a function handle to a
%                 custom function
%       Default: 'correlation'
%   [ClustMethod]: String specifying the clustering method used. Can be
%                  any of the 'method' strings from linkage function.
%       Default: 'complete'
%   [Show]: String indicating what to plot after the calculation
%       'all' (default): plot dendrogram along with corresponding spectra
%       'allBlurred': plot dendrogram and blurred spectra
%       'spec': plot only clustered spectra
%       'specBlurred': plot only clustered blurred spectra
%       'clusters': plot dendrogram, corresponding spectra and mean spectra
%                 for each cluster.
%       'none': plot nothing
% Outputs:
%   ClusterNums: Mx1 array listing index of cluster each spectrum is
%                associated with.
%   I: Mx1 array listing order of spectra in dendrogram

% Input validation
% Find number of spectra and pixel intensities
inp = inputParser;
addRequired( inp, 'Spectra', @(x) isnumeric(x) && ismatrix(x) )
parse( inp, Spectra );
[Nspectra, Npixel] = size(Spectra);

%Find wavelengths
addParameter( inp, 'Wav', linspace(1,Npixel,Npixel), @(x) isnumeric(x) ...
    && ismatrix(x) && size(x,1)==1 && size(x,2)==Npixel);
inp.KeepUnmatched = true;
parse( inp, Spectra, varargin{:})
inpTmp = inp.Results;

%Parse rest of inputs
addParameter( inp, 'Smoothing', 5, @(x) isscalar(x) && (x>=0) );
addParameter( inp, 'Thr', 0.5, @(x) isscalar(x) && (x>=0) );
addParameter( inp, 'Limits', [min(inpTmp.Wav) max(inpTmp.Wav)], @(x) ...
    ismatrix(x) && size(x,1)==1 && size(x,2)==2)
addParameter( inp, 'DistMetric', 'correlation', @(x) any(isstring(x), ...
    ischar(x), isa(x,'function_handle')))
addParameter( inp, 'ClustMethod', 'complete', @(x) any(isstring(x), ...
    ischar(x) ))
addParameter( inp, 'Show', 'all', @(x) any(validatestring(x, ...
    {'all','allBlurred','spec','specBlurred','clusters','None'})))
inp.KeepUnmatched = false;
parse( inp, Spectra, varargin{:});

inp = inp.Results;


% Apply smoothing and wavelength limits to input spectra
filtSpectra = NaN(Nspectra,  sum(inp.Wav>inp.Limits(1) & ...
    inp.Wav<inp.Limits(2)) );
for i = 1:Nspectra
    filtSpectra(i,:) = imgaussfilt(Spectra(i, inp.Wav>inp.Limits(1) & ...
        inp.Wav<inp.Limits(2)), inp.Smoothing);
end

%Create linkage
Z = linkage( filtSpectra, inp.ClustMethod, inp.DistMetric );

%Define clusters
ClusterNums = cluster(Z, 'Cutoff', inp.Thr, 'criterion', 'distance');

%Create plots
switch inp.Show
    case 'all'
        figure()
        subplot(2,1,1)
        [~,~,I] = dendrogram( Z, Nspectra, 'ColorThreshold', inp.Thr);
        ylabel('Distance')
        subplot(2,1,2)
        imagesc( 1:Nspectra, inp.Wav, Spectra(I,:)' )
        ylabel('Wavelength')
        xlabel('Site #')
    case 'allBlurred'
        figure()
        subplot(2,1,1)
        [~,~,I] = dendrogram( Z, Nspectra, 'ColorThreshold', inp.Thr);
        ylabel('Distance')
        subplot(2,1,2)
        imagesc( 1:Nspectra, inp.Wav, filtSpectra(I,:)' )
        ylabel('Wavelength')
        xlabel('Site #')
    case 'spec'
        figure()
        imagesc( 1:Nspectra, inp.Wav, Spectra' )
        ylabel('Wavelength')
        xlabel('Site #')
    case 'specBlurred'
        figure()
        imagesc( 1:Nspectra, inp.Wav, filtSpectra' )
        ylabel('Wavelength')
        xlabel('Site #')
    case 'clusters'
        figure()
        subplot(2,1,1)
        [~,~,I] = dendrogram( Z, Nspectra, 'ColorThreshold', inp.Thr);
        ylabel('Distance')
        subplot(2,1,2)
        imagesc( 1:Nspectra, inp.Wav, Spectra(I,:)' )
        ylabel('Wavelength')
        xlabel('Site #')
        
        figure()
        Nclus = max(ClusterNums);
        for i = 1:Nclus
            subplot( Nclus, 1, i)
            plot( inp.Wav, mean( Spectra( ClusterNums==i,:),1) )
            ylabel( strcat( num2str(sum(ClusterNums==i)), ' sites') )
        end
        xlabel( 'Wavelength' )
    case 'None'
end
end

