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
            obj             = app.userObjects{index};
            [view, slice]   = GUI.GetUOViewAndSlice(obj);    
            
            %Switch slice and view            
            app.viewPerImage(app.imIdx)     = view;
            app.slicePerImage(app.imIdx)    = slice;
            
            GUI.UpdateSliceSlider(app);
            Graphics.UpdateImage(app);
            
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
    
        function SwitchViewAndFocus(app,new_view_idx,caller_name)
        % When switching to another view, store current properties for
        % later recalling them
        % Input: new_view_idx - idx of view that was pressed
        %        caller_name - object that was pressed, used to manage
        %        calling this function from unknown sources (not
        %        pre-defined).
        
            GUI.DisableAllButtonsAndActions(app);
            GUI.RevertControlsStatus(app);
            prev_view           = app.current_view;
            app.current_view    = new_view_idx;
                      
            app.View1Button.BackgroundColor = [.96 .96 .96];
            app.View2Button.BackgroundColor = [.96 .96 .96];
            
            eval(['app.' caller_name '.BackgroundColor = [.96 .96 .0];']);
                       
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
            %Check if the screen that was pressed is different from the
            %current view.
            if( (hit.Source.Parent == app.UIAxes1                       ...
                    && app.current_view == 2)       ||                  ...
                (hit.Source.Parent == app.UIAxes2                       ...
                    && app.current_view == 1)   )
            
                    %Switch focus to the screen that was pressed
                    Backups.CreateBackup(app);
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
                end
                
            elseif(app.drawing.mode == 2)
                %Here we want to drag a point
                ROI.StartDragging(app, hit)
            
            elseif(app.drawing.mode == 3)
                % Here we are adding a manual measurement
                Measurements.MouseMeasurementLines(app,hit,hitx,hity);
                
            elseif(app.drawing.mode == 4)
                % Here we are using the automatic ROI drawing
                Segmentation.MouseMagicDraw(app,hit,hitx,hity);
            
            elseif app.drawing.mode == 5
                %Here we are drawing a circular ROI
                ROI.StartDrawingCircular(app, hit);                
            
            elseif hit.Button == 2
                %Here we adjust the contrast
                GUI.StartChangingContrast(app, hit)
            end
            
            Graphics.UpdateUserInteractions(app)
            
        end
        
        function MouseReleasedInImage(app, hit)
        %When editing an ROIpoint, finalize the editing
            if app.drawing.mode == 2
                %Change segmentation
                ROI.ValidateModifiedROIPoints(app)
            elseif app.drawing.mode == 5
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
            set(hit.Source,...
                    'WindowButtonMotionFcn',...
                    '')
            set(hit.Source,...
                    'WindowButtonUpFcn',...
                    '')
            GUI.SetButtonDownFcn(app)           
            end

        
        function MouseDraggedInImage(app, hit)
            %Triggers when the mouse moves in the image after the
            %windowbuttonmotionFCN has been set for the UIAxes elements.
            %Calls ROI.MoveROIPoint with the new position of the cursor 
            %relative to the top left corner with the scale of the image.
            if isempty(app.dragPoint)
                return
            end
            disp(hit.IntersectionPoint)
            hitx = round(hit.IntersectionPoint(1));
            hity = round(hit.IntersectionPoint(2));
            %Edit ROI
            if app.drawing.mode == 2
                ROI.MoveROIPoint(app, [hitx, hity])
            %Circular ROI
            elseif app.drawing.mode == 5
                ROI.DrawCircularROI(app, [hitx, hity])
            elseif app.drawing.mode == 6
                GUI.AdjustContrast(app, hitx, hity)
            end
            
        end
        
        %% Keypresses
        
        function UIKeyPress(app, event)
        % Manages keypresses when UIAxes are in focus
            
            key     = event.Key;
            if isempty(app.data)
                return
%             elseif(~isfield(app.data{app.imIdx},'img') ||...
%                     isempty(app.data{app.imIdx}.img))
%                 return
            end
            if(strcmp(key,'uparrow'))
                GUI.SliceUp(app)
            elseif(strcmp(key,'downarrow'))
                GUI.SliceDown(app)
            elseif(strcmp(key, 'backspace'))
                Interaction.BackspacePressed(app)
            elseif(strcmp(key, 'z'))
                Interaction.ToggleZoom(app)
            elseif(strcmp(key, 'h'))
                GUI.ResetAxisZoom(app)
            elseif(strcmp(key, 'control'))
                app.ctrl    = true;
            end
        end
        
        function UIKeyRelease(app, event)
        % Manages keypresses when UIAxes are in focus
            
            key     = event.Key;
            if isempty(app.data)
                return
