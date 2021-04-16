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
                    app.imagePerAxis(app.current_view);
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
            for i = 1:length(app.userObjects)
                obj = app.userObjects{i};
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
        
        
        function DeleteUO(app)
            %When the deletemenu in he UOBox conextmenu is called.
            idx     = app.UOBox.Value;
            if isempty(idx)
                return
            end
            
            app.userObjects(idx) = [];
            GUI.UpdateUOBox(app)
            Graphics.UpdateImage(app)
        end
        
        
        function RenameUO(app)
            %When the renamemenu in he UOBox conextmenu is called.
            idx     = app.UOBox.Value;
            newName     = Interaction.PromptName();
            newName     = Objects.CheckNameUnique(app, newName, ...
                app.userObjects{idx}.type);
            app.userObjects{idx}.name   = newName{1};
            GUI.UpdateUOBox(app)
            Graphics.UpdateUserObjects(app)
        end
        
        function CopyUOTo(app)
            %When the copytoMenu in the UOBox contextmenu is called.
            idx         = app.UOBox.Value;
            if isempty(idx)
                return
            end
            
            obj         = app.userObjects{idx};
            if obj.type == 2
                return %Don't copy measurements
            end
            currentIdx  = app.userObjects{idx}.imageIdx;
            targetIdx   = Interaction.PromptTarget(app);
            
            newMask     = Align.AlignMask(app.data{targetIdx},...
                            app.data{currentIdx},...
                            obj.data);                
            
            newMask( newMask >= 0.5) = 1;
            newMask( newMask < 0.5) = 0;
                        
            Objects.AddNewUserObj(app,...
                    "type", obj.type, ...
                    "data", newMask,...
                    "points", [], ... %TODO, copy points
                    "name", obj.name,...
                    "imageIdx", targetIdx)
                
            GUI.UpdateUOBox(app)
            Graphics.UpdateUserObjects(app)
        end
        
        
    end
end