classdef Interaction < handle
    %This static class deals with user interaction. All interactions should
    %provide callbacks in the appdesigner code that then call functions in
    %this class. The functions here will then call functions in the other
    %classes to complete the user interaction.
    
    methods (Static)         
        function ChangeListBoxValue(app, index)
        %Changes the value of the AvailableImageListBox
            
            %Get the name of the file at the index
            name = app.AvailableimagesListBox.Items{index};
            app.AvailableimagesListBox.Value = name;
        end
        
        function ListBoxChanged(app)
            %Finds the new index of the AvailableImagesListBox and calls
            %functions to update the app acoordingly. 
            
            value = app.AvailableimagesListBox.Value;
            index = -1;
            for ij = 1:length(app.AvailableimagesListBox.Items)
                if(strcmp(app.AvailableimagesListBox.Items{ij},value) > 0)
                    index = ij;
                    break;
                end
            end
            
            if(index == -1)
                return
            end
            
            %Save current zoom. Used to store any changes made througout
            %the standard UI instead of ctrl+scroll.
            GUI.StoreZoomLevel(app)
            
            %Update app
            Study.SwitchImage(app, index)
        end
        
        function UOBoxChanged(app)
            %Called when the user selects one of the items in the ROIBox.
            %Finds the index of the selected value and switches the GUI to
            %the right slice & view.
            
            index   = app.UOBox.Value;
            
            if index <= 0
                return
            end
%             UOidx           = app.UOBox.ItemsData(index);

            %Find obj
            index = Objects.findUOIndex(app, index);
            if index == -1
                return
            end
            
            %Switch slice and view       
            obj                             = app.userObjects{index};
            [view, slice]                   = Objects.GetUOViewAndSlice(obj);    
            app.viewPerImage(app.imIdx)     = view;
            app.slicePerImage(app.imIdx)    = slice;
            
            GUI.UpdateSliceSlider(app)
            Graphics.UpdateImage(app)
            GUI.ResetAxisZoom(app)
            
            %Update GUI
            GUI.UpdateAxisButtons(app)
            %Update visible slider
            if obj.visible
                app.VisibleSlider.Value = 'On';
            else
                app.VisibleSlider.Value = 'Off';
            end
            
        end
        
        function AlgorithmChanged(app)
        %Sets the right algorithm selection   
        
            value = app.AlgorithmDropDown.Value;
            for ij=1:length(app.AlgorithmDropDown.Items)
                if(strcmp(value, app.AlgorithmDropDown.Items{ij}) > 0)
                    break
                end
            end
            app.drawing.magic_method = ij; 
        end
        
        
    %% UIAxes interactions
    
        function SwitchViewAndFocus(app,new_view_idx,~)
        % When switching to another view, store current properties for
        % later recalling them
        % Input: new_view_idx - idx of view that was pressed
        %        caller_name - object that was pressed, used to manage
        %        calling this function from unknown sources (not
        %        pre-defined).
        
            if isempty(app.studyNames)
                return
            end
        
            GUI.DisableAllButtonsAndActions(app);
            
            %Save current zoom. Used to store any changes made througout
            %the standard UI instead of ctrl+scroll.
            GUI.StoreZoomLevel(app)
            
            app.current_view    = new_view_idx;
                       
            %Switch to the correct image
            index   = app.imagePerAxis(new_view_idx);
            Study.SwitchImage(app, index)
            Interaction.ChangeListBoxValue(app, index)
            GUI.UpdateUOBox(app)
        end
        
        function MouseClickedInImage(app,hit)
            %Handles clicks in the image area. Calls functions depending on
            %the state of various buttons.
            %Input: hit - the location where the mouse was pressed.
            if isempty(app.data)
                return
            end
            if isempty(app.data{app.imIdx})
                return
            end
            if app.busyStatus   %Don't do anything if the app is busy
                return
            end
            
            %Check if the screen that was pressed is different from the
            %current view.
            if (hit.Source.Parent == app.UIAxes1                       ...
                    && app.current_view == 2)       ||                  ...
                (hit.Source.Parent == app.UIAxes2                       ...
                    && app.current_view == 1)       &&                  ...
                    hit.Button == 1
            
                    %Switch focus to the screen that was pressed
                    if(hit.Source.Parent == app.UIAxes1)
                        Interaction.SwitchViewAndFocus(...
                        app,1,'View1Button');
                    else
                        Interaction.SwitchViewAndFocus(...
                        app,2,'View2Button');
                    end
            end
            
            hitx = round(hit.IntersectionPoint(1));
            hity = round(hit.IntersectionPoint(2));
            
            if(app.should_show_selection == true)
                % Here we want to delete something by clicking
                Interaction.MouseDeleteObjectAtCoordinates(app,hitx,hity);
                
            elseif(app.drawing.mode == 1)
                % Here we are manually drawing an ROI
                if hit.Button == 1
                    ROI.AddPointToPolygon(app,hitx,hity);
                elseif hit.Button == 3
                    ROI.ValidateDrawingPoints(app);
                    app.drawing.mode                        = 0;
                    app.DrawPolygonButton.BackgroundColor   = ...
                                            [.96 .96 .96];
                    GUI.ResetCursor(app)
                end
                
