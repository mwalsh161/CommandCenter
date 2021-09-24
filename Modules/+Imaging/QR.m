classdef QR < Modules.Imaging
    % Decodes QRs in images from an external imaging module.

    % Internal helper variables.
    properties(Hidden)
        current_img;    % Cache for the previous image.
        graphics = [];  % Contains handles for graphics objects for QR drawing.
    end
    properties(SetAccess=private)
        % Internal variables for the positions of each potential QR code.
        % v are the positions in camera-space (pixels), V are the positions in QR-space.
        % v_all and V_all include potential QRs that did not decode in a self-consistent manner.
        v_good = [];
        V_good = [];
        v_all = [];
        V_all = [];
    end
    properties
        % This system assumes only local movements, and ignores decoded QRs far from expected. Expected is updated when 3+ QRs self-consistently decode.
        X_expected = NaN;
        Y_expected = NaN;
    end
    
    properties(Constant, Hidden)
        displaytypes = {'Raw', 'Flattened', 'Convolution X', 'Convolution Y', '(Convolution X)^3 + (Convolution Y)^3', 'Thresholded'};
    end
    
    % Prefs which display in the UI pane. See help_text for context.
    properties(GetObservable,SetObservable)
        QR_len = Prefs.Double(6.25, 'units', 'um', 'readonly', true,    'help_text', 'Length of QR arm. This is set to the standard value.');
        QR_rad = Prefs.Double(.3,   'units', 'um', 'readonly', true,    'help_text', 'Radius of the three large QR dots. This is set to the standard value.');
        QR_ang = Prefs.Double(0,    'units', 'deg',                     'help_text', 'QR code angle in the image coordinates (CCW).');

        image = Prefs.ModuleInstance('inherits', {'Modules.Imaging'}, 'set', 'set_image', ...
                                                                        'help_text', 'The imaging module to do QR decoding upon.');

        flip =   Prefs.Boolean('set', 'set_variable', ...
                                                                        'help_text', 'Whether the image should be flipped across the x axis. This should be used along with rotate to put the image in a user-friendly frame.');
        rotate = Prefs.MultipleChoice(0, 'set', 'set_variable', 'allow_empty', true, 'choices', {0, 90, 180, 270}, ...
                                                                        'help_text', 'Rotation (CCW) of the image after flipping. This should be used along with flip to put the image in a user-friendly frame.');

        display = Prefs.MultipleChoice('Raw', 'set', 'set_variable', 'allow_empty', false, 'choices', Imaging.QR.displaytypes, ...
                                                                        'help_text', 'These displaymodes allow the user to see the various stages in the algorithm that allows robust and fast convolutional QR detection.');
                                                                    
        X = Prefs.Double(NaN,   'readonly', true,                       'help_text', 'Detected X position in QR-space of the center of the field of view.');
        Y = Prefs.Double(NaN,   'readonly', true,                       'help_text', 'Detected Y position in QR-space of the center of the field of view.');
        N = Prefs.Integer(NaN,  'readonly', true,                       'help_text', 'Number of self-consistent QR codes within a field of view.')
        M = Prefs.DoubleArray(NaN, 'readonly', true, 'help_text', 'matrix for affine transformation between QR and camera space')
        b = Prefs.DoubleArray(NaN, 'readonly', true, 'help_text', 'offset vector for affine transformation between QR and camera space')
    end
    
    % Variables required for imaging modules. This should be cleaned up in the future.
    properties
        maxROI = [-1 1; -1 1];
        prefs = {'image', 'flip', 'rotate', 'display', 'calibration', 'QR_ang', 'X', 'Y', 'N', 'M', 'b'};
    end
    properties(GetObservable,SetObservable)
        resolution = [120 120];
        ROI = [-1 1;-1 1];
        continuous = false;
    end

    % Constructor variables.
    methods(Access=private)
        function obj = QR()
            obj.loadPrefs;
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Imaging.QR();
            end
            obj = Object;
        end
    end
    
    % Set variables to handle UI events / etc.
    methods
        function image = set_image(obj, image, ~)
            obj.maxROI = image.maxROI;
            obj.ROI = image.ROI;
        end
        function set.ROI(obj,val)
            % Update ROI without going outside maxROI
            val(1,1) = max(obj.maxROI(1,1),val(1,1)); %#ok<*MCSUP>
            val(1,2) = min(obj.maxROI(1,2),val(1,2));
            val(2,1) = max(obj.maxROI(2,1),val(2,1));
            val(2,2) = min(obj.maxROI(2,2),val(2,2));
            
            % Now make sure no cross over
            val(1,2) = max(val(1,1),val(1,2));
            val(2,2) = max(val(2,1),val(2,2));
            obj.ROI = val;
        end
        function val = set_variable(obj, val, ~)
            obj.analyze();
        end
    end
    
    % Image acquisition and processing variables.
    methods
        function img = snapImage(obj)
            obj.current_img = obj.image.snapImage();
            
            img = obj.analyze();
        end
        % Required method of Modules.Imaging. The "snap button" in the UI calls this and displays the camera result on the imaging axis.
        function snap(obj, im)
            im.CData = obj.snapImage();
        end
        % Analysis method to detect QRs and display them in our graphics figure.
        function displayimg = analyze(obj)
            img = obj.current_img;
            
            % No image to analyze: break.
            if isempty(img)
                return
            end
            
            % Transform the image according to the user's desire.
            if obj.flip
                img = flipud(img);
            end
            if obj.rotate ~= 0
                img = rot90(img, round(obj.rotate/90));
            end

            % Provide a guess starting point for the convolutional algorithm.
            options_guess = struct('ang', (obj.QR_ang + 90) * pi / 180, 'calibration', obj.calibration, 'X_expected', obj.X_expected, 'Y_expected', obj.Y_expected);
            
            % Perform the convolution, which returns a list of the 
            [v, V, options_fit, stages] = Base.QRconv(img, options_guess);
            
            % Coordinates in QR-space of the center of the field of view.
            obj.X = options_fit.Vcen(1);
            obj.Y = options_fit.Vcen(2);
            obj.M = options_fit.M;
            obj.b = options_fit.b;
            
            % Number of successfully-decoded QRs.
            obj.N = sum(~options_fit.outliers & ~isnan(V(1,:)));
            
            % Store the detected QRs in memory for later user access.
            obj.v_all = v; % Camera-space (pixels).
            obj.V_all = V; % QR-space.
            
            % Remove the QRs which did not self-consistently decode for the good list.
            obj.v_good = reshape(v(~isnan(V)),2,[]);
            obj.V_good = reshape(V(~isnan(V)),2,[]);
            
            % If we have agreement, 
            if obj.N >= 3
                % Update the expected values for next time (as movement will generally be local, we can expect similar values).
                obj.X_expected = obj.X;
                obj.Y_expected = obj.Y;
                
                QR_ang2 = (options_fit.ang * 180 / pi);

                % Update the QR angle with our fit value.
                if abs(QR_ang2 - obj.QR_ang) < 1
                    obj.QR_ang = mean([QR_ang2, obj.QR_ang]);
                end

                % Update the pixels-to-microns calibration.
                if abs(options_fit.calibration / obj.calibration - 1) < .02
                    obj.calibration = mean([options_fit.calibration, obj.calibration]);
                    obj.image.calibration = obj.calibration;
                end
            end

            % Change coordinates from pixels to microns for display.
            v = (v + obj.ROI(:,1)) * obj.calibration;

            % Determine which stage of the convolutional algorithm we will display. This is useful for understanding and debugging.
            switch obj.display
                case Imaging.QR.displaytypes{1}
                    displayimg = img;
                case Imaging.QR.displaytypes{2}
                    displayimg = stages.flat;
                case Imaging.QR.displaytypes{3}
                    displayimg = stages.convH;
                case Imaging.QR.displaytypes{4}
                    displayimg = stages.convV;
                case Imaging.QR.displaytypes{5}
                    displayimg = stages.conv;
                case Imaging.QR.displaytypes{6}
                    displayimg = stages.bw;
                otherwise
                    displayimg = img;
            end

            % We use an external figure to display the QRs. If this figure has not been created, create it.
            if isempty(obj.graphics) || isempty(obj.graphics.figure) || ~isvalid(obj.graphics.figure)
                % Make the figure and axes.
                obj.graphics.figure = figure('Name', 'QR Navigation', 'NumberTitle', 'off', 'Menubar', 'none', 'Toolbar', 'none');
                obj.graphics.figure.Position(2) = obj.graphics.figure.Position(2) - obj.graphics.figure.Position(3) + obj.graphics.figure.Position(4);
                obj.graphics.figure.Position(4) = obj.graphics.figure.Position(3);
                obj.graphics.axes = axes('Units', 'normalized', 'Position', [0 0 1 1], 'PickableParts', 'none', 'DataAspectRatio', [1 1 1]);
                hold(obj.graphics.axes, 'on');
                disableDefaultInteractivity(obj.graphics.axes)
                
                % Make the image to display.
                obj.graphics.img =          imagesc(obj.graphics.axes, ...
                                                [ obj.ROI(1,1),  obj.ROI(1,2)] * obj.calibration, ...
                                                [ obj.ROI(2,1),  obj.ROI(2,2)] * obj.calibration, ...
                                                NaN(obj.resolution));
                colormap('gray');
                                          
                % Make other graphics objects.
                obj.graphics.text = [];
                
                obj.graphics.grid =         plot(obj.graphics.axes, NaN, NaN, 'c-', 'LineWidth', .5);
                obj.graphics.grid.Color(4) = 0.25;
                
                cx = (obj.ROI(1,1) + obj.ROI(1,2))/2;
                cy = (obj.ROI(2,1) + obj.ROI(2,2))/2;
                obj.graphics.center =       scatter(obj.graphics.axes, cx, cy, 'go');
                obj.graphics.centertext =   text(obj.graphics.axes, cx, cy, 'Center', 'color', 'g');
                                        
                obj.graphics.p3 =           plot(obj.graphics.axes, NaN, NaN, 'r-', 'LineWidth',.5);
                obj.graphics.p2 =           plot(obj.graphics.axes, NaN, NaN, 'y-', 'LineWidth',1);
                obj.graphics.p1 =           plot(obj.graphics.axes, NaN, NaN, 'g-', 'LineWidth',2);
                obj.graphics.p3.Color(4) = 0.25;
            end

            % Update the graphics objects with our image.
            obj.graphics.img.CData = displayimg;

            % Helper variables to construct the shape of the squares that outline where we have detected QRs. These are centered on the lower left QR
            % corner. The NaN at the end removes lines which would connect squares, leaving them disjointed as desired.
            p = .15;
            lx0 = obj.QR_len * cosd(obj.QR_ang + 90);
            ly0 = obj.QR_len * sind(obj.QR_ang + 90);
            sqx = [-p*(ly0+lx0) (1+p)*lx0-p*ly0 (1+p)*(ly0+lx0)  (1+p)*ly0-p*lx0 -p*(ly0+lx0) NaN];
            sqy = [-p*(ly0-lx0) (1+p)*ly0-p*lx0 (1+p)*(ly0-lx0) -(1+p)*lx0-p*ly0 -p*(ly0-lx0) NaN];

            % Make some empty variables which will hold the squares for displaying different types of detected QRs
            p1x = []; p1y = [];     % Self-consistent QRs.
            p2x = []; p2y = [];     % QRs which decode, but are not self-consistent (do not make sense).
            p3x = []; p3y = [];     % QRs which do not decode (violate checksum or otherwise).
            
            kk = 1;                 % Empty iterator.
            
            for ii = 1:size(v,2)
                squarex = v(1,ii) + sqx;
                squarey = v(2,ii) + sqy;
                
                if isnan(V(1,ii))
                    p3x = [p3x squarex]; %#ok<AGROW>
                    p3y = [p3y squarey]; %#ok<AGROW>
                else
                    if options_fit.outliers(ii)
                        p2x = [p2x squarex]; %#ok<AGROW>
                        p2y = [p2y squarey]; %#ok<AGROW>
                    else
                        p1x = [p1x squarex]; %#ok<AGROW>
                        p1y = [p1y squarey]; %#ok<AGROW>
                    end
                    
                    % Make more text objects if there are not enough.
                    if kk > length(obj.graphics.text)
                        obj.graphics.text(kk) = text(obj.graphics.axes, NaN, NaN, '', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
                    end
                    
                    % QRs which decoded successfully additionally get a text label. Set the text objects to the proper values.
                    set(obj.graphics.text(kk), 'String', ['[' num2str(V(1,ii)) ', ' num2str(V(2,ii)) ']']);
                    set(obj.graphics.text(kk), 'Position', [v(1,ii) + lx0/2 + ly0/2, v(2,ii) + ly0/2 - lx0/2]);
                    set(obj.graphics.text(kk), 'Color', 'g');
                    if options_fit.outliers(ii)
                        set(obj.graphics.text(kk), 'Color', 'y');
                    end
                    
                    kk = kk + 1;
                end
            end
            
            % Set all unneeded text objects to not display.
            while kk <= length(obj.graphics.text)
                set(obj.graphics.text(kk), 'String', '');
                set(obj.graphics.text(kk), 'Position', [NaN, NaN]);
                set(obj.graphics.text(kk), 'Color', 'k');
                
                kk = kk + 1;
            end
            
            % Color the pointer at the center of the FoV according to what was decoded.
            if any(isnan(options_fit.Vcen))
                obj.graphics.centertext.String = '';
                obj.graphics.center.MarkerEdgeColor = 'y';
            else
                obj.graphics.centertext.String = ['  [' num2str(options_fit.Vcen(1), '%.2f') ', ' num2str(options_fit.Vcen(2), '%.2f') ']'];
                obj.graphics.center.MarkerEdgeColor = 'g';
            end
            
            % Update all our graphics with the lines we have created.
            obj.graphics.p1.XData = p1x; obj.graphics.p1.YData = p1y;
            obj.graphics.p2.XData = p2x; obj.graphics.p2.YData = p2y;
            obj.graphics.p3.XData = p3x; obj.graphics.p3.YData = p3y;
            
            gdata = (affine(floor(options_fit.Vcen) + [[0, 1, 1, 0, 0]; [0, 0, 1, 1, 0]], options_fit.M,  options_fit.b)  - size(img)'/2 ) * options_fit.calibration;
            gdata = [gdata [NaN; NaN], (affine(floor(options_fit.Vcen) + [[0, 1, 0, 1, 0]; [0, 0, 1, 1, 0]], options_fit.M2, options_fit.b2) - size(img)'/2 ) * options_fit.calibration];
            
            obj.graphics.grid.XData = gdata(1,:);
            obj.graphics.grid.YData = gdata(2,:);
            
            obj.graphics.img.XData = [ obj.ROI(1,1),  obj.ROI(1,2)] * obj.calibration;
            obj.graphics.img.YData = [ obj.ROI(2,1),  obj.ROI(2,2)] * obj.calibration;
            
            try     % These lines sometime break, so we will try them carefully.
                xlim(obj.graphics.axes, obj.graphics.img.XData);
                ylim(obj.graphics.axes, obj.graphics.img.YData);
            catch
            end
        end
    end
    
    % Video methods required by Modules.Imaging -- currently just a while loop implementation.
    methods
        function startVideo(obj,im)
            obj.continuous = true;
            while obj.continuous
                obj.snap(im,true);
                drawnow;
            end
        end
        function stopVideo(obj)
            obj.continuous = false;
        end
        
        % Focus not implemented (see metastage)
        function focus(obj,ax,stageHandle) %#ok<INUSD>
        end
    end
end

% Helper function for affine transformations (scale + rotation + shear + translation)
function v_ = affine(v, M, b)
    % v and v_ are either column vectors (2x1) or arrays of column vectors (2xN) of the same size
    % M is a matrix (2x2)
    % b is a column vector (2x1)
    v_ = M * v + b;
end