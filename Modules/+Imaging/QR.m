classdef QR < Modules.Imaging
    %

    properties
        maxROI = [-1 1; -1 1];
        prefs = {'imager', 'flip', 'rotate', 'display', 'calibration', 'QR_ang'};
    end
    properties
        graphics = [];  % Contains handles for graphics objects for QR drawing.
    end
    properties(Constant)
        displaytypes = {'Raw', 'Flattened', 'Convolution X', 'Convolution Y', 'Convolution X^3 + Y^3', 'Thresholded'};
    end
    properties(GetObservable,SetObservable)
        QR_len = Prefs.Double(6.25, 'unit', 'um', 'readonly', true);
        QR_rad = Prefs.Double(.3,   'unit', 'um', 'readonly', true);
        QR_ang = Prefs.Double(0,    'unit', 'deg');
        
        image = Prefs.ModuleInstance('inherits', {'Modules.Imaging'}, 'set', 'set_image');
%         imager = Modules.Imaging.empty;
        
        flip =   Prefs.Boolean();
        rotate = Prefs.MultipleChoice(0, 'allow_empty', false, 'choices', {0, 90, 180, 270});
        
        display = Prefs.MultipleChoice('Raw', 'allow_empty', false, 'choices', Imaging.QR.displaytypes);
%         my_logical = Prefs.Boolean();
        
        resolution = [120 120];                 % Pixels
        ROI = [-1 1;-1 1];
        continuous = false;
        
        
        
%         image = Base.Meas([120 120], 'name', 'Image', 'unit', 'cts');
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
            img = obj.image.snapImage();
        end
        function snap(obj,im,continuous)
            if nargin < 3
                continuous = false;
            end
            
            img = obj.image.snapImage();
            
            if obj.flip
                img = flipud(img);
            end
            
            if obj.rotate ~= 0
                img = rot90(img, round(obj.rotate/90));
            end
            
            [cx, cy, CX, CY, flat, conv, convH, convV, bw] = ...
                Base.QRconv(img, (  obj.QR_ang + 90) * pi / 180,...
                                    obj.QR_rad / obj.calibration,...
                                    obj.QR_len / obj.calibration);
                     
            cx = (cx + obj.ROI(1,1)) * obj.calibration;
            cy = (cy + obj.ROI(2,1)) * obj.calibration;
            
            
                                
            switch obj.display
                case Imaging.QR.displaytypes{1}
                    im.CData = img;
                case Imaging.QR.displaytypes{2}
                    im.CData = flat;
                case Imaging.QR.displaytypes{3}
                    im.CData = convH;
                case Imaging.QR.displaytypes{4}
                    im.CData = convV;
                case Imaging.QR.displaytypes{5}
                    im.CData = conv;
                case Imaging.QR.displaytypes{6}
                    im.CData = bw;
                otherwise
                    im.CData = img;
            end
            
            a = im.Parent;
            
%             a.Children
            
            if isempty(obj.graphics) || ~isvalid(obj.graphics.figure) % ~continuous || length(a.Children) == 1
%                 delete(obj.graphics)
%                 t = text(a, NaN, NaN, '', 'g');
%                 hold(a, 'on')
                obj.graphics.figure = figure;
                obj.graphics.axes = axes;
                hold(obj.graphics.axes, 'on');
                obj.graphics.img = imagesc(obj.graphics.axes, ...
                                            [ obj.ROI(1,1),  obj.ROI(1,2)] * obj.calibration, ...
                                            [ obj.ROI(1,1),  obj.ROI(1,2)] * obj.calibration, ...
                                            NaN(obj.resolution));
                obj.graphics.p1 = plot(obj.graphics.axes, NaN, NaN, 'r-');
                obj.graphics.p2 = plot(obj.graphics.axes, NaN, NaN, 'g*');
            end
            
            obj.graphics.img.CData = im.CData;
            
            obj.graphics.p2.XData = cx;
            obj.graphics.p2.YData = cy;
            
            p1x = [];
            p1y = [];
%             tstr = {};
    
            lx0 = obj.QR_len * cos((obj.QR_ang + 90) * pi / 180);
            ly0 = obj.QR_len * sin((obj.QR_ang + 90) * pi / 180);
            
            for ii = 1:length(cx)
                p1x = [p1x cx(ii) + [0 lx0 ly0+lx0 ly0 0, NaN]];
                p1y = [p1y cy(ii) + [0 ly0 ly0-lx0 -lx0 0, NaN]];
%                 tstr{ii} = ['[' num2str(CX(ii)) ', ' num2str(CY(ii)) ']'];
            end
%             
            
            obj.graphics.p1.XData = p1x;
            obj.graphics.p1.YData = p1y;
            
%             p1x
%             p1y
%             
% %             p1x
% %             
% %             obj.graphics
%             
%             im
%             a
%             a.Children
%             
%             drawnow
            
%             t.
%             t.String = tstr;
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
