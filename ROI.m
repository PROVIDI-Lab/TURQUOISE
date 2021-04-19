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
            
            Cv      = app.current_view;
            imID    = app.imagePerAxis(Cv);
            slice   = app.slicePerImage(imID);
            view    = app.viewPerImage(imID);

            %add new point
            if(view == 3)
                app.points{Cv} = [app.points{Cv}; hitx hity slice];
            elseif(view == 2)
                app.points{Cv} = [app.points{Cv}; hitx slice hity];
            elseif(view == 1)
                app.points{Cv} = [app.points{Cv}; slice hitx hity];
            end
        end
        
        function ValidateDrawingPoints(app)
        % When at least 3 points are specified in app.drawing.points, a
        % segmentation is constructed and added to the app.
        %   
            Cv  = app.current_view;
            if(size(app.points{Cv},1) <= 3)
                return
            end
            
            %Prompt user for name
            name    = Interaction.PromptName();
            if isempty(name)
               	return
            end
%             app.points{Cv}  = [app.points{Cv}; app.points{Cv}(1,:)];
            app.points{Cv}  = ROI.ValidatePoints(app, app.points{Cv});
            GUI.DisableControlsStatus(app);
            drawnow;

            Backups.CreateBackup(app);
            %Construct the segmentation from the drawing.points.
            ROI.CreateSegmentation(app, name{1})
