function c = findMarkers(im,conv,ax_debug)
r = Base.QR.r/conv;

lp = r/4;
im_filt = imgaussfilt(im,lp);
if isvalid(ax_debug(1))
    imagesc(ax_debug(1),im_filt);
    title(ax_debug(1),sprintf('findMarkers: lowpass (%0.2f px)',lp));
end

% Find Circles
% Convert to BW (logical)
BW = im_filt;
thresh = median(im_filt(:)) - Base.QR.BW_std*std(im_filt(:));
BW = im_filt<=thresh;
if isvalid(ax_debug(2))
    imagesc(ax_debug(2),BW);
    title(ax_debug(2),sprintf('findMarkers: binary (thresh %0.2f)',thresh));
end
st = regionprops(BW,'Area','Centroid','Eccentricity');
A = pi*r^2;
if all(isvalid(ax_debug))
    c = cat(1,st.Centroid);
    s(1,1) = scatter(ax_debug(1),c(:,1),c(:,2),'ro');
    s(1,2) = scatter(ax_debug(2),c(:,1),c(:,2),'ro');
end
sel = [st.Area]>A*0.25;  % Filter for regions with area greater than
st = st(sel);
if all(isvalid(ax_debug))
    c = cat(1,st.Centroid);
    s(2,1) = scatter(ax_debug(1),c(:,1),c(:,2),'o','markeredgecolor',[ 0.9100 0.4100 0.1700]);
    s(2,2) = scatter(ax_debug(2),c(:,1),c(:,2),'o','markeredgecolor',[ 0.9100 0.4100 0.1700]);
end
sel = [st.Area]<A*1.5;  % Filter for regions with area less than
st = st(sel);
if all(isvalid(ax_debug))
    c = cat(1,st.Centroid);
    s(3,1) = scatter(ax_debug(1),c(:,1),c(:,2),'yo');
    s(3,2) = scatter(ax_debug(2),c(:,1),c(:,2),'yo');
end
sel = [st.Eccentricity]<0.7; % Filter for eccentricity less than
st = st(sel);
c = cat(1,st.Centroid);

if all(isvalid(ax_debug))
    c = cat(1,st.Centroid);
    s(4,1) = scatter(ax_debug(1),c(:,1),c(:,2),'mo');
    s(4,2) = scatter(ax_debug(2),c(:,1),c(:,2),'mo');
    legend(s(:,2),{'Too small','Too big','Too Eccentric','Passed (covered by blue unless error)'})
end
end