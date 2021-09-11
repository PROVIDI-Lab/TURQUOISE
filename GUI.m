classdef GUI < handle
    methods (Static)
        
        function InitGUI(app)
           %Initialises the window for when a new study is loaded.
           %Called by Study.InitStudy
           
            
%             rect = get(app.UIAxes1,'OuterPosition');
%             imagesc(app.UIAxes1,zeros(rect([4 3])));
%             colormap(app.UIAxes1,'gray');
%             axis(app.UIAxes1,'off');
            

            %Enable all menus
            app.ViewMenu.Enable     = 'on';
            app.AnalyseMenu.Enable  = 'on';
            app.DrawMenu.Enable     = 'on';
            app.SegmentMenu.Enable  = 'on';


            GUI.ResetViews(app);
            
            %Select and display the first image of the study, and if
            %possible, display the second image on the second view.
            if(~isempty(app.AvailableimagesListBox.Items))
                
                if size(app.AvailableimagesListBox.Items,2) > 1
                    app.current_view      = 2;
                    %Keep track of which image is in which view
                    app.imagePerAxis(app.current_view) = 2;
                    app.AvailableimagesListBox.Value =...
                        app.AvailableimagesListBox.Items{2};
                    app.imIdx = 2;
                    %Show everything
                    GUI.DisplayNewImage(app, 2)
                    
                    %Switch back
                    app.current_view = 1;
                end
                %Keep track of which image is in which view
                app.imagePerAxis(app.current_view) = 1;
                app.AvailableimagesListBox.Value =                      ...
                    app.AvailableimagesListBox.Items{1};
                app.imIdx = 1;
                
                %Show everything
                GUI.DisplayNewImage(app, 1)
                
            end
            
            GUI.RevertControlsStatus(app);
            
        end
        
        function h = SetupAxis(the_ax)
        %Constructs the UIAxes
            rect = get(the_ax,'OuterPosition');
            bg = zeros(rect([4 3]));
            bg(round(end/2),round(end/2)) = 1;
            h = imagesc(the_ax,bg);
            colormap(the_ax,'gray');
            axis(the_ax,'off');
            the_ax.BackgroundColor = 'k';
        end
        
        function ResetViews(app)
            %Resets both views and switches all displaying options to their
            %default values.
%             app.view_axis                        = 3;
            app.slicePerImage       = ones(1,length(app.slicePerImage))*-1;
            app.viewPerImage        = ones(1,length(app.viewPerImage))*3;
            app.current_view        = 1;
            app.imagePerAxis        = [1,1];
            app.Align               = '';
           
            GUI.UpdateAxisButtons(app);
            GUI.UpdateViewButtons(app);
            GUI.UpdateAlignButtons(app);
           
            h = imagesc(app.UIAxes1, zeros(100));
            set(h,'ButtonDownFcn',@app.MouseClickedInImage);
           
            h2 = imagesc(app.UIAxes2, zeros(100));
            set(h2,'ButtonDownFcn',@app.MouseClickedInImage);
            
        end
        
        function DisplayNewImage(app, index)
        %Changes the GUI to display an image that hasn't been displayed 
        %before. 
        %Input:
        %app - the RMSStudio app
        %index - index of the image in the AvailableImageBox
            