%             ROI.StoreROIPoints(app)
            
            app.points{Cv} = [];
            GUI.RevertControlsStatus(app);
        end
        
        function ValidateModifiedROIPoints(app)
            %Called after an ROI point is moved and the mouse is released.
            %Does mostly the same as ValidateDrawingPoints, just with the
            %most recent roiPoints and not drawing.points.
            
            
            Backups.CreateBackup(app);
            %Circular ROI
            if app.userObjects{app.currentDragPoint{1}}.type == 3
                ROI.ModifyCircle(app);
            else            
                %Normal ROI
                ROI.ModifySegmentation(app)
            end
        end            
        
        %% Dragging ROI points
        
        function StartDragging(app, hit)
        %Stores the location from which an ROIpoint is being dragged.
            x = hit.Source.Parent.Parent.CurrentPoint(1);
            y = hit.Source.Parent.Parent.CurrentPoint(2);
            hitx = round(hit.IntersectionPoint(1));
            hity = round(hit.IntersectionPoint(2));
            app.dragPoint   = [hitx, x, hity, y];
            ROI.FindPoint(app);
            
            %Only continue if a point has been found
            if isempty(app.currentDragPoint)
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
            %TODO: check if this works in sag/cor views
            x   = app.dragPoint(1);
            y   = app.dragPoint(3);
            
            %Go over all ROI objects and check whether any point is within
            % 5 voxels (in the current plane) of where the user clicked
            %in the image.
            for i   = length(app.userObjects):-1:1
                obj     = app.userObjects{i};
                idx     = ROI.DistanceToPoints(obj.points, x, y);
                if idx  ~= -1
                    app.currentDragPoint   = {i, idx};
                    break
                end                
            end
        end
            
        function idx    = DistanceToPoints(points, x,y)
            idx     = -1;
            xp      = points(:,1);
            yp      = points(:,2);
            d       = sqrt( (x-xp).^2 + (y-yp).^2);
            [M, I]  = min(d);
            if M <= 5 %less than 5 voxels away
               idx  = I;
            end
        end
        
        
        function MoveROIPoint(app, newPos)
           %Modifies an ROI point to be in a new position. Called when the 
           %user drags one of the points.
           
            imID    = app.imagePerAxis(Cv);
            view    = app.viewPerImage(imID);
           
            x    = round(newPos(1));
            y    = round(newPos(2));
            z    = app.slicePerImage(imID);
            
            if view == 1
               pos  = [z,x,y];
            elseif view == 2
               pos  = [x,z,y];
            else
               pos  = [x,y,z];               
            end
            %If the obj is a circular ROI, edit accordingly
            if app.userObjects{app.currentDragPoint{1}}.type == 3
               %TODO fix different views 
               points  = app.userObjects{...
                        app.currentDragPoint{1}}.points(:,1:2);
                if app.currentDragPoint{2} == 1%Middle is dragged, move ROI
                    dx  = x - points(1,1);
                    dy  = y - points(1,2);
                    x2  = points(2,1) + dx;
                    y2  = points(2,2) + dy;

            %                     app.userObjects{app.currentDragPoint{1}}.points = ...
            %                         round([x,y,z; x2,y2,z]);
                    app.currentCircle = round([x,y,x2,y2]);
                else %Edge is dragged, increase size

                    app.currentCircle  = round(...
                        [points(1,1), points(1,2), x, y]);
                end
                %Draw guide circle
                if app.current_view  == 1
                    Graphics.DrawCircleInAxis(app, app.UIAxes1);
                else
                    Graphics.DrawCircleInAxis(app, app.UIAxes2);
                end
                return
            else %Normal ROI
                app.userObjects{app.currentDragPoint{1}}.points(...
                    app.currentDragPoint{2},:)     = round(pos);
            end

            Graphics.UpdateUserInteractions(app);
        end
        
        
        
        function CreateSegmentation(app, name)
        %Creates a segmentation from a collection of points.
            Cv  = app.current_view;
            Objects.AddNewUserObj(app,...
                    "type", 1, ...
                    "data", ROI.PointsToMask(app, app.points{Cv}),...
                    "points", app.points{Cv}, ...
                    "name", name)
        end        
        
        function ModifySegmentation(app)
            %Creates a modified segmentation from the app.roiPoints. Mostly
            %the same as CreateSegmentation.
            
            if isempty(app.currentDragPoint)
                return
            end
            objId           = app.currentDragPoint{1};
            obj             = app.userObjects{objId};
            points          = obj.points;
            points(end+1,:) = points(1,:);
            points          = round(points);
            mask            = ROI.PointsToMask(app, points);
            
            app.userObjects{objId}.set('data', mask);
            app.userObjects{objId}.set('changed', true);
            app.userObjects{objId}.makeProperties(app);
            Graphics.UpdateUserObjects(app);
        end
        
        function mask = PointsToMask(app, points)
        %Creates an array the size of the current image where everything in
        %the points is filled in.
        
            imID    = app.imagePerAxis(app.current_view);
            view    = app.viewPerImage(imID);
            axis4D  = app.d4PerImage(imID);
        
            %preallocate the mask
            points  = round(points);
            mask    = false(size(...
                app.data{imID}.img(:,:,:, axis4D)));
            
            %The mask is made slice by slice.
            idx = unique(points(:,view));
            for ii = idx'
                tmpPoints   = points( points(:, view) == ii,:);
                mask = ROI.ConstructVertices(mask, tmpPoints);
            end

            %finalise segmentation, fill all holes
            for iz  = 1:size(mask, view)
                %iz=app.current_slice:app.current_slice
                %1:size(app.segmentation.img,3)
                if(view == 3)
                    mask(:,:,iz) = imfill(mask(:,:,iz), 'holes');
                elseif(view == 2)
                    mask(:,iz,:) = imfill(squeeze(mask(:,iz,:)), 'holes');
                elseif(view == 1)
                    mask(iz,:,:) = imfill(squeeze(mask(iz,:,:)), 'holes');
                end
            end       
        end
        
        function mask = ConstructVertices(mask, points)
            %Gets a mask and some points in a 2d plane. Fills in all the 
            %areas between the points in the mask to construct vertices.

            %Add first point again to complete the circle
            points(end+1,:) = points(1,:);
           
            %Add all pixels in between the vertices to the mask
            for x=2:size(points,1)
                mask(...
                    points(x-1,1),...
                    points(x-1,2),...
                    points(x-1,3))  = 1;
                mask(...
                    points(x,1),...
                    points(x,2),...
                    points(x,3))    = 1;

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
                    mask(p(1),p(2),p(3)) = 1;
                    if(all(p-points(x,:) == 0))
                        break
                    end
                    catcher = catcher + 1;
                end
                if(catcher == 500)
                    disp('Catcher!');
                end

            end
        end
        
        function points = ValidatePoints(app, points)
        %Makes sure that all points are valid.
            sz  = size(...
                app.data{app.imIdx}.img(:,:,:,...
                app.d4PerImage(app.imIdx)));
            points(:,1)     = min(points(:,1), sz(1));
            points(:,2)     = min(points(:,2), sz(2));
            points(:,3)     = min(points(:,3), sz(3));
            points          = max(points,1);
        end
        
        %% Circular ROIs
        
        function StartDrawingCircular(app, hit)
            
            x = hit.Source.Parent.Parent.CurrentPoint(1);
            y = hit.Source.Parent.Parent.CurrentPoint(2);
            hitx = round(hit.IntersectionPoint(1));
            hity = round(hit.IntersectionPoint(2));
            app.dragPoint       = [hitx, x, hity, y];
            app.currentCircle   = [hitx, hity, 0, 0];
            
            set(hit.Source.Parent.Parent,                               ...
                'WindowButtonMotionFcn',                                ...
                @app.MouseDraggedInImage);

            set(hit.Source.Parent.Parent,                               ...
                'WindowButtonUpFcn',                                    ...
                @app.MouseReleasedInImage);
            
        end
        
        function FinishDrawingCircular(app)
        %Constructs a list of points from which a segmentation can be 
        %constructed. Then adds the corresponding segmentation to the 
        %program.
        
            %Stop drawing
            app.drawing.mode = 0;
            
            [points, markers] = ...
                ROI.GetCirclePointsMarkers(app);
            
            %Validate & Create
            
            name    = Interaction.PromptName();
            if isempty(name)
               	return %TODO: stop drawing
            end
            points  = ROI.ValidatePoints(app, points);
            Backups.CreateBackup(app);            
            
            Objects.AddNewUserObj(app,...
                    "type", 3, ...
                    "data", ROI.PointsToMask(app, points),...
                    "points", markers, ...
                    "name", name{1})
        end
        
        function ModifyCircle(app)
        %Modifies an existing circular ROI user object
            if isempty(app.currentCircle)
                return
            end
            [points, markers] = ...
                    ROI.GetCirclePointsMarkers(app);
            points  = ROI.ValidatePoints(app, points);
            Backups.CreateBackup(app);            
            
            app.userObjects{app.currentDragPoint{1}}.set(...
                'data', ROI.PointsToMask(app, points));
            app.userObjects{app.currentDragPoint{1}}.set(...
                'points', markers);
        end
        
        function [points, markers] = GetCirclePointsMarkers(app)
        %Constructs the points at the edge of a circular ROI as well as
        %the markers that define it from app.currentCircle.
            
            imID    = app.imagePerAxis(Cv);
            view    = app.viewPerImage(imID);
            slice   = app.slicePerImage(imID);
            %Find position of circle
            tmp                 = num2cell(app.currentCircle);
            [x0, y0, x1, y1]    = deal(tmp{:});
            rad                 = pdist([x0,y0; x1,y1],'euclidean');
            
            %Sample enough points
            nPoints = round(2 * rad * pi); 
            if isnan(nPoints)
                nPoints = 100;
            end
            angles  = linspace(0, 2*pi, nPoints);
            x       = round(rad * cos(angles) + x0);
            y       = round(rad * sin(angles) + y0);
            z       = ones(1, nPoints) * slice;
            
            if view        == 3
                points  = [x;y;z]';
            elseif view    == 2
                points  = [x;z;y]';
            elseif view    == 1
                points  = [z;x;y]';
            end
            
            %Create markers that define the circle (one in the middle,
            %one at the edge)
            insert  = @(a, x, n)cat(2,  x(1:n-1), a, x(n:end)); 
            mark0   = insert(slice, [x0, y0], view);
            mark1   = insert(slice, [x1, y1], view);
            markers = [mark0; mark1];
            
            
        end
        
        function DrawCircularROI(app, newPos)
            app.currentCircle(3:4) = newPos;
            if app.current_view  == 1
                Graphics.DrawCircleInAxis(app, app.UIAxes1);
            else
                Graphics.DrawCircleInAxis(app, app.UIAxes2);
            end 
        end
        
        %%
        
        function RemoveSegmentation(app, index)
            %Removes the specified segmentation from the current 
            %segmentations. 
            %Input: index - the index of the segmentation to be removed.
           
            %TODO: update also remove name
            %TODO: removing a segmentation in the middle should reduce all
            %other labels by one.
            %TODO: remove all ROIpoints associated
            Cv      = app.current_view;
            if(index ~= 0)
                    L = app.segmentation{Cv}.img    == index;
                    app.segmentation{Cv}.img(L)     = 0;
            end
        end
        
        function RemoveAllROIs(app)
        %Remove all ROIs from the current image
            
            app.userObjects = {};
            Graphics.UpdateImage(app);
            
        end
        
    end
end