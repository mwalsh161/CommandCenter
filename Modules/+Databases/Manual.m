classdef Manual < Modules.Database
    %MANUAL Saves the data structure and png.
    
    properties(SetAccess=private)
        autosave = false;
    end
    properties
        ImPath = '.';
        ExpPath = '.';
        prefs = {'ImPath','ExpPath'};
    end
    
    methods(Access=private)
        function obj = Manual()
            obj.loadPrefs;
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Databases.Manual();
            end
            obj = Object;
        end
    end
    methods
        function SaveIm(obj,image,ax,module,notes)
            [fname,path] = uiputfile('*.mat','Save Image As',fullfile(obj.ImPath,['Image' datestr(now,'yyyy_mm_dd_HH_MM_ss') '.mat']));
            if fname
                obj.ImPath = path;
                fname = fullfile(path,fname);
                image.notes = notes;  % Add in notes string
                save(fname,'image')
                obj.SavePNG(image,fname,ax)
            end
        end
        function SavePNG(obj,im,fname,ax)
            [a,b,~] = fileparts(fname);
            fname = [fullfile(a,b) '.png'];
            map = colormap(ax);
            clim = get(ax,'clim');
            newIm = round((double(im.image)-clim(1))*(size(map,1)-1)/(diff(clim)))+1;
            imwrite(newIm,map,fname,'png',...
                'CLower',sprintf('%0.2f',clim(1)),...
                'CUpper',sprintf('%0.2f',clim(2)),...
                'ROI',sprintf('%0.2f,%0.2f;%0.2f,%0.2f',im.ROI(1,1),im.ROI(1,2),im.ROI(2,1),im.ROI(2,2)),...
                'Software',mfilename('class'),...
                'Source',im.ModuleInfo.module);
        end
        function SaveExp(obj,data,~,module,notes)
            exp = strrep(class(module),'.','_');
            [fname,path] = uiputfile('*.mat','Save Experiment Data As',fullfile(obj.ExpPath,[exp datestr(now,'yyyy_mm_dd_HH_MM_ss') '.mat']));
            if fname
                obj.ExpPath = path;
                data.notes = notes;  % Add in notes string
                save(fullfile(path,fname),'data','-v7.3')  % v7.3 flag compresses and allows huge files
            end
        end
        
        function settings(obj,panelH)
            
        end
    end
    
end

