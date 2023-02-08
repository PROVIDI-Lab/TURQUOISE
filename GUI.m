classdef GUI < handle
    methods (Static)
        
        function InitGUI(app)
           %Initialises the window for when a new study is loaded.
           %Called by Study.InitStudy            

            %Enable all menus
            app.ViewMenu.Enable     = 'on';
            app.AnalyseMenu.Enable  = 'on';
            app.DrawMenu.Enable     = 'on';
            app.SegmentMenu.Enable  = 'on';

            d = uiprogressdlg(app.UIFigure, 'Title',...
                'New Patient');
            
            %Select and display the first image of the study, and if
            %possible, display the second image on the second view.
            if(~isempty(app.studyNames))
                
                if length(app.studyNames) > 1
                    msg = sprintf('Preparing image 1 of 2');
                    d.Message = msg;
                    d.Value = 0.5;
                    app.current_view      = 2;
                    %Keep track of which image is in which view
                    idx = app.imagePerAxis(app.current_view);
                    app.AvailableimagesListBox.Value =...
                        app.AvailableimagesListBox.Items{idx};
                    app.imIdx = idx;
                    %Show everything
                    GUI.DisplayNewImage(app, idx)
                    
                    %Switch back
                    app.current_view = 1;
                end
                
                msg = sprintf('Preparing image 2 of 2');
                d.Message = msg;
                d.Value = 1;
                app.current_view      = 1;
                %Keep track of which image is in which view
                idx = app.imagePerAxis(app.current_view);
                app.AvailableimagesListBox.Value =...
                    app.AvailableimagesListBox.Items{idx};
                app.imIdx = idx;
                %Show everything
                GUI.DisplayNewImage(app, idx)
                
            end

            GUI.InitCrosshair(app)
            
            GUI.RevertControlsStatus(app);
            app.UIFigure.Visible = 'off';
            app.UIFigure.Visible = 'on';
            close(d);
        end
        
        function SetupAxis(app, the_ax, axID)
        %Constructs the UIAxes
            rect = get(the_ax,'OuterPosition');
            bg = zeros(rect([4 3]));
            bg(round(end/2),round(end/2)) = 1;
            app.imageRenderer{axID} = imagesc(the_ax, bg);
            colormap(the_ax,'gray');
            axis(the_ax,'off');
            the_ax.BackgroundColor = 'k';
        end

        function AddUOLayer(app, axID, objID)
            %Creates new imagesc with UO color and transparency 0

            the_ax  = app.GetAxis(axID);
            rect = round(get(the_ax,'OuterPosition'));
            col = app.colors_list(objID,:);
            im  = cat(3, ones(rect([4 3])) * col(1),...
                         ones(rect([4 3])) * col(2),...
                         ones(rect([4 3])) * col(3));

            hold(the_ax, 'on')
            app.UORenderer{axID}{objID} = imshow(im, 'Parent', the_ax);
            set(app.UORenderer{axID}{objID},'AlphaData', 0);
            hold(the_ax, 'off')

            set(app.UORenderer{axID}{objID},...
                'ButtonDownFcn',@app.MouseClickedInImage);
        end
        
        function ResetViews(app)
            %Resets both views and switches all displaying options to their
            %default values.
            app.slicePerImage       = {};
            Study.FindRealWorldReference(app);  %restore axis
            app.current_view        = 1;
