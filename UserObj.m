classdef UserObj < matlab.mixin.SetGet
    
    properties (Access = public)
       imageIdx,                %Image on which obj is drawn
       type,                    %ROI = 1, measurement = 2, ...
       graphics,                %Graphics of the object
       changed      = true,     %Stores whether to redraw
       visible      = true,     %Stores whether to display
       boxVisible   = true,     %Stores whether to display infobox
       data,                    %Seg, other
       points,                  %ROIPoints, drawing points
       name,                    %Name of the object
       prop,                    %Other properties
       ID,                      %Which userObj is this
       
    end
    
    methods        
        function obj = makeProperties(obj, app)
            
            if obj.type == 1 || obj.type == 3
                axis4D      = app.d4PerImage(obj.imageIdx);
                L           = obj.data == 1;
                VS          = ...
                    min(app.data{obj.imageIdx}.hdr.dime.pixdim(2:4));
                V           = ...
                    app.data{obj.imageIdx}.img(:,:,:, axis4D);
                
                obj.prop            = struct();
                obj.prop.name       = obj.name;
                obj.prop.volume     = length(find(L))*VS^3;
                obj.prop.mean       = mean(V(L(:)));
                obj.prop.max        = max(V(L(:)));    
                obj.prop.min        = min(V(L(:)));
                obj.prop.std        = std(V(L(:)));    
            elseif obj.type == 2
                
                P1                  = obj.points(1,:);
                P2                  = obj.points(2,:);
                direction = P2-P1;
                CL                  = norm(direction,2);
                obj.prop            = struct();
                obj.prop.name       = obj.name;
                obj.prop.points     = obj.points;
                obj.prop.length     =...
                    CL*min(app.data{obj.imageIdx}.hdr.dime.pixdim(2:4));
                
            end
            
        end
        
        function setVisible(obj, visible)
            if isempty(obj.graphics)
                return
            end
            
            for i = 1:length(obj.graphics)
               obj.graphics{i}.Visible  = visible; 
               obj.visible              = visible;
            end
            
        end
        
        function setBoxVisible(obj, boxVisible)
            if isempty(obj.graphics)
                return
            end
            
            for i = 1:length(obj.graphics)
                %if text..
                if isa(obj.graphics{i}, 'matlab.graphics.primitive.Text')
                    if ~isvalid(obj.graphics{i})
                        continue
                    end
                    obj.graphics{i}.Visible  = boxVisible; 
                    obj.boxVisible           = boxVisible;
                end
            end
            
        end
        
        
        
    end
    
end