classdef SmartSample < handle
    %SMARTSAMPLE Tracks visited positions in real space and diamond space.
    %   Functionality to move across sample given diamond space
    %   coordinates.  Image positions are interpreted from QR codes.
    %
    %   The stage position will be used to give a confidence score of the
    %   interpreted QR codes, but this requires a clean QR code to start!
    %
    %   When initializing, make sure in focus and QR code visible!
    
    properties
        % Properties to set on imaging device when acquiring white light
        % images.  The format should be {prop1,val1,prop2,val2...}
        %   properties should be identical to the module property to be set
        whiteLightImProperties = {};
        % Properties to set on imaging device when acquiring fluorescent
        % images.  The format should be {prop1,val1,prop2,val2...}
        %   properties should be identical to the module property to be set
        greenLightImProperties = {};
        chipSize  % [x y] Size of chip in um
        allowedDev = 20; % um (allowed error between stage position and sample position)
        
        % NV fitting/detection
        spatial_filter = [100 980; 94 543;95 61;408 61;1056 63;1238 509;1216 980];  % For fitting NVs (coordinates in pixels on frame)
        NVsize = 8;  % Diameter of NV in pixels (bin = 1)
        sensitivity = 3.5;  % NV detection threshold (stddev above mean on band-pass filtered image based on NVsize).
        
        % EBL cross location from edge
        crossesPos = [500,500;500,-500;-500 500;-500 -500];
        % Aberration correction locations from center
        aberrationCorrectionPos = [500,-500;500,500;-500,500];
        
        maxJog = 1000;  % um Minimum stepsize for motors
        accuracy = 5;   % um Accuracy required for destination
        blackList = NaN(0,2); % Positions on stage to not suggest as nearest neighbor
        
        % Safety
        start_height = NaN;
        working_distance = 200;  % um
    end
    properties(SetAccess=private)
        stagePositions = NaN(0,3);  % Nx3 matrix: [x,y,z;x2,y2,z2;...xN,yN,zN]
        samplePositions = NaN(0,3); % Nx3 matrix: [x,y,0;...]

        % readInfo struct from Base.QR with added success field to
        % interpret type of error
        %   status: 0 = no error, 1 = not found 2 = wrong digitization,
        %           3 = Pad check failed, 4 = border breach
        readInfos = struct('qrInfo',{},'tform',{},'err',{},'npoints',{},'status',{});
        
        lastImage                   % Can use this to grab an image that resulted in an error
        focusMetrics                % Metric for focussing (see if there is a trend)
        focusTime                   % Time in seconds to complete focusing
        
        % State of illumination (green, white, off). This is prepared when initialzied.
        %   NOTE this is the last state set by SmartSample. Not necessary current state!
        %   Could add a listener to src.source_on property
        LightState = 'white';
    end
    properties(Access=private)
        WhiteLight
        GreenLaser
        Managers
    end
    
    methods
        function obj = SmartSample(chipSize,WhiteLight,GreenLaser,Managers,varargin)
            % SmartSample(chipSize,wl,gl,managers,prop,val)
            res = Managers.Imaging.active_module.resolution;
            assert(numel(varargin)/2==round(numel(varargin))/2,'Property missing value in input!')
            for i = 1:numel(varargin)/2
                obj.(varargin{2*i-1}) = varargin{2*i};
            end
            if GreenLaser.source_on
                GreenLaser.off;
            end
            if ~WhiteLight.source_on
                WhiteLight.on;
            end
            obj.setImProps(obj.whiteLightImProperties);
            obj.chipSize = chipSize;
            obj.WhiteLight = WhiteLight;
            obj.GreenLaser = GreenLaser;
            obj.Managers = Managers;
            % Intialize position
            stage = obj.Managers.Stages(1);
            f = findall(0,'name','SmartSample Initialization');
            if isempty(f) || ~isvalid(f)
                f = figure('units','normalized','position',[0 0 1 1],'name','SmartSample Initialization','visible','off');
            else
                clf(f)
                f.Visible = 'off';
            end
            [samplePos,stagePos,readInfo] = obj.getPosition('enhanced',true,'verbose',axes('parent',f));
            f.Visible = 'on';
            assert(readInfo.status==0,...
                sprintf('Error finding/reading QR code: StatusCode=%i.',readInfo.status))
          %  button = questdlg('Continue?','SmartSample Initialization','Yes');
            close(f)
          %  assert(strcmp(button,'Yes'),...
          %      'Aborted SmartSample Initialization. Prepare sample and try again.')
            % Move in x and y to next readable code
            R = readInfo.tform.T(1:2,1:2);
            % Make sure edge cases aren't a problem in x or y (only need to check positive side)
            direction = [1 1];
            for i = 1:2
                if samplePos(i) + Base.QR.spacing_between > obj.chipSize(i)
                    direction(i) = -1;
                end
            end
            for axis = 1:2
                sampleJog = [0 0];
                for i = 1:10  % Limit to 10 steps in a direction
                    sampleJog(axis) = Base.QR.spacing_between;
                    nextStageJog = direction.*sampleJog*R;
                    stage.jog([nextStageJog 0]);
                    stage.waitUntilStopped;
                    err = obj.getPosition;
                    if ~(err==1)
                        break
                    end
                end
            end
            obj.start_height = stagePos(3);
        end
        function set.whiteLightImProperties(obj,val)
            len = numel(val);
            assert(len/2 == floor(len/2),'Missing property/value pair.')
            obj.whiteLightImProperties = val;
        end
        function set.greenLightImProperties(obj,val)
            len = numel(val);
            assert(len/2 == floor(len/2),'Missing property/value pair.')
            obj.greenLightImProperties = val;
        end
        %% Acquiring Images
        function oldState = illumination(obj,state)
            % Use this to make sure correct illumination
            % Allows for only 3 states (green, white, off)
            oldState = obj.LightState;
            switch lower(state(1))
                case 'g'
                    if obj.WhiteLight.source_on
                        obj.WhiteLight.off;
                    end
                    obj.GreenLaser.on;
                    obj.LightState = 'green';
                case 'w'
                    if obj.GreenLaser.source_on
                        obj.GreenLaser.off;
                    end
                    obj.WhiteLight.on;
                    obj.LightState = 'white';
                case 'o'
                    obj.GreenLaser.off;
                    obj.WhiteLight.off;
                    obj.LightState = 'off';
                otherwise
                    error('%s is not a valid state. Options are green, white, off',state)
            end
        end
        function setImProps(obj,props)
            % Sets the imaging module from Managers to given props
            for i = 1:numel(props)/2
                obj.Managers.Imaging.active_module.(props{i*2-1}) = props{i*2};
            end
        end
        function im = acquire(obj,type,varargin)
            % type: "white" or "green"
            % Returns a SmartImage
            assert(ismember(type,{'white','green'}),'Must be either white or green.')
            before = obj.illumination(type);
            obj.setImProps(obj.([type 'LightImProperties']));
            im = obj.acquireImage(varargin{:});
            obj.lastImage = im;
            obj.illumination(before);
        end
        function im = acquireImage(obj,force_save)
            if nargin < 2
                force_save = false;
            end
            cont = obj.Managers.Imaging.active_module.continuous;
            im = obj.Managers.Imaging.snap(~force_save);  % quietly = not(force_save)
            if cont
                obj.Managers.Imaging.startVideo;
            end
        end
        
        %% Position Finding
        function [varargout] = getPosition(obj,varargin)
            % GETPOSITION Focuses, then takes a SmartImage and returns (x,y) or will acquire the
            % image if none given.
            % Will attempt to move 2 in all directions to find readable QR
            % code. After that, it will error.
            %
            % GETPOSITION(obj, [prop1,val1,...])
            %   props are property,value pairs
            %   props = im (SmartImage), enhanced (bool), verbose (figure),
            %           focus (bool)
            %
            % OUTPUT help:
            % err: 0 = no error, 1 = not found 2 = wrong digitization,
            %      3 = Pad check failed, 4 = border breach
            % 
            % Default for verbose is false. Otherwise, supply valid axes.
            % 
            % Parse Input
            props = {'im','enhanced','verbose','focus'};
            im = [];
            enhanced = false;
            verbose = false;
            focus = true;
            n = numel(varargin);
            assert(n/2==floor(n/2),'A property is missing its value pair.')
            for i = 1:n/2
                prop = varargin{i*2-1};
                val = varargin{i*2};
                assert(logical(sum(strcmp(prop,props))),sprintf('Property %s not valid.',prop))
                eval(sprintf('%s=val;',prop));
            end
            if isempty(im)
                if focus
                    obj.focus;
                end
                im = obj.acquire('white');
            end
            % Evaluate
            stagePos = obj.Managers.Stages.position;
            try
                if enhanced
                    [samplePos,readInfo] = Base.QR.enhancedReader(im,verbose); %#ok<UNRCH>
                else
                    [samplePos,readInfo] = Base.QR.reader(im,verbose);
                end
                status = 0;
                samplePos(end+1) = 0;
            catch e
                switch e.message
                    case 'Could not find QR structure.'
                        status = 1;
                    case 'Checksum failed.'
                        status = 2;
                    case 'Padding bits are incorrect.'
                        status = 3;
                    case 'Border is nonzero.'
                        status = 4;
                    otherwise
                        rethrow(e)
                end
                obj.blackList(end+1,:) = stagePos(1:2);
                readInfo = struct('qrInfo',NaN,'tform',NaN,'err',NaN,'npoints',NaN);
                samplePos = [NaN,NaN,NaN];
            end
            % Double check it is within chip bounds (it cannot read
            %     negative valuess, so just make sure not too large)
            assert(samplePos(1) <= obj.chipSize(1) && samplePos(2) <= obj.chipSize(2),...
                'Observed position outside chip boundary!')
            readInfo.status = status;
            
            % Update object
            obj.readInfos(end+1) = readInfo;
            obj.samplePositions(end+1,:) = samplePos;
            obj.stagePositions(end+1,:) = stagePos;
            varargout = {samplePos,stagePos,readInfo,im};
            varargout = varargout(1:max(1,nargout));
        end
        function focus(obj)
            obj.illumination('white');
            obj.setImProps(obj.whiteLightImProperties);
            [metric,time] = obj.Managers.Imaging.autofocus;
            obj.focusMetrics(end+1) = metric;
            obj.focusTime(end+1) = time;
            obj.Managers.Stages.waitUntilStopped;
        end
        function [NVs,fl,wl,posSample] = getNVs(obj,varargin)
            % Attempts to get NVs at current location without focusing
            % If verbose desired, fig be figure handle
            % Inputs opts: 'fig' (figure handle)
            %              'wl' (whitelight image)
            %              'fl' (greenlight image)
            %              'frame_pos_only'
            %   If wl and fl aren't both specified, retakes both.
            props = {'fig','wl','fl','frame_pos_only'};
            fig = false;
            wl = Base.SmartImage.empty(0);
            fl = Base.SmartImage.empty(0);
            frame_pos_only = false;
            n = numel(varargin);
            assert(n/2==floor(n/2),'A property is missing its value pair.')
            for i = 1:n/2
                prop = varargin{i*2-1};
                val = varargin{i*2};
                assert(logical(sum(strcmp(prop,props))),sprintf('Property %s not valid.',prop))
                eval(sprintf('%s=val;',prop));
            end
            if ishandle(fig) && isvalid(fig)
                ax1 = subplot(1,2,1,'parent',fig);
                ax2 = subplot(1,2,2,'parent',fig);
            else
                ax1 = false;
                ax2 = false;
            end
            wasOn = false;
            if isempty(wl) || isempty(fl)
                if obj.Managers.Imaging.active_module.continuous
                    wasOn = true;
                    oldType = obj.LightState;
                    obj.Managers.Imaging.stopVideo;
                end
                % Parallel computing might be nice here - find position while
                % snapping green
                if ~frame_pos_only
                    wl = obj.acquire('white');
                end
                fl = obj.acquire('green');
            end
            % Global position
            if ~frame_pos_only
                [posSample,~,readInfo] = obj.getPosition('im',wl,'verbose',ax1,'enhanced',true);
                if readInfo.status
                    error('Error getting position. Status: %i',readInfo.status)
                end
            end
            im = double(fl.image);
            % Find NVs
            [NV,err] = NVposition2D(im,obj.NVsize,obj.sensitivity,obj.spatial_filter,ax2);  % inputs: image, NV size (px)[, hp, lp, n]
            if isempty(NV)
                NVs = struct('global',{},...
                    'frame',{},...
                    'err',err,...
                    'npoints',{});
                return
            end
            % Convert from pixel -> um
            x = fl.ROI(1,:);
            y = fl.ROI(2,:);
            im = fl.image;
            conv = [diff(x)/(size(im,2)-1),diff(y)/(size(im,1)-1)]; % um/pixel
            NV(:,1) = (NV(:,1)-1)*conv(1) + x(1);
            NV(:,2) = (NV(:,2)-1)*conv(2) + y(1);
            sz = size(NV,1);
            if ~frame_pos_only
                % Transform to sample frame
                pos = transformPointsInverse(readInfo.tform,NV);
                if wasOn && oldType(1)~='o'   % Was on, and a light was not off
                    obj.setImProps(obj.([oldType 'LightImProperties']));
                    obj.Managers.Imaging.startVideo;
                end
                npoints = zeros(sz,1) + readInfo.npoints;
                coord_err = zeros(sz,1) + readInfo.err;
            else
                pos = NaN(sz,2);
                npoints = zeros(sz,1);
                coord_err = zeros(sz,1);
            end
            NVs = struct('global',mat2cell(pos,ones(1,sz),2),...
                'frame',mat2cell(NV,ones(1,sz),2),...
                'err',num2cell(err),...
                'npoints',num2cell(npoints),...
                'coord_err',num2cell(coord_err));
        end
        %% Position Setting
        function [closestStage,closestSample] = closestKnownPosition(obj,pos,posType)
            % Return closest position in stage coordinates (x,y,z) and sample (x,y)
            % Needed to also limit to most recent set, because of stage drift
            % If the closest known position is the current one, choose next closest.
            %   If posType == 'stage', pos should be in stage frame (x,y,z) or (x,y).
            %   If posType == 'sample', pos should be in sample frame (x,y,z) or (x,y).
            assert(length(pos)>=2,'Pos vector must atleast be x,y.')
            % Prune stage and sample lists to remove NaNs
            mask = find(~isnan(obj.samplePositions));
            mask = mask(1:end/3);  % Only need to know first column of the 3!
            stage = obj.stagePositions(mask,:);  % Nx3
            sample = obj.samplePositions(mask,:);% Nx3
            stage(1:max(0,end-2000),:)=[];
            sample(1:max(0,end-2000),:)=[];
            % Remove black listed locations
            [~,d] = knnsearch(obj.blackList,stage(:,1:2),'K',1);
            sample(d<Base.QR.spacing_between,:)=[];
            stage(d<Base.QR.spacing_between,:)=[];
            switch posType
                case 'stage'
                    [~,d] = knnsearch(pos(1:2),stage(:,1:2),'K',1);
                case 'sample'
                    [~,d] = knnsearch(pos(1:2),sample(:,1:2),'K',1);
                otherwise
                    error('Unknown posType: should be "stage" or "sample".')
            end
            I = 1:size(sample,1);
            I(d<=Base.QR.spacing_between)=[];  % Remove places that are too close
            d(d<=Base.QR.spacing_between)=[];
            [~,ind] = min(d);
            I = I(ind);
            assert(length(I)==1,sprintf('I should be of length 1, not %i',length(I)));
            closestStage = stage(I,:);
            closestSample = sample(I,1:2);
        end
        function [approxJog,currentPos] = estimateJog(obj,pos,currentPos,stagePos,readInfo,ax,ax2)
            % If currentPos AND stagePos AND qrInfo aren't given, querry position
            % pos is sample position
            if nargin < 5
                [currentPos,stagePos,readInfo] = obj.getPosition('enhanced',true);
                ax = []; ax2 = [];
            elseif nargin < 6
                ax = []; ax2 = [];
            elseif nargin < 7
                ax2 = [];
            end
            assert(readInfo.status==0,'Could not get sample position.')
            % Approximate Z
            sa = obj.samplePositions;
            st = obj.stagePositions;
            mask = find(isnan(sa));
            mask = mask(1:end/3);  % Only need to know first column!
            sa(mask,:) = [];
            st(mask,:) = [];
            % Only use last 4000 data points, because stage drifts over time
            sa_fit = sa; st_fit = st;
            sa_fit(1:max(0,end-4000),:)=[];
            st_fit(1:max(0,end-4000),:)=[];
            if size(sa_fit,1) > 20
                M = [sa_fit(:,1:2) sa_fit(:,1:2).^2 ones(size(sa_fit,1),1)]\st_fit(:,3); % Second-order fit
                Z = [pos pos.^2 1]*M;
            else
                M = [sa_fit(:,1:2) ones(size(sa_fit,1),1)]\st_fit(:,3); % first-order fit
                Z = [pos 1]*M;
            end
            if ~isempty(ax) % Take care of verbose axes
                if ishandle(ax)
                    plot3(ax,sa(:,1),sa(:,2),st(:,3),'.','markersize',12);
                    hold(ax,'on')
                    plot3(ax,sa_fit(:,1),sa_fit(:,2),st_fit(:,3),'r.','markersize',12);
                    title(ax,sprintf('Sample locations (%i points)',size(st,1)));
                    xlabel(ax,'x (um sample)');
                    ylabel(ax,'y (um sample)');
                    zlabel(ax,'z (um stage)');
                    hold(ax,'on')
                    [X,Y] = meshgrid(linspace(0,obj.chipSize(1),200),linspace(0,obj.chipSize(2),200));
                    if size(sa_fit,1)>20
                        thZ = reshape([X(:) Y(:) X(:).^2 Y(:).^2 ones(size(X(:),1),1)]*M,200,200);
                    else
                        thZ = reshape([X(:) Y(:) ones(size(X(:),1),1)]*M,200,200);
                    end
                    mesh(ax,X,Y,thZ)
                    hold(ax,'off')
                    view(ax,-20,76);
                    if ~isempty(ax2)
                        if ishandle(ax2)
                            if size(sa_fit,1)>20
                                thZ = [sa(:,1:2),sa(:,1:2).^2 ones(size(st,1),1)]*M;
                            else
                                thZ = [sa(:,1:2) ones(size(st,1),1)]*M;
                            end
                            stem3(ax2,st(:,1),st(:,2),thZ-st(:,3),'.','markersize',10);
                            title(ax2,'Residuals (Stage coords)')
                            xlabel(ax2,'x (um stage)');
                            ylabel(ax2,'y (um stage)');
                            zlabel(ax2,'dz (um stage)');
                            view(ax2,-20,76);
                        else
                            warning('ax2 must be valid handle.')
                        end
                    end
                    
                else
                    warning('ax must be valid handle.')
                end
            end
            if Z >= obj.start_height + obj.working_distance
                error('Estimated Z to be %0.2f, which is higher than limit (%0.2f)',Z,obj.start_height + obj.working_distance);
            end
            if size(st_fit,1) > Inf
                % NEED TO RECONSIDER THIS TO USE LOCAL DATA HEAVIER
                trans = fitgeotrans(sa_fit(:,1:2),st_fit(:,1:2),'affine');
                st_pos = trans.transformPointsForward(pos);
                st_pos(3) = Z;
                approxJog = st_pos - stagePos;
            else
                dZ = Z-stagePos(3);
                R = readInfo.tform.T(1:2,1:2);
                approxJog = [(pos-currentPos(1:2))*R dZ];
            end
        end
        function setPositionBlind(obj,pos,pLoc)
            % Will not take pictures/verify position - takes one leap of faith
            sa = obj.samplePositions;
            st = obj.stagePositions;
            mask = find(isnan(sa));
            mask = mask(1:end/3);  % Only need to know first column!
            sa(mask,:) = [];
            st(mask,:) = [];
            trans = fitgeotrans(sa(:,1:2),st(:,1:2),'affine');
            st_pos = trans.transformPointsForward(pos);
            M = [sa(:,1:2) ones(size(sa,1),1)]\st(:,3);
            st_pos(3) = [pos 1]*M;
            obj.Managers.Stages.move(st_pos);
            obj.Managers.Stages.waitUntilStopped;
            if nargin == 3 && isvalid(pLoc)
                set(pLoc,'xdata',pos(1),'ydata',pos(2));
                drawnow;
            end
        end
        function currentPos = setPosition(obj,pos,pLoc,varargin)
            % Move stage to approximate sample
            % See estimatePosition inputs
            % pLoc is a handle to a plot to update sample pos
            if nargin < 3
                pLoc = [];
            end
            if ~isempty(pLoc) && isvalid(pLoc)
                temp = plot(pLoc.Parent,pos(1),pos(2),'+k');
            end
            for i = 1:10
                try
                    [approxJog,currentPos] = obj.estimateJog(pos,varargin{:});  % Keep in mind that this focuses too
                    varargin = {};  % Should only happen on first iteration of loop
                catch err
                    if ~isempty(pLoc) && isvalid(temp)
                        delete(temp)
                    end
                    rethrow(err)
                end
                if ~isempty(pLoc) && isvalid(pLoc)
                    set(pLoc,'xdata',currentPos(1),'ydata',currentPos(2));
                    drawnow;
                end
                varargin = {};
                dist = sqrt(sum(approxJog.^2));
                if dist < obj.accuracy
                    if ~isempty(pLoc) && isvalid(temp)
                        delete(temp)
                    end
                    return
                end
                shorten = max([1,dist/obj.maxJog]);  % Don't make longer!
                jog = approxJog/shorten;
                if ~obj.validPosition(jog)
                    if ~isempty(pLoc) && isvalid(temp)
                        delete(temp)
                    end
                    error('Destination out of stage range.')
                end
                obj.Managers.Stages.jog(jog);
                obj.Managers.Stages.waitUntilStopped;
            end
            if ~isempty(pLoc) && isvalid(temp)
                delete(temp)
            end
            error('Could not navigate to position in 10 attempts.')
        end
        function valid = validPosition(obj,approxJog)
            % Returns true or false based on the estimation of the current
            % position.  Useful to pre-screen which candidate positions are
            % valid.
            % See estimatePosition inputs
            valid = true;
            stage = obj.Managers.Stages.active_module;
            approxStagePos = stage.position + approxJog;
            lims = {'xRange','yRange','zRange'};
            for i = 1:numel(lims)
                limit = stage.(lims{i});
                if approxStagePos(i) < min(limit) || approxStagePos(i) > max(limit)
                    valid = false;
                    return
                end
            end
        end
        %% Visualization
        function h = drawSample(obj,ax)
            % Renders sample in sample frame, returning hgtransform object
            if nargin < 2
                f = figure('name','SmartSampleMap');
                ax = axes('tag','SmartSample','parent',f);
            end
            axis(ax,'image')
            xlabel(ax,'x (um)')
            ylabel(ax,'y (um)')
            h = hgtransform('parent',ax,'tag','Sample','HitTest','off');
            % Draw border
            rectanglerot(h,[0 0 obj.chipSize(1:2)],[0.5 0.5 0.5],'linewidth',1.5,...
                'tag','Sample','facealpha',1,'HitTest','off');
            % Draw EBL crosses
            n = size(obj.crossesPos,1);
            for i = 1:n
                s = 300;  % size in um
                if obj.crossesPos(i,1) < 0
                    x = obj.chipSize(1)+obj.crossesPos(i,1);
                else
                    x = obj.crossesPos(i,1);
                end
                if obj.crossesPos(i,2) < 0
                    y = obj.chipSize(2)+obj.crossesPos(i,2);
                else
                    y = obj.crossesPos(i,2);
                end
                d = [-1 1]*s/2;
                line(d+x,[y y],'parent',h,'linewidth',3,'HitTest','off')
                line([x x],d+y,'parent',h,'linewidth',3,'HitTest','off')
            end
            % Draw Aberration Correction region (-spacing/2..spacing)
            n = size(obj.aberrationCorrectionPos,1);
            for i = 1:n
                spacing = Base.QR.spacing_between;
                centerpos = obj.chipSize/2 + obj.aberrationCorrectionPos(i,:);
                centerpos = floor(centerpos/spacing)*spacing;
                bottomleft = [-spacing/2 -spacing/2] + centerpos;
                rectanglerot(h,[bottomleft spacing spacing],'linewidth',1,'HitTest','off');
            end
            % Marker at origin
            plot(h,0,0,'r*','HitTest','off');
        end
        function ax = drawInStage(obj,varargin)
            % Renders sample in stage frame, returning hgtransform object
            % Same input as drawSample
            sample = obj.drawSample(varargin{:});
            ax = sample.Parent;
            sa = obj.samplePositions;
            st = obj.stagePositions;
            mask = find(isnan(sa));
            mask = mask(1:end/3);  % Only need to know first column!
            badPos = st(mask,:);
            goodPos = st(~mask,:);
            sa(mask,:) = [];
            st(mask,:) = [];
            tform = [sa(:,1:3) ones(size(sa,1),1)]\[st ones(size(st,1),1)];
            tform(:,4) = [0;0;0;1];  % Fix rounding errors
            tform(3,3) = 1;
            tform = tform';
            try
                xlim = obj.Managers.Stages.modules{1}.xRange;
                ylim = obj.Managers.Stages.modules{1}.yRange;
            catch
                error('Could not load any stage modules. Make sure there is an active stage.')
            end
            sample.Matrix = tform;
            h = hgtransform('parent',ax,'tag','Stage');
            rectanglerot(h,[xlim(1) ylim(1) diff(xlim) diff(ylim)],...
                'red','linewidth',2,'tag','Stage','facealpha',0.2);
            h.Matrix = makehgtform('translate',[0 0 obj.Managers.Stages.position(3)]);
            hold(ax,'on');
            plot3(ax,goodPos(:,1),goodPos(:,2),goodPos(:,3),'b*','tag','StagePoints','HitTest','off');
            plot3(ax,badPos(:,1),badPos(:,2),badPos(:,3),'r*','tag','StagePoints','HitTest','off');
            set(ax,'DataAspectRatioMode','auto')
        end
    end
    
end