%             app.view_axis               = 3;
            GUI.UpdateAxisButtons(app);
            app.zoomToggle              = false;
            app.slicePerImage(index)    = round(size(...
                                            app.data{index}.img,3)/2);
            %Set axis limits
            ax      = app.GetAxis(app.current_view);
            imSize  = size(app.data{index}.img);
            ax.XLim = [0, imSize(1)];
            ax.YLim = [0, imSize(2)];
                        
            %Update all GUI elements
            GUI.UpdateSliceSlider(app);
            GUI.UpdateMinMaxSlider(app);
            GUI.UpdateUOBox(app);
            
            Graphics.UpdateImage(app);            
        end  
        
        function SwitchImage(app, index)
        %Changes the GUI to display an image that has been displayed 
        %before. 
        %Input:
        %app - the RMSStudio app
        %index - index of the image in the AvailableImageBox

            GUI.UpdateAxisButtons(app)
            app.zoomToggle      = false;
                        
            %Update all GUI elements
            GUI.UpdateSliceSlider(app);
            GUI.UpdateMinMaxSlider(app);
            GUI.UpdateUOBox(app);
            
            Graphics.UpdateImage(app);
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
            
            verticalScrollCount     = event.VerticalScrollCount;
            verticalScrollAmount    = MathUtils.GetScrollAmount(app);
            verticalScrollAmount    = verticalScrollAmount * ...
                                        verticalScrollCount;
                                    
            axID    = GUI.FindAxisUnderCursor(app, event);
            if axID == -1
                return
            end
            imID    = app.imagePerAxis(axID);
            
            if app.ctrl %Zoom instead of scrolling
                scrollCount     = verticalScrollAmount;
                GUI.ZoomAxis(app, axID, scrollCount, event);                
                return
            end
            
            slice   = app.slicePerImage(imID) - verticalScrollAmount;
            Interaction.UpdateSlice(app, slice, axID);
            
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
        
        function ZoomAxis(app, axID, scrollCount, event)
            
            the_axis        = app.GetAxis(axID);
            zoomAmount      = scrollCount * 0.02; 
            imID            = app.imagePerAxis(axID);
            
            %Zoom in x direction            
            xDelta           = the_axis.XLim(2) - the_axis.XLim(1);
            if xDelta == Inf
                xDelta   = size(app.data{imID}.img, 1);
            end
            
            xMinAxis        = the_axis.Position(1);
            xPos            = event.Source.CurrentPoint(1) - xMinAxis;
            xPos            = xPos / the_axis.Position(3) * ...
                                xDelta + the_axis.XLim(1);                            
            xDelta          = xDelta * (1 + zoomAmount); %Add minimum change?
            [xMin, xMax]    = MathUtils.GetNewRange(xDelta, xPos, ...
                                    the_axis.XLim(1), the_axis.XLim(2));                                
            the_axis.XLim   = [xMin, xMax];
            
            %Zoom in y direction            
            yDelta           = the_axis.YLim(2) - the_axis.YLim(1);
            if yDelta == Inf
                yDelta   = size(app.data{imID}.img, 1);
            end
            
            yPos        = the_axis.Position(2) + the_axis.Position(4) -...
                            event.Source.CurrentPoint(2);
            yPos            = yPos / the_axis.Position(4) * ...
                    yDelta + the_axis.YLim(1);
            yDelta          = yDelta * (1 + zoomAmount);
            [yMin, yMax]    = MathUtils.GetNewRange(yDelta, yPos, ...
                                    the_axis.YLim(1), the_axis.YLim(2));                
                                
            the_axis.YLim   = [yMin, yMax];
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
            if(isempty(app.data{app.current_view}))
                return
            end
            
            %Get data dimensions
            refvol  = app.data{app.imIdx}.img;
            slice   = app.slicePerImage(app.imIdx);
            
            %Update SliceSlider
            viewAxis    = app.viewPerImage(app.imIdx);
            viewSize    = size(refvol, viewAxis);
            app.SliceSlider.Limits = [1 viewSize];
            max_ticks = 4;
            step = round(viewSize / (max_ticks-1));
            app.SliceSlider.MajorTicks =  [1 : step : viewSize viewSize];
            app.SliceSlider.MinorTicks = 1 : 1 : viewSize;
            if isnan(slice)
                slice = round( viewSize / 2);
                app.slicePerImage(app.imIdx) = slice;
            end
            app.SliceSlider.Value = double(slice);
            
        end
        
        function Update4DSlider(app)
            %Updates the slider that sets the 4d axis
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
        
        function AdjustContrast(app, hitx, hity)
            
            dX              = hitx - app.dragPoint(1);
            dY              = hity - app.dragPoint(3);
            app.MinValue    = max(min(100, dX),0);
            app.MaxValue    = max(min(100, dY),0);
            
            app.cMinValue = app.MinValue;
            app.cMaxValue = app.MaxValue;
            
            app.MinvalSlider.MajorTicks = [0 50 100];
            app.MinvalSlider.Value      =...
                double(floor(app.MinValue/app.MaxValue*100));
            app.MaxvalSlider.MajorTicks = [0 50 100];
            app.MaxvalSlider.Value      =...
                double(floor(app.MaxValue/app.MaxValue*100));
            
            
        end
        
        
        %% Update buttons
        
        function UpdateViewButtons(app)
            %Updates the view buttons to display the correct one.
            view    = app.current_view;
            
            %Reset the values
            app.View1Button.BackgroundColor     = [.96 .96 .96];
            app.View2Button.BackgroundColor     = [.96 .96 .96];
            
            if     view == 1
                app.View1Button.BackgroundColor = [.96 .96 0];
            elseif view == 2
                app.View2Button.BackgroundColor = [.96 .96 0];
            end
        end
        
        function UpdateAxisButtons(app)
            %Updates the axisview buttons to display the correct one.
            imID    = app.imagePerAxis(app.current_view);
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
        
        %% UOBox
        
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

                name     = obj.name;
                if ~ischar(name)
                       name =  num2str(name);
                end

                [view, slice]   = GUI.GetUOViewAndSlice(obj);
                views           = {'Sag', 'Cor', 'Ax'};
                view            = views{view};
                types           = {'ROI', 'MSR', 'ROI'};
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
                    app.userObjects{UOidx}.setVisible(value);
                end
            else
                app.userObjects{idx}.setVisible(value);
            end
            
            Graphics.UpdateUserObjects(app);
                
        end
        
        
        %% Enable / disable user interaction
        
        function SetButtonDownFcn(app)
           %Sets the button down function on all the tempDrawings objects.
           set(app.tempDrawings, 'ButtonDownFcn',@app.MouseClickedInImage);
