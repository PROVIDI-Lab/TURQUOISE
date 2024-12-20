classdef UserObj < matlab.mixin.SetGet
    
    properties (Access = public)
       imageIdx                 %Image on which obj is drawn
       type                     %ROI = 1, measurement = 2, ...
       additive     = true      %Additive or subtractive ROI
       visible      = true      %Stores whether to display
       maskQ        = true      %Whether to be displayed as a mask. if false, display outline
       data                     %Seg, other
       outlineData              %only the outside parts of the segmentation
       points                   %ROIPoints, drawing points
       worldCoords              %ROIPoints, stored as world coordinates
       name                     %Name of the object
       prop                     %Other properties
       ID                       %Which userObj is this
       deleted      = false     %Stores if the userObj has been deleted
       renaming     = false     %Stores whether the object is to be renamed
       editing      = false     %stores whether the object is being edited
       viewDim                  %Stores the viewing dimension
       comment
       color
       profile
       volume
       meanVal
       stdVal
       prctile5
       prctile25
       prctile50
       prctile75
       prctile95
    end
    
    methods        
        function obj = makeProperties(obj, app)

            %get world coordinates
            tm  = app.transMatPerImage{obj.imageIdx};
            ijk = [obj.points, ones(length(obj.points),1)];
            xyz = tm * ijk';
            obj.worldCoords = xyz(1:3, :)';
            
            %Find object statistics
            if obj.type == 1 || obj.type == 3 || obj.type == 4
                axis4D      = app.d4PerImage(obj.imageIdx);
                L           = obj.data == 1;
                VS          = ...
                    prod(app.data{obj.imageIdx}.hdr.dime.pixdim(2:4));
                V           = ...
                    app.data{obj.imageIdx}.img(:,:,:, axis4D);
                
                obj.volume          = length(find(L))*VS/1000; %volume in mL

                obj.meanVal         = mean(V(L(:)));
                obj.stdVal          = std(V(L(:)));    
                obj.prctile5        = prctile(V(L(:)), 5);
                obj.prctile25       = prctile(V(L(:)), 25);
                obj.prctile50       = prctile(V(L(:)), 50);
                obj.prctile75       = prctile(V(L(:)), 75);
                obj.prctile95       = prctile(V(L(:)), 95);
            end
            
        end
        
        function createMask(obj, app, varargin)
            if obj.type ~= 1 && obj.type ~= 3 && obj.type ~= 4
                return
            end

            if nargin == 3
                pts = varargin{1};
            else
                pts = obj.points;
            end
            
            obj.data    = ROI.PointsToMask(app,...
                pts, app.imID, obj.type);            
        end

        function createOutline(obj)
            %creates a mask wheter only the outside 2 px are visible

            %find all slices
            [x,y,z] = ind2sub(size(obj.data), find(obj.data));

            if isempty(x)
                return
            end

            tmp = [x,y,z];
            slices = unique(tmp(:, obj.viewDim));

            obj.outlineData = false(size(obj.data));


            for i = 1:length(slices)
                slice = slices(i);

                if obj.viewDim == 1
                    maskSlc    = squeeze(obj.data(slice, :, :));
                elseif obj.viewDim == 2
                    maskSlc     = squeeze(obj.data(:, slice, :));
                else
                    maskSlc     = squeeze(obj.data(:, :, slice));
                end
                
                eroded = imerode(maskSlc, strel('disk', 3));
                outline = maskSlc - eroded;
                outline = outline > 0;

                if obj.viewDim == 1
                    obj.outlineData(slice, :, :)  = outline;
                elseif obj.viewDim == 2
                    obj.outlineData(:, slice, :)  = outline;
                else
                    obj.outlineData(:, :, slice)  = outline;
                end
            end

        end
        
        function setVisible(obj, visible, ~)
             obj.visible              = visible;
        end   

        function setMask(obj, maskQ, ~)
            obj.maskQ = maskQ;
        end
        
    end
end