%             elseif(app.drawing.mode == 2)
%                 %Here we want to drag a point
%                 ROI.StartDragging(app, hit)
            
            elseif(app.drawing.mode == 3)
                % Here we are adding a manual measurement
                Measurements.MouseMeasurementLines(app,hit,hitx,hity);
                
            elseif(app.drawing.mode == 4)
                % Here we are using the automatic ROI drawing
                Segmentation.MouseMagicDraw(app,hit,hitx,hity);            
            
            elseif hit.Button == 2
                %Here we adjust the contrast
                GUI.StartChangingContrast(app, hit)
                
            elseif hit.Button == 3
                %Here we open a contextmenu when clicking a UO
                id = Objects.FindUOUnderMouse(app, hit, app.current_view);                
                if id > 0
                    C = get(app.UIFigure, 'CurrentPoint');
                    GUI.UOContextMenu(app, id, C) 
                end
            end
            
            Graphics.UpdateUserInteractions(app)
            
        end
        
        function MouseReleasedInImage(app, hit)
        %When editing an ROIpoint, finalize the editing
            
            if app.busyStatus   %Don't do anything if the app is busy
                return
            end
        
%             if app.drawing.mode == 2
%                 %Change segmentation
%                 ROI.ValidateModifiedROIPoints(app)
%                 GUI.ResetCursor(app)
            if app.drawing.mode == 5
                ROI.FinishDrawingCircular(app)
            elseif app.drawing.mode == 6
                app.drawing.mode = 0;
            else
                return
            end
            
            app.currentDragPoint    = {};
            app.dragPoint           = [];
            app.currentCircle       = [];
            
            Graphics.UpdateImage(app)
            set(hit.Source,'WindowButtonUpFcn','')
%             GUI.SetButtonDownFcn(app)           
            end

        
        function MouseDraggedInImage(app, hit)
            %Triggers when the mouse moves in the image after the
            %windowbuttonmotionFCN has been set for the UIAxes elements.
            %Calls ROI.MoveROIPoint with the new position of the cursor 
            %relative to the top left corner with the scale of the image.
            if isempty(app.dragPoint) || isempty(app.currentDragPoint)
                
                GUI.MouseHover(app, hit)                
                return
            end
            
            if app.busyStatus   %Don't do anything if the app is busy
                return
            end
            
            hitx = round(hit.IntersectionPoint(1));
            hity = round(hit.IntersectionPoint(2));
            %Edit ROI
%             if app.drawing.mode == 2
%                 GUI.SetDragCursor(app)
%                 ROI.MoveROIPoint(app, [hitx, hity])
            %Circular ROI