%            %UIAxes1
%            children     = get(app.UIAxes1,'Children');
%            children     = children(1:end-1);
% %            set(children,'HitTest','off')
%            set(children,'ButtonDownFcn',@app.MouseClickedInImage);
%            
%            %UIAxes2
%            children     = get(app.UIAxes2,'Children');
%            children     = children(1:end-1);
% %            set(children,'HitTest','off')
%            set(children,'ButtonDownFcn',@app.MouseClickedInImage);
%             
        end
        
        function RemoveButtonDownFcn(app)
           %Removes the button down function on all the tempDrawings
           set(app.tempDrawings, 'ButtonDownFcn','');
%            %UIAxes1
%            children     = get(app.UIAxes1,'Children');
%            children     = children(1:end-1);
% %            set(children,'HitTest','off')
%            set(children,'ButtonDownFcn','');
%            
%            %UIAxes2
%            children     = get(app.UIAxes2,'Children');
%            children     = children(1:end-1);
% %            set(children,'HitTest','off')
%            set(children,'ButtonDownFcn','');
            
        end
        
        % This enables it back (user interaction)
        function RevertControlsStatus(app,only_non_action_buttons)
            if(nargin < 2 || only_non_action_buttons == false)
%                 app.SelectDeleteButton.Enable           = 'on';
%                 app.UndoButton.Enable                   = 'on';
%                 app.SelectionsensitivityButton.Enable   = 'on';
                app.DrawPolygonButton.Enable            = 'on';
                app.EditPolygonButton.Enable            = 'on';
                app.AlignLRButton.Enable                = 'on';
                app.AlignRLButton.Enable                = 'on';
                app.VisibleSlider.Enable                = 'on';
%                 app.MagicdrawButton.Enable              = 'on';
%                 app.SensitivitySlider.Enable            = 'on';
%                 app.DCheckBox.Enable                    = 'on';
%                 app.AlignlabelsButton.Enable            = 'on';
%                 app.AlgorithmDropDown.Enable            = 'on';
%                 app.MeasureAutoButton.Enable            = 'on';
%                 app.MeasureLineButton.Enable            = 'on';
                app.FileMenu.Enable                     = 'on';
                app.ViewMenu.Enable                     = 'on';
                app.AnalyseMenu.Enable                  = 'on';
                app.DrawMenu.Enable                     = 'on';
                app.SegmentMenu.Enable                  = 'on';
            end
            
%             app.LoadLabelsButton.Enable         = 'on';
%             app.SaveeditedsegmButton.Enable     = 'on';
            app.CoronalButton.Enable            = 'on';
            app.SagittalButton.Enable           = 'on';
            app.AxialButton.Enable              = 'on';
            app.SliceSlider.Enable              = 'on';
            app.MinvalSlider.Enable             = 'on';
            app.MaxvalSlider.Enable             = 'on';
%             app.LoadButton.Enable               = 'on';
            app.AvailableimagesListBox.Enable   = 'on';
