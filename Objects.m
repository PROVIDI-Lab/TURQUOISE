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
                    app.imagePerAxis(app.current_view);
            end
            if isempty(obj.name)
                obj.name        = ...
                    ['uObj' num2str(length(app.userObjects))];
            else
                obj.name    = Objects.CheckNameUnique(...
                    app, obj.name, obj.type);
            end
            if isempty(obj.ID)
                obj.ID          = length(app.userObjects) + 1;
            end
            
            %Calculate properties
            obj.makeProperties(app);
            %Add to list            
            app.userObjects{end+1}  = obj;
            GUI.UpdateUOBox(app);
            Graphics.UpdateUserObjects(app);
            Backups.CreateBackup(app);
        end
        
        function name = CheckNameUnique(app, name, ~)
            %Compares names between new object and existing objects.
            %In the case of identical names, adds a number to the end.           
            
            counter     = 0;
            for i = 1:length(app.userObjects)
                obj = app.userObjects{i};
                if obj.imageIdx ~= app.imIdx 
                    continue
                end
                %Very ugly way of removing any numbers from string.
                objName     = obj.name;
                for i=0:9
                    objName = strrep(objName, num2str(i), '');
                end
                if strcmp(objName, name)
                    counter = counter + 1;
                end              
            end
            if counter > 0
                name    = strcat(name, num2str(counter));
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
        
        function idx = FindUoForImage(app, imIdx)
            %Returns the index of the first uo with obj.imageIdx == imIdx
            %If none are found, returns -1
            idx = -1;
            
            for i = 1:length(app.userObjects)
                obj = app.userObjects{i};
                if obj.imageIdx == imIdx
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
        
        function EditUO(app)
            %When the edit menu in he UOBox contextmenu is called.
            idx     = app.UOBox.Value;
            if isempty(idx)
                return
            end
            
            idx = Objects.findUOIndex(app, idx);
            if idx == -1
                return
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
            points  = obj.points(:,1:2);
            
            %Hide contour
            app.userObjects{idx}.setVisible(false);
            
            %Create polygon with contextmenu
            ax = app.GetAxis(app.current_view);
            h = images.roi.Polygon(ax, 'Position', points);
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
            idx     = app.UOBox.Value;
            idx     = Objects.findUOIndex(app, idx);
            if idx == -1
                return
            end
            points  = polygon.Position;
            
            slice   = app.slicePerImage(app.imIdx);
            slice   = ones(size(points(:,1)))*slice;
            
            points  = [points, slice];
            app.userObjects{idx}.points = points;
            app.userObjects{idx}.makeProperties(app);
            
            %Create new contour
            app.userObjects{idx}.createMask(app)
            app.userObjects{idx}.set('changed', true);
            
            %turn contour back on
            app.userObjects{idx}.setVisible(true)
%             delete('app.userObjects{idx}.graphics')
            
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
            ax = app.GetAxis(app.current_view);
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
            
            view    = app.viewPerImage(app.imIdx);
            slice   = app.slicePerImage(app.imIdx);
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
            ax = app.GetAxis(app.current_view);
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
            
            view    = app.viewPerImage(app.imIdx);
            slice   = app.slicePerImage(app.imIdx);
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
            app.userObjects{idx}.setVisible(true);
            
            delete(roi)
            
        end
        
        
        
        
        %%
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
            
            app.userObjects(idx) = [];
            GUI.UpdateUOBox(app)
            Graphics.UpdateImage(app)
            Backups.CreateBackup(app); 
        end
        
        
        function RenameUO(app)
            %When the renamemenu in he UOBox conextmenu is called.
            idx     = app.UOBox.Value;
            if isempty(idx)
                return
            end
            idx = Objects.findUOIndex(app, idx);
            if idx == -1
                return
            end
            
            newName     = Interaction.PromptName(app);
            newName     = Objects.CheckNameUnique(app, newName, ...
                app.userObjects{idx}.type);
            app.userObjects{idx}.name   = newName{1};
            GUI.UpdateUOBox(app)
            Graphics.UpdateUserObjects(app)
            Backups.CreateBackup(app); 
        end
        
        function CopyUOTo(app)
            %When the copytoMenu in the UOBox contextmenu is called.
            idx         = app.UOBox.Value;
            if isempty(idx)
                return
            end
            idx = Objects.findUOIndex(app, idx);
            if idx == -1
                return
            end
            
            obj         = app.userObjects{idx};
            if obj.type == 2
                return %Don't copy measurements
            end
            currentIdx  = app.userObjects{idx}.imageIdx;
            targetIdx   = Interaction.PromptTarget(app);
            
            newMask     = Align.AlignMask(app.data{targetIdx},...
                            app.data{currentIdx},...
                            obj.data);                
            
            newMask( newMask >= 0.5) = 1;
            newMask( newMask < 0.5) = 0;
                        
            Objects.AddNewUserObj(app,...
                    "type", obj.type, ...
                    "data", newMask,...
                    "points", [], ... %TODO, copy points
                    "name", obj.name,...
                    "imageIdx", targetIdx)
                
            GUI.UpdateUOBox(app)
            Graphics.UpdateUserObjects(app)
            Backups.CreateBackup(app); 
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
        
        
        function ToggleVisibleUO(app)
            %Toggles the visible status of the object
            
            idx     = app.UOBox.Value;
            idx = Objects.findUOIndex(app, idx);
            
            visible = app.userObjects{idx}.visible;
            app.userObjects{idx}.setVisible(~visible)
        end
        
        function ToggleVisibleUOInfoBox(app, varargin)
            %Toggles the visible status of the infobox of the object
            
            if nargin == 1
                idx     = app.UOBox.Value;
            else
                idx   = varargin{1};
            end
            
            idx = Objects.findUOIndex(app, idx);
            
            if idx == -1    %UO has been deleted since
                return
            end
            
            boxVisible = app.userObjects{idx}.boxVisible;
            app.userObjects{idx}.setBoxVisible(~boxVisible)             
        end        
        
