classdef Interaction < handle
    %This static class deals with user interaction. All interactions should
    %provide callbacks in the appdesigner code that then call functions in
    %this class. The functions here will then call functions in the other
    %classes to complete the user interaction.
    
    methods (Static)                 
        function ListBoxChanged(app)
            %Finds the new index of the AvailableImagesListBox and calls
            %functions to update the app acoordingly. 
            
            value = app.AvailableimagesListBox.Value;
            [~, index] = ismember(value, ...
                app.AvailableimagesListBox.Items);
                        
            %if index matches the index of any of the other axes, ignore
            otherView = [1,2];
            otherView(app.axID) = [];
            if app.imagePerAxis(otherView) == index
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

            %Find obj
            index = Objects.findUOIndex(app, index);
            if index == -1
                return
            end
            
            %Switch slice and view       
            obj             = app.userObjects{index};
            [view, slice]   = Objects.GetUOViewAndSlice(obj);
            view            = NiftiUtils.findProjectionFromViewDim( ...
                    app, obj.imageIdx, view);
            app.viewPerImage(app.imID) = view;
            app.slicePerImage{app.imID}{view}    = slice;
            
            GUI.UpdateSliceSlider(app)
            Graphics.UpdateImage(app)
            GUI.InitCrosshair(app)
            Graphics.UpdateAxisParams(app, 1)
            Graphics.UpdateAxisParams(app, 2)
