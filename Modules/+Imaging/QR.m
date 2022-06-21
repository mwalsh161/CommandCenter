classdef QR < Modules.Imaging
    %

    properties
        maxROI = [-1 1; -1 1];
        prefs = {'image', 'flip', 'rotate', 'display', 'calibration', 'QR_ang'};
    end
    properties(Hidden)
        graphics = [];  % Contains handles for graphics objects for QR drawing.
    end
    properties(Constant)
        displaytypes = {'Raw', 'Flattened', 'Convolution X', 'Convolution Y', '(Convolution X)^3 + (Convolution Y)^3', 'Thresholded'};
    end
    properties(GetObservable,SetObservable)
        QR_len = Prefs.Double(6.25, 'unit', 'um', 'readonly', true, 'help_text', 'Length of QR arm. This is set to the standard value.');
        QR_rad = Prefs.Double(.3,   'unit', 'um', 'readonly', true, 'help_text', 'Radius of the three large QR dots. This is set to the standard value.');
        QR_ang = Prefs.Double(0,    'unit', 'deg', 'help_text', 'QR code angle in the image coordinates (CCW).');

        image = Prefs.ModuleInstance('inherits', {'Modules.Imaging'}, 'set', 'set_image'); %

        flip =   Prefs.Boolean('set', 'set_variable', 'help_text', 'Whether the image should be flipped across the x axis. This should be used along with rotate to put the image in a user-friendly frame.');
        rotate = Prefs.MultipleChoice(0, 'set', 'set_variable', 'allow_empty', true, 'choices', {0, 90, 180, 270}, 'help_text', 'Rotation (CCW) of the image after flipping. This should be used along with flip to put the image in a user-friendly frame.');

        display = Prefs.MultipleChoice('Raw', 'set', 'set_variable', 'allow_empty', false, 'choices', Imaging.QR.displaytypes);
%         my_logical = Prefs.Boolean();

        resolution = [120 120];                 % Pixels
        ROI = [-1 1;-1 1];
        continuous = false;

%         image = Base.Meas([120 120], 'name', 'Image', 'unit', 'cts');
    end
    properties(Access=private, Hidden)
        current_img;    % Cache for the previous image.
    end
    properties(SetAccess=private)
        options_fit = []
        X
        Y
        N
    end
    properties
        X_expected = NaN;
        Y_expected = NaN;
        v = [];
        V = [];
        v_all = [];
        V_all = [];
    end

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
        function focus(obj,ax,stageHandle) %#ok<INUSD>
        end
        function img = snapImage(obj) %this is super confusing
            obj.current_img = obj.image.snapImage();
            
            img = obj.analyze();
        end
        function snap(obj,im,continuous) %#ok<INUSD>
            if nargin < 3
                continuous = false; %#ok<NASGU>
            end

            im.CData = obj.snapImage();
        end
        function val = set_variable(obj, val, ~)
            obj.analyze();
        end
        function img = grabFrame(obj)
            if obj.image.core.isSequenceRunning()
                while obj.image.core.getRemainingImageCount() == 0
                    pause(.01);
                end
            
                dat = obj.image.core.popNextImage();
                width = obj.image.core.getImageWidth();
                height = obj.image.core.getImageHeight();
                obj.current_img = transpose(reshape(typecast(dat, obj.image.pixelType), [width, height]));
                img = obj.current_img;
                
                obj.analyze();
            end
        end
        function displayimg = analyze(obj)
            img = obj.current_img;
            
            if isempty(img)
                % Clear figure?
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
            
            % Perform the convolution, 
            [v, V, options_fit, stages] = Base.QRconv(img, options_guess);
            
            %save props
            obj.options_fit = options_fit;
            obj.X = options_fit.Vcen(1);
            obj.Y = options_fit.Vcen(2);
            obj.N = sum(~options_fit.outliers & ~isnan(V(1,:))); % N -> numQRs
            obj.v_all = v; %pixel space.
            obj.V_all = V; %QR space.
            obj.V = reshape(V(~isnan(V)),2,[]); %remove the NaNs.
            obj.v = reshape(v(~isnan(V)),2,[]); %remove the NaNs.
            
            if obj.N >= 3
                obj.X_expected = obj.X;
                obj.Y_expected = obj.Y;
            end
            
            %
            if obj.N > 2
                QR_ang2 = (options_fit.ang * 180 / pi);

                if abs(QR_ang2 - obj.QR_ang) < .5
                    obj.QR_ang = mean([QR_ang2, obj.QR_ang]);
                end

                %
                if abs(options_fit.calibration / obj.calibration - 1) < .02
                    obj.calibration = mean([options_fit.calibration, obj.calibration]);
                    obj.image.calibration = obj.calibration;
                end
            end

            % Change coordinates from pixels to microns for display.
            v = (v + obj.ROI(:,1)) * obj.calibration;

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

            if isempty(obj.graphics) || isempty(obj.graphics.figure) || ~isvalid(obj.graphics.figure) % ~continuous || length(a.Children) == 1
                obj.graphics.figure = figure('Name', 'QR Navigation', 'NumberTitle', 'off', 'Menubar', 'none', 'Toolbar', 'none');
                obj.graphics.figure.Position(2) = obj.graphics.figure.Position(2) - obj.graphics.figure.Position(3) + obj.graphics.figure.Position(4);
                obj.graphics.figure.Position(4) = obj.graphics.figure.Position(3);
                obj.graphics.axes = axes('Units', 'normalized', 'Position', [0 0 1 1], 'PickableParts', 'none', 'DataAspectRatio', [1 1 1]);
                
                hold(obj.graphics.axes, 'on');
                disableDefaultInteractivity(obj.graphics.axes)
                obj.graphics.img =          imagesc(obj.graphics.axes, ...
                                                [ obj.ROI(1,1),  obj.ROI(1,2)] * obj.calibration, ...
                                                [ obj.ROI(2,1),  obj.ROI(2,2)] * obj.calibration, ...
                                                NaN(obj.resolution));
                colormap('gray');
                                            
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
                
                obj.graphics
            end

            obj.graphics.img.CData = displayimg;

            p1x = []; p1y = [];
            p2x = []; p2y = [];
            p3x = []; p3y = [];

            lx0 = obj.QR_len * cosd(obj.QR_ang + 90);
            ly0 = obj.QR_len * sind(obj.QR_ang + 90);
            
            kk = 1;
            
