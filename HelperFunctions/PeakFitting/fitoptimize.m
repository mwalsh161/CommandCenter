function [x0, xx, xxx] = fitoptimize(x, y)
    % Given a 1xN sweep x producing a 1xN signal y, fitoptimize chooses an x0 likely to maximize signal.
    % Somewhat resilient to noise and multi-peaking. Will preference peaks centered in the range x.
    m = nanmin(y); M = nanmax(y);
    
    if m == M
        x0 = mean(x);
        return
    end
    
    y = (y - m)/(M - m);

    levellist = .75:.05:.95;
    xx = NaN(1, length(levellist));
    
    for ii = 1:length(levellist)
        xx(ii) = levelfun(y > levellist(ii));
    end
    
    xxx = xx;
    
    outliers = true;
    
    centerdistance = abs(xx - mean(x));
    [~, I] = sort(centerdistance);
    xx = xx(I);
    
    while any(outliers) && std(xx) > 0              % While there are outliers...
        outliers = abs(xx - mean(xx)) >= std(xx);   % Define outliers to be those outside one standard deviation (low bar to increase chance of rejection).
        xx(find(outliers, 1, 'last')) = [];         % Reject the least prominant outlier
    end
    
    xxx = x(round(xxx));
    
    x0 = mean(x(floor(xx)) + x(ceil(xx)))/2;
    
    function centroid = levelfun(data)
        data = imdilate(data, strel('diamond', 4));

        [labels, ~] = bwlabel(data, 8);
        candidates = regionprops(labels, 'Area', 'Centroid');
        [~, indices] = sort([candidates.Area], 'descend');
        centroid = max(candidates(indices(1)).Centroid);
    end
end