%             app.Align               = '';
            
            GUI.UpdateAxisInfo(app);
            GUI.UpdateAlignButtons(app);
           
            set(app.imageRenderer{1},'CData', zeros(100));
            set(app.imageRenderer{2},'CData', zeros(100));

            %Remove any objects drawn on the screen
            for idx = 1:length(app.userObjects)
                obj     = app.userObjects{idx};
                delete(app.UORenderer{1}{obj.ID})
                delete(app.UORenderer{2}{obj.ID})
            end
            app.UORenderer      = {{},{}};  %TODO: don't hardcode ndum Axes
                        
        end
        
        function DisplayNewImage(app, index)
        %Changes the GUI to display an image that hasn't been displayed 
        %before. 
        %Input:
        %app - the RMSStudio app
        %index - index of the image in the AvailableImageBox
            
            if isempty(app.data{index})
                return
            end

            GUI.UpdateAxisInfo(app);
            app.zoomToggle              = false;
            
            uoIdx = Objects.FindUoForImage(app, index);
            if uoIdx ~= -1
                uo = app.userObjects{uoIdx};
                [view, slice]   = Objects.GetUOViewAndSlice(uo);
                app.viewPerImage(index) = view;
                app.slicePerImage{index}{view} = slice;
            else
                view = app.viewPerImage(index);
                app.slicePerImage{index}{view}    = round(size(...
                                            app.data{index}.img,3)/2);
            end
            
            %Update all GUI elements
            GUI.UpdateSliceSlider(app);
            GUI.UpdateMinMaxSlider(app);
            GUI.UpdateUOBox(app);
            
            %Draw the new image
            Graphics.UpdateImage(app);   
            Graphics.UpdateAxisParams(app, app.current_view);
            GUI.InitCrosshair(app)
        end  
        
        function SwitchImage(app, index)
        %Changes the GUI to display an image that has been displayed 
        %before. 
        %Input:
        %app - the RMSStudio app
        %index - index of the image in the AvailableImageBox

            app.zoomToggle      = false;
            
            %Update all GUI elements
            Graphics.ResetTextRenderer(app)
            GUI.UpdateSliceSlider(app)
            GUI.UpdateMinMaxSlider(app)
            GUI.UpdateUOBox(app)
            GUI.ChangeListBoxValue(app, index)
            GUI.UpdateAxisButtons(app)
                        
            Graphics.UpdateImage(app)
            Graphics.UpdateAxisParams(app, app.current_view)
            GUI.InitCrosshair(app)
        end
        
        function DisplayError(app)
            %Changes the statuslamp to show an error has occurred
            app.AvailableimagesListBox.Enable = 'on';
            app.StatusLamp.Color     = [0.9100 0.4100 0.1700];
            app.StatusLampLabel.Text = 'Error';
        end
        
        %% Scrolling & zooming the axes
        
        function Scroll(app, event)
        %Manages the scrollwheelEvent 
        
            if isempty(app.data) || isempty(app.studyNames)
                return
            end
            verticalScrollCount     = event.VerticalScrollCount;
            axID    = GUI.FindAxisUnderCursor(app, event);
            if axID == -1
                return
            end
            imID    = app.imagePerAxis(axID);
            
            if app.ctrl %Zoom instead of scrolling
                scrollCount     = verticalScrollCount;
                GUI.ZoomAxis(app, axID, scrollCount, event);
                return
            end
            view    = app.viewPerImage(imID);
            slice   = app.slicePerImage{imID}{view} - verticalScrollCount;
            Interaction.UpdateSlice(app, slice, axID);

            hit     = GUI.GetHitFromCurrentPoint(app, axID, event);
            i       = hit(1);
            j       = hit(2);
            GUI.MoveCrosshair(app, i, j, axID)
            
        end
        
        function SliceUp(app)
            imID    = app.imagePerAxis(app.current_view);
            view    = app.viewPerImage(imID);
            slice   = app.slicePerImage{imID}{view} + 1;
            Interaction.UpdateSlice(app, slice, app.current_view);
        end
        
        function SliceDown(app)
            imID    = app.imagePerAxis(app.current_view);
            view    = app.viewPerImage(imID);
            slice   = app.slicePerImage{imID}{view} - 1;
            Interaction.UpdateSlice(app, slice, app.current_view);
        end
        
        function axID = FindAxisUnderCursor(app, event)
           %Returns the axisID of the axis currently under the cursor.
           
           xpos = event.Source.CurrentPoint(1);
           ypos = event.Source.CurrentPoint(2);
           %Go over all axes
           %UIAxes 1
           pos  = app.UIAxes1.Position;
           xMin     = pos(1);
           xMax     = pos(1) + pos(3);
           yMin     = pos(2);
           yMax     = pos(2) + pos(4);
           if xMin < xpos && xpos < xMax && yMin < ypos && ypos < yMax
               axID = 1;
               return
           end
           
           %UIAxes 2
           pos  = app.UIAxes2.Position;
           xMin     = pos(1);
           xMax     = pos(1) + pos(3);
           yMin     = pos(2);
           yMax     = pos(2) + pos(4);
           if xMin < xpos && xpos < xMax && yMin < ypos && ypos < yMax
               axID = 2;
               return
           end
            
           axID = -1;
           return
        end

        function axID = FindAxisAtPosition(app, position)
           %Returns the axisID of the axis currently under the cursor.
           
           xpos     = position(1);
           ypos     = position(2);
           
           %Go over all axes
           %UIAxes 1
           pos  = app.UIAxes1.Position;
           xMin     = pos(1);
           xMax     = pos(1) + pos(3);
           yMin     = pos(2);
           yMax     = pos(2) + pos(4);
           if xMin < xpos && xpos < xMax && yMin < ypos && ypos < yMax
               axID = 1;
               return
           end
           
           %UIAxes 2
           pos  = app.UIAxes2.Position;
           xMin     = pos(1);
           xMax     = pos(1) + pos(3);
           yMin     = pos(2);
           yMax     = pos(2) + pos(4);
           if xMin < xpos && xpos < xMax && yMin < ypos && ypos < yMax
               axID = 2;
               return
           end
            
           axID = -1;
           return
        end


        
        function ZoomAxis(app, axID, scrollCount, event)
            %Zooms the image, additionally translates the current viewpoint
            %to keep the cursor mostly centered during zooming
            
            zoomAmount      = 1 + scrollCount * 0.1; 
            zoomFactor      = app.viewingParams(4);

            zoomFactor      = zoomFactor * zoomAmount;
            zoomFactor      = min(zoomFactor, 3);
            zoomFactor      = max(zoomFactor, 0.2);
            
            app.viewingParams(4) = zoomFactor;

            %Keep the cursor in (roughly) the same spot
            %formula for the new center is:
            %   x + 0.5*zoom*(old_range - 2x)
            %   where x is cursor position (in pixel coordinates)
            %   zoom is zoom level as a fraction
            %   old_range is pixel dimensions before zooming

            hit     = GUI.GetHitFromCurrentPoint(app, axID, event);
            xPos    = hit(1);
            yPos    = hit(2);

            %Next, calculate xCenter and yCenter
            xCenter         = xPos;% + 0.5 * zoomFactor * (deltaX - 2*xPos);
            yCenter         = yPos;% + 0.5 * zoomFactor * (deltaY - 2*yPos);

            
            %find and correct the zPos for centering
            imID            = app.imagePerAxis(axID);
            viewAxis        = app.viewPerImage(imID); 
            zPos            = app.slicePerImage{imID}{viewAxis};
            ijkView     = NiftiUtils.GetIJKView(app);
            dim         = size(app.data{imID}.img, ijkView);
            zPos        = zPos - dim/2;
            
            app.viewingParams(5:7) = [xCenter, yCenter, 1];

            Graphics.UpdateImageForAxis(app, axID);

        end
        
        function ResetAxisZoom(app)

            app.viewingParams(4) = 1;
            app.viewingParams(5:7) = [-1, -1, -1];
            Graphics.UpdateImageForAxis(app, app.current_view);
        end        
        

        function hit = GetHitFromCurrentPoint(app, axID, event)
        %Find i,j position of mouseevent that only gives cursor position
            ax              = app.GetAxis(axID);
            deltaX          = ax.XLim(2) - ax.XLim(1);
            xPos            = event.Source.CurrentPoint(1);
            xPos            = (xPos - ax.InnerPosition(1)) / ...
                ax.InnerPosition(3);
            xPos            = xPos * deltaX;

            deltaY          = ax.YLim(2) - ax.YLim(1);
            yPos            = event.Source.CurrentPoint(2);
            yPos            = (yPos - ax.InnerPosition(2)) /...
                ax.InnerPosition(4);
            yPos            = deltaY - ( yPos * deltaY);
            
            hit = [xPos, yPos];

        end

    %% Sliders && UI elements

        function SensitivitySlider(app)
        %Sets the sensitivityslider value to the program
            value = app.SensitivitySlider.Value;
            value = round(value);
            app.SensitivitySlider.Value = value;
            app.drawing.magic_sensitivity = value; 
        end
        
        function UpdateSliceSlider(app)
        % Sets the limits and current value of the slice slider
            if(isempty(app.data{app.imIdx}))
                return
            end
            
            %Get data dimensions
            view    = app.viewPerImage(app.imIdx);
            slice   = app.slicePerImage{app.imIdx}{view};
            
            %Update SliceSlider
            viewAxis    = NiftiUtils.GetIJKView(app);
            viewSize    = size(app.data{app.imIdx}.img, viewAxis);
            if(viewSize == 1) % workaround when only 1 slice is available
                viewSize = 2;
            end
            app.SliceSlider.Limits = [1 viewSize];
            max_ticks = 4;
            step = round(viewSize / (max_ticks-1));
            app.SliceSlider.MajorTicks =  [1 : step : viewSize viewSize];
            app.SliceSlider.MinorTicks = 1 : 1 : viewSize;
            if isnan(slice) || slice < 0 || slice > viewSize
                slice = round( viewSize / 2);
                app.slicePerImage{app.imIdx}{view} = slice;
            end
            
            try
                app.SliceSlider.Value = double(slice);
            catch
                return
            end            
        end
        
        function Update4DSlider(app)
            %Updates the slider that sets the 4d axis
            refvol  = app.data{app.imIdx}.img;
            
            app.DSlider.MajorTicks = 1:1:size(refvol,4);
            if(size(refvol,4) > 20)
                app.DSlider.MajorTicks = 1:10:size(refvol,4);
            end
            if(size(refvol,4) > 1)
                app.DSlider.Limits = [1 size(refvol,4)];
            else
                app.DSlider.Limits = [1 2];
            end
            app.DSlider.Value = double(app.d4PerImage(app.imIdx)); 
        end
        
        function UpdateMinMaxSlider(app)
        %Updates the min and max sliders
            if ~isfield(app.data{app.imIdx}, 'img')
                return
            end