%             GUI.ResetAxisZoom(app)
            
            %Update GUI
            GUI.UpdateAxisButtons(app)
            
        end

        function SwitchUserProfile(app)

            %Updates the UOBox and draws new UOs belonging to the other
            %profile

            IOUtils.LoadUserObjects(app, app.imID)
            GUI.UpdateUOBox(app)

            %Draw new UORenderer layers
            %TODO" don't hardode axes
            GUI.InitUORenderer(app, 1)
            GUI.InitUORenderer(app, 2)
                        
            %Update to the new image
            Graphics.UpdateAxes(app)

        end
        
        
    %% UIAxes interactions
    
    function SwitchViewAndFocus(app, newAxID,~)
        % Switches the program to another UIAxis
        % Input: newAxID - idx of view that was pressed

        if isempty(app.sessionNames) %return if no images loaded
            return
        end
        app.axID    = newAxID;

        %Switch to the correct image
        app.imID   = app.imagePerAxis(newAxID);
        GUI.SwitchAxis(app, newAxID)
    end
    
    function MouseClickedInImage(app, hit)
        %Handles clicks in the image area. Calls functions depending on
        %the state of various buttons.
        %Input: hit - the location where the mouse was pressed.
        
        if isempty(app.data)
            return
        end
        if isempty(app.data{app.imID})
            return
        end
        if app.busyStatus   %Don't do anything if the app is busy
            return
        end
        
        %Check if the screen that was pressed is different from the
        %current view.
        if (hit.Source.Parent == app.UIAxes1                       ...
                && app.axID == 2)       ||                  ...
            (hit.Source.Parent == app.UIAxes2                       ...
                && app.axID == 1)       &&                  ...
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
        
        %Find image position of hit
        column      = round(hit.IntersectionPoint(1));
        row         = round(hit.IntersectionPoint(2));

        %Flip j, because we want bottom left as 0,0
        imID        = app.imagePerAxis(app.axID);  
        sz          = NiftiUtils.FindInPlaneResolution(app, imID);
        row         = sz(2) - row + 1;
        %Bound j, to prevent errors
        row         = min(row, sz(2));
        row         = max(row, 1);

        app.CoordinateInspectorApp.viewpixALabel.Text = strcat('c: ', num2str(column), ', r: ', num2str(row));

        
        
        %%%%
        %Do stuff based on drawing mode           
        if(app.drawing.mode == 1)
            % Here we are manually drawing an ROI
            if hit.Button == 1
                ROI.AddPointToPolygon(app,column,row);
            elseif hit.Button == 3  %right mouse button, finish drawing
                if(size(app.points{app.axID},1) <= 3)
                    return
                end
                Interaction.PromptName(app);
                app.drawing.mode                        = 0;
                app.DrawPolygonButton.BackgroundColor   = ...
                                        [.96 .96 .96];
                GUI.ResetCursor(app)
            end
        
        elseif(app.drawing.mode == 3)
            % Here we are adding a manual measurement
            Measurements.MouseMeasurementLines(app,hit,column,row);
            
        elseif(app.drawing.mode == 4)
            % Here we are using the automatic ROI drawing
            app.ContourPickerApp.PosSelected(column,row, app.axID);   
        
        elseif hit.Button == 2  %mmb
            %Here we adjust the contrast
            GUI.StartChangingContrast(app, hit, column, row)
            
        elseif hit.Button == 3  %rmb
            %Here we open a contextmenu when clicking a UO
            id = Objects.FindUOUnderMouse(app, column, row, app.axID);

            if id > 0
                C = get(app.UIFigure, 'CurrentPoint');
                GUI.UOContextMenu(app, id, C) 
                return
            else
                %rmb + drag is pan image
                GUI.StartDragging(app, hit, column, row)
            end
        else
            %If not doing anything else, move the cursor and other
            %panels around
            GUI.ButtonDown(app, hit)
            GUI.MoveCrosshair(app, column, row)
        end
        
        Graphics.UpdateUserInteractions(app)
        
    end
        
        function MouseReleasedInImage(app, hit)
        %When editing an ROIpoint, finalize the editing
            
            %Dragging the crosshair
            if app.buttonDown
                app.buttonDown = false;
                return
            end
        
            if app.drawing.mode == 5
                ROI.FinishDrawingCircular(app)
            elseif app.drawing.mode == 6
                app.drawing.mode = 0;
            elseif app.drawing.mode == 7
                app.drawing.mode = 0;
                GUI.ResetCursor(app);
            else
                return
            end
            
            app.dragPoint           = [];
            app.currentCircle       = [];
            
            Graphics.UpdateImage(app)
            set(hit.Source,'WindowButtonUpFcn','')     
        end

        
        function MouseDraggedInImage(app, hit)
            %Triggers when the mouse moves in the image after the
            %windowbuttonmotionFCN has been set for the UIAxes elements.
            if isempty(app.sessionNames)
                return
            end

            column      = round(hit.IntersectionPoint(1));
            row         = round(hit.IntersectionPoint(2));

            %Find image
            axID        = GUI.FindAxisUnderCursor(app, hit);
            if axID == -1
                return
            end
            imID        = app.imagePerAxis(axID);  

            %Flip column, because we want bottom left as 0,0
            sz          = NiftiUtils.FindInPlaneResolution(app, imID);
            row         = sz(2) - row + 1;

            %Bound row and column, to prevent errors
            row         = min(row, sz(2));
            row         = max(row, 1);
            column      = min(column, sz(1));
            column      = max(column, 1);

            app.CoordinateInspectorApp.viewpixALabel.Text = strcat('c: ', num2str(column), ', r: ', num2str(row));

            %Don't do anything if we're outside the image
            if any(isnan([column,row]))
                return
            end

            %If dragpoint is empty, we're not adjusting contrast, or
            %panning across the axis.
            if isempty(app.dragPoint)
                GUI.MouseHover(app, column, row, axID)                
                return
            end            

            if app.drawing.mode == 6        %contrast
                GUI.AdjustContrast(app, column, row)
            elseif app.drawing.mode == 7    %dragging
                GUI.DragAxis(app, hit)
            end     
        end

        function ToggleInteractionTimer(app)
            %If the user scrolls through the image, this timer is started.
            %If it goes off, the images will be rendered at a higher
            %quality and the crosshairs will disappear. If this function is
            %called, it will either reset or start the timer.     


            if strcmp(app.interactionTimer.Running, 'on')
                stop(app.interactionTimer)
                start(app.interactionTimer)
                return
            else
                start(app.interactionTimer)
            end

            Graphics.SetMotionGraphics(app)

        end

        function InteractionTimerCallback(~, ~, app)

            if app.buttonDown
                stop(app.interactionTimer)
                start(app.interactionTimer)
                return
            end
            stop(app.interactionTimer)
            Graphics.SetStaticGraphics(app)
        end

        function CancelTimerCallback(~, ~, app)

            stop(app.cancelTimer)
            start(app.cancelTimer)

            if ~isprop(app, 'progressDlg')
                return
            end

            try
                if isempty(app.progressDlg)
                    return
                end
                if ~app.progressDlg.CancelRequested
                    return
                end
            catch
                return
            end
            

            %else, reset
            app.progressDlg.CancelRequested = false;
            GUI.RevertControlsStatus(app)
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
                        GUI.Scroll(app, -1, app.axID)
                    case 'downarrow'
                        GUI.Scroll(app, 1, app.axID)
                    case 'backspace'
                        Interaction.BackspacePressed(app)
                    case 'h'
                        GUI.ResetAxisZoom(app)
                    case 'd'
                        Interaction.DrawPolygon(app)
                    case 'control'
                        app.ctrl    = true;
                    case 'f12'
                        Interaction.Debug(app)
                    case 'f11'
                        Interaction.ForceRedraw(app)
                    case 's'
                        Interaction.ChangeViewAxis(app, 2)
                    case 'c'
                        Interaction.ChangeViewAxis(app, 1)
                    case 'a'
                        Interaction.ChangeViewAxis(app, 3)
                    case 'q'
                        profile on
                    case 'w'
                        profile viewer
                    case 'escape'
                        GUI.RevertControlsStatus(app)
                    case 'm'
                        Interaction.MagicDraw(app)
                    case 'p'
                        a = Interaction.PromptMask(app);
                        disp(fullfile(app.sessionPath, app.sessionNames{app.imID}, a));
                end
                
            elseif contains(modifier, 'control')
                
                switch key
                    case 'control'
                        app.ctrl    = ~app.ctrl;
                    case 'o'
                        app.ctrl = false;
                        Interaction.LoadStudy(app)
                    case 's'
                        app.ctrl = false;
                        Interaction.Save(app)
                    case 'z'
                        app.ctrl = false;
                        Backups.Undo(app)
                    case 'y'
                        app.ctrl = false;
                        Backups.Redo(app)
                    case 'f2'
                        app.ctrl = false;
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
            
            if isempty(app.points)
                return
            end
            if isempty(app.points{app.axID})
                return
            end
            
            app.points{app.axID}(end, :) = [];
            Graphics.UpdateImage(app);
            
        end
        
        %% UI buttons
        
        function ChangeViewAxis(app, viewAxis)
        %Switches viewAxis of the current UIAxis to the specified one
        %coronal = 1, sagittal = 2, axial = 3
            app.viewPerImage(app.imID) = viewAxis;

            %Update image slice
            % viewDim = NiftiUtils.FindViewingDimension(app, app.imID);
            % app.slicePerImage{app.imID}{viewAxis} = ...
            %             round(size(app.data{app.imID}.img, viewDim)/2);

            GUI.DisableControlsStatus(app)
            GUI.UpdateSliceSlider(app)
            Graphics.UpdateImage(app)
            GUI.UpdateAxisButtons(app)
            Graphics.UpdateAxisParams(app, app.axID);
            GUI.InitCrosshair(app)
            GUI.RevertControlsStatus(app)
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
                delete(fullfile(app.sessionPath));
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
           IOUtils.PrepareStudy(app, app.filepath)
           GUI.RevertControlsStatus(app)
            
        end
        
        function Reload(app)
            GUI.DisableControlsStatus(app)
            IOUtils.PrepareStudy(app, app.sessionPath)
            GUI.RevertControlsStatus(app)     
            app.ctrl    = false;
        end
        
        function Save(app)
        %Called when the user presses the 'save_edited' button. Writes the
        %segmentation to the disk as well as any measurements and ROI
        %properties.
        %Input:
        %   app - the RMSstudio app
        %
            if isempty(app.sessionNames)
                return
            end
            GUI.DisableControlsStatus(app, 'Saving', 'on')
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

            stop(app.cancelTimer)

            close all;
            delete(app)
        end
           
            
        
        function LoadNewLabels(app)
            %Loads a new segmentation for the current image.

            defPath         = app.dataset{1};
            [file, path]    = uigetfile(...
                    {'*.nii.gz; *.nii; *.json', ...
                    'Segmentation files (*.nii.gz, *.nii, *.json)'}, ...
                'Load Segmentation', defPath);
            fp              = fullfile(path, file);
            if ~exist(fp, "file")
                return
            end

            if contains(fp, '.json')
                IOUtils.loadSegmentationPoints(...
                    app, fp, idx);
            else
                IOUtils.LoadSegmentation(app, fp, app.imID)
            end
            
            obj = app.userObjects{end};
            GUI.UpdateUOBox(app);
            axID = find(app.imagePerAxis == obj.imageIdx);
            if axID
                GUI.AddUOLayer(app, axID, obj.ID)
                Graphics.UpdateImage(app)
            end
            Backups.CreateBackup(app)
            
            %Switch to new labels
            GUI.UpdateUOBox(app)
            app.UOBox.Value    = app.UOBox.ItemsData(end - 1);
            Interaction.UOBoxChanged(app);
        end
        
        function LoadLabelsFromStudy(app)
            %If one of the images in the study is a mask, this copies it
            %and loads it as the mask for the current image

            %Get the mask selection
            maskID = Interaction.PromptTarget(app);

            fp = fullfile(app.sessionPath, [ app.sessionNames{maskID} '.nii.gz']);
            if ~ exist(fp, 'file')
                fp = fullfile(app.sessionPath, [ app.sessionNames{maskID} '.nii']);
                if ~exist(fp, 'file')
                    errordlg("Can't find this file")
                    return
                end
            end

            IOUtils.LoadSegmentation(app, fp, app.imID)

            obj = app.userObjects{end};
            GUI.UpdateUOBox(app);
            axID = find(app.imagePerAxis == obj.imageIdx);
            if axID
                GUI.AddUOLayer(app, axID, obj.ID)
                Graphics.UpdateImage(app)
            end
            Backups.CreateBackup(app)
            
            %Switch to new labels
            GUI.UpdateUOBox(app)
            app.UOBox.Value    = app.UOBox.ItemsData(end - 1);
            Interaction.UOBoxChanged(app);

        end

        function DrawPolygon(app)
            %Called when the user presses the 'draw polygon' button.
            
            if isempty(app.data{app.imID})
                return
            end
            
            if(app.drawing.mode ~= 1)
                app.drawing.mode = 1;
                app.DrawPolygonButton.BackgroundColor = [.96 .96 0];
                GUI.SetCursor(app, 'crosshair')
            else
                app.drawing.mode = 0;
                app.DrawPolygonButton.BackgroundColor = [.96 .96 .96];
                GUI.ResetCursor(app)
                Graphics.UpdateImage(app);
            end
            Graphics.UpdateImage(app);
        end
        
        function CircularROI(app)
        %Prepares drawing a Circular ROI
            if isempty(app.data{app.imID})
                return
            end
            ROI.StartDrawingCircular(app);    
        end
        
        function EllipseROI(app)
        %Prepares drawing a Circular ROI
            if isempty(app.data{app.imID})
                return
            end
            ROI.StartDrawingEllipse(app);    
        end
        
        
        % function PerformAutomaticEllipseMeasurement(app)
        %     % Called when the user presses the 'measure auto' button.
        % 
        %     Measurements.PerformAutomaticEllipseMeasurement(app)
        % end
        
        function MeasureLine(app)
        %Toggles 
            if(app.drawing.mode ~= 3)
                app.drawing.mode    = 3;
            else
                app.drawing.mode    = 0;
                app.points{app.axID}      = [];
            end 
        end
        
        function MagicDraw(app)
            %Called when the user presses the 'magic draw' button.
            if(app.drawing.mode ~= 4)
                GUI.SetCursor(app, 'crosshair')
                app.drawing.mode = 4;

                app.ContourPickerApp.Open()
            else
                app.drawing.mode = 0;
                GUI.ResetCursor(app)

                app.ContourPickerApp.Close()
            end
            Graphics.UpdateImage(app); 
        end
        
        
        % function AlignLeftRight(app, alignment)
        %     %Switches the alignment between the two views 
        % 
        %     if isempty(app.Align)
        %         app.Align = '';
        %     end
        % 
        %     %Turn off alignment when pressing on the same button
        %     if strcmp(alignment, app.Align)
        %         app.Align = '';
        %     else
        %         app.Align = alignment;
        %     end
        % 
        %     GUI.UpdateAlignButtons(app)
        % end
        % 
        % function choice = RegisterSelectedImageToDialog(app)
        %     %Called when the user presses the 'align labels' button. 
        %     %Prompts the user for an image to which the current labels 
        %     %should be registered, then registers them.
        % 
        %     IOUtils.SaveSegmentations(app);
        % 
        %     GUI.DisableControlsStatus(app);
        %     app.UIFigure.Visible = 'off';
        %     drawnow;
        % 
        %     d = dialog('Position',                                      ...
        %                [300 300 250 150],                               ...
        %                'Name',                                          ...
        %                'Select Target');
        %     uicontrol('Parent',d,                                 ...
        %         'Style','text',                                         ...
        %         'Position',[20 80 210 40],                              ...
        %         'String','Select the registration target');
        % 
        %     uicontrol('Parent',d,                               ...
        %         'Style','popup',                                        ...
        %         'Position',[75 70 100 25],                              ...
        %         'String',app.sessionNames,              ...
        %         'Callback',@popup_callback);
        % 
        %     uicontrol('Parent',d,                                 ...
        %         'Position',[89 20 70 25],                               ...
        %         'String','Align!',                                      ...
        %         'Callback','delete(gcf)');
        % 
        %     choice = app.sessionNames{1};
        % 
        %     % Wait for d to close before running to completion
        %     uiwait(d);
        %     app.UIFigure.Visible = 'on';
        %     GUI.RevertControlsStatus(app);
        % 
        %     function popup_callback(popup, ~)
        %         idx = popup.Value;
        %         popup_items = popup.String;
        %         % This code uses dot notation to get properties.
        %         % Dot notation runs in R2014b and later.
        %         % For R2014a and earlier:
        %         % idx = get(popup,'Value');
        %         % popup_items = get(popup,'String');
        %         choice = char(popup_items(idx,:));
        %         delete(gcf);
        %         app.UIFigure.Visible = 'on';
        %         drawnow
        %         MathUtils.PerformElastixRegistration(app,choice);
        %     end
        % end
        
        function UpdateSlice(app, value, axID)
        %Updates the slice to the new value, then updates the GUI
        %Input:
        %   value - new value for current_slice
            slice   = round(value);
            imID    = app.imagePerAxis(axID);
            view    = app.viewPerImage(imID);

            if isempty(app.data{imID})
                return
            end
            
            imgSize = size(app.data{imID}.img);
            %Limit the value between 1 and max
            if(slice < 1)
                slice = 1;
            end
            %TODO: view_axis per image
            viewDim = NiftiUtils.FindViewingDimension(app, imID);
            if slice > imgSize(viewDim)
                slice = imgSize(viewDim);
            end

            %check if the slice should still be updated after bounding
            if app.slicePerImage{imID}{view} == slice
                return
            end
            
            app.slicePerImage{imID}{view}   = slice;
