function [offsets,thetas,scalings] = findQR(c,conv)
% Finds QR code or returns error using imfindcircles
%% Init
spacing = Base.QR.spacing/mean(conv);
dist = @(a,b)sqrt((a(1)-b(1))^2+(a(2)-b(2))^2);
angle = @(a,b)acos(dot(a,b)/(norm(a)*norm(b)));
%% Go through all circles in c
offsets = {};
thetas = {};
scalings = {};
candidate_verts = 1:size(c,1);   % Index into c
candidate_origins = 1:size(c,1); % Index into c
while ~isempty(candidate_origins)
    i = candidate_origins(1);    % Use first value everytime since we will pop it at the end
    candidates = [];
    % Narrow options to candidates
    for j = candidate_verts
        d = dist(c(i,:),c(j,:));
        if spacing*0.5 < d && d < spacing*1.5
            candidates(end+1) = j;
        end
    end
    % See if any align to form QR shape
    done = false;
    for j = candidates
        for k = candidates
            a = angle(c(j,:)-c(i,:),c(k,:)-c(i,:));
            if abs(a - pi/2)<Base.QR.angle_thresh...
                    &&abs(dist(c(i,:),c(j,:))/dist(c(i,:),c(k,:))-1)<Base.QR.leg_len_thresh
                origin = c(i,:);
                verts(1,:) = c(j,:)-origin;
                verts(2,:) = c(k,:)-origin;
                if (verts(1,1)*verts(2,2)-verts(1,2)*verts(2,1))>0
                    x = verts(1,:);
                else
                    x = verts(2,:);
                end
                theta = -sign(x(2))*angle([1 0],x);
                scaling = norm(x)/Base.QR.spacing;
                offset = origin;
                thetas{end+1} = theta;
                scalings{end+1} = scaling;
                offsets{end+1} = offset;
                % If this was a QR code, we want to remove all of these points from candidate_*
                candidate_verts(candidate_verts==j) = [];
                candidate_verts(candidate_verts==k) = [];
                candidate_verts(candidate_verts==i) = [];
                % If they were vertices, then they certainly aren't origins
                candidate_origins(candidate_origins==j) = [];
                candidate_origins(candidate_origins==k) = [];
                done = true;
                break
            end
        end
        if done
            break
        end
    end
    candidate_origins(1) = [];  % Either it was an origin and has been logged, or it wasn't.
end
%                 if to_plot
%                     figure;
%                     imagesc(im);
%                     axis image
%                     colormap gray
%                     set(gca,'YDir','normal')
%                     hold on
%                     plot(c(:,1),c(:,2),'b*')
%                     plot(origin(1),origin(2),'r*')
%                     plot(c(j,1),c(j,2),'g*')
%                     plot(c(k,1),c(k,2),'g*')
%                 end
assert(numel(thetas)>0,'Could not find QR structure.')
end
