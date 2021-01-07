classdef ROI < handle
    %This static class deals with all functions that deal with a 
    %(user-made) segmentation. The storage and addition of points is 
    %managed, as well as the conversion from polygon points to 
    %segmentation.
    
    methods (Static)
        
        function AddPointToPolygon(app, hitx, hity)
            % This handles the manual drawing of ROIs. Called when the
            % mouse is pressed somewhere in the image. It adds the point to
            % app.drawing. 
            
            %If app.drawing doesn't exist yet, initialise it.
            if(~isfield(app.drawing,'points')   ||                  ...
                    ~isfield(app.data,'img')    ||                  ...
                    isempty(app.data.img))
                app.drawing.points = [];
            end

            %add new point
            if(app.view_axis == 3)
                app.drawing.points = [app.drawing.points;           ...
                                        hitx hity app.current_slice];
            elseif(app.view_axis == 2)
                app.drawing.points = [app.drawing.points;           ...
                                        hitx app.current_slice hity];
            elseif(app.view_axis == 1)
                app.drawing.points = [app.drawing.points;           ...
                                        app.current_slice hitx hity];
            end
        end
        
        function ValidateDrawingPoints(app)
        % When at least 3 points are specified in app.drawing.points, a
        % segmentation is constructed and added to the app.
        %
            if(size(app.drawing.points,1) <= 3)
                return
            end
            
            %Prompt user for name
            name    = Interaction.PromptName();
            if ~isempty(name)
                app.seg_names{end+1} = name{1};
            else
                return
            end
        
            app.drawing.active = false;
            app.DrawPolygonButton.BackgroundColor = [.96 .96 .96];
            app.drawing.points = [app.drawing.points;           ...
                                    app.drawing.points(1,:)];
        
            GUI.DisableControlsStatus(app);
            drawnow;
            %Create segmentation
                
            Backups.CreateBackup(app);
            %Construct the segmentation from the drawing.points.
%             ROI.CreateSegmentation(app)
            ROI.StoreROIPoints(app)

            %Create Label
%             ROI.UpdateSegmentationProperties(app);
            ROI.UpdateROIBox(app);
                
            Graphics.DeleteAllDrawingPoints(app);
            app.drawing.points = [];
%             app.segmentation_list{                                    ...
%                 app.current_image_idx} = app.segmentation;
            GUI.RevertControlsStatus(app);
        end
        
        function ValidateModifiedROIPoints(app)
            %Called after an ROI point is moved and the mouse is released.
            %Does mostly the same as ValidateDrawingPoints, just with the
            %most recent roiPoints and not drawing.points.
            
            GUI.DisableControlsStatus(app);
            drawnow;
            %Create segmentation
                
            Backups.CreateBackup(app);
            %Construct the segmentation from the drawing.points.
            ROI.ModifySegmentation(app)

            %Create Label
            ROI.UpdateSegmentationProperties(app);
            GUI.RevertControlsStatus(app);
        end
            
        
        function StoreROIPoints(app)
            %Stores the points that were used in drawing the segmentation
            %in app.roiPoints. Furthermore add to ROIPointIndex
            app.roiPoints = [app.roiPoints; app.drawing.points];
            
            %Remove the last point (which is in there twice);
            app.roiPoints(end,:)  = [];
            newIndex    = ones(length(app.drawing.points)-1,1);
            if ~isempty(app.roiPointIndex)
                newIndex    = newIndex * max(app.roiPointIndex(:));
            end
            app.roiPointIndex = [app.roiPointIndex; newIndex];
            
        end
        
        function StartDragging(app, hit)
            x = hit.Source.Parent.Parent.CurrentPoint(1);
            y = hit.Source.Parent.Parent.CurrentPoint(2);
            hitx = round(hit.IntersectionPoint(1));
            hity = round(hit.IntersectionPoint(2));
            app.dragPoint   = [hitx, x, hity, y];
            ROI.FindPoint(app);
            
            %Only continue if a point has been found
            if app.currentDragPoint == -1
                return
            end

            set(hit.Source.Parent.Parent,                               ...
                'WindowButtonMotionFcn',                                ...
                @app.MouseDraggedInImage);

            set(hit.Source.Parent.Parent,                               ...
                'WindowButtonUpFcn',                                    ...
                @app.MouseReleasedInImage);
                
        end
        
        function FindPoint(app)
            %Finds the point closest to where the user clicked in the
            %image if the point is within 5 voxels and in the same plane as
            %the view.
            %Writes the point index to the app.currentDragPoint object.
            
            if isempty(app.dragPoint)
                return
            end
            x   = app.dragPoint(1);
            y   = app.dragPoint(3);
            
            %Find all ROI points in the current slice in the current
            %viewAxis
            points  = app.roiPoints;
            selection     = points(:,app.view_axis) == app.current_slice;
            points  = points(selection,:);
            index   = 1:length(app.roiPoints);
            index   = index(selection);
            
            %Find the point closest to x,y
            distances   = zeros(1,length(points));
            for i = 1:length(points)
               xp               = points(i,1);
               yp               = points(i,2);
               d                = sqrt( (x-xp)^2 + (y-yp)^2);
               distances(i)     = d;
            end
            
            [M, I]  = min(distances);
            if M <= 5 %less than 5 voxels away
               app.currentDragPoint     = index(I); 
            end
            
        end
            
        
        function MoveROIPoint(app, newPos)
           %Modifies an ROI point to be in a new position. Called when the 
           %user drags one of the points. 
           
           x    = newPos(1);
           y    = newPos(2);
           z    = app.current_slice;
           if app.view_axis == 1
               pos  = [z,x,y];
           elseif app.view_axis == 2
               pos  = [x,z,y];
           else
               pos  = [x,y,z];               
           end
           app.roiPoints(app.currentDragPoint,:)  = pos;    