%             V = app.data_list{app.current_image(app.imIdx)}.img(:,:,:,1);
            V = app.data{app.imIdx}.img(:,:,:,1);
            app.MinValue = min(V(:));
            if app.MinValue <0
                app.MinValue = 0;
            end
            app.MaxValue = max(V(:));
            app.cScalePerImage{app.imIdx} = [app.MinValue, app.MaxValue];
%             app.cMinValue = app.MinValue;
%             app.cMaxValue = app.MaxValue;
            if(app.MinValue == app.MaxValue)
                app.MinValue = 0;
                app.MaxValue = 100;
            end
%             max_ticks = 6;
%             step = round((100)/max_ticks);
            app.MinvalSlider.MajorTicks = [0 50 100];
            app.MinvalSlider.Value      =...
                double(floor(app.MinValue/app.MaxValue*100));
            app.MaxvalSlider.MajorTicks = [0 50 100];
            app.MaxvalSlider.Value      =...
                double(floor(app.MaxValue/app.MaxValue*100));
        end
        
        
        function StartChangingContrast(app, hit)
           %Records the point where the cursor was pressed to change 
%               x = hit.Source.Parent.Parent.CurrentPoint(1);
%               y = hit.Source.Parent.Parent.CurrentPoint(2);
                hitx = round(hit.IntersectionPoint(1));
                hity = round(hit.IntersectionPoint(2));
                app.dragPoint   = [hitx, 0, hity, 0];
                app.drawing.mode = 6;
                
                set(hit.Source.Parent.Parent.Parent,...
                    'WindowButtonMotionFcn',...
                    @app.MouseDraggedInImage);

                set(hit.Source.Parent.Parent.Parent,...
                    'WindowButtonUpFcn',...
                    @app.MouseReleasedInImage);
        end
        
        function AdjustContrast(app, hitx, hity)
            %Compares hitx and hity with the previous cursor position to
            %determine the new min and max display values.
            %X influences the min value & Y influences the max value

            dX              = (hitx - app.dragPoint(1));
            dY              = (hity - app.dragPoint(3));
            if isnan(dX)
                dX = 0;
            end
            if isnan(dY)
                dY = 0;
            end
            minVal          = app.MinvalSlider.Value + dX;
            minVal          = max(min(100, minVal),1);
            maxVal          = app.MaxvalSlider.Value - dY;
            maxVal          = max(min(100, maxVal),1);
            
            %Set the new slider positions
            app.MinvalSlider.MajorTicks = [0 50 100];
            app.MinvalSlider.Value      = double(floor(minVal));
            app.MaxvalSlider.MajorTicks = [0 50 100];
            app.MaxvalSlider.Value      = double(floor(maxVal));
            
            %update dragPoint for smooth transitions
            app.dragPoint(1) = hitx;
            app.dragPoint(3) = hity;
            
            %Update the contrast
            cMaxVal = maxVal/100*app.MaxValue;
            cMinVal = minVal/100*app.MaxValue;
            if cMaxVal <= cMinVal
                cMaxVal = cMinVal + 0.001;
            end
            
            app.cScalePerImage{app.imIdx} = [cMinVal, cMaxVal];
            Graphics.UpdateImage(app); 
            
        end
        
        function UpdateMaxContrast(app, value)
            %Previously MaxvalSliderValueChanging
            %Calculates the new cScale based on the slider value
            next_maxvalue   = value/100*app.MaxValue;
            cVals           = app.cScalePerImage{app.imIdx};
            cMinVal         = cVals(1);
            if cMinVal >= next_maxvalue
                next_maxvalue = cMinVal+0.001;
            end
            app.cScalePerImage{app.imIdx} = [cMinVal, next_maxvalue];
            Graphics.UpdateImage(app); 
        end
        
        function UpdateMinContrast(app, value)
            %Previously MinvalSliderValueChanging
            %Calculates the new cScale based on the slider value
            next_minvalue = value/100*app.MaxValue;
            cVals           = app.cScalePerImage{app.imIdx};
            cMaxVal         = cVals(2);
            if cMaxVal <= next_minvalue
                next_minvalue = cMaxVal - 0.001;
            end
            app.cScalePerImage{app.imIdx} = [next_minvalue, cMaxVal];
            Graphics.UpdateImage(app);
        end
        
        
        %% Update buttons
                
