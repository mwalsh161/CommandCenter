classdef PropertyManager < handle
    %SuperClass for handeling properties
    
    methods
        function obj = PropertyManager()
        end
    end
    methods(Static)
        
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Managers.PropertyManager();
            end
            obj = Object;
        end
    end
    
    methods (Access=private)
        
        function obj_property_location=get_correct_obj(obj,property_name)
            prop_index=find_property(obj,property_name);
            if isprop(obj,'prop_struct_cell_array')&& ~isempty(obj.prop_struct_cell_array)
                property=obj.prop_struct_cell_array{prop_index};
                if isfield(property,'origin')
                    origin=property.origin;
                    obj_property_location=obj.(origin);
                    obj.(origin).panel_handle=obj.panel_handle;
                else
                    obj_property_location=obj;
                end
            else
                obj_property_location=obj;
            end
        end
            
        function check_popup_values(obj,property,property_name,property_value)
            indice=ismember(property_value,property.options);
            assert(sum(indice)>0,[property_value,' is not a valid option for ',property_name,'!'])
        end
        
        function isvalid_property_name(obj,property_name)
            assert(ischar(property_name),'Property name must be a string!')
            assert(ismember(property_name,obj.prefs),'Not a valid property name!')
        end
        
        function indice=find_indice(obj,property,property_name,property_value)
            indice=strfind(property.options,property_value);
            truth_vector=cellfun('isempty',indice);
            indice_vector=1:length(indice);
            indice=indice_vector(~truth_vector);
            if isempty(indice)
                error([property_value,' is not an allowed property value for ',property_name])
            end
            
        end
        
        function [indice,property]=set_pop_up(obj,name,val)
            if ~ischar(val)
                val=obj.(name).options{val};
            end
            obj.check_popup_values(obj.(name),name,val);
            indice=obj.find_indice(obj.(name),name,val);
            obj.(name).default=indice;
        end
        
        function property=set_edit_values(obj,name,val)
            value=str2num(val);
            obj.(name).default=val;
        end
        
        function prop_index=find_property(obj,name)
            prop_index=[];
            pref_list=obj.prefs();
            truth_table=strfind(pref_list,name);
            for index=1:length(truth_table)
                if truth_table{index}==1
                    prop_index=index;
                end
            end
            assert(~isempty(prop_index),['Could not find property ',name])
        end
        
        function set_valid_property_value(obj,property_name,property_value)
            if strcmp(obj.(property_name).style,'edit')
                assert(ischar(property_value),'Exp property values must be entered as string!')
                obj.class_set_property(property_name,property_value)
            else
                obj.class_set_property(property_name,property_value)
            end
        end
        
        function evaluate_property_callback(obj,property_name,val)
            if isfield(obj.(property_name),'Callback')
                eval(obj.(property_name).Callback)
            end
        end

        function set_property_according_to_style(obj,style,name,val) 
            switch style
                case 'popup'
                    indice=obj.set_pop_up(name,val);
                case 'edit'
                    obj.set_edit_values(name,val);
                case 'text'
            end
        end
        
    end
    
    methods
        function prop_struct_cell_array=define_origin(obj,origin,prop_struct_cell_array)
            for index=1:length(prop_struct_cell_array)
               property=prop_struct_cell_array{index};
               property.origin=origin;
               prop_struct_cell_array{index}=property;
            end  
        end

        function pref_list=determine_pref_list(obj,prop_structure)
            pref_list=[];
            for index=1:length(prop_structure)
                pref_list=[pref_list,{prop_structure{index}.name}];
            end
        end
        
        function updateGUI_from_experiment(obj,property_name,val)
            if ~isempty(obj.panel_handle)&& isvalid(obj.panel_handle)
                obj.panel_handle.UserData.update(obj.panel_handle,property_name,val);%update GUI
            end
        end
        
        function [prop_struct_cell_array,prefs]=initialize_properties(obj)
            prefs_possible=[];
            prop_struct_cell_array=[];
            prefs=properties(obj);
            for index=1:length(prefs)
                pref_name=prefs{index};
                if isprop(obj,pref_name) && isstruct(obj.(pref_name)) && isfield(obj.(pref_name),'style')
                    try
                        prefs_possible{index}=pref_name;
                    end
                end
                
            end
            prefs_possible=prefs_possible(~cellfun('isempty',prefs_possible));
            obj.prefs=prefs_possible;
            obj.loadPrefs;
            for index=1:length(prefs)
                pref_name=prefs{index};
                if isprop(obj,pref_name) && isstruct(obj.(pref_name)) && isfield(obj.(pref_name),'style')
                    try
                        prop_struct_cell_array{index}=obj.(pref_name);
                    end
                end
                
            end
            prop_struct_cell_array=prop_struct_cell_array(~cellfun('isempty',prop_struct_cell_array));
            for index=1:length(prop_struct_cell_array)
                property=prop_struct_cell_array{index};
                obj.setProperty(property.name,property.default);
            end
        end
        
        function setProperty(obj,property_name,val)
            isvalid_property_name(obj,property_name);%determine if the property name is a valid property name
            obj_property_location=obj.get_correct_obj(property_name);
            set_valid_property_value(obj_property_location,property_name,val); %determine if val is a valid property value if so then set it
            GUI_value=getProperty(obj_property_location,property_name);
            updateGUI_from_experiment(obj,property_name,GUI_value)
            obj_property_location.evaluate_property_callback(property_name,val);
        end
        
        function val=getProperty(obj,property_name)
            obj_property_location=obj.get_correct_obj(property_name);
            if strcmp(obj_property_location.(property_name).style,'popup')
                val=obj_property_location.(property_name).options{obj_property_location.(property_name).default};
            else
                val=obj_property_location.(property_name).default;
                val=(val);
            end
        end
        
        function val=property_change(obj,hObj,eventData)
            property_name=hObj.Tag;
            value=eventData.new_value;
            if strcmp(eventData.previous_value,eventData.new_value)
                % Case of no change
                val=eventData.new_value;
            else
                try
                    obj.setProperty(property_name,value);
                    val=obj.getProperty(property_name);
                catch ME
                    
                    display(ME.message)
                    val=eventData.previous_value;
                    if ~isempty(obj.panel_handle)&& isvalid(obj.panel_handle)
                        obj.panel_handle.UserData.update(obj.panel_handle,property_name,eventData.previous_value);%do not update GUI if error in callback
                    end
                    
                end
                
            end
        end
        
        function class_set_property(obj,name,val)
            if isstruct(val)
                obj.(name).default=val.default;
            else
                obj.set_property_according_to_style(obj.(name).style,name,val)
            end
        end
        
        function h=set_properties_settings(obj,panelH,prop_struct_cell_array)
            function_handle=@obj.property_change;
            h=uicontrolgroup(prop_struct_cell_array,function_handle,'Parent',panelH);
        end
        
    end

end

