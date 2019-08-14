function c = findMarkers(im,conv,sensitivity,ax_debug)
r = Base.QR.r/conv;
A = pi*r^2;
thresh.eccentricity = 0.7;    % Filter for eccentricity less than
thresh.larger_area = A*0.25;  % Filter for area greater than
thresh.smaller_area = A*4;    % Filter for area less than

lp = r/4;
im_filt = imgaussfilt(im,lp);
if isvalidax(ax_debug(1))
    imagesc(ax_debug(1),im_filt);
    title(ax_debug(1),sprintf('findMarkers: lowpass (%0.2f px)',lp));
end

% Find Circles
% Convert to BW (logical)
thresh.BW = median(im_filt(:)) - sensitivity*std(im_filt(:));
BW = im_filt<=thresh.BW;
if isvalidax(ax_debug(2))
    imagesc(ax_debug(2),BW);
    title(ax_debug(2),sprintf('findMarkers: binary (thresh %0.2f)',thresh.BW));
end
st = regionprops(BW,'Area','Centroid','Eccentricity');

if all(isvalidax(ax_debug)) && ~isempty(st)
    c = cat(1,st.Centroid);
    s(1,1) = scatter(ax_debug(1),c(:,1),c(:,2),'ro');
    s(1,2) = scatter(ax_debug(2),c(:,1),c(:,2),'ro');
end
sel = [st.Area]>thresh.larger_area;
st = st(sel);

if all(isvalidax(ax_debug)) && ~isempty(st)
    c = cat(1,st.Centroid);
    s(2,1) = scatter(ax_debug(1),c(:,1),c(:,2),'o','markeredgecolor',[ 0.9100 0.4100 0.1700]);
    s(2,2) = scatter(ax_debug(2),c(:,1),c(:,2),'o','markeredgecolor',[ 0.9100 0.4100 0.1700]);
end
sel = [st.Area]<thresh.smaller_area;
st = st(sel);

if all(isvalidax(ax_debug)) && ~isempty(st)
    c = cat(1,st.Centroid);
    s(3,1) = scatter(ax_debug(1),c(:,1),c(:,2),'yo');
    s(3,2) = scatter(ax_debug(2),c(:,1),c(:,2),'yo');
end
sel = [st.Eccentricity]<thresh.eccentricity;
st = st(sel);

c = cat(1,st.Centroid);

if all(isvalidax(ax_debug)) && ~isempty(st)
    c = cat(1,st.Centroid);
    s(4,1) = scatter(ax_debug(1),c(:,1),c(:,2),'mo');
    s(4,2) = scatter(ax_debug(2),c(:,1),c(:,2),'mo');
    legend(s(:,2),{sprintf('Area<%g px^2',thresh.larger_area),...
                   sprintf('Area>%g px^2',thresh.smaller_area),...
                   sprintf('Eccentricity<%g',thresh.eccentricity),...
                   'Passed (covered by blue unless error)'})
end
end