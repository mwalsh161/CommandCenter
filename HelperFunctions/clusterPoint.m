function [clusterNums,N,centers] = clusterPoint(X,threshold)
%CLUSTERPOINT Group 2D points that fall within a distance threshold
%   This will iteratively calculate nearest neighbors from X until there
%   are no more nearest neighbors closer than the threshold. Each iteration
%   will update cluster centers by averaging points in that cluster before
%   the next cycle begins.
% Inputs: brackets indicate name, value optional pair:
%   X: Nx2 numeric array of (x,y) pairs
%   threshold: numeric scalar indicating maximum distance for a point to be
%       from the center of the cluster (threshold > 0).
% Outputs:
%   clusterNums: the cluster "ID" for all points in X (or NaN if not in
%       cluster). Number will be between 1 and M (or NaN); it indexes into
%       N and centers.
%   N: Mx1 numeric array of the number of points in cluster
%   centers: Mx2 numeric array of (x,y) pairs indicating the caluclated
%       center of clusters.
%   iterations: The number of iterations required until convergence.

% Test with no args
if nargin == 0
    [clusterNums,N,centers] = test();
    return;
end

% We know that merging two groups might result in a lower distance, so we
% can turn off the non-monotonic tree warning.
S = warning('off','stats:linkage:NonMonotonicTree');
clusterNums = clusterdata(X,'linkage','centroid','Criterion','distance','Cutoff',threshold);
warning(S) % Turns back to previous state

% Do a bit extra processing to get valuable metadata
clusters = 1:max(clusterNums);
N = NaN(length(clusters),1);
centers = NaN(length(clusters),2);
for i = 1:length(clusters)
    pts = clusterNums == clusters(i);
    N(i) = sum(pts);
    centers(i,:) = mean(X(pts,:),1); % Should match linkage method
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
t = tic;
[clusterNums,N,centers] = clusterPoint(X,threshold);
dt = toc(t);

clusters = unique(clusterNums);

f = UseFigure('test.clusterPoint',true); ax = axes('parent',f);
hold(ax,'on'); axis(ax,'image');
title(ax,sprintf('Clustering (%i ms); drawing...',round(dt*1000)));

legend_holder = gobjects(1,0);
cs = lines(7);
t = tic;
for i = 1:length(clusters)
    pts = X(i==clusterNums,:);
    np = N(i);
    if np > 1
        leg_entry = findobj(legend_holder,'UserData',np);
        if isempty(leg_entry)
            leg_entry = line(ax,NaN,NaN,'linewidth',2,'color',cs(length(legend_holder)+1,:),...
                'DisplayName',[num2str(np) ' points'],'UserData',np);
            legend_holder(end+1) = leg_entry;
        end
        drawcircle(ax,'Center',centers(i,:),'Radius',threshold,'Color',leg_entry.Color,...
            'deletable',false,'InteractionsAllowed','none');
        line(ax,pts(:,1),pts(:,2),'LineStyle','none','Marker','o','color',leg_entry.Color);
    else
        line(ax,pts(:,1),pts(:,2),'LineStyle','none','Marker','o','color',[0 0 0]);
    end
end
legend(legend_holder);
title(ax,sprintf('Clustering (%i ms); drawing (%i ms)',round(dt*1000),round(toc(t)*1000)));
end