%             if app.drawing.mode == 5
%                 ROI.DrawCircularROI(app, [hitx, hity])
            if app.drawing.mode == 6
                GUI.AdjustContrast(app, hitx, hity)
            end            
        end
        
        %% Keypresses
        
        function UIKeyPress(app, event)
        % Manages keypresses when UIAxes are in focus
        
            key         = event.Key;
            modifier    = event.Modifier;    
            
            if app.busyStatus   %Don't do anything if the app is busy
                %Only allow ctrl+escape to break
                if strcmp(key, 'escape') 
                    GUI.RevertControlsStatus(app)
                end
                return
            end
            
            if isempty(modifier)
                switch key
                    case 'uparrow'
                        GUI.SliceUp(app)
                    case 'downarrow'
                        GUI.SliceDown(app)
                    case 'backspace'
                        Interaction.BackspacePressed(app)
                    case 'h'
                        GUI.ResetAxisZoom(app)
                    case 'd'
                        Interaction.DrawPolygon(app)
                    case 'z'
                        Interaction.ToggleZoom(app)
%                     case 'e'
%                         Interaction.EditPolygon(app)
                    case 'v'
                        Interaction.showADCHist(app)
                    case 'control'
                        app.ctrl    = true;
                    case 'f12'
                        Interaction.Debug(app)
                end
                
            elseif contains(modifier, 'control')
                
                switch key
                    case 'control'
                        app.ctrl    = true;
                    case 'o'
                        Interaction.LoadStudy(app)
                    case 's'
                        Interaction.Save(app)
                    case 'z'
                        Backups.Undo(app)
                    case 'y'
                        Backups.Redo(app)
                    case 'f2'
                        Interaction.Reload(app)
                end
            end
        end
        
        function UIKeyRelease(app, event)
        % Manages keypresses when UIAxes are in focus
            
            if app.busyStatus   %Don't do anything if the app is busy
                return
            end
        
            key     = event.Key;
            if isempty(app.data)
                return
            end
            
            switch key
                case 'control'
                    app.ctrl    = false;
                otherwise
                    return
            end
        end
        
        function BackspacePressed(app)
        %Remove the last points in app.drawing
            
            Cv = app.current_view;
            if isempty(app.points)
                return
            end
            if isempty(app.points{Cv})
                return
            end
            
            app.points{Cv}(end, :) = [];
            Graphics.UpdateImage(app);
            
        end
        
        function ToggleZoom(app)
            %Toggle the zoom function of the current UIAxes.
            ax  = [app.UIAxes1, app.UIAxes2];
            ax  = ax(app.current_view);            
            
            if app.zoomToggle
                zoom(ax, 'off')
                app.zoomToggle = false;
            else
                zoom(ax, 'on')
                app.zoomToggle = true;
            end            
        end
        
        %%
        
        function MouseDeleteObjectAtCoordinates(app,hitx,hity)
            %This handles the deletion of objects when the mouse is pressed
            %at the object location. Measurements have priority over
            %segmentation when deleting objects. 
            %
            %Input: hitx - the x-coordinate of the mouse
            %       hity - the y-coordinate of the mouse
            
            return
            
%             %Remove any previous deletion contours.
%             if(app.selection_contour ~= -1)
%                 delete(app.selection_contour);
%                 app.selection_contour = -1;
%             end
%             
%             %Find the object type to be deleted. Either Measurement or ROI.
%             [delOb, ij, meas] = Study.FindObjectTypeAtPos(app, hitx, hity);
%             
%             %Remove the objects
%             if(delOb == 1)
%                 ROI.RemoveSegmentation(app, ij)
%             elseif(delOb == 2)
%                 Measurements.RemoveMeasurement(app, meas)
%             end
%             
%             if delOb ~= 0
%                app.should_show_selection = false;
%             end
%             
%             %Create backup
%             Backups.CreateBackup(app);
        end       
        
        
        %% UI buttons
        
        function ChangeViewAxis(app, viewAxis)
        %Switches viewAxis of the current UIAxis to the specified one
        %coronal = 1, sagittal = 2, axial = 3
            app.viewPerImage(app.imIdx) = viewAxis;
