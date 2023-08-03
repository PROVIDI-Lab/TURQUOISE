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
                    app.axID      = 2;
                    %Keep track of which image is in which view
                    idx = app.imagePerAxis(app.axID);
                    app.AvailableimagesListBox.Value =...
                        app.AvailableimagesListBox.Items{idx};
                    app.imID = idx;
                    %Show everything
                    GUI.DisplayNewImage(app, idx)
                    
                    %Switch back
                    app.axID = 1;
                end
                
                msg = sprintf('Preparing image 2 of 2');
                d.Message = msg;
                d.Value = 1;
                app.axID      = 1;
                %Keep track of which image is in which view
                idx = app.imagePerAxis(app.axID);
                app.AvailableimagesListBox.Value =...
                    app.AvailableimagesListBox.Items{idx};
                app.imID = idx;
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
            the_ax.Toolbar = [];

            GUI.SetupCrosshairs(app, the_ax, axID)
        end

        function InitUORenderer(app, axID)
            %whenever a new image gets displayed on any UIAxis, remove all
            %previous UORenderer layers and draw new ones for all
            %userObjects on that image.

            %First, remove all UO layers 
            for i = 1:length(app.UORenderer{axID})
                delete(app.UORenderer{axID}{i})
            end

            app.UORenderer{axID} = {};

            %Draw new ones for the objects on that image
            UOIDs = Objects.GetAllUOIDsForImage(app, ...
                app.imagePerAxis(axID));
            for i = 1:length(UOIDs)
                GUI.AddUOLayer(app, axID, UOIDs(i))
            end

        end

        function AddUOLayer(app, axID, objID)
            %Creates new imagesc with UO color and transparency 0

            if axID == 0
                return
            end

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

            %restore any changes to the axis
            Graphics.UpdateAxisParams(app, axID)
        end

        function RemoveUOLayer(app, axID, objID)

            delete(app.UORenderer{axID}{objID})

        end

        function SetupCrosshairs(app, the_axis, axID)
            %Plots the crosshairs on each image axis. Crosshairs are
            %updated in Graphics.DrawCrosshairInAxis, which only sets the
            %data.

            hold(the_axis,'on');
            %Draw two lines
            l1  = plot(the_axis, ...
                [1, 2], [1, 2], '--c',...
                'HitTest',                              ...
                'on',                                   ...
                'ButtonDownFcn',                        ...
                @app.MouseClickedInImage, ...
                'Visible','off');
        
            l2  = plot(the_axis, ...
                [1, 2], [1, 2], '--c',...
                'HitTest',                              ...
                'on',                                   ...
                'ButtonDownFcn',                        ...
                @app.MouseClickedInImage, ...
                'Visible','off');

            hold(the_axis,'off');
            app.crosshairRenderer{axID} = [l1, l2];

        end
        
        function ResetViews(app)
            %Resets both views and switches all displaying options to their
            %default values.
            app.slicePerImage       = {};
            Study.FindRealWorldReference(app);  %restore axis
            app.axID        = 1;
            
            GUI.UpdateAxisButtons(app);
           
            set(app.imageRenderer{1},'CData', zeros(100));
            set(app.imageRenderer{2},'CData', zeros(100));

            GUI.InitUORenderer(app, 1)
            GUI.InitUORenderer(app, 2)
                        
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

            GUI.UpdateAxisButtons(app);
            
            %find image dimension in order: cor, sag, ax
            tm          = app.transMatPerImage{index};
            or          = NiftiUtils.FindOrientation(tm);
            imageOr     = strfind('csa', or(5)); 
            imSize = round(size(app.data{index}.img)/2); 

            if imageOr == 1 %cor
                imSize = flip(imSize);
            elseif imageOr == 2 %sag
                imSize = [imSize(2:3) imSize(1)];
            end
            app.slicePerImage{app.imID} = num2cell(imSize);
                    
            uoIdx = Objects.FindUoForImage(app, index);
            if uoIdx ~= -1
                uo = app.userObjects{uoIdx};
                [view, slice]   = Objects.GetUOViewAndSlice(uo);
                app.viewPerImage(index) = view;
                app.slicePerImage{index}{view} = slice;
            end
            
            %Update all GUI elements
            GUI.UpdateSliceSlider(app);
            GUI.UpdateMinMaxSlider(app);
            GUI.UpdateUOBox(app);
            GUI.Update4DSlider(app);

            %Setup the new UO renderer layers
            GUI.InitUORenderer(app, app.axID)
            
            %Draw the new image
            Graphics.UpdateImage(app);   
            Graphics.UpdateAxisParams(app, app.axID);
            Graphics.UpdateAxisScaling(app, app.axID);
            GUI.InitCrosshair(app)
        end  
        
        function SwitchImage(app, index)
        %Changes the GUI to display an image that has been displayed 
        %before. 
        %Input:
        %app - the RMSStudio app
        %index - index of the image in the AvailableImageBox
            
            %Update all GUI elements
            Graphics.ResetTextRenderer(app)
            GUI.UpdateSliceSlider(app)
            GUI.UpdateMinMaxSlider(app)
            GUI.UpdateUOBox(app)
            GUI.ChangeListBoxValue(app, app.imagePerAxis(index))
            GUI.UpdateAxisButtons(app)
            GUI.Update4DSlider(app)

            %Draw new UORenderer layers
            GUI.InitUORenderer(app, app.axID)
                        
            %Update to the new image
            Graphics.UpdateImage(app)
            Graphics.UpdateAxisParams(app, app.axID)
            GUI.InitCrosshair(app)
        end

        function SwitchAxis(app, index)
            %Updates the GUI to the new axis
            %Update all GUI elements
            Graphics.ResetTextRenderer(app)
            GUI.UpdateSliceSlider(app)
            GUI.UpdateMinMaxSlider(app)
            GUI.UpdateUOBox(app)
            GUI.ChangeListBoxValue(app, app.imagePerAxis(index))
            GUI.UpdateAxisButtons(app)
            GUI.Update4DSlider(app)
        end


        
        function DisplayError(app)
            %Changes the statuslamp to show an error has occurred
            app.AvailableimagesListBox.Enable = 'on';
            app.StatusLamp.Color     = [0.9100 0.4100 0.1700];
            app.StatusLampLabel.Text = 'Error';
        end
        
        %% Scrolling & zooming the axes
        
        function Scroll(app, varargin)
        %Manages the scrollwheelEvent 
        
            if isempty(app.data) || isempty(app.studyNames)
                return
            end

            Interaction.ToggleInteractionTimer(app)

            if nargin == 2  %app + event

                event           = varargin{1};
                scrollCount     = event.VerticalScrollCount;
                axID            = GUI.FindAxisUnderCursor(app, event);
                if axID == -1
                    return
                end

            elseif nargin == 3  %app + value + axID

                scrollCount = varargin{1};
                axID        = varargin{2};
            end

            imID    = app.imagePerAxis(axID);
            
            if app.ctrl %Zoom instead of scrolling
                GUI.ZoomAxis(app, axID, scrollCount, event);
                return
            end

            view    = app.viewPerImage(imID);
            slice   = app.slicePerImage{imID}{view} - scrollCount;
            Interaction.UpdateSlice(app, slice, axID)

            GUI.MoveCrosshair(app, axID)
            
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
            
            zoomAmount      = scrollCount * 0.05; 
            zoomFactor      = app.viewingParams(4);

            zoomFactor      = zoomFactor + zoomAmount;
            zoomFactor      = min(zoomFactor, 1.5);
            zoomFactor      = max(zoomFactor, 0.1);
            
            app.viewingParams(4) = zoomFactor;

            %Get position from crosshairPerAxis
            row         = app.crosshairPerAxis{axID}(1);
            column      = app.crosshairPerAxis{axID}(2);
            
            %Get real world coordinates
            xyz         = NiftiUtils.rc2xyz(app, row, column, axID);

            GUI.ZoomAxisAtPosition(app, 1, xyz)
            GUI.ZoomAxisAtPosition(app, 2, xyz)

            %Display crosshair
            GUI.CrosshairPerAxis(app, 1)
            GUI.CrosshairPerAxis(app, 2)
        end


        function ZoomAxisAtPosition(app, axID, xyz)
            %Uses the zoomFactor stored in app.viewingParams(4) to zoom the
            %UIAxes. Position is given in world coordinates and calculated
            %back to image coordinates.

            %find i&j image coordinates of xyz hit
            imID        = app.imagePerAxis(axID);
            tm          = app.transMatPerImage{imID};
            ijk         = NiftiUtils.xyz2ijk(app, tm, xyz, axID);

            %Remove relative viewing axis
            viewDim     = NiftiUtils.FindViewingDimension(app, imID);
            ijk(viewDim)   = [];
            iPos        = ijk(1);
            jPos        = ijk(2);

            the_axis        = app.GetAxis(axID);

            %find image dimensions
            sz  = size(app.data{imID}.img);
            sz(viewDim) = [];

            %Find new limits - get width/height from zoomfactor and image
            %dimensions. 

            newWidth = sz(1) * app.viewingParams(4);
            newHeight = sz(2) * app.viewingParams(4);

            %find previous axis positions
            i0 = the_axis.XLim(1);
            i1 = the_axis.XLim(2);
            j0 = the_axis.YLim(1);
            j1 = the_axis.YLim(2);

            
            %find relative position of cursor
            iPerc   = (iPos-i0)/(i1-i0);
            jPerc   = (jPos-j0)/(j1-j0);

            %Find new limits such that cursor stays (roughly) in the same
            %position
            deltaI  = (i1-i0)-newWidth;
            deltaJ  = (j1-j0)-newHeight;

            i0New   = i0 + iPerc*deltaI;
            i1New   = i1 - (1-iPerc)*deltaI;
            j0New   = j0 + jPerc*deltaJ;
            j1New   = j1 - (1-jPerc)*deltaJ;

            the_axis.XLim = [i0New, i1New];
            the_axis.YLim = [j0New, j1New];

            Graphics.UpdateOrientationInfoOnAxis(app, axID)

        end

        
        function ResetAxisZoom(app)
        %Resets the XLim and YLim of both axes to match the image sizes

            app.viewingParams(4) = 1;

            Graphics.UpdateAxisParams(app, 1)
            Graphics.UpdateAxisParams(app, 2)

            GUI.InitCrosshair(app)
        end      

        function StartDragging(app, hit, i, j)
           %Records the point where the cursor was pressed to allow
           %dragging the image

                app.dragPoint   = [i, 0, j, 0];
                app.drawing.mode = 7;   %drag mode

                set(hit.Source.Parent.Parent.Parent,...
                    'WindowButtonUpFcn',...
                    @app.MouseReleasedInImage);
                
                GUI.SetCursor(app, 'fleur')

        end

        function DragAxis(app, hit)
            %Compares hitx and hity with the previous cursor position to
            %drag the images

            hitx = round(hit.IntersectionPoint(1));
            hity = round(hit.IntersectionPoint(2));
            dX              = -(hitx - app.dragPoint(1)) / 2;
            dY              = -(hity - app.dragPoint(3)) / 2;
            if isnan(dX)
                dX = 0;
            end
            if isnan(dY)
                dY = 0;
            end

            axID    = GUI.FindAxisUnderCursor(app, hit);
            if axID <= 0
                return
            end
            the_axis =  app.GetAxis(axID);
            %get the current axis limits
            x0          = the_axis.XLim(1);
            x1          = the_axis.XLim(2);
            y0          = the_axis.YLim(1);
            y1          = the_axis.YLim(2);

            %Set new XLim and YLim
            the_axis.XLim = [x0 + dX, x1 + dX];
            the_axis.YLim = [y0 + dY, y1 + dY];
            
            %update dragPoint
            app.dragPoint(1) = hitx;
            app.dragPoint(3) = hity;

            %Update axis info position
            Graphics.UpdateOrientationInfoOnAxis(app, axID)
            
        end
        

        function hit = GetHitFromCurrentPoint(app, axID, event)
        %Find i,j position of mouseevent that only gives cursor position
            ax              = app.GetAxis(axID);
            deltaX          = ax.XLim(2) - ax.XLim(1);
            xPos            = event.Source.CurrentPoint(1);
            xPos            = (xPos - ax.InnerPosition(1)) / ...
                ax.Position(3);
            xPos            = xPos * deltaX + ax.XLim(1);

            deltaY          = ax.YLim(2) - ax.YLim(1);
            yPos            = event.Source.CurrentPoint(2);
            yPos            = (yPos - ax.InnerPosition(2)) /...
                ax.Position(4);
            yPos            = deltaY - ( yPos * deltaY) + ax.YLim(1);
            
            sz = NiftiUtils.FindInPlaneResolution(app, ...
                app.imagePerAxis(axID));

            hit = [xPos, sz(2) - yPos];

        end

        function hit = GetHitFromCurrentPointZoom(app, axID, event)
        %Find i,j position of mouseevent that only gives cursor position
        %Special version for zooming because for some stupid reason,
        %although this produces less accurate locations, it keeps the
        %cursor constant while zooming?!
            ax              = app.GetAxis(axID);
            deltaX          = ax.XLim(2) - ax.XLim(1);
            xPos            = event.Source.CurrentPoint(1);
            xPos            = (xPos - ax.InnerPosition(1)) / ...
                ax.Position(3);
            xPos            = xPos * deltaX;    %changes here

            deltaY          = ax.YLim(2) - ax.YLim(1);
            yPos            = event.Source.CurrentPoint(2);
            yPos            = (yPos - ax.InnerPosition(2)) /...
                ax.Position(4);
            yPos            = deltaY - ( yPos * deltaY);    %changes here
            
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
        % Sets the limits and current value of the slice slider. To be
        % called when a new image / imageOrientation is loaded.
            if(isempty(app.data{app.imID}))
                return
            end
            
            %Get data dimensions
            view    = app.viewPerImage(app.imID);
            slice   = app.slicePerImage{app.imID}{view};
            
            %Update SliceSlider
            viewAxis    = NiftiUtils.FindViewingDimension(app, app.imID);
            viewSize    = size(app.data{app.imID}.img, viewAxis);
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
                app.slicePerImage{app.imID}{view} = slice;
            end
            
            try
                app.SliceSlider.Value = double(slice);
            catch
                return
            end            
        end

        function UpdateSliceSliderValue(app, value)
            %Updates the value of the slice slider, to be called when the
            %user scrolls through the image.
            
            try
                app.SliceSlider.Value = double(value);
            catch
                return
            end

        end
        
        function Update4DSlider(app)
            %Updates the slider that sets the 4d axis
            imSz4D  = size(app.data{app.imID}.img, 4);

            if imSz4D == 1
                app.DSlider.Enable = 'off';
                app.Increase4DButton.Enable = 'off';
                app.Decrease4DButton.Enable = 'off';
                return
            else
                app.DSlider.Enable = 'on';
                app.Increase4DButton.Enable = 'on';
                app.Decrease4DButton.Enable = 'on';
            end
            
            app.DSlider.MajorTicks = 1:1:imSz4D;
            if(imSz4D > 20)
                app.DSlider.MajorTicks = 1:10:imSz4D;
            end

            app.DSlider.Limits = [1 imSz4D];
            app.DSlider.Value = double(app.d4PerImage(app.imID)); 
        end
        
        function UpdateMinMaxSlider(app)
        %Updates the min and max sliders
            if ~isfield(app.data{app.imID}, 'img')
                return
            end
