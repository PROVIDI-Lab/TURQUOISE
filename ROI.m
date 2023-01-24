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
            view    = app.viewPerImage(imID);
            slice   = app.slicePerImage{imID}{view};

            %add new point
            if(view == 3)
                app.points{Cv} = [app.points{Cv}; hitx hity slice];
            elseif(view == 2)
                app.points{Cv} = [app.points{Cv}; hitx slice hity];
            elseif(view == 1)
                app.points{Cv} = [app.points{Cv}; slice hitx hity];
            end

        end
        
        function ValidateDrawingPoints(app, ROIName, newROI)
        % When at least 3 points are specified in app.drawing.points, a
        % segmentation is constructed and added to the app.
        %   
            Cv  = app.current_view;
            if isempty(ROIName) || size(app.points{Cv},1) <= 3
               	return
            end

            app.points{Cv}  = ROI.ValidatePoints(app, app.points{Cv});

            %Check if a new ROI should be made
            if newROI
                ROI.CreateSegmentation(app, ROIName)
                app.points{Cv} = [];
                return
            end
            
            %If not, add to existing ROI
            imID = app.imagePerAxis(Cv);
            for i = 1:length(app.userObjects)
                obj = app.userObjects{i};
                if strcmp(obj.name, ROIName) && obj.imageIdx == imID
                    Objects.AddToUO(app, obj.ID)
                    break
                end
            end
            app.points{Cv} = [];
            
        end
        
        function CreateSegmentation(app, name)
        %Creates a segmentation from a collection of points.
            Cv  = app.current_view;
            Objects.AddNewUserObj(app,...
                "type", 1, ...
                "data", ROI.PointsToMask(...
                app, app.points{Cv}, app.imagePerAxis(Cv), 1),...
                "points", app.points{Cv}, ...
                "name", name)
        end        
        
        function mask = PointsToMask(app, points, imID, type)
        %Creates an array the size of the current image where everything in
        %the points is filled in.
        
            %preallocate the mask
            mask    = false(size(app.data{imID}.img));

            if type == 3
                maskSlc     = ROI.GetCircularMask(points, mask);
                mask        = ROI.AddSliceToMask(...
                    mask, maskSlc, points(4), points(5));
                return
            elseif type == 4
                maskSlc     = ROI.GetEllipseMask(points, mask);
                mask        = ROI.AddSliceToMask(...
                    mask, maskSlc, points(6), points(7));
                return
            elseif type ~= 1
                return
            end

            %Get world-coordinate points
            tm  = app.transMatPerImage{imID};
            ijk = [points, ones(length(points),1)];
            xyz = tm * ijk';
            worldCoords = xyz(1:3, :)';

            %find relative viewing axis
            or          = NiftiUtils.FindOrientation(tm);
            viewAxis    = app.viewPerImage(imID);
            imageOr     = strfind('sca', or(5)); 
            or_Mat      = [3,1,2; 1,3,2; 1,2,3];
            view        = or_Mat(imageOr, viewAxis);
            slice       = app.slicePerImage{imID}{viewAxis};

            %Get xref and yref, limits of the image in world-coordinates
            [xref, yref]    = NiftiUtils.GetSliceBoundary(...
                app, app.current_view, view, slice);

            worldCoords(:,view) = [];
            xi              = worldCoords(:,1);
            yi              = worldCoords(:,2);

            maskSz          = size(app.data{imID}.img);
            maskSz(view)    = [];
            maskSlc         = zeros(maskSz(1), maskSz(2));

            maskSlc         = roipoly(xref, yref, maskSlc, xi, yi);
            mask            = ROI.AddSliceToMask(...
                mask, maskSlc, view, slice);

            return

            
            points  = round(points);
            [view, ~]   = ROI.GetViewAndSlice(points);                        
            
            %The mask is made slice by slice.
            idx = unique(points(:,view));   
            %todo: Index in position 2 exceeds array bounds.
            for ii = idx'
                tmpPoints   = points( points(:, view) == ii,:);
                tmpPoints(:,view) = [];
                maskDim     = size(mask);
                maskDim(view) = [];
                maskSlc = ones(maskDim);
                maskSlc = roipoly(maskSlc, tmpPoints(:,1), tmpPoints(:,2));
                mask    = ROI.AddSliceToMask(mask, maskSlc, view, ii);
            end              
        end
        
        function mask = AddSliceToMask(mask, maskSlc, view, slc)
            if(view == 3)
                mask(:,:,slc) = maskSlc;
            elseif(view == 2)
                mask(:,slc,:) = maskSlc;
            elseif(view == 1)
                mask(slc,:,:) = maskSlc;
            end
        end

        function points = ValidatePoints(app, points)
        %Makes sure that all points are valid.
       
            sz  = size(...
                app.data{app.imIdx}.img(:,:,:,...
                app.d4PerImage(app.imIdx)));
            points(:,1)     = min(points(:,1), sz(2));
            points(:,2)     = min(points(:,2), sz(1));
            points(:,3)     = min(points(:,3), sz(3));
            points          = max(points,1);
        end
        
        function [view, slice] = GetViewAndSlice(points)
            %Finds the view that was (most likely) used to draw the ROI as
            %well as the slice that has the moist points on it.
            
            x   = points(:,1); 
            y   = points(:,2); 
            z   = points(:,3); 
            %Find most occurring value
            [Mx, Fx]    = mode(x);
            [My, Fy]    = mode(y);
            [Mz, Fz]    = mode(z);
            
            [~,  view]  = max([Fx, Fy, Fz]);
            
            modes       = [Mx, My, Mz];
            slice       = modes(view);
        end
        
        %% Circular ROIs
        
        function StartDrawingCircular(app)
            
            ax = app.GetAxis(app.current_view);
            roi = drawcircle(ax);        
            
            cm = roi.ContextMenu;
            %Add item to save the polygon & stop editing
            m1 = uimenu(cm,'Text','Save Circle');
            m1.MenuSelectedFcn = ...
                {@ROI.FinishDrawingCircular, app, roi};
        end
        
        function FinishDrawingCircular(~, ~, app, roi)
        %Constructs a mask from the circular ROI object.
        %Prompts the user for a name and adds a new user object.
            
            %Validate & Create
            name    = Interaction.PromptName(app);
            if isempty(name)
               	return 
            end
            
            %Create points & mask
            view    = app.viewPerImage(app.imIdx);
            slice   = app.slicePerImage{app.imIdx}{view};
            points  = [roi.Center, roi.Radius, view, slice];
            mask    = ROI.PointsToMask(app, points, app.imIdx, 3);
            
            %Create UO
            Objects.AddNewUserObj(app,...
                    "type", 3, ...
                    "data", mask, ...
                    "points", points, ...
                    "name", name{1})
                
            %Remove polygon
            delete(roi)
            
            %Redraw
            Graphics.UpdateImage(app)
        end
        
        
        function maskSlc = GetCircularMask(points, mask)
            %Returns a slice with a circular mask defined by the points.
            %The center is given in the first two points (x,y) and the
            %radius by the third point.
            %An empty mask is given as well to find the correct dimensions
            %of the slice. The view is stored in points(4)
            
            centerX     = points(1);
            centerY     = points(2);
            radius      = points(3);
            view        = points(4);
            
            maskDim     = size(mask);
            maskDim(view) = [];
            
            [xx, yy] = meshgrid(1:maskDim(2), 1:maskDim(1));
            % create the circle.
            maskSlc = (yy - centerY).^2 + (xx - centerX).^2 <= radius.^2;
        end
        %% Ellipse ROIs
        
        function StartDrawingEllipse(app)
            
            ax = app.GetAxis(app.current_view);
            roi = drawellipse(ax);        
            
            cm = roi.ContextMenu;
            %Add item to save the polygon & stop editing
            m1 = uimenu(cm,'Text','Save ROI');
            m1.MenuSelectedFcn = ...
                {@ROI.FinishDrawingEllipse, app, roi};
        end
        
        function FinishDrawingEllipse(~, ~, app, roi)
        %Constructs a mask from the Ellipse ROI object.
        %Prompts the user for a name and adds a new user object.
            
            %Validate & Create
            name    = Interaction.PromptName(app);
            if isempty(name)
               	return 
            end
            
            %Create points & mask
            view    = app.viewPerImage(app.imIdx);
            slice   = app.slicePerImage{app.imIdx}{view};
            points  = [roi.Center, roi.SemiAxes, roi.RotationAngle,...
                view, slice];
            mask    = ROI.PointsToMask(app, points, app.imIdx, 4);
            
            %Create UO
            Objects.AddNewUserObj(app,...
                    "type", 4, ...
                    "data", mask, ...
                    "points", points, ...
                    "name", name{1})
                
            %Remove polygon
            delete(roi)
            
            %Redraw
            Graphics.UpdateImage(app)
        end
        
        
        function maskSlc = GetEllipseMask(points, mask)
            %Returns a slice with a Ellipse mask defined by the points.
            %The center is given in the first two points (x,y) and the
            %Semi axes by points 3-4. The rotation is stored in points(5).
            %An empty mask is given as well to find the correct dimensions
            %of the slice. The view is stored in points(6)
            
            centerX     = points(1);
            centerY     = points(2);
            radiusX     = points(3);
            radiusY     = points(4);
            rotation    = points(5);
            view        = points(6);
            
            maskDim     = size(mask);
            maskDim(view) = [];
            
            %define grid
            [xx, yy] = meshgrid(1:maskDim(2), 1:maskDim(1));
            
            %apply rotation
            theta       = (90 - rotation) * pi / 180;
            xr          = xx - centerX;
            yr          = yy - centerY;
            x0          = cos(theta)*xr + sin(theta)*yr;
            y0          = -sin(theta)*xr + cos(theta)*yr;
            
            % create the ellipse
            maskSlc = x0.^2 / radiusY^2 + y0.^2 / radiusX^2 <= 1;
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