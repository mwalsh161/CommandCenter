classdef QR
    % QR Detect and read "QR" codes
    % Two main methods: READER and ENHANCEDREADER. reader does not use the
    % extra alignment markers and does not fit the markers as precicely.
    % enhancedReader does all of that (takes longer).  See method
    % definition for more details.
    % Common methods:
    %   [pos,qrInfo] = reader(im,varargin)
    %   [pos,tform,err,npoints,qrInfo] = enhancedReader([SAME AS READER])
    %   [row,col,version,legacy_error] = analyze(code); code can be
    %       anything that can convert to char vector. Must be 1xBase.QR.length.
    %   handles = plotQRinfo(ax,qrInfo);
    %
    % NOTE: All transformations performed here are nonreflective similar:
    %       rotation, translation and scale only.
    %   While most of the time an inverted QR code won't decode properly,
    %   there are cases where they will! The obvious example is one with
    %   transpose symetry. There are other possible ones that don't have
    %   symmetry but will pass the checksum correctly and yield an
    %   incorrect result. The user must take care in these situations.
    
    properties(Constant)
        % Bit definitions
        length = 25;    % Total lenght of code
        pad = [1 5]; % Pad locations of bits (indexed from 1)
        padVal = 1; % Pad logical value
        vb = 4;   % Version bits
        rb = 8;   % Number of bits to encode the row
        cb = 8;   % Number of bits to encode the col
        cs = 3;   % Checksum
        
        % Paramters of QR code (um)
        module_size = 0.75;  % 0.75
        r = Base.QR.module_size/1.5;
        d = Base.QR.module_size + 0.5;  % Newer versions use module_size not r
        spacing = sqrt(Base.QR.length)*Base.QR.module_size + 2*Base.QR.d;
        NSecondary = 3;  % Number of secondary markers (per arm)
        centralMarks = 0; % Number (n) of central marks (per dim)
        spacing_between = 40;  % um
        
        % Detection constants
        diffraction_limit = 0.1; % um (used when fitting in enhancedReader)
    end

    %% Main methods
    methods(Static)
        function [pos,readInfo,f_debug] = reader(im,varargin)
            % READER Returns QR info if the 3 larger markers are found
            %   The image should be corrected for flat illumination already.
            % Inputs; brackets indicate name,value optional pair:
            %   im: a SmartImage info struct (reader uses the "image" and
            %       "ROI" fields
            %   [sensitivity]: (5) n standard deviations above median when
            %       choosing the binary threshold for finding QR markers
            %   [significance]: (0.05) used to assert enough contrast in
            %       logical 1 and logical 0 pixel values. It is the 'Alpha'
            %       input to ttest2.
            %   [leg_len_thresh]: (0.05) 1 - ratio of length of each leg
            %   [angle_thresh]: (0.1) Error from pi/2 between legs
            %   [debug]: (false) Creates a figure with relevant graphics at each step
            % Outputs:
            %   pos: The estimated position of the image's (0,0) coordinate in
            %       the QR frame. Based on all QRs detected.
            %   readInfo: The details about the result. Fields:
            %       qrInfo*: an array of structs
            %       tform: image coords -> QR coords. This can be thought
            %           of as the inverted "average" of the qrInfo.QR2imT.
            %       std: 1x2 double. std in [x,y] resutling from tform. The units are
            %           in the QR coords. This should be same as image if calibrated well.
            %       npoints: n points used to calculate tform. Always zero
            %           for this function. Reserved for enhancedReader.
            %   f_debug: either empty gobjects or the figure handle if debug is true
            %   *qrInfo includes:
            %       row, col and version: the encoded QR info. If error is
            %           not empty, row and col are empty doubles and
            %           version is NaN.
            %       code: 1xN char (binarystring). Depending on what/if the
            %           error is, this may be empty.
            %       estimate: 1xN double. Estimated value of code as a
            %       double. abs(code - estimate) is ~p(success)
            %       significance: the p value from a ttest between the
            %       reference for logical 0 bits and 1 bits.
            %       error: An empty MException, or the MException if one
            %           occured during decoding
            %       legacy_err: If correct interpretation of code required
            %           assuming the legacy error in the python GDS generator.
            %       QR2imT: Affine transform QR(x,y)[um] -> image(x,y)[um].*
            %       * If error is not empty, these will be from the root
            %       (0,0) QR code instead of the one encoded.
            
            % There will be 3 coordinate systems used throughout this function:
            %   Pixel: corresponding to resized image pixel locations
            %       (resized image is a concept entirely internal to this
            %       method)
            %   Image: The "lab" coordinates. Units used in image.ROI.
            %   QR: The "sample" coordinates. Generated from decoding QR
            %       code and knowledge of QR positioning.
            assert(size(im.image,3)==1,'Image must be gray scale.')
            x = im.ROI(1,:);
            y = im.ROI(2,:);
            im = double(im.image); % Necessary for some filter operations
            p = inputParser;
            addParameter(p,'sensitivity',5,@(a)validateattributes(a,{'numeric'},{'scalar','nonnegative'}));
            addParameter(p,'significance',0.05,@(a)validateattributes(a,{'numeric'},{'scalar','>',0,'<',1}));
            addParameter(p,'leg_len_thresh',0.05,@(a)validateattributes(a,{'numeric'},{'scalar','nonnegative'}));
            addParameter(p,'angle_thresh',0.1,@(a)validateattributes(a,{'numeric'},{'scalar','nonnegative'}));
            addParameter(p,'debug',false,@(a)validateattributes(a,{'logical'},{'scalar'}));
            parse(p,varargin{:});
            p = p.Results;
            
            ax_debug = gobjects(1,4);
            f_debug = gobjects(1);
            if p.debug
                f_debug = figure('name','QR.reader','units','normalized',...
                    'position',[0 0 1 1]);
                dcm_obj = datacursormode(f_debug);
                set(dcm_obj,'UpdateFcn',@Base.QR.tooltip_fn)
                colormap(f_debug,'gray');
                for i = 1:length(ax_debug)
                    ax_debug(i) = subplot(2,2,i,'parent',f_debug);
                    hold(ax_debug(i),'on');
                    axis(ax_debug(i),'image');
                end
                set(ax_debug,'ydir','normal');
                imagesc(ax_debug(1),x,y,im);
                title(ax_debug(1),sprintf('Original (%i x %i)',size(im,2),size(im,1)))
            end
            
            % Resize to square px
            conv = [diff(x)/(size(im,2)-1),diff(y)/(size(im,1)-1)]; % um/pixel
            conv = max(conv); % Reduce to worst resolution
            im = imresize(im,round([diff(y),diff(x)]/conv)+1);
            if p.debug
                imagesc(ax_debug(2),im);
                title(ax_debug(2),sprintf('Square px (%i x %i)',size(im,2),size(im,1)))
            end
            
            % Find all relevent QRs
            marker_cands = Base.QR.findMarkers(im,conv,p.sensitivity,ax_debug(3:4)); % Nx2 double
            markersBase = [0,0;Base.QR.spacing,0;0,Base.QR.spacing]; % Markers base location (root QR)
            [QR2pxT,markersPx_act] = Base.QR.findQR(marker_cands,conv,markersBase,...
                                    p.leg_len_thresh,p.angle_thresh,...
                                    ax_debug(3:4)); % 1xN affine2d, Nx2 px points
            % Note, QR2pxT is not returned because it refers to the resized image (square pixels)
            % markersPx_act are the actual locations from findMarkers
            % corresponding to the QR codes.
            markersImAct = (markersPx_act - 1).*conv + [x(1), y(1)]; % Translate to image coords
            markersQRAct = NaN(size(markersImAct)); % Filled in as analyzed
            
            % Go through and attempt to decode QR codes
            nQRs = length(QR2pxT);
            qrInfo = struct('row',[],'col',[],'version',[],'code',[],...
                            'QR2imT',[],'legacy_err',[],'error',cell(1,nQRs));
            for i = 1:nQRs
                % Calculated theoretical marker position
                markersPx = transformPointsForward(QR2pxT(i), markersBase);
                markersIm = (markersPx - 1).*conv + [x(1), y(1)];
                qrInfo(i).code = false(0);
                qrInfo(i).estimate = false(0);
                qrInfo(i).legacy_err = false;
                bitSamples_px = NaN(0,2);
                try
                    [code,pVal,estimate,bitSamples_px] = Base.QR.digitize(im,QR2pxT(i),p.significance,markersPx);
                    qrInfo(i).code = code;
                    qrInfo(i).estimate = estimate;
                    qrInfo(i).significance = pVal;
                    
                    [row,col,ver,legacy_error] = Base.QR.analyze(code);
                    qrInfo(i).row = row;
                    qrInfo(i).col = col;
                    qrInfo(i).version = ver;
                    qrInfo(i).legacy_err = legacy_error;
                    qrInfo(i).error = MException.empty();
                    % Calculate QR2imT in real coords (no more pixel references)
                    % NOTE: No need to use markersIm_act since there is no new data; just scaled.
                    markersQRAct((i-1)*3+1:i*3,:) = markersBase + [col, row].*Base.QR.spacing_between;
                    qrInfo(i).QR2imT = fitgeotrans(markersQRAct((i-1)*3+1:i*3,:), markersIm,'nonreflectivesimilarity');
                    markers_c = 'g';
                catch err
                    qrInfo(i).version = NaN;
                    qrInfo(i).error = err;
                    % Note this is the QR at (0,0)
                    qrInfo(i).QR2imT = fitgeotrans(markersBase, markersIm,'nonreflectivesimilarity');
                    markers_c = 'r';
                end
                if p.debug
                    scale = sqrt(QR2pxT(i).T(1,1)^2 + QR2pxT(i).T(2,1)^2);
                    bitSamples_im = bitSamples_px/scale; % relative coords; thus only scale matters
                    Base.QR.plotQRinfo(ax_debug(1),qrInfo(i),bitSamples_im);
                    plot(ax_debug(2),markersPx(:,1),markersPx(:,2),[markers_c 'o'],'LineWidth',2);
                end
            end
            % Get overall image transform
            mask = ~isnan(markersQRAct);
            npoints = sum(mask)/2; % divide by 2 because a x,y pair is 1 point
            im2QRT = affine2d.empty();
            pos = NaN(1,2);
            err = NaN(1,2);
            if any(mask)
                markersImAct(~mask) = []; % Remvoing instead of keeping retains array shape
                markersQRAct(~mask) = [];
                im2QRT = fitgeotrans(markersImAct,markersQRAct,'nonreflectivesimilarity');
                % Calculate position and error in control points
                pos = transformPointsForward(im2QRT, [0,0]);
                markers_theory = transformPointsForward(im2QRT, markersImAct);
                err = sqrt(mean((markers_theory-markersQRAct).^2)); % std in x and y
            end
            % Prepare output
            readInfo = struct('qrInfo',qrInfo,'tform',im2QRT,'std',err,'npoints',npoints);
        end
        function [pos,readInfo,ax] = enhancedReader(im,varargin)
            % Same input as reader
            % Uses one QR code, and finds all possible neighboring points
            % Will fire up parallel pool to fit circles.
            % err is the average error of the control points position
            % npoints is the number of control points
            % When applying tform, remember it is necessary to add a 1 at
            %    the end of the vector (for the constant term)
            [~,readInfo,ax] = Base.QR.reader(im,varargin{:});
            qrInfo = readInfo.qrInfo;
            i = 1;  % Denote which QR code to use
            [lab,sample] = Base.QR.hone(im,qrInfo(i),ax);
            % Switch world view from ROI to full sample
            s = Base.QR.spacing_between;
            sample(:,1) = sample(:,1) + qrInfo(i).col*s;
            sample(:,2) = sample(:,2) + qrInfo(i).row*s;
            npoints = size(lab,1);
            % Get rotatioin/scaling/translation transformation
            tform = fitgeotrans(lab,sample,'nonreflectivesimilarity');
            approxSample = transformPointsForward(tform,lab);
            err = abs(approxSample(:,1:2)-sample);
            err = mean(sqrt(err(:,1).^2+err(:,2).^2));
            pos = transformPointsForward(tform,[0 0]);   % Get sample frame coordinate at center of lab frame, (0,0)
            readInfo = struct('qrInfo',qrInfo,'tform',tform.invert(),'err',err,'npoints',npoints);
        end
    end
    %% Graphics tools
    methods(Static)
        function [c,r] = BasicBlock(qrInfo)
            % Builds position markers for qr sample at 0,0
            % Construct sample frame coordinates for all nearest neighbors
            c = [0,0; Base.QR.spacing,0; 0,Base.QR.spacing];
            r = [1 1 1]*max(Base.QR.r,Base.QR.diffraction_limit);
            if Base.QR.NSecondary > 0
                % Sorry for poor naming. This is spacing between a single QR's corners
                dist = Base.QR.spacing/(Base.QR.NSecondary+1);
                for ax=1:2
                    p = [0,0];
                    for i = 1:Base.QR.NSecondary
                        p(ax) = i*dist;
                        c(end+1,:) = p;
                        r(end+1) = max(Base.QR.module_size/4,Base.QR.diffraction_limit);
                    end
                end
            end
            if Base.QR.centralMarks > 0
                % This spacing refers to distance between QR codes
                dist = Base.QR.spacing_between/(Base.QR.centralMarks+1);
                for x = 1:Base.QR.centralMarks
                    for y = 1:Base.QR.centralMarks
                        p = [x,y]*dist;
                        c(end+1,:) = p;
                        r(end+1) = max(Base.QR.module_size/4,Base.QR.diffraction_limit);
                    end
                end
            end
        end
        function handles = plotQRinfo(ax,qrInfo,bitSamples)
            % Plot the QR code based on the qrInfo. The value of the
            % bits scatter points correspond to the estimate of the bit
            % value. If no code is supplied, this scatter plot will be
            % omitted. If estimate is NaN, the scatter plot will be
            % binary instead of "gray scale". Red markers indicate an error
            % occured, green indicate success. The blue marker indicates
            % the top left of the code.
            % bitSamples is mainly for internal use. It is the module (bit) postiions
            % sampled to decide logical bit value
            assert(isvalidax(ax),'Axes must be valid.')
            if nargin < 3
                bitSamples = NaN(0,2);
            end
            n = length(qrInfo);
            handles = struct('markers',[],'bitSamples',[],'bits',cell(1,n));
            % Construct base QR and bits
            modSize = Base.QR.module_size;  % um
            numMods = sqrt(Base.QR.length);
            [Y,X] = meshgrid(linspace(modSize*numMods,modSize,numMods),...
                linspace(modSize,modSize*numMods,numMods)); % Starts from top left and rasters down
            bitsBase = [X(:), Y(:)]+Base.QR.d-modSize/2;
            markersBase = [0,0;Base.QR.spacing,0;0,Base.QR.spacing];
            for i = 1:n
                posBits = bitsBase;
                posMarkers = markersBase;
                if isempty(qrInfo(i).error) % Use correct QR
                    posBits = posBits + [qrInfo(i).col, qrInfo(i).row].*Base.QR.spacing_between;
                    posMarkers = posMarkers + [qrInfo(i).col, qrInfo(i).row].*Base.QR.spacing_between;
                end
                posBits = transformPointsForward(qrInfo(i).QR2imT,posBits);
                posMarkers = transformPointsForward(qrInfo(i).QR2imT,posMarkers);
                % Draw markers
                if isempty(qrInfo(i).error)
                    colors = zeros(3,3) + [0 1 0]; % green
                else
                    colors = zeros(3,3) + [1 0 0]; % red
                end
                colors(3,:) = [0 0 1]; % blue upper left (last point in list)
                handles(i).markers = scatter(ax,posMarkers(:,1),posMarkers(:,2),...
                    36,colors,'linewidth',2);
                % Draw bit sample positions
                handles(i).bitSamples = scatter(ax,...
                    posBits(1,1)+bitSamples(:,1),posBits(1,2)+bitSamples(:,2),10,[0,0,1]); % blue
                % Draw bits based on their estimate
                code = qrInfo(i).estimate;
                if isempty(code)
                    code = false(Base.QR.length,1);
                end
                colors = zeros(Base.QR.length,3) + code;
                handles(i).bits = scatter(ax,posBits(:,1),posBits(:,2),36,colors);
            end
        end
        
        function txt = tooltip_fn(~,event_obj)
            pos = get(event_obj,'Position');
            txt = {['X: ',num2str(pos(1))],...
                ['Y: ',num2str(pos(2))]};
            if isa(event_obj.Target,'matlab.graphics.chart.primitive.Scatter')
                I = get(event_obj, 'DataIndex');
                estimate = event_obj.Target.CData(I);
                txt{end+1} = ['Bit Estimate: ',num2str(estimate,'%0.4f')];
            end
        end
    end
    %% External methods
    methods(Static)
        c = findMarkers(im,conv,sensitivity,ax_debug); % Nx2 double
        [QR2pxT,cQR] = findQR(c,conv,markersBase,leg_thresh,angle_thresh,debug_ax) % 1xN affine2d
        [codeOut,p,estimate,posPxs] = digitize(im,unit2pxT,significance,markersPx)
        [row,col,version,legacy_error] = analyze(code)
        
        [offset,theta,scaling] = hone(im,qrInfo,ax);
    end
    
end