%            app.UpdateUserObj();
           if app.current_view  == 1
               Graphics.DrawPointsInAxis(app, app.UIAxes1);
           else
               Graphics.DrawPointsInAxis(app, app.UIAxes2);
           end
        end
        
        function PointsToSegmentation(app)
        %Converts the Roi points to segmentations.
           
            %Create a blanc segmentation if none exists.
            if(~isfield(app.segmentation,'hdr') ||                      ...
               ~isfield(app.segmentation,'img'))
                %                 app.segmentation.untouch = 1;
                app.segmentation.hdr = app.data.hdr;
                app.segmentation.img =                                  ...
                    zeros(size(app.data.img(:,:,:,1)));
            end
            
            maxLabel    = max(app.segmentation.img(:));
            maxIndex    = max(app.roiPointIndex(:));
            
            %Don't do anything if the amount of segmentations is correct.
            if maxLabel >= maxIndex
                return
            end
            
            
            %Create the segmentation for each index
            for index = maxLabel+1:maxIndex
               
                points = app.roiPoints(app.roiPointIndex == index, :);
                points = [points; points(1,:)];
                ROI.CreateSegmentation(app, points, index);
                
            end
            
            %Update the properties
            ROI.UpdateSegmentationProperties(app);
            
        end
        
        function CreateSegmentation(app, points, index)
        %Creates a segmentation from a collection of points.
        %Input: points, the points from which to construct a segmentation.
        %       index,  the segmentation index belonging to the points.
        
            %Add all pixels in between the vertices to the segmentation
            for x=2:size(points,1)
                app.segmentation.img(                                   ...
                    points(x-1,1),...
                    points(x-1,2),...
                    points(x-1,3))  = index;
                app.segmentation.img(                                   ...
                    points(x,1),...
                    points(x,2),...
                    points(x,3))    = index;
                
                %Construct vector between point x and x-1
                d = points(x,:)-points(x-1,:);
                d = d/norm(d,2);
                if(any(isnan(d)))
                    continue
                end

                %Add all points between the most recently drawn points
                catcher = 1;
                while (catcher < 500)
                    p = round(points(x-1,:)+d*catcher);
                    app.segmentation.img(p(1),p(2),p(3)) = index;
                    if(all(p-points(x,:) == 0))
                        break
                    end
                    catcher = catcher + 1;
                end
                if(catcher == 500)
                    disp('Catcher!');
                end
                
            end
            %finalise segmentation, fill all holes
            for iz=app.current_slice:app.current_slice
                %1:size(app.segmentation.img,3)
                if(app.view_axis == 3)
                    app.segmentation.img(:,:,iz) =                  ...
                        imfill(app.segmentation.img(:,:,iz),        ...
                                'holes');
                elseif(app.view_axis == 2)
                    app.segmentation.img(:,iz,:) =                  ...
                        imfill(                                     ...
                            squeeze(app.segmentation.img(:,iz,:)),  ...
                            'holes');
                elseif(app.view_axis == 1)
                    app.segmentation.img(iz,:,:) =                  ...
                        imfill(                                     ...
                            squeeze(app.segmentation.img(iz,:,:)),  ...
                            'holes');
                end
            end            
        end        
        
        function ModifySegmentation(app)
            %Creates a modified segmentation from the app.roiPoints. Mostly
            %the same as CreateSegmentation, just using app.roiPoints
            %instead of app.drawing.points.
            
            if app.currentDragPoint == -1 || isempty(app.segmentation)
                return
            end
            
            %Find all the points that belong to the modified segmentation.
            segIndex    = app.roiPointIndex(app.currentDragPoint);
            pointIndex  = app.roiPointIndex == segIndex;
            points      = app.roiPoints(pointIndex,:);
            
            %Add the first point to the end
            points(end+1,:)     = points(1,:);
            
            %Round all the points
            points      = round(points);
            
            %First remove the existing segmentation
            idx     = app.segmentation.img == segIndex;
            app.segmentation.img(idx)   = 0;
            
            %Fill in the new segmentation            
            for x=2:size(points,1)
                app.segmentation.img(                                   ...
                    points(x-1,1),...
                    points(x-1,2),...
                    points(x-1,3))  = segIndex;
                app.segmentation.img(                                   ...
                    points(x,1),...
                    points(x,2),...
                    points(x,3))    = segIndex;
                
                %Catch something
                d = points(x,:)-points(x-1,:);
                d = d/norm(d,2);
                if(any(isnan(d)))
                    continue
                end

                %Add all points between the most recently drawn points
                catcher = 1;
                while (catcher < 500)
                    p = round(points(x-1,:)+d*catcher);
                    app.segmentation.img(p(1),p(2),p(3)) = segIndex;
                    if(all(p-points(x,:) == 0))
                        break
                    end
                    catcher = catcher + 1;
                end
                if(catcher == 500)
                    disp('Catcher!');
                end
                
            end
            %finalise segmentation, fill all holes
            for iz=app.current_slice:app.current_slice
                %1:size(app.segmentation.img,3)
                if(app.view_axis == 3)
                    app.segmentation.img(:,:,iz) =                  ...
                        imfill(app.segmentation.img(:,:,iz),        ...
                                'holes');
                elseif(app.view_axis == 2)
                    app.segmentation.img(:,iz,:) =                  ...
                        imfill(                                     ...
                            squeeze(app.segmentation.img(:,iz,:)),  ...
                            'holes');
                elseif(app.view_axis == 1)
                    app.segmentation.img(iz,:,:) =                  ...
                        imfill(                                     ...
                            squeeze(app.segmentation.img(iz,:,:)),  ...
                            'holes');
                end
            end
        end
        
        function UpdateSegmentationProperties(app)
            %Prepares the labels and keeps the numbers correct 
            %during visualization.
            
            if isempty(app.segmentation)
                return
            end
            
            maxLabel    = max(app.segmentation.img(:));
            app.segmentation.properties = cell(maxLabel,1);
            
            %Add properties to the updated segmentation list
            for seg_id=1:maxLabel
                
                L           = app.segmentation.img == seg_id;
                try
                    Name    = app.seg_names{seg_id};
                catch
                    %If no name can be found, number the ROIs
                    Name    =seg_id;
                end
                VS          = min(app.data.hdr.dime.pixdim(2:4));
                Volume      = length(find(L))*VS^3;
                V           = app.data.img(:,:,:,app.current_4d_idx);
                MeanVolSig  = mean(V(L(:)));
                MaxVolSig   = max(V(L(:)));
                MinVolSig   = min(V(L(:)));
                StdVolSig   = std(V(L(:)));
                perc25Vol   = prctile(V(L(:)), 25, 'all');
                perc50Vol   = prctile(V(L(:)), 50, 'all');
                perc75Vol   = prctile(V(L(:)), 75, 'all');
                
                
                app.segmentation.properties{seg_id} = { ...
                    {'Name',   Name},                   ...
                    {'Volume', Volume},                 ...
                    {'Mean',   MeanVolSig},             ...
                    {'Max',    MaxVolSig},              ...
                    {'Min',    MinVolSig},              ...
                    {'Std',    StdVolSig},              ...
                    {'perc25',  perc25Vol},             ...
                    {'perc50',  perc50Vol},             ...
                    {'perc75',  perc75Vol}
                    };
            end
        end
        
        function UpdateROIBox(app)
            %Clear items
            app.ROIBox.Items    = {};
            
            %Add ROIs
            if isfield(app.segmentation, 'properties')
                for seg_id = 1:size(app.segmentation.properties, 1)
                    name    = app.segmentation.properties{seg_id}{1}{2};
                    if ~ischar(name)
                       name =  num2str(name);
                    end

                    app.ROIBox.Items{seg_id}        = name;
                    app.ROIBox.ItemsData(seg_id)    = seg_id;
                end
            elseif isempty(app.segmentation) && ~isempty(app.seg_names)
                   
                for seg_id = 1:size(app.seg_names, 1)
                    name    = app.seg_names{seg_id};
                    if ~ischar(name)
                       name =  num2str(name);
                    end

                    app.ROIBox.Items{seg_id}        = name;
                    app.ROIBox.ItemsData(seg_id)    = seg_id;
                end
            end
            
            %Add 'None'
            idx     = size(app.ROIBox.Items, 2) + 1;
            app.ROIBox.Items{idx}       = 'None';
            app.ROIBox.ItemsData(idx)   = -1;
        end
        
        function RemoveSegmentation(app, index)
            %Removes the specified segmentation from the current 
            %segmentations. 
            %Input: index - the index of the segmentation to be removed.
           
            %TODO: update also remove name
            %TODO: removing a segmentation in the middle should reduce all
            %other labels by one.
            if(index ~= 0)
                    L = app.segmentation.img    == index;
                    app.segmentation.img(L)     = 0;
            end
        end
        
        function RemoveAllROIs(app)
        %Remove all ROIs from the current image
            
            %Don't do anything if no ROIs exist
            if(~isfield(app.segmentation, 'img'))
                return
            end
            
            %Remove everything
            app.segmentation                                = [];
            app.seg_names                                   = {}; 
            app.roiPoints                                   = [];
            app.roiPointIndex                               = [];
            ROI.UpdateROIBox(app)
            
        end
        
    end
end