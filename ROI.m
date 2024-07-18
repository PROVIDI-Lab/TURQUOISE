classdef ROI < handle
    %This static class deals with all functions that deal with a 
    %(user-made) segmentation. The storage and addition of points is 
    %managed, as well as the conversion from polygon points to 
    %segmentation.
    
    methods (Static)
        
        function AddPointToPolygon(app, row, column)
            % This handles the manual drawing of ROIs. Called when the
            % mouse is pressed somewhere in the image. It adds the point to
            % app.drawing. 

            %Get image coordinates
            ijk         = NiftiUtils.rc2ijk(app, row, column);
            ijk         = round(ijk);

            %add to points
            app.points{app.axID} = [app.points{app.axID}; ijk];
        end
        
        function ValidateDrawingPoints(app, ROIName, newROI)
        % When at least 3 points are specified in app.drawing.points, a
        % segmentation is constructed and added to the app.
        %   
            if isempty(ROIName) || size(app.points{app.axID},1) <= 3
               	return
            end
            
            %Checks if points should be adapted to match image orientation
            % validatedPts = ROI.ValidatePoints(app);
            validatedPts = app.points{app.axID};

            %Check if a new ROI should be made
            if newROI
                ROI.CreateSegmentation(app, ROIName, validatedPts)
                app.points{app.axID} = [];
                Graphics.DeleteAllTempDrawings(app);
                return
            end
            
            %If not, add to existing ROI
            imID = app.imagePerAxis(app.axID);
            for i = 1:length(app.userObjects)
                obj = app.userObjects{i};
                if strcmp(obj.name, ROIName) && ...
                        obj.imageIdx == imID && ...
                        obj.deleted ~= 1     && ...
                        strcmp(obj.profile, app.user_profile)
                    Objects.AddToUO(app, obj.ID, validatedPts)
                    break
                end
            end

            app.points{app.axID} = [];
            Graphics.DeleteAllTempDrawings(app);
            
        end
        
        function CreateSegmentation(app, name, pts)
        %Creates a segmentation from a collection of points.
            
            mask = ROI.PointsToMask(...
                app, pts, app.imagePerAxis(app.axID), 1);
        
            Objects.AddNewUserObj(app,...
                "type", 1, ...
                "data", mask,...
                "points", pts, ...
                "name", name)

            obj = app.userObjects{end};
            GUI.UpdateUOBox(app);
            axID = find(app.imagePerAxis == obj.imageIdx);
            if axID
                GUI.AddUOLayer(app, axID, obj.ID)
                Graphics.UpdateImage(app)
            end
            Backups.CreateBackup(app)
        end        
        
        function mask = PointsToMask(app, points, imID, varargin)
        %Creates an array the size of the current image where everything in
        %the points is filled in.

            %find relative viewing axis
            viewDim = NiftiUtils.FindViewingDimension(app, imID);
            if nargin == 5
                type = varargin{1};
                viewDim = varargin{2};
            elseif nargin == 4
                type = varargin{1};
            else
                type = 1;
            end

            %Find image orientation
            tm          = app.transMatPerImage{imID};
            or          = NiftiUtils.FindOrientation(tm);
            imageOr     = strfind('csa', or(5)); 
        
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

            %iterate over slices in the view direction
            slices = unique(points(:,viewDim));
            for i = 1:length(slices)
                slice = slices(i);

                %select current slice
                tmp = points(points(:, viewDim) == slice,:);   
                
                %Empty mask
                maskSz          = size(app.data{imID}.img);
                maskSz(viewDim) = [];
                maskSlc         = false(maskSz(1), maskSz(2));

                %Fill in region with roipoly
                tmp(:, viewDim) = [];
                xi              = tmp(:,1);
                yi              = tmp(:,2);

                if imageOr == 3 && viewDim == 1 || ...  % ax im, cor proj
                   imageOr == 3 && viewDim == 2 || ...  % ax im, sag proj
                   imageOr == 1 && viewDim == 2 || ...  % cor im, ax proj
                   imageOr == 1 && viewDim == 1 || ...  % cor im, sag proj
                   imageOr == 2 && viewDim == 2 || ...  % sag im, ax proj
                   imageOr == 2 && viewDim == 1
                    maskSlc         = roipoly(maskSlc, yi, xi);
                else
                    maskSlc         = roipoly(maskSlc, xi, yi);
                end

                %Flip at the end, because matlab graphics have their origin
                %top-left, and the image coordinates have their origin
                %bottom-left. 
                maskSlc     = flip(maskSlc);
                mask        = ROI.AddSliceToMask(...
                    app, mask, maskSlc, slice);
            end    
        end
        
        function mask = AddSliceToMask(app, mask, maskSlc, slcNum)

            axTable     = [3,2,1; 2,3,1; 1,2,3];
            flipTable   = [0,0,1; 0,0,1; 1,0,0];
            flipXTable  = [0,0,0; 0,0,0; 0,0,0];
            
            imID        = app.imagePerAxis(app.axID);
            tm          = app.transMatPerImage{imID};
            or          = NiftiUtils.FindOrientation(tm);
            imageOr     = strfind('csa', or(5)); 
            viewingAxis = app.viewPerImage(imID);

            ax          = axTable(imageOr, viewingAxis);
            flp         = flipTable(imageOr, viewingAxis);
            flpx        = flipXTable(imageOr, viewingAxis);


            if flp
                maskSlc = flip(maskSlc);
            end

            if flpx
                maskSlc = flip(maskSlc,2);
            end

            if(ax == 3)
                mask(:,:,slcNum) = maskSlc;
            elseif(ax == 2)
                mask(:,slcNum,:) = maskSlc;
            elseif(ax == 1)
                mask(end - slcNum + 1,:,:) = maskSlc;
            end
        end

        function newPoints = MaskToPoints(mask, points, viewDim)
            
            newPoints = [];

            %find all slices
            [x,y,z] = ind2sub(size(mask), find(mask));

            if isempty(x)
                return
            end

            tmp = [x,y,z];
            slices = unique(tmp(:, viewDim));


            for i = 1:length(slices)
                slice = slices(i);

                %original points have precedence
                idx     = points(:, viewDim) == slice;
                if any(idx)
                    newPoints = [newPoints; points(idx,:)];
                    continue
                end

                tmpPoints = ROI.MaskToPoints2D(mask, slice, viewDim);
                %add points to list
                newPoints = [newPoints; tmpPoints];
            end
        end

        function points = MaskToPointsNew(mask, viewDim)
            %Mask to points version when no existing points are available
            points = [];

            %find all slices
            [x,y,z] = ind2sub(size(mask), find(mask));

            if isempty(x)
                return
            end

            tmp = [x,y,z];
            slices = unique(tmp(:, viewDim));

            for i = 1:length(slices)
                slice = slices(i);

                tmpPoints = ROI.MaskToPoints2D(mask, slice, viewDim);
                %add points to list
                points = [points; tmpPoints];
            end
        end

        function tmpPoints = MaskToPoints2D(mask, slice, viewDim)

            %find points from mask slice
            if viewDim == 1
                tmpSlice    = squeeze(mask(slice, :, :));
            elseif viewDim == 2
                tmpSlice     = squeeze(mask(:, slice, :));
            else
                tmpSlice     = squeeze(mask(:, :, slice));
            end

            %Get points by sobel edge detection
            sEdge   = edge(tmpSlice, 'sobel');
            [x,y]   = ind2sub(size(sEdge), find(sEdge));

            %Find boundary pixels in order
            tmpPoints = bwtraceboundary(sEdge, [x(1), y(1)], 'N');

            %bwtraceboundary sometimes messes up the order, so here we
            %enforce it. Also, removes any duplicate points.
            tmpPoints = MathUtils.SortPointsByDistance(tmpPoints);

            %Reduce amount of lines by Douglas-Peucker Algorithm
            %Tolerance hardcoded to 0.8 seems to give good results.
            tmpPoints = dpsimplify(tmpPoints, 0.8);

            %flip x, for some reason?
            sz      = size(mask);
            sz(viewDim) = [];
            tmpPoints(:,1) = sz(1) - tmpPoints(:,1);

            %add slice dim, swap x and y 
            tmpPoints = [tmpPoints(:,2),...
                         tmpPoints(:,1),...
                         ones(length(tmpPoints), 1) * slice];

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
            
            ax = app.GetAxis(app.axID);
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
            view    = app.viewPerImage(app.imID);
            slice   = app.slicePerImage{app.imID}{view};
            points  = [roi.Center, roi.Radius, view, slice];
            mask    = ROI.PointsToMask(app, points, app.imID, 3);
            
            %Create UO
            Objects.AddNewUserObj(app,...
                    "type", 3, ...
                    "data", mask, ...
                    "points", points, ...
                    "name", name{1})

            obj = app.userObjects{end};
            GUI.UpdateUOBox(app);
            axID = find(app.imagePerAxis == obj.imageIdx);
            if axID
                GUI.AddUOLayer(app, axID, obj.ID)
                Graphics.UpdateImage(app)
            end
            Backups.CreateBackup(app)
                
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
            
            ax = app.GetAxis(app.axID);
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
            view    = app.viewPerImage(app.imID);
            slice   = app.slicePerImage{app.imID}{view};
            points  = [roi.Center, roi.SemiAxes, roi.RotationAngle,...
                view, slice];
            mask    = ROI.PointsToMask(app, points, app.imID, 4);
            
            %Create UO
            Objects.AddNewUserObj(app,...
                    "type", 4, ...
                    "data", mask, ...
                    "points", points, ...
                    "name", name{1})

            obj = app.userObjects{end};
            GUI.UpdateUOBox(app);
            axID = find(app.imagePerAxis == obj.imageIdx);
            if axID
                GUI.AddUOLayer(app, axID, obj.ID)
                Graphics.UpdateImage(app)
            end
            Backups.CreateBackup(app)
                
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

        %% Interpolating

        function [newPoints, newMask] = Interpolate(obj)
            
            %first, find all slices
            slcLst = unique(obj.points(:, obj.viewDim));

            %Make a list of points per slice
            pointsLst = {};
            for i = 1:length(slcLst)
                slice   = slcLst(i);
                idx     = obj.points(:,obj.viewDim) == slice;
                tmppnts = obj.points(idx,:);
                pointsLst{end+1} = tmppnts;
            end

            %Get image dimensions
            sz  = size(obj.data);
            X   = linspace(1, sz(1), sz(1));
            Y   = linspace(1, sz(2), sz(2));
            Z   = linspace(1, sz(3), sz(3));

            %Interpolate
            newMask = blendedPolymask(pointsLst, X, Y ,Z);

            %Get new points from mask
            newPoints = ROI.MaskToPoints(newMask, ...
                obj.points, obj.viewDim);


        end
                
    end
end