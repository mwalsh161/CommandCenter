function [x0, xx, xxx] = fitoptimize(x, y)
    % Given a 1xN sweep x producing a 1xN signal y, fitoptimize chooses an x0 likely to maximize signal.
    % Somewhat resilient to noise and multi-peaking. Will preference peaks centered in the range x.
    m = nanmin(y); M = nanmax(y);
    
    if m == M
        x0 = mean(x);
        return
    end
    
    y = (y - m)/(M - m);

    levellist = .5:.05:.95;
    xx = NaN(1, length(levellist));
    
    for ii = 1:length(levellist)
        xx(ii) = levelfun(y > levellist(ii));
    end
    
    xxx = xx;
    
    outliers = true;
    
    centerdistance = abs(xx - mean(x));
    xx = sort(centerdistance);
    
    while any(outliers) && std(xx) > 0
        outliers = abs(xx - mean(xx)) >= std(xx);
        
        % Reject the least prominant outlier
        xx(find(outliers, 1, 'last')) = [];
    end
    
    xxx = x(round(xxx));
    
    x0 = mean(x(floor(xx)) + x(ceil(xx)))/2;
    
    function centroid = levelfun(data)
        data = imdilate(data, strel('diamond', 4));

        [labels, ~] = bwlabel(data, 8);
        candidates = regionprops(labels, 'Area', 'Centroid');
        [~, indices] = sort([candidates.Area], 'descend');
        centroid = candidates(indices(1)).Centroid(1);
    end
end