%             V = app.data_list{app.current_image(app.imID)}.img(:,:,:,1);
            V = app.data{app.imID}.img(:,:,:,1);
            app.MinValue = min(V(:));
            if app.MinValue <0
                app.MinValue = 0;
            end
            app.MaxValue = max(V(:));
            app.cScalePerImage{app.imID} = [app.MinValue, app.MaxValue];
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
        
        
        function StartChangingContrast(app, hit, i, j)
           %Records the point where the cursor was pressed to change 
%               x = hit.Source.Parent.Parent.CurrentPoint(1);
%               y = hit.Source.Parent.Parent.CurrentPoint(2);
                app.dragPoint   = [i, 0, j, 0];
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

            dX              = (hitx - app.dragPoint(1)) / 3;
            dY              = (hity - app.dragPoint(3)) / 3;
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
            
            app.cScalePerImage{app.imID} = [cMinVal, cMaxVal];
            Graphics.UpdateAxisScaling(app, app.axID); 
            
        end
        
        function UpdateMaxContrast(app, value)
            %Previously MaxvalSliderValueChanging
            %Calculates the new cScale based on the slider value
            next_maxvalue   = value/100*app.MaxValue;
            cVals           = app.cScalePerImage{app.imID};
            cMinVal         = cVals(1);
            if cMinVal >= next_maxvalue
                next_maxvalue = cMinVal+0.001;
            end
            app.cScalePerImage{app.imID} = [cMinVal, next_maxvalue];
            Graphics.UpdateAxisScaling(app, app.axID);  
        end
        
        function UpdateMinContrast(app, value)
            %Previously MinvalSliderValueChanging
            %Calculates the new cScale based on the slider value
            next_minvalue = value/100*app.MaxValue;
            cVals           = app.cScalePerImage{app.imID};
            cMaxVal         = cVals(2);
            if cMaxVal <= next_minvalue
                next_minvalue = cMaxVal - 0.001;
            end
            app.cScalePerImage{app.imID} = [next_minvalue, cMaxVal];
            Graphics.UpdateAxisScaling(app, app.axID); 
        end
        
        
        %% Update buttons
                
        function UpdateAxisButtons(app)
            %Updates the axisview buttons to display the correct one.
            imID    = app.imagePerAxis(app.axID);
            view    = app.viewPerImage(imID);
            
            %Reset the values
            app.AxialButton.BackgroundColor         = [.96 .96 .96];
            app.SagittalButton.BackgroundColor      = [.96 .96 .96];
            app.CoronalButton.BackgroundColor       = [.96 .96 .96];
            
            if     view == 1
                app.CoronalButton.BackgroundColor   = [.96 .96 0];
            elseif view == 2
                app.SagittalButton.BackgroundColor  = [.96 .96 0];
            elseif view == 3
                app.AxialButton.BackgroundColor     = [.96 .96 0];
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
        %Updates the UOBox widget with the different user-made ROIs.

            GUI.UpdateProfileBox(app)

            %Clear items
            app.UOBox.Items     = {};
            app.UOBox.ItemsData = [];   
            %Add ROIs
            counter     = 1;
            for idx     = 1:length(app.userObjects)
                obj  = app.userObjects{idx};
                if obj.imageIdx ~= app.imagePerAxis(app.axID)
                   continue
                end
                if obj.deleted
                    continue
                end
                if ~strcmp(app.user_profile, obj.profile)
                    continue
                end

                name     = obj.name;
                if ~ischar(name)
                       name =  num2str(name);
                end

                [view, slice]   = Objects.GetUOViewAndSlice(obj);
                view            = NiftiUtils.findProjectionFromViewDim(...
                    app, obj.imageIdx, view);
                views           = {'Cor', 'Sag', 'Ax'};
                view            = views{view};
                name            = GUI.GetUOBoxName(...
                                    name, slice, view);

                app.UOBox.Items{counter}        = name.char;
                app.UOBox.ItemsData(counter)    = obj.ID;
                counter = counter + 1;           
            end   
            
            %Add 'None'
            idx     = size(app.UOBox.Items, 2) + 1;
            app.UOBox.Items{idx}       = 'None';
            app.UOBox.ItemsData(idx)   = -1;
        end
        
        function name = GetUOBoxName(name, slice, view)
        %Creates a name that fits in the UOBox. 
        
            %25 characters
            %NAME###########slc#viw
            %        15      4   3

            dname   = 15 - length(name);
            if dname <= 0
                name = name(1:11) + "... ";
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

            name = name + slice + view;
            
        end

        function UpdateProfileBox(app)
            
            %Clear items
            app.ProfileListBox.Items     = {};
            style = uistyle("Icon", "");
            addStyle(app.ProfileListBox, style)

            %Add any profiles from UOs
            for i = 1:length(app.userObjects)
                if app.userObjects{i}.deleted
                    continue
                end

                if isempty(app.ProfileListBox.Items)
                    app.ProfileListBox.Items{1} = ...
                        app.userObjects{i}.profile;

                    %Add an icon to signify UO presence
                    style = uistyle("Icon", "uoIcon.png");
                    addStyle(app.ProfileListBox, style, "item", ...
                        length(app.ProfileListBox.Items))
                elseif ~any(contains(app.ProfileListBox.Items, ...
                        app.userObjects{i}.profile))
                    app.ProfileListBox.Items{end+1} = ...
                        app.userObjects{i}.profile;

                    %Add an icon to signify UO presence
                    style = uistyle("Icon", "uoIcon.png");
                    addStyle(app.ProfileListBox, style, "item", ...
                        length(app.ProfileListBox.Items))
                end
            end


            %Add profiles from the  preferences
            profiles = getpref('rmsstudio', 'profiles');
            for i = 1:length(profiles)
                if ~any(contains(app.ProfileListBox.Items, ...
                        profiles{i}))
                    app.ProfileListBox.Items{end+1} = ...
                        profiles{i};
                end
            end

            if any(strcmp(app.ProfileListBox.Items, app.user_profile))
                app.ProfileListBox.Value = app.user_profile;
            end
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

            %only works for newer matlab versions
            v = strsplit(version, '.');
            if str2num(v{1}) >= 9 && str2num(v{2}) > 13
                if ~app.hasUO(idx)
                    style = uistyle("Icon", "uoIcon.png");
                    addStyle(app.AvailableimagesListBox, style, "item", idx)
                else
                    style = uistyle("Icon", "");
                    addStyle(app.AvailableImagesListBox, style, "item", idx)
                end
            end
            app.hasUO(idx) = ~app.hasUO(idx);
        end
        
        %% Cursor stuff
        
        function SetCursor(app, style)
            set(app.UIFigure, 'Pointer', style)
        end
        
        function ResetCursor(app)
            %Sets the cursor for the UIFigure to an arrow icon (default)
            set(app.UIFigure, 'Pointer', 'arrow')
        end
        
        function MouseHover(app, row, column, axID)
            %Called by Interaction.MouseDraggedInImage. Checks which UO is
            %underneath the cursor (if any). Displays UO info in UOlabel.
            %Additionally displays the value of the image underneath the
            %cursor in the HoverLabel

            if isempty(app.data); return;  end
            % if GUI.isMultipleCall();  return;  end

            UOId = Objects.FindUOUnderMouse(app, row, column, axID);
            
            if app.buttonDown
                %set/reset activity timer
                eTime = toc;

                app.frameTimeLst(end+1) = eTime;
               
                text = strcat('FPS = ', ...
                    num2str(1/mean(app.frameTimeLst(end-10:end))));
                app.fpsLabel.Text = text;
                tic
                Interaction.ToggleInteractionTimer(app)
                GUI.MoveCrosshair(app, row, column, axID)
                GUI.DisplayHoverValue(app, row, column, axID)
            end

            if UOId == -1
                app.UOHoverLabel.Text = "";
                return
            end

            GUI.DisplayUOText(app, UOId)

        end

        function flag=isMultipleCall()
        %Checks whether there are multiple function calls in the function
        %stack. 
          flag = false;
          % Get the stack
          s = dbstack();
          if numel(s) <= 2
            % Stack too short for a multiple call
            return
          end
          % How many calls to the calling function are in the stack?
          names = {s(:).name};
          TF = strcmp(s(2).name,names);
          count = sum(TF);
          if count>1
            % More than 1
            flag = true;
          end
        end

        function DisplayHoverValue(app, row, column, axID)
            %Get the value of the voxel underneath the cursor and write to
            %app.HoverLabel
            
            if isnan(row) || isnan(column)
                return
            end
            
            ijk     = NiftiUtils.rc2ijk(app, row, column, axID);
            %Find value - permuted because matlab switches rows and
            %columns...
            imID    = app.imagePerAxis(axID);

            %ijk 1 and 2 are switched, because of matlab reasons
            res = app.data{imID}.img(end - ijk(2) + 1, ijk(1), ijk(3));
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
                        '\tVolume:%.2f mm^3 \tMean: %.2f \n%s');
            String   = sprintf(String,              ...               
                               Volume,              ...
                               MeanSig, ...
                               string(obj.comment));
            app.UOHoverLabel.Text = String;
        end

        %% Crosshair

        function InitCrosshair(app)
        %Finds the middle point of the image in the first UIAxes.
        %Moves the crosshair to that position.

        %Find middle of first image
        imID        = app.imagePerAxis(app.axID);  
        sz          = size(app.data{imID}.img);
        viewAxis    = app.viewPerImage(imID);
        sz(viewAxis)    = [];
        i               = round(sz(1)/2);
        j               = round(sz(2)/2);
        
        %Convert to world coordinates
        xyz         = NiftiUtils.rc2xyz(app, i, j);

        %Draw crosshair for each axis   -TODO: don't hardcode axes
        GUI.CrosshairPerAxis(app, 1, xyz)
        GUI.CrosshairPerAxis(app, 2, xyz)

        Graphics.ToggleCrosshairsInAxis(app, 1, 'off')
        Graphics.ToggleCrosshairsInAxis(app, 2, 'off')
        end


        function MoveCrosshair(app, varargin)
        %Moves the crosshair to the new position. Scrolls the images on the
        %other ax(i/e)s along with the position.

            if nargin == 2     %axID
                axID        = varargin{1};
                row         = app.crosshairPerAxis{axID}(1);
                column      = app.crosshairPerAxis{axID}(2);
                
                %Invert the column, for some reason?
                imID        = app.imagePerAxis(app.axID);  
                sz          = NiftiUtils.FindInPlaneResolution(app, imID);
                column      = sz(2) - column;
                column      = min(column, sz(2));
                column      = max(column, 1);
                xyz         = NiftiUtils.rc2xyz(app, row, column, axID);

            elseif nargin == 3     %row, column
                row         = varargin{1};
                column      = varargin{2};
                xyz         = NiftiUtils.rc2xyz(app, row, column);
            elseif nargin == 4
                row         = varargin{1};
                column      = varargin{2};
                axID        = varargin{3};
                xyz         = NiftiUtils.rc2xyz(app, row, column, axID);
            end

            %Draw crosshair for each axis   -TODO: don't hardcode axes
            GUI.CrosshairPerAxis(app, 1, xyz)
            GUI.CrosshairPerAxis(app, 2, xyz)

        end

        function CrosshairPerAxis(app, axID, varargin)
        %Finds the image position of world coordinate xyz for image imID.
        %Also calculates endpoints of the crosshair and calls the rendering
        %function
        %If the xyz position doesn't match the current slice, scroll
        
            imID        = app.imagePerAxis(axID);
            viewDim     = NiftiUtils.FindViewingDimension(app, imID);
            viewingAxis = app.viewPerImage(imID);

            if nargin == 3  %xyz is given
                xyz = varargin{1};

                %Find ijk
                tm          = app.transMatPerImage{imID};
                ijk         = NiftiUtils.xyz2ijk(app, tm, xyz, axID);
                ijk         = round(ijk');
    
                [row,column]       = NiftiUtils.ijk2rc(app, axID, ijk);
                app.crosshairPerAxis{axID} = [row,column];
            else    %xyz not given, we take the position from 
                    % app.crosshairPerAxis
                row         = app.crosshairPerAxis{axID}(1);
                column      = app.crosshairPerAxis{axID}(2);
                ijk         = NiftiUtils.rc2ijk(app, row, column, axID);
            end

            %Find slice and the image if needed
            slice       = ijk(viewDim);
            if ~isempty(app.slicePerImage{imID})
                if slice ~= app.slicePerImage{imID}{viewingAxis}
                    Interaction.UpdateSlice(app, slice, axID)
                end
            end
            
            %Draw the crosshairs
            sz  = NiftiUtils.FindInPlaneResolution(app, imID);
            Graphics.DrawCrosshairInAxis(app, axID, row, column, sz)

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
            
            m0 = uimenu(cm,'Text','Edit Points');
            m1 = uimenu(cm,'Text','Delete');
            m2 = uimenu(cm,'Text','Rename');
            m3 = uimenu(cm,'Text','Toggle Visibility');
            m4 = uimenu(cm, 'Text', 'More');

            %submenu - Delete
            d1 = uimenu(m1, 'Text', 'Delete Slice');
            d2 = uimenu(m1, "Text", 'Delete ROI');

            %submenu - Other
            s1 = uimenu(m4,'Text','Copy To');
            s2 = uimenu(m4, 'Text', 'Add Comment');
            s3 = uimenu(m4, 'Text', 'Show Histogram');
            s4 = uimenu(m4, 'Text', 'Interpolate mask slices');

            drawnow     %Necessary to display the cm
            
            %callbacks
            m0.MenuSelectedFcn = ...
                {@Objects.EditUO, app, id};
            m2.MenuSelectedFcn = ...
                {@Objects.RenameUO, app, id};
            m3.MenuSelectedFcn = ...
                {@Objects.ToggleVisibleUO, app, id};

            d1.MenuSelectedFcn = ...
                {@Objects.DeleteUOSlice, app, id};
            d2.MenuSelectedFcn = ...
                {@Objects.DeleteUO, app, id};

            s1.MenuSelectedFcn = ...
                {@Objects.CopyUOTo, app, id};
            s2.MenuSelectedFcn = ...
                {@Objects.AddComment, app, id};
            s3.MenuSelectedFcn = ...
                {@Objects.ShowHist, app, id};
            s4.MenuSelectedFcn = ...
                {@Objects.InterpSlices, app, id};

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

            close(app.progressDlg)
            app.busyStatus  = false;
            figure(app.UIFigure)    %Request focus back to the uifigure

        end
        
        
        % This prevents user interaction
        function DisableControlsStatus(app, varargin)
            title = 'Loading';
            indeterminate = 'off';
            if nargin == 2
                title = varargin{1};
            elseif nargin == 3
                title = varargin{1};
                indeterminate = varargin{2};
            end

            app.progressDlg =  uiprogressdlg(app.UIFigure, 'Title',...
                title, 'Cancelable','on', 'Indeterminate', indeterminate);
            app.busyStatus  = true;

        end

        function UpdateProgressDialogue(app, varargin)
            if nargin == 3
                msg = varargin{1};
                val = varargin{2};
            elseif nargin == 2
                msg = varargin{1};
                val = app.progressDlg.Value;
            end

            app.progressDlg.Message = msg;
            app.progressDlg.Value   = val;
        end
        
        
        function DisableAllButtonsAndActions(app)
            % Resets actions to baseline
            app.drawing.mode                            = 0;
            
            app.currentDragPoint                    = -1;
            app.dragPoint                           = [];
            
            %Turns off zooming for all axes
            zoom(app.UIAxes1, 'off')
            zoom(app.UIAxes2, 'off')
        end
    end
end