%         function UOId = FindUOClicked(app, hit)
%            %Called when the user right-clicks a UO. Tries to determine
%            %which is clicked.
%            
%            %TODO: add line
%            if isa(hit.Source, 'matlab.graphics.primitive.Text')
%                UOId = Objects.FindTextUO(app, hit);
%            elseif isa(hit.Source, 'matlab.graphics.chart.primitive.Contour')
%                UOId = Objects.FindContourUO(app, hit);
%            else
%                UOId = -1;
%            end
%         end
        
        function UOId = FindUOUnderMouse(app, hit, varargin)
           
            UOId = -1;
            
            hitx = round(hit.IntersectionPoint(1));
            hity = round(hit.IntersectionPoint(2));
            
            if isnan(hitx) || isnan(hity)
                return
            end
            
            if nargin == 2
                x   = round(hit.Point(1));
                if x <= hit.Source.Position(3)/2
                    view = 1;
                else
                    view = 2;
                end
            else
                view = varargin{1};
            end
            
            imID    = app.imagePerAxis(view);
            try
                slice   = app.slicePerImage(imID);
            catch
                return
            end
             
            %Go over all UOs in reverse order
            for i = flip(1:length(app.userObjects))
                
                obj = app.userObjects{i};
                if obj.imageIdx ~= imID
                    continue
                end
                if ~obj.visible
                    continue
                end
                
                if obj.type == 1 || obj.type == 3 || obj.type == 4
                    try
                        if obj.data(hity,hitx,slice)
                          UOId = obj.ID; 
                          return
                        end
                    catch
                        return
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
        
%         function UOId = FindTextUO(app, hit)
%             %Finds a userobject with a text graphics object.
%             UOId = -1;
%             name = hit.Source.String{1};
%             
%             for i = 1:length(app.userObjects)
%                 obj = app.userObjects{i};               
%                 if strcmp(obj.name, name)
%                    UOId = obj.ID; 
%                 end
%             end            
%         end
%         
%         function UOId = FindContourUO(app, hit)
%             %Finds a userobject with a contour graphics object.
%             UOId = -1;
%             contour = hit.Source.ContourMatrix;
%             
%             
%             %For each point in obj.points, check if it exists in the 
%             %contourmatrix. if so, that's the object. 
%             for i = 1:length(app.userObjects)
%                 obj = app.userObjects{i};   
%                 
%                 %if the obj doesn't have the right imageID, skip it
%                 Cv      = app.current_view;
%                 imID    = app.imagePerAxis(Cv);
%                 if obj.imageIdx ~= imID
%                     continue
%                 end
%                 
%                 %Compare points
%                 points = obj.points;
%                 hits = 0;
%                 for pointId = 1:size(points, 1)
%                     x = points(pointId, 1);
%                     y = points(pointId, 2);
%                     res = ...
%                         sum(sum(contour == x, 1) .* sum(contour == y, 1));
%                     if res == 0
%                         break
%                     else
%                         hits = hits + 1;
%                     end
%                 end
%                 
%                 if hits == size(points, 1)
%                     UOId = obj.ID;
%                 end                
%             end 
%         end
%         
        
    end
end