classdef Objects < handle
    methods (Static)
        
        function AddNewUserObj(app, varargin)
            
            obj         = UserObj();
            
            for idx     = 1:2:nargin-1
                if ~isprop(obj, varargin{idx})
                    continue
                end
                
                str     = strcat(...
                    'obj.', varargin{idx}, ' = varargin{idx+1}');
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
            end
            
            if isempty(obj.ID)
                obj.ID          = length(app.userObjects) + 1;
            end
            
            %Calculate properties
            obj.makeProperties(app);
            
            %Add to list            
            app.userObjects{end+1}  = obj;
            
        end
        
    end
end