%             if(app.current_slice > size(app.data{app.imIdx}.img,3))
%                 app.current_slice =...
%                     round(size(app.data{app.imIdx}.img,3)/2);
%             end
            GUI.UpdateSliceSlider(app)
            Graphics.UpdateImage(app)
            GUI.UpdateAxisButtons(app)
            GUI.ResetAxisZoom(app)
        end
        
        function ResetStudy(app)
        %Removes the entire .rmsstudio folder
            GUI.DisableControlsStatus(app);
            app.UIFigure.Visible = 'off';
            drawnow;
            answer = questdlg(...
                'This will reset this study folder, are you sure?', ...
               	'Study reset', ...
               	'Yes','No','No');
            if(strcmp(answer,'Yes') > 0)
                delete(fullfile(app.current_folder,'*rmsstudio*'));
            else
                GUI.RevertControlsStatus(app);
            end
            GUI.DisableAllButtonsAndActions(app);
            app.UIFigure.Visible = 'on';
        end
        
        function DeleteROIsAndMeasurements(app)
        % Removes any measurements and segmentations stored in the current
        % image. 
        
            %Remove measurements
            Measurements.RemoveAllMeasurements(app);
            %Remove ROIs
            ROI.RemoveAllROIs(app);
            GUI.UpdateUOBox(app);
            Graphics.UpdateImage(app);
            
            %Create backup
            Backups.CreateBackup(app);
        end
        
        function LoadStudy(app)
           %Checks whether unsaved work exists. If so, prompts the user to
           %save. 
           
           if app.unsavedProgress
               proceed = Interaction.PromptSave(app);
               if ~proceed
                   return
               end
           end
           GUI.DisableControlsStatus(app)
           IOUtils.PrepareStudy(app)
           GUI.RevertControlsStatus(app)
            
        end
        
        function Reload(app)
            GUI.DisableControlsStatus(app)
            IOUtils.PrepareStudy(app, app.filepath)
            GUI.RevertControlsStatus(app)            
        end
        
        function Save(app)
        %Called when the user presses the 'save_edited' button. Writes the
        %segmentation to the disk as well as any measurements and ROI
        %properties.
        %Input:
        %   app - the RMSstudio app
        %
            if isempty(app.studyNames)
                return
            end
            GUI.DisableControlsStatus(app)
            Study.SaveToDisk(app)
            Study.ToggleUnsavedProgress(app, false);
            GUI.RevertControlsStatus(app)
        end
        
        function Exit(app)
            if app.unsavedProgress
               proceed = Interaction.PromptSave(app);
               if ~proceed
                   return
               end
            end
                       
            closereq
        end
           
            
        
        function LoadNewLabels(app)
            %Loads a new segmentation for the current image.
            defPath         = strcat(app.filepath, "\.rmsstudio");
            [file, path]    = uigetfile('*.nii',                        ...
                                'Load Segmentation',                    ...
                                defPath);
            fp              = fullfile(path, file);
            if ~exist(fp)
                return
            end
            
            IOUtils.LoadSegmentation(app, fp, app.imIdx);  
            GUI.UpdateUOBox(app)
            
            %Switch to new labels
            items   = app.UOBox.Items;
            app.UOBox.Value    = length(items) - 1;
            Interaction.UOBoxChanged(app);
        end
        
        function LoadROIPoints(app)
        %Loads a new segmentation for the current image.
            defPath         = strcat(app.filepath, "\.rmsstudio");
            [file, path]    = uigetfile('*.json',                       ...
                                'Load ROI points',                      ...
                                defPath);
            fp              = fullfile(path, file);
            
            IOUtils.loadSegmentationPoints(app, fp, app.imIdx);  
            Graphics.UpdateImage(app);
        end
        
        function DrawPolygon(app)
            %Called when the user presses the 'draw polygon' button.
            
            if isempty(app.data{app.imIdx})
                return
            end
            
            if(app.drawing.mode ~= 1)
                app.drawing.mode = 1;
                app.DrawPolygonButton.BackgroundColor = [.96 .96 0];
                GUI.SetDrawCursor(app)
            else
                app.drawing.mode = 0;
                app.DrawPolygonButton.BackgroundColor = [.96 .96 .96];
                GUI.ResetCursor(app)
                Graphics.UpdateImage(app);
            end
            Graphics.UpdateImage(app);
            Graphics.UpdateSelectionContour(app); 
        end
        
        function CircularROI(app)
        %Prepares drawing a Circular ROI
            if isempty(app.data{app.imIdx})
                return
            end
            ROI.StartDrawingCircular(app);    
        end
        
        function EllipseROI(app)
        %Prepares drawing a Circular ROI
            if isempty(app.data{app.imIdx})
                return
            end
            ROI.StartDrawingEllipse(app);    
        end
        
        
        function PerformAutomaticEllipseMeasurement(app)
            % Called when the user presses the 'measure auto' button.
            
            Measurements.PerformAutomaticEllipseMeasurement(app)
        end
        
        function MeasureLine(app)
        %Toggles 
            if(app.drawing.mode ~= 3)
                app.drawing.mode    = 3;
            else
                app.drawing.mode    = 0;
                app.points{app.current_view}      = [];
            end 
        end
        
        function MagicDraw(app)
            %Called when the user presses the 'magic draw' button.
            if(app.drawing.mode ~= 4)