%             elseif(~isfield(app.data{app.imIdx},'img') ||...
%                     isempty(app.data{app.imIdx}.img))
%                 return
            end
            if(strcmp(key,'uparrow'))
                GUI.SliceUp(app)
            elseif(strcmp(key,'downarrow'))
                GUI.SliceDown(app)
            elseif(strcmp(key, 'backspace'))
                Interaction.BackspacePressed(app)
            elseif(strcmp(key, 'z'))
                Interaction.ToggleZoom(app)
            elseif(strcmp(key, 'control'))
                app.ctrl    = false;
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
        
        % TODO: split
        function MouseDeleteObjectAtCoordinates(app,hitx,hity)
            %This handles the deletion of objects when the mouse is pressed
            %at the object location. Measurements have priority over
            %segmentation when deleting objects. 
            %
            %Input: hitx - the x-coordinate of the mouse
            %       hity - the y-coordinate of the mouse
            
            %Create backup
            Backups.CreateBackup(app);
            
            %Remove any previous deletion contours.
            if(app.selection_contour ~= -1)
                delete(app.selection_contour);
                app.selection_contour = -1;
            end
            
            %Find the object type to be deleted. Either Measurement or ROI.
            [delOb, ij, meas] = Study.FindObjectTypeAtPos(app, hitx, hity);
            
            %Remove the objects
            if(delOb == 1)
                ROI.RemoveSegmentation(app, ij)
            elseif(delOb == 2)
                Measurements.RemoveMeasurement(app, meas)
            end
            
            if delOb ~= 0
               app.should_show_selection = false;
            end
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
            GUI.UpdateSliceSlider(app);
            Graphics.UpdateImage(app);
            GUI.UpdateAxisButtons(app);
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
                GUI.DisableControlsStatus(app);
            else
                GUI.RevertControlsStatus(app);
            end
            GUI.DisableAllButtonsAndActions(app);
            app.UIFigure.Visible = 'on';
        end
        
        function RemoveSingle(app)
        %Toggles removal of userobjects when clicking
            if(~isfield(app.segmentation{app.current_view},'img') &&...
                    isempty(app.measure_lines{app.current_view}))
                return
            end
            SL_D = app.should_show_selection;
            GUI.DisableAllButtonsAndActions(app);
            if(SL_D == false)
                app.should_show_selection = true;
            else
                app.should_show_selection = false;
            end
            Graphics.UpdateImage(app);
            Graphics.UpdateSelectionContour(app);
        end
        
        function DeleteROIsAndMeasurements(app)
        % Removes any measurements and segmentations stored in the current
        % image. 
            
            %Create backup
            Backups.CreateBackup(app);
        
            %Remove measurements
            Measurements.RemoveAllMeasurements(app);
            %Remove ROIs
            ROI.RemoveAllROIs(app);
            GUI.UpdateUOBox(app);
            Graphics.UpdateImage(app);
        end
        
        function Save(app)
        %Called when the user presses the 'save_edited' button. Writes the
        %segmentation to the disk as well as any measurements and ROI
        %properties.
        %Input:
        %   app - the RMSstudio app
        %
        
            if isempty(app.AvailableimagesListBox.Items)
                return
            end
            Study.SaveToDisk(app)
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
            
            DP_D = app.drawing.mode ~= 1;
            if(DP_D)
                app.drawing.mode = 1;
                app.DrawPolygonButton.BackgroundColor = [.96 .96 0];
            else
                app.drawing.mode = 0;
                app.DrawPolygonButton.BackgroundColor = [.96 .96 .96];
                ROI.ValidateDrawingPoints(app);
                Graphics.UpdateImage(app);
            end
            Graphics.UpdateImage(app);
            Graphics.UpdateSelectionContour(app); 
        end
        
        function EditPolygon(app)
            %Toggles the edit function on or off.
            
            if app.drawing.mode == 2
                app.drawing.mode = 0;
                app.EditPolygonButton.BackgroundColor = [.96 .96 .96];
                GUI.RemoveButtonDownFcn(app);
                app.currentDragPoint    = {};
                app.dragPoint           = [];
                Graphics.UpdateUserInteractions(app);
            else
                app.drawing.mode = 2;
                app.EditPolygonButton.BackgroundColor = [.96 .96 0];
                GUI.SetButtonDownFcn(app);
                Graphics.UpdateUserInteractions(app);
