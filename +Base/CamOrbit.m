classdef CamOrbit < handle

    properties(Access=private)
        last_pos = [0 0];
        ax
    end
    
    methods
        function obj = CamOrbit(fig,ax)
            obj.ax = ax;
            set(fig,'WindowButtonDownFcn',@obj.ButtonDownFcn);
            set(fig,'WindowButtonUpFcn',@obj.ButtonUpFcn)
        end
        function ButtonDownFcn(obj, src,~ )
            %BUTTONUPFCN Assigns ButtonMotionFcn
            set(src,'WindowButtonMotionFcn',@obj.ButtonMotionFcn)
            pos = get(0,'PointerLocation');
            pos = pos(1,1:2);
            obj.last_pos = pos;
        end
        function ButtonMotionFcn(obj, ~,~ )
            pos = get(0,'PointerLocation');
            pos = pos(1,1:2);
            delta = pos-obj.last_pos;
            obj.last_pos = pos;
            dtheta = delta(1,1);
            dphi = delta(1,2);
            mult = 0.5;
            camorbit(obj.ax,dtheta*mult,dphi*mult)
        end
        function ButtonUpFcn( obj,src,~ )
            %BUTTONUPFCN Unassigns ButtonMotionFcn
            set(src,'WindowButtonMotionFcn','')
        end
        
        
    end
    
end