%             app.ResetstudyButton.Enable         = 'on';
            app.SliceDecreaseButton.Enable      = 'on';
            app.SliceIncreaseButton.Enable      = 'on';
%             app.ShufflecolorsButton.Enable      = 'on';
            
            Cv      = app.current_view;
            if(~isempty(app.data{Cv}) && ndims(app.data{Cv}.img) > 3)
                app.DSlider.Enable          = 'on';
                app.Decrease4DButton.Enable = 'on';
                app.Increase4DButton.Enable = 'on';
            end
            
            app.View1Button.Enable          = 'on';
            app.View2Button.Enable          = 'on';
            app.StatusLampLabel.Text        = 'Idle';
            app.StatusLamp.Color            = 'g';
%             app.Labels3DButton.Enable       = 'on';
%             app.LabelsstatsButton.Enable    = 'on'; 
        end
        
        
        % This prevents user interaction
        function DisableControlsStatus(app,only_action_buttons)
            app.FileMenu.Enable                     = 'off';
            app.ViewMenu.Enable                     = 'off';
            app.AnalyseMenu.Enable                  = 'off';
            app.DrawMenu.Enable                     = 'off';
            app.SegmentMenu.Enable                  = 'off';
%             app.SelectDeleteButton.Enable           = 'off';
%             app.UndoButton.Enable                   = 'off';
%             app.SelectionsensitivityButton.Enable   = 'off';
            app.DrawPolygonButton.Enable            = 'off';
            app.EditPolygonButton.Enable            = 'off';
            app.AlignLRButton.Enable                = 'off';
            app.AlignRLButton.Enable                = 'off';
%             app.DeleteROIsALLButton.Enable          = 'off';
%             app.MagicdrawButton.Enable              = 'off';
%             app.SensitivitySlider.Enable            = 'off';
%             app.AlignlabelsButton.Enable            = 'off';
%             app.AlgorithmDropDown.Enable            = 'off';
%             app.MeasureAutoButton.Enable            = 'off';
%             app.MeasureLineButton.Enable            = 'off';
%             app.DCheckBox.Enable                    = 'off';
%             app.Labels3DButton.Enable               = 'off'; 
%             app.LabelsstatsButton.Enable            = 'off'; 
            if(nargin > 1 && only_action_buttons == true)
                return
            end
%             app.LoadLabelsButton.Enable         = 'off';
%             app.SaveeditedsegmButton.Enable     = 'off';
            app.CoronalButton.Enable            = 'off';
            app.SagittalButton.Enable           = 'off';
            app.AxialButton.Enable              = 'off';
            app.SliceSlider.Enable              = 'off';
            app.MinvalSlider.Enable             = 'off';
            app.MaxvalSlider.Enable             = 'off';
%             app.LoadButton.Enable               = 'off';
            app.AvailableimagesListBox.Enable   = 'off';
%             app.ResetstudyButton.Enable         = 'off';
            app.SliceDecreaseButton.Enable      = 'off';
            app.SliceIncreaseButton.Enable      = 'off';
            app.Decrease4DButton.Enable         = 'off';
            app.Increase4DButton.Enable         = 'off';
            app.View1Button.Enable              = 'off';
            app.View2Button.Enable              = 'off';
%             app.ShufflecolorsButton.Enable      = 'off';
            app.DSlider.Enable                  = 'off';
            app.StatusLampLabel.Text            = 'Busy';
            app.StatusLamp.Color                = 'r';
        end
        
        
        function DisableAllButtonsAndActions(app)
            % Resets actions to baseline
            app.should_show_selection                   = false;
            app.drawing.mode                            = 0;
            
            app.currentDragPoint                    = -1;
            app.dragPoint                           = [];
%             app.DrawpolygonButton.BackgroundColor   = [.96 .96 .96];
%             app.SelectDeleteButton.BackgroundColor  = [.96 .96 .96];
%             app.MagicdrawButton.BackgroundColor     = [.96 .96 .96];
%             app.MeasureLineButton.BackgroundColor   = [.96 .96 .96];
            
%             app.current_view                        = 1;
%             app.View1Button.BackgroundColor         = [.96 .96 0];
%             app.View2Button.BackgroundColor         = [.96 .96 .96];
            
            %Turns off zooming for all axes
            zoom(app.UIAxes1, 'off')
            zoom(app.UIAxes2, 'off')
        end
    end
end