function order = dependency_sort(graph)
% DEPENDENCY_SORT Sort a directed graph.
%   Input graph is a structure with "s" and "edges". 
%   s - array of nodes that have no incoming edges.
%   edges - nx2 array of nodes that form an edge. For example:
%       1, 2
%       6, 3
%       are two edges from node 1 to 2 and from 6 to 3.
%
%   Note: nodes must be numeric values. Before using this function, you
%   need to encode your nodes into numeric values. The easiest way is to
%   have a list, and simply use the index number as the node into this
%   function.

s = graph.s;
edges = graph.edges;
order = [];

while ~isempty(s)
    n = s(1);
    s(1) = [];
    order(end+1) = n;
    % Find all edges leaving node
    leaving = find(edges(:,1)==n);
    while ~isempty(leaving)
        i = leaving(1);
        m = edges(i,2);
        edges(i,:) = [];
        if isempty(find(edges(:,2)==m,1))
            s(end+1) = m;
        end
        leaving = find(edges(:,1)==n);
    end
end
if ~isempty(edges)
    error('Module dependency has a cycle')
end
end