%         function UpdateAxisInfo(app)
%             %Updates the axisview buttons to display the correct one.
%             imID    = app.imagePerAxis(app.current_view);
%             
%             axInfo  = NiftiUtils.FindOrientation(...
%                 app.transMatPerImage{imID});
%             
%             %Reset the values of the buttons
%             app.AxialButton.BackgroundColor         = [.96 .96 .96];
%             app.SagittalButton.BackgroundColor      = [.96 .96 .96];
%             app.CoronalButton.BackgroundColor       = [.96 .96 .96];
%             
%             if     axInfo(5) == 'c'
%                 app.CoronalButton.BackgroundColor   = [.96 .96 0];
%             elseif axInfo(5) == 's'
%                 app.SagittalButton.BackgroundColor  = [.96 .96 0];
%             else
%                 app.AxialButton.BackgroundColor     = [.96 .96 0];
%             end
% 
%         end

        function UpdateAxisButtons(app)
            %Updates the axisview buttons to display the correct one.
            imID    = app.imagePerAxis(app.current_view);
            view    = app.viewPerImage(imID);
            
            %Reset the values
            app.AxialButton.BackgroundColor         = [.96 .96 .96];
            app.SagittalButton.BackgroundColor      = [.96 .96 .96];
            app.CoronalButton.BackgroundColor       = [.96 .96 .96];
            
            if     view == 2
                app.CoronalButton.BackgroundColor   = [.96 .96 0];
            elseif view == 1
                app.SagittalButton.BackgroundColor  = [.96 .96 0];
            elseif view == 3
                app.AxialButton.BackgroundColor     = [.96 .96 0];
            end
        end
        
        function UpdateAlignButtons(app)
            %Updates the alignment buttons to highlight the one that's 
            %currently active.
            app.AlignLRButton.BackgroundColor   = [.96 .96 .96];
            app.AlignRLButton.BackgroundColor   = [.96 .96 .96];
            
            if isempty(app.Align)
                return
            end
            
            if strcmp(app.Align, 'LR')
                app.AlignLRButton.BackgroundColor   = [.96 .96 0];
            elseif strcmp(app.Align, 'RL')
                app.AlignRLButton.BackgroundColor   = [.96 .96 0];
            end
               
        end
        
        %% Listboxes

        function ChangeListBoxValue(app, index)
        %Changes the value of the AvailableImageListBox
            
            %Get the name of the file at the index
            name = app.AvailableimagesListBox.Items{index};
            app.AvailableimagesListBox.Value = name;
        end
        
        function UpdateUOBox(app)
        %Updates the box with the different user-made ROIs.
            
            %Clear items
            app.UOBox.Items     = {};
            app.UOBox.ItemsData = [];   
            %Add ROIs
            counter     = 1;
            for idx     = 1:length(app.userObjects)
                obj  = app.userObjects{idx};
                if obj.imageIdx ~= app.imagePerAxis(app.current_view)
                   continue
                end
                if obj.deleted
                    continue
                end

                name     = obj.name;
                if ~ischar(name)
                       name =  num2str(name);
                end

                [view, slice]   = Objects.GetUOViewAndSlice(obj);
                views           = {'Cor', 'Sag', 'Ax'};
                view            = views{view};
                types           = {'POL', 'MSR', 'CIR', 'ELL'};
                type            = types{obj.type};
                name            = GUI.GetUOBoxName(...
                                    type, name, slice, view, obj.visible);

                app.UOBox.Items{counter}        = name.char;
                app.UOBox.ItemsData(counter)    = obj.ID;
                counter = counter + 1;           
            end   
            
            %Add 'None'
            idx     = size(app.UOBox.Items, 2) + 1;
            app.UOBox.Items{idx}       = 'None';
            app.UOBox.ItemsData(idx)   = -1;
        end
        
        function name = GetUOBoxName(del, name, slice, view, visible)
        %Creates a name that fits in the UOBox. 
        %TODO: don't hardcode amount of characters
        
            %35 characters
            %DEL##NAME##############slc#viw#vis
            %  5           17        4   3   1

            ddel    = 5 - length(del);
            for i = 1:ddel
                del = del + " ";
            end

            dname   = 17 - length(name);
            if dname <= 0
                name = name(1:13) + "... ";
            else
                for i = 1:dname
                    name = name + " ";
                end
            end

            slice   = num2str(slice);
            dslice  = 4 - length(slice);
            for i = 1:dslice
               slice = slice + " "; 
            end

            if length(view) > 3
                view = view(1:3);
            end
            
            if visible
                vis     = "●";
            else
                vis     = "○";
            end

            name = del + name + slice + view + vis;
            
        end
        
        function UpdateUOVisibility(app, value)
            %Called when the visibilityslider is changed. Updates the 
            %visibility of the selected userobject. If 'None' is selected,
            %updates the visibility of all.
            
            if isempty(app.UOBox.Items)
                return
            end            
            value   = strcmp(value, 'On');
            idx     = app.UOBox.Value;
            if  isempty(idx) || idx == -1
                for i = 1:length(app.UOBox.Items)
                    UOidx   = app.UOBox.ItemsData(i);
                    if UOidx == -1
                        continue
                    end
                    app.userObjects{UOidx}.setVisible(value, app);
                end
            else
                app.userObjects{idx}.setVisible(value, app);
            end
            
            Graphics.UpdateUserObjects(app);
                
        end
        
        
        function ToggleUOPresence(app, idx)
            %Toggles the '* ' prefix of items in app.AvailableImagesListbox
            %to indicate whether UOs exist in that file.
            
            item = app.AvailableimagesListBox.Items{idx};
            if strcmp(item(1:2), '* ')
                app.AvailableimagesListBox.Items{idx} = item(3:end);
            else
                app.AvailableimagesListBox.Items{idx} = ['* ' item];
            end
            
        end
        
        %% Cursor stuff
        
        function SetWatchCursor(app)
            %Sets the cursor for the UIFigure to a loading icon (watch)
            set(app.UIFigure, 'Pointer', 'watch')
        end
        
        function SetDrawCursor(app)
            %Sets the cursor for the UIFigure to a crosshair icon 
            set(app.UIFigure, 'Pointer', 'crosshair')
        end
        
        function ResetCursor(app)
            %Sets the cursor for the UIFigure to an arrow icon (default)
            set(app.UIFigure, 'Pointer', 'arrow')
        end
        
        function MouseHover(app, hit)
            %Called by Interaction.MouseDraggedInImage. Checks which UO is
            %underneath the cursor (if any). Displays UO info in UOlabel.
            %Additionally displays the value of the image underneath the
            %cursor in the HoverLabel

            if isempty(app.data)
                return
            end

            GUI.DisplayHoverValue(app, hit)
            UOId = Objects.FindUOUnderMouse(app, hit);
            
            if app.buttonDown
                GUI.MoveCrosshair(app, hit)
            end

            if UOId == -1
                app.UOHoverLabel.Text = "";
                return
            end

            GUI.DisplayUOText(app, UOId)
        end

        function DisplayHoverValue(app, hit)
            %Get the value of the voxel underneath the cursor and write to
            %app.HoverLabel

            hitx = round(hit.IntersectionPoint(1));
            hity = round(hit.IntersectionPoint(2));
            
            if isnan(hitx) || isnan(hity)
                return
            end
            
            %Find which view the cursor is over
            if round(hit.Point(1)) <= hit.Source.Position(3)/2
                view = 1;
            else
                view = 2;
            end

            %Find imID and slice
            try
                imID    = app.imagePerAxis(view);
                ax      = app.viewPerImage(imID);
                slice   = app.slicePerImage{imID}{ax};
            catch
                return
            end

            %Find value
            try
                res = app.data{imID}.img(hity,hitx,slice);
            catch
                res = 0;
            end
            app.HoverLabel.Text = num2str(res);


        end

        function DisplayUOText(app, UOId)

            idx     = Objects.findUOIndex(app, UOId);
            obj     = app.userObjects{idx};

            if isempty(obj.prop)
                obj.prop.volume = 0;
                obj.prop.mean   = 0;
            end

            Name     = obj.name;
            Volume   = obj.prop.volume;
            MeanSig  = obj.prop.mean;

            String   = strcat(Name,                 ...
                        '\tVolume:%.2f mm^3 \tMean: %.2f');
            String   = sprintf(String,              ...               
                               Volume,              ...
                               MeanSig);
            app.UOHoverLabel.Text = String;
        end

        %% Crosshair

        function InitCrosshair(app)
        %Finds the middle point of the image in the first UIAxes.
        %Initializes the renderer and moves it to that position.

        %Find middle of first image
        imID        = app.imagePerAxis(app.current_view);  
        sz          = size(app.data{imID}.img);
        viewAxis    = app.viewPerImage(imID);
        sz(viewAxis)    = [];
        i               = round(sz(1)/2);
        j               = round(sz(2)/2);
        
        %Convert to world coordinates
        xyz         = NiftiUtils.hitToXYZ(app, i, j);


        %Draw crosshair for each axis   -TODO: don't hardcode axes
        GUI.CrosshairPerImage(app, 1, xyz)
        GUI.CrosshairPerImage(app, 2, xyz)
        end


        function MoveCrosshair(app, varargin)
        %Moves the crosshair to the new position. Scrolls the images on the
        %other ax(i/e)s along with the position.

            if nargin == 2     %hit
                hit = varargin{1};

                %return when hit is wrong
                if any(isnan(hit.IntersectionPoint))
                    return
                end
    
                %Find xyz position of hit
                i           = hit.IntersectionPoint(1);
                j           = hit.IntersectionPoint(2);
                xyz         = NiftiUtils.hitToXYZ(app, i, j);
            elseif nargin == 4
                i           = varargin{1};
                j           = varargin{2};
                axID        = varargin{3};
                xyz         = NiftiUtils.hitToXYZ(app, i, j, axID);
            end

            %Draw crosshair for each axis   -TODO: don't hardcode axes
            GUI.CrosshairPerImage(app, 1, xyz)
            GUI.CrosshairPerImage(app, 2, xyz)

        end

        function CrosshairPerImage(app, axID, xyz)
        %Finds the image position of world coordinate xyz for image imID.
        %Also calculates endpoints of the crosshair and calls the rendering
        %function
        %If the xyz position doesn't match the current slice, scroll
        
            %Find ijk
            imID        = app.imagePerAxis(axID);
            tm          = app.transMatPerImage{imID};
            ijk         = NiftiUtils.xyz2ijk(tm, xyz);

            %Remove relative viewing axis
            or          = NiftiUtils.FindOrientation(tm);
            viewAxis    = app.viewPerImage(imID);
            imageOr     = strfind('sca', or(5)); 
            or_Mat      = [3,1,2; 1,3,2; 1,2,3];
            view        = or_Mat(imageOr, viewAxis);
            slice       = ijk(view);
            ijk(view)   = [];

            %Scroll if needed
            if ~isempty(app.slicePerImage{imID})
                if slice ~= app.slicePerImage{imID}{viewAxis}
                    Interaction.UpdateSlice(app, slice, axID)
                end
            end

            %find size of image
            sz          = size(app.data{imID}.img);
            sz(viewAxis)= [];
            
            %Draw
            Graphics.DrawCrosshairInAxis(app, axID, ijk, sz)
            

        end

        function ButtonDown(app, hit)
            %toggles app.buttonDown and sets up a callback for dragging and
            %releasing the mouse.

            try
                set(hit.Source.Parent.Parent.Parent,...
                'WindowButtonUpFcn',...
                @app.MouseReleasedInImage);
            catch
                return
            end

            app.buttonDown = true;
        end

        
        %% Context menus
        
        function UOContextMenu(app, id, pos)
            %Creates a contextmenu where the user clicked
            %Input: 
            %   app - the app
            %   id  - id of the userobject
            %   pos - cursor position

            %Find axis
            axID    = GUI.FindAxisAtPosition(app, pos);
            axis    = app.GetAxis(axID);
            
            cm = uicontextmenu(app.UIFigure);
            
            m1 = uimenu(cm,'Text','Delete');
            m2 = uimenu(cm,'Text','Rename');
            m3 = uimenu(cm,'Text','Copy To');
            m4 = uimenu(cm,'Text','Toggle Visibility');

            drawnow     %Necessary to display the cm
            
            m1.MenuSelectedFcn = ...
                {@Objects.DeleteUO, app, id};
            m2.MenuSelectedFcn = ...
                {@Objects.RenameUO, app, id};
            m3.MenuSelectedFcn = ...
                {@Objects.CopyUOTo, app, id};
            m4.MenuSelectedFcn = ...
                {@Objects.ToggleVisibleUO, app, id};

            cm.Position   = [pos(1), pos(2)];
            cm.Visible    = 'on';

            axis.ContextMenu = cm;           
           return           
        end
        %% UI text elements
        
        function ToggleUnsavedIndicator(app)
            if app.unsavedProgress
                app.UIFigure.Name = ['RMSStudio ' app.current_folder ' *'];
            else
                app.UIFigure.Name   = ['RMSStudio ' app.current_folder];
            end
        end
        
        
        %% Enable / disable user interaction
        
        function SetButtonDownFcn(app)
           %Sets the button down function on all the tempDrawings objects.
           set(app.tempDrawings, 'ButtonDownFcn',@app.MouseClickedInImage);
        end
        
        function RemoveButtonDownFcn(app)
           %Removes the button down function on all the tempDrawings
           set(app.tempDrawings, 'ButtonDownFcn','');
        end
        
        function RevertControlsStatus(app)
            %Re-ables user interaction with the different menus, buttons,
            %UI elements and more.
            %Buttons
            app.DrawPolygonButton.Enable            = 'on';
            app.AlignLRButton.Enable                = 'on';
            app.AlignRLButton.Enable                = 'on';
            app.VisibleSlider.Enable                = 'on';
            app.SliceDecreaseButton.Enable          = 'on';
            app.SliceIncreaseButton.Enable          = 'on';
            app.CoronalButton.Enable                = 'on';
            app.SagittalButton.Enable               = 'on';
            app.AxialButton.Enable                  = 'on';

            %Menus
            app.FileMenu.Enable                     = 'on';
            app.ViewMenu.Enable                     = 'on';
            app.AnalyseMenu.Enable                  = 'on';
            app.DrawMenu.Enable                     = 'on';
            app.SegmentMenu.Enable                  = 'on';
            
            %Sliders
            app.SliceSlider.Enable                  = 'on';
            app.MinvalSlider.Enable                 = 'on';
            app.MaxvalSlider.Enable                 = 'on';

            %Listboxes
            app.AvailableimagesListBox.Enable       = 'on';
            app.AvailableStudiesListBox.Enable      = 'on';
            app.UOBox.Enable                        = 'on';


            %4d stuff