%                 setptr(gcf, 'hand');
            end
        end
        
        function CircularROI(app)
        %Prepares drawing a Circular ROI
            if isempty(app.data{app.imIdx})
                return
            end
            if(app.drawing.mode ~= 5)
                app.drawing.mode = 5;
            else
                app.drawing.mode = 0;
            end
        end
        
        function PointsToSegmentation(app)
            %Called when the user chooses the PointsToSegmentation Menu
            %option. Calls functions to construct segmentation objects from
            %the points in the image.
            
            GUI.DisableAllButtonsAndActions(app)
            ROI.PointsToSegmentation(app)     
            Graphics.UpdateImage(app)
            GUI.RevertControlsStatus(app)
        end
        
        
        function PerformAutomaticEllipseMeasurement(app)
            % Called when the user presses the 'measure auto' button.
            
            %Create Backup
            Backups.CreateBackup(app);
            Measurements.PerformAutomaticEllipseMeasurement(app)
        end
        
        function MeasureLine(app)
        %Toggles 
            DP_D = app.drawing.mode;
            GUI.DisableAllButtonsAndActions(app);
            if(DP_D ~= 3)
                app.drawing.mode    = 3;
            else
                app.drawing.mode    = 0;
                app.points{Cv}      = [];
            end 
        end
        
        function MagicDraw(app)
            %Called when the user presses the 'magic draw' button.
            DP_D = app.drawing.mode;
            GUI.DisableAllButtonsAndActions(app);
            if(DP_D ~= 4)
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
                'String',app.AvailableimagesListBox.Items,              ...
                'Callback',@popup_callback);
            
            btn = uicontrol('Parent',d,                                 ...
                'Position',[89 20 70 25],                               ...
                'String','Align!',                                      ...
                'Callback','delete(gcf)');
            
            choice = app.AvailableimagesListBox.Items{1};
            
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
        
        function Undo(app)
            %Called when Undo-button is pressed. 
%             Study.Undo(app)
            Backups.RestoreBackup(app)
        end
        
        function UpdateSlice(app, value, axID)
        %Sets the current_slice to the new value, then updates the GUI
        %Input:
        %   value - new value for current_slice
            slice = round(value);
            imID    = app.imagePerAxis(axID);
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
        
        function choice = PromptName()
            %Called when the user finishes drawing an ROI or measurement.
            %Prompts them for a name that is either in the selection box or
            %a custom one.
            
            d = dialog('Position',[300 300 250 150],'Name','Select One');
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
            
            profile = '';
            
            if nargin() == 2
                file    = fullfile(varargin, 'profiles.txt');
                file    = file{1};
                if exist(file, 'file') == 2
                    fileID  = fopen(file,    'r');
                    names   = {};
                    name    = fgetl(fileID);
                    while name ~= -1
                        names{end+1}    = name;
                        name    = fgetl(fileID);
                    end
                    fclose(fileID);
                    names{end+1}        = 'Other';
                    
                    d = dialog('Position',[300 300 250 150],'Name',     ...
                        'Select One');
                    txt = uicontrol('Parent',d,...
                           'Style','text',...
                           'Position',[20 80 210 40],...
                           'String','Choose profile name');

                    popup = uicontrol('Parent',d,...
                           'Style','popup',...
                           'Position',[75 70 100 25],...
                           'String',names,    ...
                           'Callback',@popup_callback);

                    btn = uicontrol('Parent',d,...
                           'Position',[89 20 70 25],...
                           'String','Select',...
                           'Callback','delete(gcf)');

                   %Default
                    profile = {names{1}};
                    
                    uiwait(d);

                else
                    %A path is specified but not file exists.
                    
                    %prompt for profile and write to file.
                    profile = inputdlg("Enter profile name");
%                     profile = upper(profile);      
                    fid     = fopen(file, 'wt');
                    fprintf(fid, strcat(profile{1}, '\n'));
                    fclose(fid);
                    
                end
            else
            %If no filepath is given, prompt for the profile and don't do
            %anything else.
                profile = inputdlg(['Enter profile name.' newline       ...
                '(We suggest the first three letters of your name']);
            
                if isempty(profile)
                    profile = {''};
                end
            end
            
            %Add the profile to the app
            profile  = upper(profile);
            
            %Add to app
            if strcmp(app.user_profile, profile)
                return
            end
            app.user_profile    = profile;
            app.backup_list     = [];
            
            
            %When the file exists, but 'other' is chosen, prompt for new
            %profile name and add it to the file.
            function popup_callback(popup, event)
                idx = popup.Value;
                popup_items = popup.String;
                res = char(popup_items(idx,:));

                if strcmp(res, 'Other') == 1
                  profile = inputdlg("Enter profile name");
                  profile  = upper(profile);
                  
                  fid   = fopen(file, 'a+');
                  fprintf(fid, strcat(profile{1}, '\n'));
                  fclose(fid);
                  
                  delete(gcf)
                  
                else
                  profile = {res};
                end
            end
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
                   'String',    app.AvailableimagesListBox.Items,...
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
        
        
        
        %% Other
        
        function ShuffleColors(app)
        %Shuffles the colors of the measurements & segmentations
            IX = randperm(size(app.colors_list,1));
            app.colors_list = app.colors_list(IX,:);
            Graphics.UpdateImage(app);
            Graphics.UpdateSelectionContour(app);
        end
        
    end
end