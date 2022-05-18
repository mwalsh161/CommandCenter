function [cent, varargout]=FastPeakFind(d,thresh)
edg = 3;
if any(d(:))
	d=d.*(d>thresh);
    %d = d(d>thresh); ??? 
	if any(d(:))
		sd=size(d);
        [x, y]=find(d(edg:sd(1)-edg,edg:sd(2)-edg));
               
        % initialize outputs
        cent=[];%
        cent_map=zeros(sd);
               
        x=x+edg-1;
        y=y+edg-1;
        for j=1:length(y)
            if (d(x(j),y(j))>=d(x(j)-1,y(j)-1 )) &&...
               (d(x(j),y(j))>d(x(j)-1,y(j))) &&...
               (d(x(j),y(j))>=d(x(j)-1,y(j)+1)) &&...
               (d(x(j),y(j))>d(x(j),y(j)-1)) && ...
               (d(x(j),y(j))>d(x(j),y(j)+1)) && ...
               (d(x(j),y(j))>=d(x(j)+1,y(j)-1)) && ...
               (d(x(j),y(j))>d(x(j)+1,y(j))) && ...
               (d(x(j),y(j))>=d(x(j)+1,y(j)+1));              
                   cent = [cent ;  y(j) ; x(j)];
                   cent_map(x(j),y(j))=cent_map(x(j),y(j))+1; % if a binary matrix output is desired
            end
        end
	else % in case image after threshold is all zeros
		cent=[];
        cent_map=zeros(size(d));
        if nargout>1 ;  varargout{1}=cent_map; end
        return
	end
else % in case raw image is all zeros (dead event)
	cent=[];
    cent_map=zeros(size(d));
    if nargout>1 ;  varargout{1}=cent_map; end
    return
end
if nargout>1 ;  varargout{1}=cent_map;
end