%                 app.MagicdrawButton.BackgroundColor = [.96 .96 0];
                app.drawing.mode = 4;
            else
                app.drawing.mode = 0;
            end
            Graphics.UpdateImage(app);
            Graphics.UpdateSelectionContour(app); 
        end
        
        
        function AlignLeftRight(app, alignment)
            %Switches the alignment between the two views 
            
            if isempty(app.Align)
                app.Align = '';
            end
            
            %Turn off alignment when pressing on the same button
            if strcmp(alignment, app.Align)
                app.Align = '';
            else
                app.Align = alignment;
            end
            
            GUI.UpdateAlignButtons(app)
        end
        
        function choice = RegisterSelectedImageToDialog(app)
            %Called when the user presses the 'align labels' button. 
            %Prompts the user for an image to which the current labels 
            %should be registered, then registers them.
            
            IOUtils.SaveSegmentations(app);
            
            GUI.DisableControlsStatus(app);
            app.UIFigure.Visible = 'off';
            drawnow;
            
            d = dialog('Position',                                      ...
                       [300 300 250 150],                               ...
                       'Name',                                          ...
                       'Select Target');
            txt = uicontrol('Parent',d,                                 ...
                'Style','text',                                         ...
                'Position',[20 80 210 40],                              ...
                'String','Select the registration target');
            
            popup = uicontrol('Parent',d,                               ...
                'Style','popup',                                        ...
                'Position',[75 70 100 25],                              ...
                'String',app.studyNames,              ...
                'Callback',@popup_callback);
            
            btn = uicontrol('Parent',d,                                 ...
                'Position',[89 20 70 25],                               ...
                'String','Align!',                                      ...
                'Callback','delete(gcf)');
            
            choice = app.studyNames{1};
            
            % Wait for d to close before running to completion
            uiwait(d);
            app.UIFigure.Visible = 'on';
            GUI.RevertControlsStatus(app);
            
            function popup_callback(popup,event)
                idx = popup.Value;
                popup_items = popup.String;
                % This code uses dot notation to get properties.
                % Dot notation runs in R2014b and later.
                % For R2014a and earlier:
                % idx = get(popup,'Value');
                % popup_items = get(popup,'String');
                choice = char(popup_items(idx,:));
                delete(gcf);
                app.UIFigure.Visible = 'on';
                drawnow
                MathUtils.PerformElastixRegistration(app,choice);
            end
        end
        
        function UpdateSlice(app, value, axID)
        %Sets the current_slice to the new value, then updates the GUI
        %Input:
        %   value - new value for current_slice
            slice = round(value);
            imID    = app.imagePerAxis(axID);
            
            if isempty(app.data{imID})
                return
            end
            
            imgSize = size(app.data{imID}.img);
            %Limit the value between 1 and max
            if(slice < 1)
                slice = 1;
            end
            %TODO: view_axis per image
            if(slice > imgSize(app.viewPerImage(imID))) 
                slice = imgSize(app.viewPerImage(imID));
            end
            
            app.slicePerImage(imID)   = slice;
            
            %Update the GUI
            if axID == app.current_view
                GUI.UpdateSliceSlider(app)
            end
            Graphics.UpdateImageForAxis(app, axID);
            Graphics.UpdateSelectionContour(app);
        end
        
        
        function Update4D(app, value)
            %Updates the 4D axis for the current image
            max4D   = size(app.data{app.imIdx}.img, 4);
            min4D   = 1;
            if value > max4D
                value   = max4D;
            elseif value < min4D
                value   = min4D;
            end 
            
            app.d4PerImage(app.imIdx)   = value;
            GUI.Update4DSlider(app);
            Graphics.UpdateImage(app);
            Graphics.UpdateSelectionContour(app);   
        end
        %% Prompts
        
        function choice = PromptName(app)
            %Called when the user finishes drawing an ROI or measurement.
            %Prompts them for a name that is either in the selection box or
            %a custom one.
            
            C = get(app.UIFigure, 'CurrentPoint');
            P0 = app.UIFigure.Position;
            x = C(1) + P0(1);
            y = round(P0(4)/2);
            
            d = dialog('Position',[x y 250 150],'Name','Select One');
            txt = uicontrol('Parent',d,...
                   'Style','text',...
                   'Position',[20 80 210 40],...
                   'String','Name of the measurement / ROI');

            popup = uicontrol('Parent',d,...
                   'Style','popup',...
                   'Position',[75 70 100 25],...
                   'String',{   'Whole Tumor';...
                                'Viable Tumor';...
                                'Necrosis';...
                                'Cyste';...
                                'Hemorrhage';...
                                'Circle';...
                                'Circle small';...
                                'Other'},...
                   'Callback',@popup_callback);

            btn = uicontrol('Parent',d,...
                   'Position',[89 20 70 25],...
                   'String','Select',...
                   'Callback',@select);
            
            %Default
            choice = {};
               
            % Wait for d to close before running to completion
            uiwait(d);

                function popup_callback(popup,event)
                   idx = popup.Value;
                   popup_items = popup.String;
                   res = char(popup_items(idx,:));
                  
                   if strcmp(res, 'Other') == 1
                       choice = inputdlg("Enter measurement / ROI name");
                       delete(gcf)
                   else
                       choice = {res};
                   end
                end
               
                function select(btn, event)
                   popupItem  = btn.Parent.Children(2);
                   idx  = popupItem.Value;
                   res  = char(popupItem.String(idx,:));

                   choice = {res};
                   delete(gcf);

                end
        end
        
        function PromptProfile(app, varargin)
            %Called when the user launches the app for the first time. Asks
            %them for a profile name to be used in separating the
            %segmentations.
            
            %If a filepath is given, first check if a list with profile
            %names already exists.
            
            if app.unsavedProgress
               proceed = Interaction.PromptSave(app);
               if ~proceed
                   return
               end
            end
            
            profile = '';
            
