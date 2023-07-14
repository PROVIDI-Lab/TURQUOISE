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

            GUI.UpdateUOBox(app)

            %Draw new UORenderer layers
            %TODO" don't hardode axes
            GUI.InitUORenderer(app, 1)
            GUI.InitUORenderer(app, 2)
                        
            %Update to the new image
            Graphics.UpdateAxes(app)

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
    
    function SwitchViewAndFocus(app, newAxID,~)
        % Switches the program to another UIAxis

        % Input: new_view_idx - idx of view that was pressed
        %        caller_name - object that was pressed, used to manage
        %        calling this function from unknown sources (not
        %        pre-defined).

            if isempty(app.studyNames)
                return
            end
        
%             GUI.DisableAllButtonsAndActions(app);           
            app.axID    = newAxID;

            %Switch to the correct image
            app.imID   = app.imagePerAxis(newAxID);
            GUI.SwitchAxis(app, newAxID)
        end
        
        function MouseClickedInImage(app,hit)
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
            
            hitx = round(hit.IntersectionPoint(1));
            hity = round(hit.IntersectionPoint(2));
                           
            if(app.drawing.mode == 1)
                % Here we are manually drawing an ROI
                if hit.Button == 1
                    ROI.AddPointToPolygon(app,hitx,hity);
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
                id = Objects.FindUOUnderMouse(app, hit, app.axID);

                if id > 0
                    C = get(app.UIFigure, 'CurrentPoint');
                    GUI.UOContextMenu(app, id, C) 
                    return
                else
                    %rmb + drag is pan image
                    GUI.StartDragging(app, hit)
                end
            else
                %If not doing anything else, move the cursor and other
                %panels around
                GUI.ButtonDown(app, hit)
                GUI.MoveCrosshair(app, hit)
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
            if isempty(app.studyNames)
                return
            end


            if isempty(app.dragPoint)
                GUI.MouseHover(app, hit)                
                return
            end

            hitx = round(hit.IntersectionPoint(1));
            hity = round(hit.IntersectionPoint(2));
            if app.drawing.mode == 6        %contrast
                GUI.AdjustContrast(app, hitx, hity)
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

        function TimerCallback(~, ~, app)

            stop(app.interactionTimer)
            Graphics.SetStaticGraphics(app)
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
                    case 'control'
                        app.ctrl    = true;
                    case 'f12'
                        Interaction.Debug(app)
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
            app.ctrl    = false;
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
                       
            closereq
        end
           
            
        
        function LoadNewLabels(app)
            %Loads a new segmentation for the current image.

            %TODO: move to IOUtils
            defPath         = strcat(app.filepath, "\.rmsstudio");
            [file, path]    = uigetfile('*.nii',                        ...
                                'Load Segmentation',                    ...
                                defPath);
            fp              = fullfile(path, file);
            if ~exist(fp, "file")
                return
            end
            
            IOUtils.LoadSegmentation(app, fp, app.imID);  
            obj = app.userObjects{end};
            GUI.UpdateUOBox(app);
            axID = find(app.imagePerAxis == obj.imageIdx);
            if axID
                GUI.AddUOLayer(app, axID, obj.ID)
                Graphics.UpdateImage(app)
            end
            Backups.CreateBackup(app)
            
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
            
            IOUtils.loadSegmentationPoints(app, fp, app.imID);  
            Graphics.UpdateImage(app);
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
                app.points{app.axID}      = [];
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
            uicontrol('Parent',d,                                 ...
                'Style','text',                                         ...
                'Position',[20 80 210 40],                              ...
                'String','Select the registration target');
            
            uicontrol('Parent',d,                               ...
                'Style','popup',                                        ...
                'Position',[75 70 100 25],                              ...
                'String',app.studyNames,              ...
                'Callback',@popup_callback);
            
            uicontrol('Parent',d,                                 ...
                'Position',[89 20 70 25],                               ...
                'String','Align!',                                      ...
                'Callback','delete(gcf)');
            
            choice = app.studyNames{1};
            
            % Wait for d to close before running to completion
            uiwait(d);
            app.UIFigure.Visible = 'on';
            GUI.RevertControlsStatus(app);
            
            function popup_callback(popup, ~)
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
         
            return
        end
                
        function choice = PromptTarget(app)
            %Called when the user copies a UserObject. The user is prompted
            %to which image the object should be copied. 
                        
            d = dialog('Position',[300 300 250 150],'Name','Select One');
            uicontrol('Parent',d,...
                   'Style','text',...
                   'Position',[20 80 210 40],...
                   'String','Copy to which image');

            uicontrol(...
                   'Parent',    d,...
                   'Style',     'popup',...
                   'Position',  [75 70 100 25],...
                   'String',    app.studyNames,...
                   'Callback',  @popup_callback);

            uicontrol('Parent',d,...
                   'Position',[89 20 70 25],...
                   'String','Select',...
                   'Callback',@select);
            
            %Default
            choice = {};
               
            % Wait for d to close before running to completion
            uiwait(d);

                function popup_callback(popup,~)
                   choice = popup.Value;
                end
               
                function select(btn, ~)
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
        
        %% Other
        
        function ShuffleColors(app)
        %Shuffles the colors of the measurements & segmentations
            IX = randperm(size(app.colors_list,1));
            app.colors_list = app.colors_list(IX,:);
            Graphics.UpdateImage(app);
        end
        
        function Debug(app)
            %Used for quick access to the app state
            disp('Debugging, press "continue"')
            a = 12;
        end
        
        function values = overlayMask(im, mask)
           
            %Overlays mask over image, takes into account different shapes
            minx = min(size(im,1), size(mask,1));
            miny = min(size(im,2), size(mask,2));
            
            newMask = mask(1:minx, 1:miny, :);
            newIm   = im(1:minx, 1:miny, :);
            
            values = newIm(newMask);            
        end
        
        function HideAllTooltips(app)
           
            
            for i = 1:length(app.userObjects)
                app.userObjects{i}.setBoxVisible(false) 
            end
%             Graphics.UpdateImage(app)            
            
        end         
            

        
        
        
        
        
        
        
    end
end