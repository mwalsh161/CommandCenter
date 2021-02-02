classdef QR < Modules.Imaging
    %

    properties
        maxROI = [-1 1; -1 1];
        prefs = {'image', 'flip', 'rotate', 'display', 'calibration', 'QR_ang'};
    end
    properties
        graphics = [];  % Contains handles for graphics objects for QR drawing.
    end
    properties(Constant)
        displaytypes = {'Raw', 'Flattened', 'Convolution X', 'Convolution Y', 'Convolution X^3 + Y^3', 'Thresholded'};
    end
    properties(GetObservable,SetObservable)
        QR_len = Prefs.Double(6.25, 'unit', 'um', 'readonly', true, 'help_text', 'Length of QR arm. This is set to the standard value.');
        QR_rad = Prefs.Double(.3,   'unit', 'um', 'readonly', true, 'help_text', 'Radius of the three large QR dots. This is set to the standard value.');
        QR_ang = Prefs.Double(0,    'unit', 'deg', 'help_text', 'QR code angle in the image coordinates (CCW).');

        image = Prefs.ModuleInstance('inherits', {'Modules.Imaging'}, 'set', 'set_image');

        flip =   Prefs.Boolean('help_text', 'Whether the image should be flipped across the x axis. This should be used along with rotate to put the image in a user-friendly frame.');
        rotate = Prefs.MultipleChoice(0, 'allow_empty', true, 'choices', {0, 90, 180, 270}, 'help_text', 'Rotation (CCW) of the image after flipping. This should be used along with flip to put the image in a user-friendly frame.');

        display = Prefs.MultipleChoice('Raw', 'allow_empty', false, 'choices', Imaging.QR.displaytypes);
%         my_logical = Prefs.Boolean();

        resolution = [120 120];                 % Pixels
        ROI = [-1 1;-1 1];
        continuous = false;

%         image = Base.Meas([120 120], 'name', 'Image', 'unit', 'cts');
    end
    
    properties(Access=private, Hidden)
        current_img;    % Storage for the image that was previously taken.
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
        function focus(obj,ax,stageHandle)
        end
        function img = snapImage(obj)
            obj.current_img = obj.image.snapImage();
            
            img = obj.analyze();
        end
        function snap(obj,im,continuous)
            if nargin < 3
                continuous = false;
            end

            obj.snapImage();
        end
        function val = set_variable(obj, val, ~)
            obj.analyze();
        end
        function displayimg = analyze(obj)
            img = obj.current_img;
            
            if obj.flip
                img = flipud(img);
            end

            if obj.rotate ~= 0
                img = rot90(img, round(obj.rotate/90));
            end

            options_guess = struct('ang', (obj.QR_ang + 90) * pi / 180, 'calibration', obj.calibration);
            
            [v, V, options_fit, stages] = Base.QRconv(img, options_guess);

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

%             a = im.Parent;

%             a.Children

            if isempty(obj.graphics) || ~isvalid(obj.graphics.figure) % ~continuous || length(a.Children) == 1
%                 delete(obj.graphics)
%                 t = text(a, NaN, NaN, '', 'g');
%                 hold(a, 'on')
                obj.graphics.figure = figure;
                obj.graphics.axes = axes;
                
                hold(obj.graphics.axes, 'on');
                obj.graphics.img =          imagesc(obj.graphics.axes, ...
                                                [ obj.ROI(1,1),  obj.ROI(1,2)] * obj.calibration, ...
                                                [ obj.ROI(2,1),  obj.ROI(2,2)] * obj.calibration, ...
                                                NaN(obj.resolution));
                                        
                obj.graphics.p1 =           plot(obj.graphics.axes, NaN, NaN, 'g-*', 'LineWidth',2);
                obj.graphics.p2 =           plot(obj.graphics.axes, NaN, NaN, 'r-*', 'LineWidth',2);
                obj.graphics.p3 =           plot(obj.graphics.axes, NaN, NaN, 'r-*', 'LineWidth',2);
                obj.graphics.p2.MarkerFaceColor(4) = 0.5;
                obj.graphics.p2.Color(4) = 0.5;
                obj.graphics.p3.MarkerFaceColor(4) = 0.25;
                obj.graphics.p3.Color(4) = 0.25;
                
                obj.graphics.text = [];
                
                obj.graphics.grid =         plot(obj.graphics.axes, NaN, NaN, 'c-', 'LineWidth', .5);
                obj.graphics.grid.Color(4) = 0.25;
                
                cx = (obj.ROI(1,1) + obj.ROI(1,2))/2;
                cy = (obj.ROI(2,1) + obj.ROI(2,2))/2;
                obj.graphics.center =       scatter(obj.graphics.axes, cx, cy, 'go');
                obj.graphics.centertext =   text(obj.graphics.axes, cx, cy, 'Center', 'color', 'g');
            end

            obj.graphics.img.CData = displayimg;

