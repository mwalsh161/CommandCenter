function [clusterNums,N,centers,dt] = clusterPoint(X,threshold,ax,matchColor)
%CLUSTERPOINT Group 2D points that fall within a distance threshold
%   This will iteratively calculate nearest neighbors from X until there
%   are no more nearest neighbors closer than the threshold. Each iteration
%   will update cluster centers by averaging points in that cluster before
%   the next cycle begins.
% Inputs: brackets indicate name, value optional pair:
%   X: Nx2 numeric array of (x,y) pairs
%   threshold: numeric scalar indicating maximum distance for a point to be
%       from the center of the cluster (threshold > 0).
%   [ax]: valid axes handle to plot result on. CLUSTERPOINT will plot rows 
%       in X (tag: 'clusterPoint') and circles for each cluster with N>2 
%       (tag: 'clusterPoint.circle'). All will be line objects. There is an
%        additional set of lines at (NaN,NaN) used to generate the legend 
%       (tag: 'clusterPoint.leg').
%   [matchColor]: (false) Should the points in a cluster's circle object be
%       the same color as the circle object? If false, they cycle through
%       lines() colors. If true, they will be the color of the circle
%       enclosing them. If sparse data, might be nicer to set to true;
%       denser data might look nicer when false.
% Outputs:
%   clusterNums: the cluster "ID" for all points in X (or NaN if not in
%       cluster). Number will be between 1 and M; it indexes into
%       N and centers.
%   N: Mx1 numeric array of the number of points in cluster
%   centers: Mx2 numeric array of (x,y) pairs indicating the caluclated
%       center of clusters.
%   dt: Time the clustering algorithm took in ms.

% Test with no args
if nargin == 0
    [clusterNums,N,centers] = test();
    return;
end

% We know that merging two groups might result in a lower distance, so we
% can turn off the non-monotonic tree warning.
S = warning('off','stats:linkage:NonMonotonicTree');
t = tic;
try
    clusterNums = clusterdata(X,'linkage','centroid','Criterion','distance','Cutoff',threshold);
catch err
    warning(S) % Turns back to previous state
    rethrow(err);
end
dt = toc(t)*1000; % ms
warning(S) % Turns back to previous state

% Do a bit extra processing to get valuable metadata
nClusters = max(clusterNums);
N = NaN(nClusters,1);
centers = NaN(nClusters,2);
for cluster = 1:nClusters
    pts = clusterNums == cluster;
    N(cluster) = sum(pts);
    centers(cluster,:) = mean(X(pts,:),1); % Should match linkage method
end

if nargin > 2 % plot on ax
    assert(isa(ax,'matlab.graphics.axis.Axes')&&isvalid(ax),'"ax" must be a valid axes.');
    if nargin < 4
        matchColor = false;
    end
    % Prepare legend
    nUnique = unique(N); % also sorts
    ncs = length(nUnique);
    legend_holder = gobjects(1,ncs);
    cs = lines(7);
    for i = 1:ncs
        if nUnique(i) > 1 % We aren't plotting circles for 1
            legend_holder(i) = line(ax,NaN,NaN,'linewidth',2,'color',cs(mod(i-1,7)+1,:),...
                'DisplayName',[num2str(nUnique(i)) ' points'],'UserData',N(i),'tag',[mfilename '.leg']);
        end
    end
    % Remove N=1 if exists (important for calling legend)
    nUnique(~isgraphics(legend_holder)) = [];
    legend_holder(~isgraphics(legend_holder)) = [];
    % Plot circless
    for i = 1:nClusters
        pts = X(i==clusterNums,:);
        np = N(i);
        if np > 1
            leg_entry = legend_holder(nUnique == np);
            lnC = leg_entry.Color;
            if ~matchColor
                lnC = cs(mod(i-1,7)+1,:);
            end
            line(ax,pts(:,1),pts(:,2),'LineStyle','none','Marker','o','color',lnC,...
                'UserData',i,'tag',mfilename);
            circle(centers(i,:),threshold,'Parent',ax,'Color',leg_entry.Color,...
                'UserData',i,'tag',[mfilename '.circle'],'linewidth',2);
        else
            line(ax,pts(:,1),pts(:,2),'LineStyle','none','Marker','o','color',[0 0 0],...
                'UserData',i,'tag',mfilename);
        end
    end
    legend(legend_holder);
end
end

function [clusterNums,N,centers] = test()
n = 10; c = 5;
threshold = 1;
Xs = rand(n,2)*10;
X = NaN(n*c,2);
for i = 1:c
    X((i-1)*n+1:i*n,:) = Xs + rand(1,2);
end
X(end+1,:) = rand(1,2)*10; % Add lone point too

f = UseFigure('test.clusterPoint',true);
ax = axes('parent',f);
axis(ax,'image');

[clusterNums,N,centers] = clusterPoint(X,threshold,ax);
end