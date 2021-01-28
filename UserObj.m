classdef UserObj < matlab.mixin.SetGet
    
    properties (Access = public)
       imageIdx,                %Image on which obj is drawn
       type,                    %ROI = 1, measurement = 2, ...
       graphics,                %Graphics of the object
       changed      = true,     %Stores whether to redraw
       visible      = true,     %Stores whether to display
       data,                    %Seg, other
       points,                  %ROIPoints, drawing points
       name,                    %Name of the object
       prop,                    %Other properties
       ID,                      %Which userObj is this
       
    end
    
    methods        
        function obj = makeProperties(obj, app)
            
            if obj.type == 1
                L           = obj.data == 1;
                VS          = ...
                    min(app.data{app.imIdx}.hdr.dime.pixdim(2:4));
                V           = ...
                    app.data{app.imIdx}.img(:,:,:,app.current_4d_idx);
                
                obj.prop            = struct();
                obj.prop.volume     = length(find(L))*VS^3;
                obj.prop.mean       = mean(V(L(:)));
                obj.prop.max        = max(V(L(:)));    
                obj.prop.min        = min(V(L(:)));
                obj.prop.std        = std(V(L(:)));    
                obj.prop.perc25     = prctile(V(L(:)), 25, 'all');
                obj.prop.perc50     = prctile(V(L(:)), 50, 'all');
                obj.prop.perc75     = prctile(V(L(:)), 75, 'all');
                    
            elseif obj.type == 2
                
                P1    = obj.points(1,:);
                P2    = obj.points(2,:);
                direction = P2-P1;
                CL    = norm(direction,2);
                obj.prop.length =...
                    CL*min(app.data{app.imIdx}.hdr.dime.pixdim(2:4));
                
            end
            
        end
        
        
    end
    
end