%             obj.graphics.p2.XData = v(1,:);
%             obj.graphics.p2.YData = v(2,:);

            p1x = []; p1y = [];
            p2x = []; p2y = [];
            p3x = []; p3y = [];

            lx0 = obj.QR_len * cosd(obj.QR_ang + 90);
            ly0 = obj.QR_len * sind(obj.QR_ang + 90);
            
            kk = 1;

            for ii = 1:size(v,2)
%                 squarex = v(1,ii) + [0 lx0 ly0+lx0 ly0 0 NaN];
%                 squarey = v(2,ii) + [0 ly0 ly0-lx0 -lx0 0 NaN];
                squarex = v(1,ii) + [ ly0 0 lx0 NaN];
                squarey = v(2,ii) + [-lx0 0 ly0 NaN];
                if isnan(V(1,ii))
                    p3x = [p3x squarex];
                    p3y = [p3y squarey];
                elseif false
                    p2x = [p2x squarex];
                    p2y = [p2y squarey];
                else
                    p1x = [p1x squarex];
                    p1y = [p1y squarey];
                    
                    str = ['[' num2str(V(1,ii)) ', ' num2str(V(2,ii)) ']'];
                    
                    if kk > length(obj.graphics.text)
                        obj.graphics.text(kk) = text(obj.graphics.axes, NaN, NaN, '', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
                    end
                    
                    obj.graphics.text(kk)
                    
%                     obj.graphics.text(kk).String = str;
%                     obj.graphics.text(kk).XData = v(1,ii) + lx0/2;
%                     obj.graphics.text(kk).YData = v(2,ii) + ly0/2;
%                     obj.graphics.text(kk).Color = 'g';
                    
                    set(obj.graphics.text(kk), 'String', str);
                    set(obj.graphics.text(kk), 'Position', [v(1,ii) + lx0/2 + ly0/2, v(2,ii) + ly0/2 - lx0/2]);
                    set(obj.graphics.text(kk), 'Color', 'g');
                    
                    kk = kk + 1;
                end
            end
            
            while kk <= length(obj.graphics.text)
%                 obj.graphics.text(kk).String = '';
%                 obj.graphics.text(kk).XData = NaN;
%                 obj.graphics.text(kk).YData = NaN;
%                 obj.graphics.text(kk).Color = 'k';
                    
                set(obj.graphics.text(kk), 'String', '');
                set(obj.graphics.text(kk), 'Position', [NaN, NaN]);
                set(obj.graphics.text(kk), 'Color', 'k');
                
                kk = kk + 1;
            end
            
            obj.graphics.img.XData = [ obj.ROI(1,1),  obj.ROI(1,2)] * obj.calibration;
            obj.graphics.img.YData = [ obj.ROI(2,1),  obj.ROI(2,2)] * obj.calibration;
            
%             vcenter = 
            obj.graphics.centertext.String = ['  [' num2str(options_fit.Vcen(1), '%.2f') ', ' num2str(options_fit.Vcen(2), '%.2f') ']'];
            
            obj.graphics.p1.XData = p1x;
            obj.graphics.p1.YData = p1y;
            
            obj.graphics.p2.XData = p2x;
            obj.graphics.p2.YData = p2y;
            
            obj.graphics.p3.XData = p3x;
            obj.graphics.p3.YData = p3y;
            
            obj.graphics.p3.XData = p3x;
            obj.graphics.p3.YData = p3y;
            
            floor(options_fit.Vcen)
            
            gdata = (affine(floor(options_fit.Vcen) + [[0, 1, 1, 0, 0]; [0, 0, 1, 1, 0]], options_fit.M,  options_fit.b)  - size(img)'/2 ) * options_fit.calibration;
            gdata = [gdata [NaN; NaN], (affine(floor(options_fit.Vcen) + [[0, 1, 1, 0, 0]; [0, 0, 1, 1, 0]], options_fit.M2, options_fit.b2) - size(img)'/2 ) * options_fit.calibration];
            
            obj.graphics.grid.XData = gdata(1,:);
            obj.graphics.grid.YData = gdata(2,:);
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