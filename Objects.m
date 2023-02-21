classdef Objects < handle
    methods (Static)
        
        function AddNewUserObj(app, varargin)
            obj         = UserObj();
            
            %very hacky way to assign properties.
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
            if isempty(obj.viewDim)
                obj.viewDim     = NiftiUtils.FindViewingDimension(...
                    app, obj.imageIdx);
            end
            if isempty(obj.comment)
                obj.comment = '';
            end

            
            %Calculate properties
            obj.makeProperties(app);
            %Add to list            
            app.userObjects{end+1}  = obj;
            GUI.UpdateUOBox(app);
            GUI.AddUOLayer(app, 1, obj.ID)      %TOOD: don't hardcode axes
            GUI.AddUOLayer(app, 2, obj.ID)  
            Graphics.UpdateUserObjects(app);
            Backups.CreateBackup(app);
        end

        function name = CheckNameUnique(app, name, idx)
            %Compares names between new object and existing objects.
            %In the case of identical names, adds a number to the end.           
            
            names = Objects.GetAllUOsForImage(app, idx);
            uniqueName = true;
            counter = 0;
            for i = 1:length(names)
                objName = names{i};
                
                if contains(objName, name)
                    if strcmp(objName, name)
                        uniqueName = false;
                    end
                    counter = counter + 1;
                end                
            end

            if uniqueName
                return
            end

            %name not unique, add number before mode signifier
            baseName   = name(1:end-2);
            modeSig    = name(end-1:end);
            name    = strcat(baseName, num2str(counter), modeSig);
        end

        function AddToUO(app, ID)
            %Adds points & data to existing ROI. 
            obj         = app.userObjects{ID};
            obj.points  = [obj.points; app.points{app.axID}];
            obj.data    = obj.data + ROI.PointsToMask(...
                app, app.points{app.axID}, app.imagePerAxis(app.axID), 1);
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
            obj.changed     = true;

            GUI.UpdateUOBox(app)
            Graphics.UpdateUserObjects(app)
        end

        function names = GetAllUOsForImage(app, index)
            names = {};
            for i = 1:length(app.userObjects)
                obj = app.userObjects{i};
                if obj.imageIdx ~= index || obj.deleted
                    continue
                end
                names{end+1} = obj.name;
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
            if ~isempty(obj.data)
                [x,y,z]     = ind2sub(size(obj.data),find(obj.data == 1));
            else
                x   = obj.points(:,1); 
                y   = obj.points(:,2); 
                z   = obj.points(:,3); 
            end
            %Find most occurring value
            [Mx, Fx]    = mode(x);
            [My, Fy]    = mode(y);
            [Mz, Fz]    = mode(z);
            
            [~,  view]  = max([Fx, Fy, Fz]);
            
            modes       = [Mx, My, Mz];
            slice       = modes(view);
        end
        
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

            %select only points from the current slice
            slice = app.slicePerImage{obj.imageIdx}{obj.viewDim};
            slcPoints = points(points(:,obj.viewDim) == slice, :);
            slcPoints(:,obj.viewDim) = [];
            
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

            newPoints  = polygon.Position;
            
            view    = app.userObjects{idx}.viewDim;
            slice   = app.slicePerImage{app.imID}{view};            
            newPoints  = [newPoints, ones(size(newPoints(:,1)))*slice];
            newPoints  = round(newPoints);

            %first remove all the old points
            sliceIdx = app.userObjects{idx}.points(:, view) == slice;
            app.userObjects{idx}.points(sliceIdx, :) = [];
            app.userObjects{idx}.points = ...
                [app.userObjects{idx}.points; newPoints];
            app.userObjects{idx}.makeProperties(app);
            
            %Create new mask
            app.userObjects{idx}.createMask(app)
            app.userObjects{idx}.set('changed', true);
            
            %turn mask back on
            app.userObjects{idx}.setVisible(true)
            
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
            app.userObjects{idx}.set('changed', true);
            
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
            app.userObjects{idx}.set('changed', true);
            
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
            
            idx = Objects.findUOIndex(app, idx);
            if idx == -1
                return
            end
            
            %delete / change properties
            app.userObjects{idx}.deleted = true;
            app.userObjects{idx}.editing = false;
            app.userObjects{idx}.renaming = true;
            app.userObjects{idx}.data = [];
            app.userObjects{idx}.points = [];
            app.userObjects{idx}.prop = [];

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
            if obj.type == 2
                return %Don't copy measurements
            end
            
            targetIdx   = Interaction.PromptTarget(app);
            
            %find new points from world coordinates
            tm  = app.transMatPerImage{targetIdx};
            xyz = [obj.worldCoords, ones(length(obj.points),1)];
            ijk = tm \ xyz';
            points = round(ijk(1:3, :))';
            %create mask
            newMask = ROI.PointsToMask(app, points, targetIdx, obj.type);
                        
            Objects.AddNewUserObj(app,...
                    "type", obj.type, ...
                    "data", newMask,...
                    "points", points, ... 
                    "worldCoords", obj.worldCoords, ...
                    "name", obj.name,...
                    "imageIdx", targetIdx)
                
            GUI.UpdateUOBox(app)
            Graphics.UpdateUserObjects(app)
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
            comment = inputdlg('','Add comment', [3 50], {prevComment});

            if ~isempty(comment)
                app.userObjects{idx}.comment = comment;
            end

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
            Graphics.UpdateUserObjects(app)
        end
                
        function UOId = FindUOUnderMouse(app, hit, varargin)
        %Checks all UOs to see which of them matches with the current
        %cursor position, view, slice etc. Returns the corresponding ID.
        
            UOId = -1;
            
            hity = round(hit.IntersectionPoint(1));
            hitx = round(hit.IntersectionPoint(2));
            
            if isnan(hitx) || isnan(hity)
                return
            end

            if nargin == 2  %Find UIaxes
                x   = round(hit.Point(1));
                if x <= hit.Source.Position(3)/2
                    axID = 1;
                else
                    axID = 2;
                end
            else
                axID = varargin{1};
            end
            

            xyz     = NiftiUtils.hitToXYZ(app, hitx, hity, axID);
            imID    = app.imagePerAxis(axID);
            tm      = app.transMatPerImage{imID};
            ijk     = NiftiUtils.xyz2ijk(tm, xyz);

            %Remove relative viewing axis
            viewDim         = NiftiUtils.FindViewingDimension(app, imID);
            slice           = ijk(viewDim);
            ijk(viewDim)    = [];

             
            %Go over all UOs in reverse order
            for i = flip(1:length(app.userObjects))
                
                obj = app.userObjects{i};
                if obj.imageIdx ~= imID
                    continue
                end
                if  obj.deleted
                    continue
                end
                
                if obj.type == 1 || obj.type == 3 || obj.type == 4
                    
                    if(viewDim == 3)
                        maskSlc = obj.data(:,:,slice);
                    elseif(viewDim == 2)
                        maskSlc = obj.data(:,slice,:);
                        maskSlc = permute(squeeze(maskSlc),[2,1]);
                    elseif(viewDim == 1)
                        maskSlc = obj.data(slice,:,:);
                        maskSlc = permute(squeeze(maskSlc),[2,1]);
                    end

                    try
                        if maskSlc(ijk(1), ijk(2))
                            UOId = obj.ID; 
                            return
                        end
                    catch
                        continue
                    end

                elseif obj.type == 2
                    
                    d = MathUtils.CalcDistancePointLine([hitx, hity], ...
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