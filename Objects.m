classdef Objects < handle
    methods (Static)
        
        function AddNewUserObj(app, varargin)
            obj         = UserObj();
            
            for idx     = 1:2:nargin-1
                if ~isprop(obj, varargin{idx})
                    continue
                end
                
                str     = strcat(...
                    'obj.', varargin{idx}, ' = varargin{idx+1};');
                eval(str);
            end
            
            %Fill in unspecified details
            if isempty(obj.imageIdx)
                obj.imageIdx     = ...
                    app.image_per_view(app.current_view);
            end
            if isempty(obj.name)
                obj.name        = ...
                    ['uObj' num2str(length(app.userObjects))];
            else
                obj.name    = Objects.CheckNameUnique(...
                    app, obj.name, obj.type);
            end
            if isempty(obj.ID)
                obj.ID          = length(app.userObjects) + 1;
            end
            
            %Calculate properties
            obj.makeProperties(app);
            %Add to list            
            app.userObjects{end+1}  = obj;
            GUI.UpdateUOBox(app);
            Graphics.UpdateUserObjects(app);
        end
        
        function name = CheckNameUnique(app, name, type)
            %Compares 
            counter     = 0;
            for obj = app.userObjects
                obj = obj{1};
                if obj.imageIdx ~= app.imIdx || obj.type ~= type
                    continue
                end
                %Very ugly way of removing any numbers from string.
                objName     = obj.name;
                for i=0:9
                    objName = strrep(objName, num2str(i), '');
                end
                if strcmp(objName, name)
                    counter = counter + 1;
                end              
            end
            if counter > 0
                name    = strcat(name, num2str(counter));
            end
        end
        
    end
end