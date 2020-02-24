function [clusterNums,centers,iterations] = clusterPoint(X,threshold)
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
%       cluster). Number will be between 1 and M (or NaN).
%   centers: Mx2 numeric array of (x,y) pairs indicating the caluclated
%       center of clusters.
%   iterations: The number of iterations required until convergence.

% Test with no args
if nargin == 0
    [clusterNums,centers,iterations] = test();
    return;
end

% Check inputs
assert(isnumeric(X)&&size(X,2)==2,'X needs to be a Nx2 numeric array.')
assert(isnumeric(threshold)&&isscalar(threshold),'threshold needs to be a numeric scalar.')
assert(threshold > 0, 'threshold needs to be positive.');

% Initial state: each cluster is a single point
centers = X; % All clusters' centers exactly each point
clusterNums = 1:size(X,1); % All points in their own cluster to start
iterations = 0;

while true
    [I,D] = knnsearch(centers,centers,'k',2); % KNNSEARCH can handle non-finite centers
    % Remove self
    self = I(:,1)'==1:size(I,1); % Values in I that are also its index in I are exactly "self"
    I(~self,2) = I(~self,1); D(~self,2) = D(~self,1);% Preserve these edge cases by copying value to column 2
    I(:,1) = []; D(:,1) = [];  % Clear first column which is either self or now preserved in column 2
    [~,sorted] = sort(D); % SORT will put all non-finite values last
    minD = D(sorted(1));
    if minD > threshold || isnan(minD)
        break % Minimum distance too large or we started with all NaNs; we're done
    end
    
    % Main part of algorithm
    iterations = iterations + 1;
    for i = 1:length(D) % go through and merge groups if close enough
        ind = sorted(i);
        if D(ind) > threshold; break; end % Finished with this iteration
        this_group = clusterNums(ind);
        nn_group = clusterNums(I(ind));
        if this_group == nn_group; continue; end % Already grouped; continue
        inds_nn_group = clusterNums==nn_group; % All points in nn_group
        new_group_members = clusterNums==this_group | inds_nn_group;
        new_center = mean(X(new_group_members,:),1);
        if any(sqrt(sum((centers(new_group_members,:)-new_center).^2,2)) > threshold)
            % Edge case where by adding new group members, group now
            % includes points > threshold from center
            continue
        end
        % Bring nearest neighbor (nn) group to this group
        clusterNums(inds_nn_group) = this_group;
        % Update group centers
        centers(inds_nn_group,:) = NaN; % Nullify nn group
        centers(this_group,:) = new_center;
    end
end
end

function [clusterNums,centers,iters] = test()
n = 10; c = 5;
threshold = 1;
Xs = rand(n,2)*10;
X = NaN(n*c,2);
for i = 1:c
    X((i-1)*n+1:i*n,:) = Xs + rand(1,2);
end
X(end+1,:) = rand(1,2)*10; % Add lone point too
[clusterNums,centers,iters] = clusterPoint(X,threshold);
f = UseFigure('test1',true); ax = axes('parent',f);
hold(ax,'on'); axis(ax,'image');
scatter(X(:,1),X(:,2));
clusters = unique(clusterNums);
legend_holder = gobjects(0);
cs = lines(7);
for i = 1:length(clusters)
    np = sum(clusters(i) == clusterNums); % num points in cluster
    if np > 1
        leg_entry = findobj(legend_holder,'UserData',np);
        if isempty(leg_entry)
            leg_entry = line(NaN,NaN,'linewidth',2,'color',cs(length(legend_holder)+1,:),...
                'DisplayName',[num2str(np) ' points'],'UserData',np);
            legend_holder(end+1) = leg_entry;
        end
        drawcircle(ax,'Center',centers(clusters(i),:),'Radius',threshold,'Color',leg_entry.Color,...
            'deletable',false,'InteractionsAllowed','none');
        
    end
    legend(legend_holder);
end
end