%             app.viewingParams(4+view)       = slice;
            
            %Update the GUI
            if axID == app.axID
                GUI.UpdateSliceSliderValue(app, slice)
            end
            Graphics.UpdateImageForAxis(app, axID);
%             Graphics.UpdateSelectionContour(app);
        end
        
        
        function Update4D(app, value)
            %Updates the 4D axis for the current image
            max4D   = size(app.data{app.imID}.img, 4);
            min4D   = 1;
            if value > max4D
                value   = max4D;
            elseif value < min4D
                value   = min4D;
            end 
            
            app.d4PerImage(app.imID)   = value;
            GUI.Update4DSlider(app);
            Graphics.UpdateImage(app);
        end
        %% Prompts
        
        function PromptName(app, varargin)
            %Called when the user finishes drawing an ROI or measurement.

            renameQ = false;
            if nargin == 2
                renameQ = varargin{1};
            end

            %Deactivate program until input is received
            GUI.DisableControlsStatus(app);
            drawnow;
            
            imID    = app.imagePerAxis(app.axID);

            objs    = Objects.GetAllUONamesForImage(app, imID);
            nameLst = getpref('rmsstudio', 'ROILst');
            app.ROIPromptApp.Show(objs, nameLst, renameQ)
        end
                
        function choice = PromptTarget(app, varargin)
            %The user is prompted for an image in the current series

            if nargin == 1
                multiselect = false;
            else
                multiselect = varargin{1};
            end

                        
            d = dialog('Position',[300 300 500 250],'Name','Select image target');
            
            if multiselect
                uicontrol(...
                       'Parent',    d,...
                       'Style',     'listbox',...
                       'Value',     [],...
                       'Min',       0, ...
                       'Max',       100, ...
                       'Position',  [40 50 420 180],...
                       'String',    app.sessionNames,...
                       'Callback',  @popup_callback);

                uicontrol(...
                    'Parent',    d,...
                    'Style',     'text',...
                    'Position',  [20 20 200 30],...
                    'String',    'Hold ctrl to select multiple targets.')
            else
                uicontrol(...
                   'Parent',    d,...
                   'Style',     'popup',...
                   'Position',  [40 50 420 30],...
                   'String',    app.sessionNames,...
                   'Callback',  @popup_callback);
            end

            uicontrol('Parent',d,...
                   'Position',[380 20 70 25],...
                   'String','Select',...
                   'Callback',@select);
            
            %Default
            if multiselect
                choice = [];
            else
                choice = app.sessionNames{1};
            end
               
            % Wait for d to close before running to completion
            uiwait(d);

                function popup_callback(popup,~)
                   choice = popup.Value;
                end
               
                function select(~, ~)
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
                 Study.ToggleUnsavedProgress(app, false);
              case 'Cancel'
                 proceed = false;
            end            
        end
        
        function PromptProfile(app)

            newProfile = inputdlg('Enter a new profile');
            newProfile = newProfile{1};
            profiles = getpref('rmsstudio', 'profiles');
            
            if any(contains(profiles, newProfile))
                errordlg('Profile already exists')
                return
            end

            profiles{end+1} = newProfile;
            setpref('rmsstudio', 'profiles', profiles)
            app.user_profile = newProfile;
            Interaction.SwitchUserProfile(app)
        end

        function choice = PromptMask(app, varargin)
            %The user is prompted for a mask target

            if nargin == 1
                multiselect = false;
                name = app.sessionNames{app.imID};
            else
                multiselect = varargin{1};
                if nargin == 2
                    name = app.sessionNames{app.imID};
                else
                    name = varargin{2};
                end
            end
            
            %get mask files to choose from
            nameDir = strrep(name, '.gz', '');
            nameDir = strrep(nameDir, '.nii', '');
            masks = dir(fullfile(app.sessionPath, nameDir, '*.nii.gz'));
            masks = {masks.name};
            d = dialog('Position',[300 300 500 250],'Name','Select mask target');

            
            if multiselect
                uicontrol(...
                       'Parent',    d,...
                       'Style',     'listbox',...
                       'Value',     [],...
                       'Min',       0, ...
                       'Max',       100, ...
                       'Position',  [40 50 420 180],...
                       'String',    masks,...
                       'Callback',  @popup_callback);

                uicontrol(...
                    'Parent',    d,...
                    'Style',     'text',...
                    'Position',  [20 20 200 30],...
                    'String',    'Hold ctrl to select multiple targets.')
            else
                uicontrol(...
                   'Parent',    d,...
                   'Style',     'popup',...
                   'Position',  [40 50 420 30],...
                   'String',    masks,...
                   'Callback',  @popup_callback);
            end

            uicontrol('Parent',d,...
                   'Position',[380 20 70 25],...
                   'String','Select',...
                   'Callback',@select);
            
            %Default
            if multiselect
                choice = [];
            else
                choice = masks{1};
            end

            if isempty(masks)
                msg = strcat("No masks found for image target: ", name);
                errordlg(msg);
                return
            end
               
            % Wait for d to close before running to completion
            uiwait(d);

            function popup_callback(popup,~)
               choice = masks{popup.Value};
            end
           
            function select(~, ~)
               delete(gcf);
            end
        end
        
        %% Other
               
        function Debug(app)
            %Used for quick access to the app state
            disp('Debugging, press "continue"')
            a = 12;
        end

        function ForceRedraw(app)
            drawnow
        end
                
        
    end
end