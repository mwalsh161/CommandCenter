classdef Counter_exp < Modules.Experiment & Drivers.PropertyManager 
    
    properties
        lineIn=struct('name','lineIn','display_name','lineIn','default','10','style','edit');
        lineOut=struct('name','lineIn','display_name','lineOut','default','10','style','edit');

        prop_struct_cell_array
        panel_handle
        Counter
    end
    
    methods(Access=private)
        function obj = Counter_exp()
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.Debug.Counter_exp();
            end
            obj = Object;
            [obj.prop_struct_cell_array]=obj.initialize_properties();
        end  
    end

    methods

        function run(obj,statusH,managers,ax)
            error('Not Implemented')
            obj.abort_request=0;
            lineIn(obj.getProperty('lineIn'));
            lineOut=(obj.getProperty('lineOut'));
            obj.Counter=Driver.Counter.instance(lineIn,lineOut);
            obj.Counter.view
        end

        function abort(obj)
            
        end
        
        function data = GetData(obj,~,~)
           
        end
        
        function settings(obj,panelH)
            h=set_properties_settings(obj,panelH,obj.prop_struct_cell_array);
            obj.panel_handle=h;
        end
        
    end
    
end