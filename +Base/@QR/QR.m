classdef QR
    % QR Detect and read "QR" codes
    % Two main methods: READER and ENHANCEDREADER. reader does not use the
    % extra alignment markers and does not fit the main markers precicely.
    % enhancedReader does all of that (takes much longer).  See method
    % definition for more details.
    %   [pos,qrInfo] = reader(im,varargin)
    %   [pos,tform,err,npoints,qrInfo] = enhancedReader([SAME AS READER])
    
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
        function [pos, err, tform] = estimatePos(readInfos)
            % ESTIMATEPOS Returns an estimated QR position for the (0,0)
            % coordinate in the image. It will take as many readInfo
            % structs as there are QR codes detected.
     %       pos = [[qrInfo.col]',[qrInfo.row]']*Base.QR.spacing_between; % QR coord
     %       pos = % pixels?
     %       pos = % sample coord
            pos = [NaN,NaN];
            err = [NaN,NaN];
            tform = affine2d.empty(0);
        end
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
            %       tform: the tform that incorporates all QRs found ("average" of qrInfo.QR2imT)
            %       err: the error as a result of the average in (x,y)
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
            %       QR2imT: Affine transform QR(x,y)[um] -> image(x,y)[um].*
            %       * If error is not empty, these will be from the root
            %       (0,0) QR code instead of the one encoded.
            
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
            QR2pxT = Base.QR.findQR(marker_cands,conv,markersBase,...
                                    p.leg_len_thresh,p.angle_thresh,...
                                    ax_debug(3:4)); % 1xN affine2d
            % Note, QR2pxT is not returned because it refers to the resized image (square pixels)

            % Go through and attempt to decode QR codes
            nQRs = length(QR2pxT);
            qrInfo = struct('row',[],'col',[],'version',[],'code',[],...
                            'QR2imT',[],'error',cell(1,nQRs));
            for i = 1:nQRs
                markersPx = transformPointsForward(QR2pxT(i), markersBase);
                markersIm = (markersPx - 1).*conv + [x(1), y(1)];
                qrInfo(i).code = false(0);
                qrInfo(i).estimate = false(0);
                bitSamples_px = NaN(0,2);
                try
                    [code,pVal,estimate,bitSamples_px] = Base.QR.digitize(im,QR2pxT(i),p.significance,markersPx);
                    qrInfo(i).code = code;
                    qrInfo(i).estimate = estimate;
                    qrInfo(i).significance = pVal;
                    
                    [row,col,ver] = Base.QR.analyze(code);
                    qrInfo(i).row = row;
                    qrInfo(i).col = col;
                    qrInfo(i).version = ver;
                    qrInfo(i).error = MException.empty();
                    % Calculate QR2imT both being in real coords (no more pixel references)
                    markersAct = markersBase + [col, row].*Base.QR.spacing_between;
                    qrInfo(i).QR2imT = fitgeotrans(markersAct, markersIm,'nonreflectivesimilarity');
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
            [pos, err, tform] = Base.QR.estimatePos(qrInfo);
            readInfo = struct('qrInfo',qrInfo,'tform',tform,'err',err,'npoints',0);
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
        
        function [row,col,version,legacy_error] = analyze(code)
            if ~ischar(code)
                try
                    code = num2str(code,'%i');
                catch
                    error('Failed to convert type ''%'' to char array.',class(code))
                end
            end
            assert(length(code)==Base.QR.length,'Code is the wrong size (must be vector)')
            if size(code,1) > 1 % Make sure a row vector (important for padVal)
                code = code';
            end
            % Make sure pad is correct, then remove
            padVal = num2str(ones(1,numel(Base.QR.pad))*Base.QR.padVal,'%i');
            legacy_error = false;
            if ~strcmp(code(Base.QR.pad),padVal)
                % There was a flaw in some of the generation code, so
                % attempt altering code to "fix" by swapping bit 5 and 6
                assert(strcmp(code([1 6]),padVal),'Padding bits are incorrect.')
                legacy_error = true;
                code([1 6]) = [];
            else
                code(Base.QR.pad) = [];
            end
            p = 1; % Pointer into code
            version = decode(Base.QR.vb,'version');
            row = decode(Base.QR.rb,'row');
            col = decode(Base.QR.cb,'column');
            checksum = decode(Base.QR.cs,'checksum');
            % Remove checksum, and test
            code(end-Base.QR.cs+1:end) = [];
            observed_checksum = mod(sum(code=='1'),2^Base.QR.cs);
            if observed_checksum ~= checksum
                if legacy_error
                    warning('Checksum failure was after a pad failure and attempt to address the legacy error.')
                end
                error('Checksum failed.')
            end
            if version > 5 && legacy_error
                warning('Had to correct for padding error that SHOULD NOT exist in versions > 5! Tell mpwalsh@mit.edu immediately.');
            end
            % Helper function to decode and error check
            function val = decode(n,name)
                val = bin2dec(code(p:p + n - 1));
                assert(~isempty(val),...
                    sprintf('No %s decoded, check Base.QR constants for consistency.',name));
                p = p + n;
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
        
        c = findMarkers(im,conv,sensitivity,ax_debug); % Nx2 double
        QR2pxT = findQR(c,conv,markersBase,leg_thresh,angle_thresh,debug_ax) % 1xN affine2d
        [codeOut,p,estimate,posPxs] = digitize(im,unit2pxT,significance,markersPx)
        
        [offset,theta,scaling] = hone(im,qrInfo,ax);
    end
    
end