%             if nargin() == 2
%                 file    = fullfile(varargin, 'profiles.txt');
%                 file    = file{1};
%                 if exist(file, 'file') == 2
%                     fileID  = fopen(file,    'r');
%                     names   = {};
%                     name    = fgetl(fileID);
%                     while name ~= -1
%                         names{end+1}    = name;
%                         name    = fgetl(fileID);
%                     end
%                     fclose(fileID);
%                     names{end+1}        = 'Other';
%                     
%                     d = dialog('Position',[300 300 250 150],'Name',     ...
%                         'Select One');
%                     txt = uicontrol('Parent',d,...
%                            'Style','text',...
%                            'Position',[20 80 210 40],...
%                            'String','Choose profile name');
% 
%                     popup = uicontrol('Parent',d,...
%                            'Style','popup',...
%                            'Position',[75 70 100 25],...
%                            'String',names,    ...
%                            'Callback',@popup_callback);
% 
%                     btn = uicontrol('Parent',d,...
%                            'Position',[89 20 70 25],...
%                            'String','Select',...
%                            'Callback','delete(gcf)');
% 
%                    %Default
%                     profile = names{1};
%                     
%                     uiwait(d);
% 
%                 else
%                     %A path is specified but not file exists.
%                     
%                     %prompt for profile and write to file.
%                     profile = inputdlg("Enter profile name");
% %                     profile = upper(profile);      
%                     fid     = fopen(file, 'wt');
%                     fprintf(fid, strcat(profile{1}, '\n'));
%                     fclose(fid);
%                     
%                 end
%             else
            %If no filepath is given, prompt for the profile and don't do
            %anything else.
            profile = inputdlg(['Enter profile name.' newline       ...
            '(We suggest the first three letters of your name']);
            if isempty(profile)
                profile = '';
            else
                profile = profile{1};
            end
