classdef QR < Modules.Imaging
    %DEBUG Creates random pixels (no hardware needed)

    properties
        maxROI = [-1 1; -1 1];
        prefs = {'calibration', 'my_module', 'imager'};
    end
    properties(Constant)
        displaytypes = {'Raw', 'Flattened', 'Convolution X', 'Convolution Y', 'Convolution X^3 + Y^3', 'Thresholded'};
    end
    properties(GetObservable,SetObservable)
        qr_len = Prefs.Double(6.25, 'unit', 'um', 'readonly', true);
        qr_rad = Prefs.Double(.3,   'unit', 'um', 'readonly', true);
        qr_ang = Prefs.Double(90,   'unit', 'deg');
        
        my_module = Prefs.ModuleInstance('inherits', {'Imaging'});
        imager = Modules.Imaging.empty;
        
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
            img = obj.imager.snapImage();
        end
        function snap(obj,im,continuous)
            img = obj.imager.snapImage();
            
            [cx, cy, CX, CY, flat, conv, convH, convV, bw] = ...
                QRconv(img, obj.qr_ang, obj.qr_rad * obj.calibration, obj.qr_len * obj.calibration);
            
            switch obj.display
                case Imaging.QR.displaytypes{1}
                    im.cdata = img;
                case Imaging.QR.displaytypes{2}
                    im.cdata = flat;
                case Imaging.QR.displaytypes{3}
                    im.cdata = convH;
                case Imaging.QR.displaytypes{4}
                    im.cdata = convV;
                case Imaging.QR.displaytypes{5}
                    im.cdata = conv;
                case Imaging.QR.displaytypes{6}
                    im.cdata = bw;
                otherwise
                    im.cdata = img;
            end
            
            a = im.Parent;
            
            if length(a.Children) == 1
%                 t = text(a, NaN, NaN, '', 'g');
                p1 = plot(a, NaN, NaN, 'r');
                p2 = plot(a, NaN, NaN, 'g*');
            else
%                 t =     a.Children(3);
                p1 =    a.Children(2);
                p2 =    a.Children(1);
            end
            
            p2.xdata = cx;
            p2.ydata = cy;
            
            p1x = [];
            p1y = [];
%             tstr = {};
            
            for ii = 1:length(cx)
                p1x = [p1x cx(ii) + [0 lx0 ly0+lx0 ly0 0, NaN]];
                p1y = [p1y cy(ii) + [0 ly0 ly0-lx0 -lx0 0, NaN]];
%                 tstr{ii} = ['[' num2str(CX(ii)) ', ' num2str(CY(ii)) ']'];
            end
%             
            
            p2.xdata = p1x;
            p2.ydata = p1y;
            
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