%             Cv      = app.current_view;
%             if(~isempty(app.data{Cv}) && ndims(app.data{Cv}.img) > 3)
            app.DSlider.Enable                  = 'on';
            app.Decrease4DButton.Enable         = 'on';
            app.Increase4DButton.Enable         = 'on';
%             end
            
            app.StatusLampLabel.Text                = 'Idle';
            app.StatusLamp.Color                    = 'g';
            
            GUI.ResetCursor(app)
            app.busyStatus                          = false;

        end
        
        
        % This prevents user interaction
        function DisableControlsStatus(app)

            %Buttons
            app.DrawPolygonButton.Enable            = 'off';
            app.AlignLRButton.Enable                = 'off';
            app.AlignRLButton.Enable                = 'off';
            app.VisibleSlider.Enable                = 'off';
            app.SliceDecreaseButton.Enable          = 'off';
            app.SliceIncreaseButton.Enable          = 'off';
             app.CoronalButton.Enable               = 'off';
            app.SagittalButton.Enable               = 'off';
            app.AxialButton.Enable                  = 'off';

            %Menus
            app.FileMenu.Enable                     = 'off';
            app.ViewMenu.Enable                     = 'off';
            app.AnalyseMenu.Enable                  = 'off';
            app.DrawMenu.Enable                     = 'off';
            app.SegmentMenu.Enable                  = 'off';
            
            %Sliders
            app.SliceSlider.Enable                  = 'off';
            app.MinvalSlider.Enable                 = 'off';
            app.MaxvalSlider.Enable                 = 'off';

            %Listboxes
            app.AvailableimagesListBox.Enable       = 'off';
            app.AvailableStudiesListBox.Enable      = 'off';
            app.UOBox.Enable                        = 'off';


            %4d stuff
            app.DSlider.Enable                      = 'off';
            app.Decrease4DButton.Enable             = 'off';
            app.Increase4DButton.Enable             = 'off';
            
            app.StatusLampLabel.Text                = 'Busy';
            app.StatusLamp.Color                    = 'r';
            
            GUI.SetWatchCursor(app)
            app.busyStatus                          = true;


        end
        
        
        function DisableAllButtonsAndActions(app)
            % Resets actions to baseline
            app.should_show_selection                   = false;
            app.drawing.mode                            = 0;
            
            app.currentDragPoint                    = -1;
            app.dragPoint                           = [];
            
            %Turns off zooming for all axes
            zoom(app.UIAxes1, 'off')
            zoom(app.UIAxes2, 'off')
        end
    end
end