%             end
            
            %Add the profile to the app
            profile  = upper(profile);
            
            %Add to app
            if strcmp(app.user_profile, profile)
                return
            end
            app.user_profile    = profile;
            app.backup_list     = [];
            
            %Reload everything
            Study.InitStudy(app)
            
            
%             %When the file exists, but 'other' is chosen, prompt for new
%             %profile name and add it to the file.
%             function popup_callback(popup, event)
%                 idx = popup.Value;
%                 popup_items = popup.String;
%                 res = char(popup_items(idx,:));
% 
%                 if strcmp(res, 'Other') == 1
%                   profile = inputdlg("Enter profile name");
%                   profile  = upper(profile);
%                   
%                   fid   = fopen(file, 'a+');
%                   fprintf(fid, strcat(profile{1}, '\n'));
%                   fclose(fid);
%                   
%                   delete(gcf)
%                   
%                 else
%                   profile = {res};
%                 end
%             end
        end
        
        
        function choice = PromptTarget(app)
            %Called when the user copies a UserObject. The user is prompted
            %to which image the object should be copied. 
                        
            d = dialog('Position',[300 300 250 150],'Name','Select One');
            txt = uicontrol('Parent',d,...
                   'Style','text',...
                   'Position',[20 80 210 40],...
                   'String','Copy to which image');

            popup = uicontrol(...
                   'Parent',    d,...
                   'Style',     'popup',...
                   'Position',  [75 70 100 25],...
                   'String',    app.studyNames,...
                   'Callback',  @popup_callback);

            btn = uicontrol('Parent',d,...
                   'Position',[89 20 70 25],...
                   'String','Select',...
                   'Callback',@select);
            
            %Default
            choice = {};
               
            % Wait for d to close before running to completion
            uiwait(d);

                function popup_callback(popup,event)
                   choice = popup.Value;
                end
               
                function select(btn, event)
                   popupItem  = btn.Parent.Children(2);
                   choice  = popupItem.Value;
                   delete(gcf);
                end
        end
        
        
        function proceed = PromptSave(app)
            
            selection = questdlg('You have unsaved work. Save?',...
              'Save?',...
              'Yes','No','Cancel','Cancel'); 
            app.UIFigure.Visible = 'off';
            app.UIFigure.Visible = 'on';
            proceed = false;
            switch selection
              case 'Yes'
                 Interaction.Save(app)
                 proceed = true;
              case 'No'
                 proceed = true;
              case 'Cancel'
                 proceed = false;
            end            
        end
        
        
        %% Other
        
        function ShuffleColors(app)
        %Shuffles the colors of the measurements & segmentations
            IX = randperm(size(app.colors_list,1));
            app.colors_list = app.colors_list(IX,:);
            Graphics.UpdateImage(app);
            Graphics.UpdateSelectionContour(app);
        end
        
        function Debug(app)
            %Used for quick access to the app state
            disp('Debugging, press "continue"')
            a = 12;
        end
        
        function showADCHist(app)
            
            img = app.data{app.imIdx}.img;
            total_mask = permute(zeros(size(img)),[2,1,3]);
            
            names = containers.Map;
            
            for i = 1:length(app.userObjects)
               uo = app.userObjects{i};
               if uo.imageIdx ~= app.imIdx
                   continue
               end

               tmp_mask = uo.data;
               if ~all(size(total_mask) == size(uo.data))
                   minx = min(size(tmp_mask,1), size(total_mask,1));
                   miny = min(size(tmp_mask,2), size(total_mask,2)); 
                   
                   tmp_mask = zeros(size(total_mask));
                   tmp_mask(1:minx, 1:miny, :) = uo.data(1:minx, 1:miny, :);
               end

               if contains(uo.name, 'Whole Tumor')
                   total_mask = total_mask + tmp_mask;
               else
                   total_mask = total_mask - tmp_mask;
               end
               
               [~,~,z] = ind2sub(size(uo.data), find(uo.data));                
               names(uo.name) = mode(z);
            end

            total_mask(total_mask > 1) = 1;
            total_mask(total_mask < 0) = 0;
            
            tmp = Interaction.overlayMask(img, total_mask);
            if mean(tmp(:)) > 500
                img = img / 1000;
            elseif mean(tmp(:)) < 0.5
                img = img * 1000;
            end

            %apply mask tot ADC
            adc_list = Interaction.overlayMask(img, total_mask);
            
            z = cell2mat(names.values);
            z = z(strcmp(names.keys, 'Whole Tumor'));
            if isempty(z)
                z = cell2mat(names.values);
                z = z(strcmp(names.keys, 'Whole Tumor1'));
            end            
            
            figure
            subplot(2,1,1)
            histogram(adc_list)
            subplot(2,1,2)
            imshowpair(img(:,:,z),total_mask(:,:,z))
            
        end
        
        function values = overlayMask(im, mask)
           
            %Overlays mask over image, takes into account different shapes
            minx = min(size(im,1), size(mask,1));
            miny = min(size(im,2), size(mask,2));
            
            newMask = mask(1:minx, 1:miny, :);
            newIm   = im(1:minx, 1:miny, :);
            
            values = newIm(newMask == 1);            
        end
        
        function PermuteFlip(app)
            
                img = app.data{app.imIdx};
                img = permute(img.img, [2,1,3]);
                img = flip(img, 1);
                img = flip(img, 2);
                
                app.data{app.imIdx}.img = img;
                Graphics.UpdateImage(app)
            
        end
        
        function FlipZ(app)
            img = app.data{app.imIdx};
            img = flip(img.img, 3);

            app.data{app.imIdx}.img = img;
            Graphics.UpdateImage(app)
        end
        
        function FlipXYObj(app)
            
            for i = 1:length(app.userObjects)
                img = app.userObjects{i}.data;                
    %             img = app.data{app.imIdx};
%                 img = permute(img, [2,1,3]);
                img = flip(img, 1);
                img = flip(img, 2);
                
                app.userObjects{i}.data = img;
            end
            Graphics.UpdateImage(app)
        end
        
        function HideAllTooltips(app)
           
            
            for i = 1:length(app.userObjects)
                app.userObjects{i}.setBoxVisible(false) 
            end
%             Graphics.UpdateImage(app)            
            
        end
            
            
        function PermuteFlipUOs(app)
            
            for i = 1:length(app.userObjects)
                img = app.userObjects{i}.data;                
            
    %             img = app.data{app.imIdx};
                img = permute(img, [2,1,3]);
%                 img = flip(img, 1);
%                 img = flip(img, 2);
                
                app.userObjects{i}.data = img;
            end
            Graphics.UpdateImage(app)
            
        end
        
        
        
        
        
        
        
    end
end