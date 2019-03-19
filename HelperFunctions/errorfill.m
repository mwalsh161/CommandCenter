classdef errorfill < handle
    %errorfill Plots in errorbar-style, but with filled in regions instead of
    %with bars
    %   Usage is like that of errorbar, with first three inputs specifying x,
    %   y, and error shading size in analog with errorbar. After that, properties
    %   of both the central data line (of type 'plot') and the shading object
    %   (of type 'fill') can be specified pairwise.
    %
    %   Unlike errorbar, if separately specifying negative/positive error,
    %   third argument should be 2xN instead of 1xN
    
    properties
        XData = [];
        YData = [];
        YNegativeDelta = [];
        YPositiveDelta = [];
    end
    properties(SetAccess=protected,Hidden)
        line = gobjects(1);
        fill = gobjects(1);
        group = gobjects(1);
    end
    
    methods
        function obj = errorfill(x,y,delta,varargin)
            props = varargin(1:2:end);
            vals = varargin(2:2:end);
            assert(length(props)==length(vals),'Property specifications must be pairwise');
            assert(length(unique(props))==length(props),'Duplicate property specifications');
            assert(size(delta,1)<=2, 'Delta must be either 1xN or 2xN');
            if size(delta,1) == 1
                delta = [delta;delta];
            end
            
            LIA = ismember(lower(props),'parent'); %find if a parent axes was specified
            if sum(LIA)==0
                ax = gca;
            else
                ax = vals{LIA};
                props(LIA) = [];
                vals(LIA) = [];
            end
            held = ishold(ax); %determine if the axes are being held
            if ~held
                cla(ax,'reset'); %to emulate the 'replace' behavior
            end
            if isempty(props) || ~ismember('edgealpha',lower(props))
                props{end+1} =  'EdgeAlpha';
                vals{end+1} = 0; %default transparent edges
            end
            if isempty(props) || ~ismember('facealpha',lower(props))
                props{end+1} =  'FaceAlpha';
                vals{end+1} = 0.35; %default transparency
            end
            obj.group = hggroup(ax,'Tag',mfilename,'UserData',obj);
            
            p = plot(obj.group,NaN,NaN);
            validplotprops = ismember(lower(props),lower(fieldnames(p.set())));
            propcell = [props(validplotprops);vals(validplotprops)];
            if ~isempty(propcell)
                [~] = set(p,propcell{:});
            end
            
            held = ishold(ax);
            hold(ax,'on');
            f = fill(obj.group,NaN,NaN,p.Color);
            validfillprops = ismember(lower(props),lower(fieldnames(f.set())));
            propcell = [props(validfillprops);vals(validfillprops)];
            [~] = set(f,propcell{:}); %there will always be at least FaceAlpha already
            if ~held
                hold(ax,'off');
            end
            uistack(p); %bring plot line ahead of fill
            obj.line = p;
            obj.fill = f;
            obj.XData = x;
            obj.YData = y;
            obj.YNegativeDelta = delta(1,:);
            obj.YPositiveDelta = delta(2,:);
            obj.update;
            % Delete this obj if group destroyed
            addlistener(obj.group,'ObjectBeingDestroyed',@(~,~)delete(obj));
        end
        function check_consistency(obj)
            err = [obj.YPositiveDelta; obj.YNegativeDelta];
            assert(~isempty(obj.XData),'No data to plot');
            assert(length(obj.YPositiveDelta)==length(obj.YNegativeDelta),'Deltas not same length')
            assert(length(obj.XData)==length(obj.YData),'x and y must be same length');
            assert(size(err,1) <= 2, 'Delta must be 1xN or 2xN');
            assert(size(err,2)==length(obj.XData),'Delta does not have same number of points as x/y');
        end
        function update(obj)
            obj.check_consistency
            
            err = [obj.YPositiveDelta; obj.YNegativeDelta];
            x = obj.XData;
            y = obj.YData;
            
            % sort x/y otherwise fill will be sad
            [x,I] = sort(x);
            y = y(I);
            err = err(:,I);
            
            % Filter out any NaNs
            I = ~any([isnan(x); isnan(y); isnan(err)]); % any(4xN) -> 1xN
            x = x(I); 
            y = y(I); 
            err = err(:,I);
            
            upperbounds = y+err(1,:);
            lowerbounds = y-err(2,:);
            bounds = horzcat([x;upperbounds],fliplr([x;lowerbounds]))';
            
            set(obj.line,'xdata',x,'ydata',y);
            set(obj.fill,'xdata',bounds(:,1),'ydata',bounds(:,2));
        end
        
        % All set methods use temp so that update can access new data and
        % temp serves as a backup on error to revert to
        function set.XData(obj,val)
            if size(val,1) > size(val,2)
                val = val';
            end
            obj.XData = val;
        end
        function set.YData(obj,val)
            if size(val,1) > size(val,2)
                val = val';
            end
            obj.YData = val;
        end
        function set.YNegativeDelta(obj,val)
            if size(val,1) > size(val,2)
                val = val';
            end
            obj.YNegativeDelta = val;
        end
        function set.YPositiveDelta(obj,val)
            if size(val,1) > size(val,2)
                val = val';
            end
            obj.YPositiveDelta = val;
        end

        function delete(obj)
            if isvalid(obj.group)
                delete(obj.group);
            end
        end
        
    end
    
end