%             sqx = [ ly0 0 lx0 NaN];
%             sqy = [ ly0 0 lx0 NaN];
            
            p = .15;
            sqx = [-p*(ly0+lx0) (1+p)*lx0-p*ly0 (1+p)*(ly0+lx0)  (1+p)*ly0-p*lx0 -p*(ly0+lx0) NaN];
            sqy = [-p*(ly0-lx0) (1+p)*ly0-p*lx0 (1+p)*(ly0-lx0) -(1+p)*lx0-p*ly0 -p*(ly0-lx0) NaN];

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
                    
                    str = ['[' num2str(V(1,ii)) ', ' num2str(V(2,ii)) ']'];
                    
                    if kk > length(obj.graphics.text)
                        obj.graphics.text(kk) = text(obj.graphics.axes, NaN, NaN, '', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
                    end
                    
                    set(obj.graphics.text(kk), 'String', str);
                    set(obj.graphics.text(kk), 'Position', [v(1,ii) + lx0/2 + ly0/2, v(2,ii) + ly0/2 - lx0/2]);
                    set(obj.graphics.text(kk), 'Color', 'g');
                    if options_fit.outliers(ii)
                        set(obj.graphics.text(kk), 'Color', 'y');
                    end
                    
                    kk = kk + 1;
                end
            end
            
            while kk <= length(obj.graphics.text)
                set(obj.graphics.text(kk), 'String', '');
                set(obj.graphics.text(kk), 'Position', [NaN, NaN]);
                set(obj.graphics.text(kk), 'Color', 'k');
                
                kk = kk + 1;
            end
            
            if any(isnan(options_fit.Vcen))
                obj.graphics.centertext.String = '';
                obj.graphics.center.MarkerEdgeColor = 'y';
            else
                obj.graphics.centertext.String = ['  [' num2str(options_fit.Vcen(1), '%.2f') ', ' num2str(options_fit.Vcen(2), '%.2f') ']'];
                obj.graphics.center.MarkerEdgeColor = 'g';
            end
            
            obj.graphics.p1.XData = p1x; obj.graphics.p1.YData = p1y;
            obj.graphics.p2.XData = p2x; obj.graphics.p2.YData = p2y;
            obj.graphics.p3.XData = p3x; obj.graphics.p3.YData = p3y;
            
            gdata = (affine(floor(options_fit.Vcen) + [[0, 1, 1, 0, 0]; [0, 0, 1, 1, 0]], options_fit.M,  options_fit.b)  - size(img)'/2 ) * options_fit.calibration;
            gdata = [gdata [NaN; NaN], (affine(floor(options_fit.Vcen) + [[0, 1, 0, 1, 0]; [0, 0, 1, 1, 0]], options_fit.M2, options_fit.b2) - size(img)'/2 ) * options_fit.calibration];
            
            obj.graphics.grid.XData = gdata(1,:);
            obj.graphics.grid.YData = gdata(2,:);
            
            obj.graphics.img.XData = [ obj.ROI(1,1),  obj.ROI(1,2)] * obj.calibration;
            obj.graphics.img.YData = [ obj.ROI(2,1),  obj.ROI(2,2)] * obj.calibration;
            
            try     % These lines sometimes breaks.
                xlim(obj.graphics.axes, obj.graphics.img.XData);
                ylim(obj.graphics.axes, obj.graphics.img.YData);
            catch
                
            end
            
%             figure(obj.graphics.figure);
        end
        
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

    end

end

function v_ = affine(v, M, b)
    % v and v_ are either column vectors (2x1) or arrays of column vectors (2xN) of the same size
    % M is a matrix (2x2)
    % b is a column vector (2x1)
    v_ = M * v + b;
end