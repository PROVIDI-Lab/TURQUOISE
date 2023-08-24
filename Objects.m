classdef Objects < handle
    methods (Static)
        
        function AddNewUserObj(app, varargin)
            obj         = UserObj();
            
            %very hacky way to assign properties.
            %in the meantime, check if profile is assigned
            hasProfile = false;
            for idx     = 1:2:nargin-1
                if ~isprop(obj, varargin{idx})
                    continue
                end

                if strcmp(varargin{idx}, "profile")
                    hasProfile = true;
                end
                
                str     = strcat(...
                    'obj.', varargin{idx}, ' = varargin{idx+1};');
                eval(str);
            end
            
            %Fill in unspecified details
            if isempty(obj.imageIdx)
                obj.imageIdx     = ...
                    app.imagePerAxis(app.axID);
            end
            if isempty(obj.name)
                obj.name        = ...
                    ['uObj' num2str(length(app.userObjects))];
            else
                obj.name    = Objects.CheckNameUnique(...
                    app, obj.name, obj.imageIdx);
            end
            if isempty(obj.ID)
                obj.ID          = length(app.userObjects) + 1;
            end
            if isempty(obj.viewDim) %might be a problem when loading
                obj.viewDim     = NiftiUtils.FindViewingDimension(...
                    app, obj.imageIdx);
            end
            if isempty(obj.comment)
                obj.comment = '';
            end

            %if the profile is empty, and no profile was specified, change
            %to app.user_profile. Otherwise, the empty profile was
            %intentional and should be kept.
            if isempty(obj.profile) && ~hasProfile
                obj.profile = app.user_profile;
            end

            
            %Calculate properties
            obj.makeProperties(app);
            %Add to list            
            app.userObjects{end+1}  = obj;
        end

        function name = CheckNameUnique(app, name, idx, profile)
            %Compares names between new object and existing objects.
            %In the case of identical names, adds a number to the end.           
            
            %Remove any +/- notation from name
            [baseName, modeSig] = Objects.SplitModeFromUOName(name);

            names = Objects.GetAllUONamesForImage(app, idx);
            uniqueName = true;
            for i = 1:length(names)
                objName = names{i};
                [baseObjName, ~] = Objects.SplitModeFromUOName(objName);
                
                if contains(baseObjName, baseName)
                    if strcmp(baseObjName, baseName)
                        uniqueName = false;
                    end
                end                
            end

            if uniqueName
                return
            end

            %name not unique, add number before mode signifier
            counter = 1;
            name    = strcat(baseName, num2str(counter), modeSig);
            while any(ismember(names, name))
                counter = counter + 1;
                name    = strcat(baseName, num2str(counter), modeSig);
            end
        end

        function [base, mode] = SplitModeFromUOName(name)

            if contains(name, ' +')
                base = strrep(name, ' +', '');
                mode = ' +';
            elseif contains(name, ' -')
                base = strrep(name, ' -', '');
                mode = ' -';
            else
                base = name;
                mode = ' +';
            end
        end

        function AddToUO(app, ID, pts)
            %Adds points & data to existing ROI. 
            %The 'pts' input can have altered points, based on image
            %orientation and projection. It should only be used to create
            %the mask.

            obj         = app.userObjects{ID};
            obj.points  = [obj.points; app.points{app.axID}];
            obj.data    = obj.data + ROI.PointsToMask(...
                app, pts, app.imagePerAxis(app.axID), 1);
            obj.data(obj.data > 1) = 1;
            obj.makeProperties(app);
            
            GUI.UpdateUOBox(app);
            Graphics.UpdateUserObjects(app);
            Backups.CreateBackup(app);
        end

        function ChangeName(app, ID, name)
        %Renames any UO named 'tmp' to the actual name

            obj             = app.userObjects{ID};
            obj.renaming    = false;

            if isempty(name)
                return
            end
            
            obj.name        = name;

            GUI.UpdateUOBox(app)
            Graphics.UpdateUserObjects(app)
        end

        %% Searching the UOs
        function names = GetAllUONamesForImage(app, index, varargin)
            %Returns the names of all UOs with a matching image and profile

            if nargin == 3
                profile = varargin{1};
            else
                profile = app.user_profile;
            end

            names = {};
            for i = 1:length(app.userObjects)
                obj = app.userObjects{i};
                if obj.imageIdx ~= index || obj.deleted || ...
                        ~strcmp(obj.profile, profile)
                    continue
                end
                names{end+1} = obj.name;
            end
        end

        function IDs = GetAllUOIDsForImage(app, varargin)
            %Returns the object.ID for each non-deleted object matching the 
            % image and profile
            index = varargin{1};

            if nargin == 2
                selectDeleted = false;
            elseif nargin == 3
                selectDeleted = varargin{2};
            end
            
            IDs = [];
            for i = 1:length(app.userObjects)
                obj = app.userObjects{i};
                if obj.imageIdx ~= index
                    continue
                end

                if ~strcmp(app.user_profile, obj.profile)
                    continue
                end

                if selectDeleted && obj.deleted
                    continue
                end
                IDs(end+1) = obj.ID;
            end
        end

        function idx = GetAllUOIdxForImage(app, varargin)
            %Returns the index of the objects in app.userObjects for each 
            % non-deleted object matching the image and profile
            index = varargin{1};

            selectDeleted = true;
            checkProfile  = true;
            switch nargin
                case 3
                    selectDeleted = varargin{2};
                case 4
                    selectDeleted = varargin{2};
                    checkProfile = varargin{3};
            end
                    
            idx = [];
            for i = 1:length(app.userObjects)
                obj = app.userObjects{i};
                if obj.imageIdx ~= index
                    continue
                end

                if checkProfile && ~strcmp(app.user_profile, obj.profile)
                    continue
                end

                if selectDeleted && obj.deleted
                    continue
                end
                idx(end+1) = i;
            end
        end

        function idx = findUOIndex(app, index)
            %Returns the index of the uo where ID == index
            idx = -1;
            for i = 1:length(app.userObjects)
                obj = app.userObjects{i};
                if obj.ID == index
                    idx = i;
                    break
                end
            end
            
        end
        
        function idx = FindUoForImage(app, imID)
            %Returns the index of the first uo with obj.imageIdx == imID
            %If none are found, returns -1
            idx = -1;
            
            for i = 1:length(app.userObjects)
                obj = app.userObjects{i};
                if obj.imageIdx == imID
                    idx = i;
                    break
                end
            end
        end
        
        function [view, slice] = GetUOViewAndSlice(obj)
        %Finds the most occuring slice per view axis. Returns the view & 
        %slice for which the most voxels are included in the segmentation
        %at the given index.
        
            %Find index of corresponding segmentation
            x   = obj.points(:,1); 
            y   = obj.points(:,2); 
            z   = obj.points(:,3); 

            %Find most occurring value
            [Mx, ~] = mode(x);
            [My, ~] = mode(y);
            [Mz, ~] = mode(z);
            
            view    = obj.viewDim;
            modes   = [Mx, My, Mz];
            slice   = modes(view);
        end


        %% Interacting with the UOs
        function EditUO(app, varargin)
            %When the edit menu in he UOBox contextmenu is called.

            if nargin == 1
                idx     = app.UOBox.Value;
                if isempty(idx)
                    return
                end
            else
                app = varargin{2};
                idx = varargin{3};
            end
                        
            obj     = app.userObjects{idx};

            %if object viewdim and current axis view don't match, return
            if obj.viewDim ~= NiftiUtils.FindViewingDimension(...
                    app, obj.imageIdx)
                views = {'a coronal', 'a sagittal', 'an axial'};
                
                text = sprintf( ...
                    strcat( ...
                    "Can't delete slice in an off-axis projection, ", ...
                    "switch to %s projection instead."), ...
                    views{obj.viewDim});
                msgbox(text)
                return
            end
            
            switch obj.type
                case 1
                    Objects.EditPolygon(app, idx)
                case 3
                    Objects.EditCircle(app, idx)
                case 4
                    Objects.EditEllipse(app, idx)
            end            
        end
        
        function EditPolygon(app, idx)
            obj     = app.userObjects{idx};
            points  = obj.points;
            
            %Hide contour
            app.userObjects{idx}.setVisible(false);
            app.userObjects{idx}.editing = true;
            Graphics.UpdateUserObjects(app);

            %get points for the current slice
            slice = app.slicePerImage{obj.imageIdx}{...
                app.viewPerImage(app.imID)};
            [x,y] = NiftiUtils.ijk2rc(app, app.axID, ...
                points, slice);
            slcPoints = [x,y];

            % %select only points from the current slice
            % slice = app.slicePerImage{obj.imageIdx}{...
            %     app.viewPerImage(app.imID)};
            % slcPoints = points(points(:,obj.viewDim) == slice, :);
            % slcPoints(:,obj.viewDim) = [];
            % 
            % %flip y
            % sz      = NiftiUtils.FindInPlaneResolution(app, app.imID);
            % slcPoints(:,2) =  sz(2) - slcPoints(:,2);
            
            
            %Create polygon with contextmenu
            ax = app.GetAxis(app.axID);
            h = images.roi.Polygon(ax, 'Position', slcPoints);
            cm = h.ContextMenu;
            cm.Children(1).Visible = 'off';
            %Add items to save the polygon & stop editing
            m1 = uimenu(cm,'Text','Save Polygon');
            m1.MenuSelectedFcn = ...
                {@Objects.FinishEditingPolygon, app, h};
            m2 = uimenu(cm, 'Text', 'Cancel');
            m2.MenuSelectedFcn = ...
                {@Objects.CancelEditing, app, h, idx};
            
        end
        
        function FinishEditingPolygon(~, ~, app, polygon)
            
            idx = -1;
            for i = 1:length(app.userObjects)
                if app.userObjects{i}.editing
                    idx = i;
                    break
                end
            end

            if idx == -1
                return
            end

            tmp  = polygon.Position;

            %flip y
            sz      = NiftiUtils.FindInPlaneResolution(app, app.imID);
            tmp(:,2) =  sz(2) - tmp(:,2);
            newPoints = NiftiUtils.rc2ijk(app, tmp(:,1), tmp(:,2));


            %get orientation info
            viewDim     = app.userObjects{idx}.viewDim;
            view    = app.viewPerImage(app.imID);
            slice   = app.slicePerImage{app.imID}{view};     


            %first remove all the old points
            sliceIdx = app.userObjects{idx}.points(:, viewDim) == slice;
            app.userObjects{idx}.points(sliceIdx, :) = [];
            app.userObjects{idx}.points = ...
                [app.userObjects{idx}.points; newPoints];
            app.userObjects{idx}.makeProperties(app);
            
            %Create new mask
            % adaptedPts = ROI.ValidatePoints(app, newPoints);
            app.userObjects{idx}.createMask(app, newPoints)
            
            %turn mask back on
            app.userObjects{idx}.setVisible(true)

            %toggle off editing
            app.userObjects{idx}.editing = 0;
            
            %Remove polygon
            delete(polygon)
            
            %backup
            Backups.CreateBackup(app)
            
            %Redraw
            Graphics.UpdateImage(app)
        end
        
        function EditCircle(app, idx)
            obj     = app.userObjects{idx};
            
            %Hide contour
            app.userObjects{idx}.setVisible(false);
            
            %Create polygon with contextmenu
            ax = app.GetAxis(app.axID);
            h   = images.roi.Circle(ax,...
                'Center',obj.points(1:2),'Radius',obj.points(3));
            cm = h.ContextMenu;
            cm.Children(1).Visible = 'off';
            %Add items to save the roi & stop editing
            m1 = uimenu(cm,'Text','Save ROI');
            m1.MenuSelectedFcn = ...
                {@Objects.FinishEditingCircle, app, h};
            m2 = uimenu(cm, 'Text', 'Cancel');
            m2.MenuSelectedFcn = ...
                {@Objects.CancelEditing, app, h, idx};
        end
        
        function FinishEditingCircle(~, ~, app, roi)
            idx     = app.UOBox.Value;
            idx     = Objects.findUOIndex(app, idx);
            if idx == -1
                return
            end
            
            view    = app.viewPerImage(app.imID);
            slice   = app.slicePerImage{app.imID}{view};
            points  = [roi.Center, roi.Radius, view, slice];
            
            app.userObjects{idx}.points = points;
            app.userObjects{idx}.makeProperties(app);
            
            %Create new contour
            app.userObjects{idx}.createMask(app)
            
            %turn contour back on
            app.userObjects{idx}.setVisible(true)
            
            %Remove polygon
            delete(roi)
            
            %backup
            Backups.CreateBackup(app)
            
            %Redraw
            Graphics.UpdateImage(app)
        end
        
        function EditEllipse(app, idx)
            obj     = app.userObjects{idx};
            points  = obj.points;
            
            if size(points,1) > size(points,2) && size(points,2) == 1
                points = points';
            end
            
            %Hide contour
            app.userObjects{idx}.setVisible(false);
            
            %Create polygon with contextmenu
            ax = app.GetAxis(app.axID);
            h   = images.roi.Ellipse(ax,...
                'Center',points(1:2),'SemiAxes',points(3:4),...
                'RotationAngle', points(5));
            cm = h.ContextMenu;
            cm.Children(1).Visible = 'off';
            %Add items to save the roi & stop editing
            m1 = uimenu(cm,'Text','Save ROI');
            m1.MenuSelectedFcn = ...
                {@Objects.FinishEditingEllipse, app, h};
            m2 = uimenu(cm, 'Text', 'Cancel');
            m2.MenuSelectedFcn = ...
                {@Objects.CancelEditing, app, h, idx};
        end
        
        function FinishEditingEllipse(~, ~, app, roi)
            idx     = app.UOBox.Value;
            idx     = Objects.findUOIndex(app, idx);
            if idx == -1
                return
            end
            
            view    = app.viewPerImage(app.imID);
            slice   = app.slicePerImage{app.imID}{view};
            points  = [roi.Center, roi.SemiAxes, roi.RotationAngle,...
                view, slice];
            
            app.userObjects{idx}.points = points;
            app.userObjects{idx}.makeProperties(app);
            
            %Create new contour
            app.userObjects{idx}.createMask(app)
            
            %turn contour back on
            app.userObjects{idx}.setVisible(true)
            
            %Remove polygon
            delete(roi)
            
            %backup
            Backups.CreateBackup(app)
            
            %Redraw
            Graphics.UpdateImage(app)
        end
        
        
        function CancelEditing(~, ~, app, roi, idx)
            %Remove the roi object and turn the visibility of the existing
            %object back on. 
            
            
            %Hide contour
            app.userObjects{idx}.setVisible(true)
            Graphics.UpdateUserObjects(app)
            delete(roi)
            
        end
        
        
        
        
        %% From contextmenu



        function DeleteUO(app, varargin)
            %When the deletemenu in he UOBox contextmenu is called.
            
            if nargin == 1
                idx     = app.UOBox.Value;
                if isempty(idx)
                    return
                end
            else
                app = varargin{2};
                idx = varargin{3};
            end

            %Prompt the user to make sure that they want to delete
            answer = questdlg('Really delete?', ...
                'Deleting', ...
                'No','Yes','No');
            
            if strcmp(answer, 'No')
                return
            end

            idx = Objects.findUOIndex(app, idx);
            if idx == -1
                return
            end
            obj = app.userObjects{idx};

            %delete / change properties
            obj.deleted = true;
            obj.editing = false;
            obj.renaming = true;
            obj.data = [];
            obj.points = [];
            obj.prop = [];

            %Remove UOLayer in renderer
            %first find right axis
            axID = find(app.imagePerAxis == obj.imageIdx);
            GUI.RemoveUOLayer(app, axID, obj.ID)

            GUI.UpdateUOBox(app)
            Graphics.UpdateImage(app)
            Backups.CreateBackup(app); 
        end

        function DeleteUOSlice(app, varargin)
            %When the deleteslicemenu in he UOBox contextmenu is called.
            
            if nargin == 1
                idx     = app.UOBox.Value;
                if isempty(idx)
                    return
                end
            else
                app = varargin{2};
                idx = varargin{3};
            end

            idx = Objects.findUOIndex(app, idx);
            if idx == -1
                return
            end

            obj = app.userObjects{idx};
            
            %if object viewdim and current axis view don't match, return
            projection = NiftiUtils.findProjectionFromViewDim( ...
                app, obj.imageIdx, obj.viewDim);

            if projection ~= app.viewPerImage(obj.imageIdx)
                views = {'a coronal', 'a sagittal', 'an axial'};
                
                text = sprintf( ...
                    strcat( ...
                    "Can't delete slice in an off-axis projection, ", ...
                    "switch to %s projection instead."), ...
                    views{obj.viewDim});
                msgbox(text)
                return
            end

            %find slice
            slice   = app.slicePerImage{obj.imageIdx}{projection};
            pIdx     = obj.points(:, obj.viewDim) == slice;
            obj.points(pIdx, :) = [];

            %if no more points remain, delete the entire object.
            if isempty(obj.points)
                Objects.DeleteUO([], [], app, idx)
                return
            end
            
            %Remove slice from UO data
            if obj.viewDim == 1
                obj.data(slice, :, :) = false;
            elseif obj.viewDim == 2
                obj.data(:, slice, :) = false;
            elseif obj.viewDim == 3
                obj.data(:, :, slice) = false;
            end

            GUI.UpdateUOBox(app)
            Graphics.UpdateImage(app)
            Backups.CreateBackup(app); 

        end
        
        
        function RenameUO(app, varargin)
            %When the renamemenu in he UOBox conextmenu is called.

            if nargin == 1
                idx     = app.UOBox.Value;
                if isempty(idx)
                    return
                end
            else
                app = varargin{2};
                idx = varargin{3};
            end
            idx = Objects.findUOIndex(app, idx);
            if idx == -1
                return
            end

            app.userObjects{idx}.renaming   = true;
            Interaction.PromptName(app, true);
            
        end
        
        function CopyUOTo(app, varargin)
            %When the copytoMenu in a contextmenu is called.
            if nargin == 1
                idx     = app.UOBox.Value;
                if isempty(idx)
                    return
                end
            else
                app = varargin{2};
                idx = varargin{3};
            end
            idx = Objects.findUOIndex(app, idx);
            if idx == -1
                return
            end
            
            obj         = app.userObjects{idx};
            
            targetIdx   = Interaction.PromptTarget(app);
            
            %find new points from world coordinates
            tm  = app.transMatPerImage{targetIdx};
            xyz = [obj.worldCoords, ones(length(obj.points),1)];
            ijk = tm \ xyz';

            %If the slice thickness is higher in the new image, we might
            %have multiple ROIs on one slice, causing issues.
            %Here, we find the closest slice in the case of multiples and
            %use that.
            prevSlices      = unique(ijk(obj.viewDim,:));
            rndPrevSlices   = round(prevSlices);
            slcDiff         = abs(prevSlices - rndPrevSlices);

            slices = unique(rndPrevSlices);

            %Go over each new slice, add the selected points to a new list.
            newPoints = [];
            for i = 1:length(slices)
                slc = slices(i);

                idx = rndPrevSlices == slc;

                %find prevSlice closest to slc
                [~, closest]    = min(slcDiff(idx));
                selection       = prevSlices(idx);
                prevSlice       = selection(closest);

                %find all points with matching prevSlice
                pntIdx          = ijk(obj.viewDim, :) == prevSlice;
                tmpPoints       = ijk(1:3, pntIdx)';
                newPoints       = [newPoints; tmpPoints];
            end


            points = round(newPoints);
            %create mask
            newMask = ROI.PointsToMask(app, points, targetIdx, obj.type);
                        
            Objects.AddNewUserObj(app,...
                    "type", obj.type, ...
                    "data", newMask,...
                    "points", points, ... 
                    "worldCoords", obj.worldCoords, ...
                    "name", obj.name,...
                    "imageIdx", targetIdx)
                
            GUI.UpdateUOBox(app);
            
            %if the image is being displayed, update it
            axID = find(app.imagePerAxis == targetIdx);
            if axID
                GUI.InitUORenderer(app, axID)
                Graphics.UpdateImageForAxis(app, axID)
            end
            Backups.CreateBackup(app); 
        end

        function ChangeUOAdditiveSubtractive(app)
            %When the switch additive/subtractive in he UOBox conextmenu 
            % is called.
            idx     = app.UOBox.Value;
            if isempty(idx)
                return
            end
            idx = Objects.findUOIndex(app, idx);
            if idx == -1
                return
            end
            
            additiveQ     = Interaction.PromptAdditiveSubtractive(app);
            app.userObjects{idx}.additive = strcmp(additiveQ, 'additive');
            Backups.CreateBackup(app); 
        end

        function AddComment(app,  varargin)
            %When the addComment in a contextmenu is called.
            if nargin == 1
                idx     = app.UOBox.Value;
                if isempty(idx)
                    return
                end
            else
                app = varargin{2};
                idx = varargin{3};
            end

            prevComment = app.userObjects{idx}.comment;
            if isempty(prevComment)
                comment = inputdlg('','Add comment', [3 50]);
            else
                comment = inputdlg('','Add comment', [3 50], prevComment);
            end

            if ~isempty(comment)
                app.userObjects{idx}.comment = comment;
            end

        end

        function ShowHist(app,  varargin)
            %When the addComment in a contextmenu is called.
            if nargin == 1
                idx     = app.UOBox.Value;
                if isempty(idx)
                    return
                end
            else
                app = varargin{2};
                idx = varargin{3};
            end

            obj = app.userObjects{idx};
            Plotting.ShowHistogram(app, obj);

        end
        
        function InterpSlices(app, varargin)
        %Interpolates any slices in between the existing mask slices 
            if nargin == 1
                idx     = app.UOBox.Value;
                if isempty(idx)
                    return
                end
            else
                app = varargin{2};
                idx = varargin{3};
            end

            obj = app.userObjects{idx};
            GUI.DisableControlsStatus(app)
            [points, mask] = ROI.Interpolate(obj);

            app.userObjects{idx}.points = points;
            app.userObjects{idx}.data   = mask;

            app.userObjects{idx}.makeProperties(app);
            Backups.CreateBackup(app); 
            GUI.RevertControlsStatus(app)

        end
        %% backups stuff
        
        function bck_objects = CreateObjectBackup(app)
           
            bck_objects = cell(length(app.userObjects), 1);
            
            for i = 1:length(app.userObjects)
                obj = app.userObjects{i};
                newObj  = UserObj();
                newObj.type     = obj.type;
                newObj.data     = [];
                newObj.points   = obj.points;
                newObj.name     = obj.name;
                newObj.imageIdx = obj.imageIdx;
                newObj.prop     = obj.prop;
                newObj.ID       = obj.ID;
                newObj.viewDim  = obj.viewDim;
                newObj.comment  = obj.comment;
                        
                bck_objects{i} = newObj;                
            end
            
        end
        
        function RestoreObjectBackup(app, objects)
            
            app.userObjects = cell(length(objects), 1);
            
            for i = 1:length(objects)
               
                app.userObjects{i} = objects{i};
                if objects{i}.type == 1 || objects{i}.type == 3
                    app.userObjects{i}.data = ...
                        ROI.PointsToMask(app, ...
                        objects{i}.points,...
                        objects{i}.imageIdx,...
                        objects{i}.type);
                end
            end
            
        end
        
        %% visibility & interaction
        
        
        function ToggleVisibleUO(app, varargin)
            %Toggles the visible status of the object

            if nargin == 1
                idx     = app.UOBox.Value;
                if isempty(idx)
                    return
                end
            else
                app = varargin{2};
                idx = varargin{3};
            end
            
            idx = Objects.findUOIndex(app, idx);
            
            visible = app.userObjects{idx}.visible;
            app.userObjects{idx}.setVisible(~visible)

            axID = find(app.imagePerAxis == ...
                app.userObjects{idx}.imageIdx);

            if ~visible
                Graphics.DrawROIInAxis(app, axID, app.userObjects{idx})
            else
                sz  = size(app.userObjects{idx}.data);
                sz(app.userObjects{idx}.viewDim) = [];
                set(app.UORenderer{axID}{app.userObjects{idx}.ID}, ...
                    'CData', zeros(sz(1), sz(2)));
                set(app.UORenderer{axID}{app.userObjects{idx}.ID}, ...
                    'AlphaData', zeros(sz(1), sz(2)));
            end
        end
                
        function UOId = FindUOUnderMouse(app, row, column, axID)
        %Checks all UOs to see which of them matches with the current
        %cursor position, view, slice etc. Returns the corresponding ID.
        
            UOId = -1;

            if column <= 0 || row <= 0
                return
            end
            
            if isnan(column) || isnan(row)
                return
            end
            
            %Get orientation info
            imID        = app.imagePerAxis(axID);
            ijk         = NiftiUtils.rc2ijk(app, row, column, axID);
             
            %Go over all UOs in reverse order
            for i = flip(1:length(app.userObjects))
                
                obj = app.userObjects{i};
                if obj.imageIdx ~= imID
                    continue
                end
                if  obj.deleted
                    continue
                end

                if ~strcmp(obj.profile, app.user_profile)
                    continue
                end
                
                if obj.type == 1 || obj.type == 3 || obj.type == 4
                    
                    try
                        maskVal = obj.data(end - ijk(2) + 1, ijk(1), ijk(3));
                    catch
                        return
                    end

                    if maskVal
                        UOId = obj.ID; 
                        return
                    end

                elseif obj.type == 2
                    
                    d = MathUtils.CalcDistancePointLine([column, row], ...
                        obj.points(1,:), obj.points(2,:));
                    
                    if d <= 5
                        UOId = obj.ID;
                        return
                    end                    
                end
                
            end
            
        end
        
    end
end