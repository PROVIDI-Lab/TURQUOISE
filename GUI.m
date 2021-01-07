classdef GUI < handle
    methods (Static)
        
        function InitGUI(app)
           %Initialises the window for when a new study is loaded.
           %Called by Study.InitStudy
           
            
%             rect = get(app.UIAxes1,'OuterPosition');
%             imagesc(app.UIAxes1,zeros(rect([4 3])));
%             colormap(app.UIAxes1,'gray');
%             axis(app.UIAxes1,'off');
            
            GUI.ResetViews(app);
            
            %Select and display the first image of the study, and if
            %possible, display the second image on the second view.
            if(~isempty(app.AvailableimagesListBox.Items))
                
                if size(app.AvailableimagesListBox.Items,2) > 1
                    app.current_view      = 2;
                    app.AvailableimagesListBox.Value =                      ...
                        app.AvailableimagesListBox.Items{2};
                    app.current_image_idx = 2;
                    %Load the image, segmentations and measurement
                    Study.LoadFromList(app, 2)
                    %Show everything
                    GUI.DisplayNewImage(app, 2)
                    %Keep track of which image is in which view
                    app.image_per_view(app.current_view) = 2;
                    
                    %Switch back
                    app.current_view = 1;
                end
                
                app.AvailableimagesListBox.Value =                      ...
                    app.AvailableimagesListBox.Items{1};
                app.current_image_idx = 1;
                %Load the image, segmentations and measurement
                Study.LoadFromList(app, 1)
                %Show everything
                GUI.DisplayNewImage(app, 1)
                %Keep track of which image is in which view
                app.image_per_view(app.current_view) = 1;
                
            end
            
            GUI.RevertControlsStatus(app);
            
        end
        
        function ResetViews(app)
            %Resets both views and switches all displaying options to their
            %default values.
            app.view_axis                        = 3;
            app.current_view                     = 1;
            app.image_per_view                   = [1,1];
           
            GUI.UpdateAxisButtons(app);
            GUI.UpdateViewButtons(app);
           
            h = imagesc(app.UIAxes1, zeros(100));
            set(h,'ButtonDownFcn',@app.MouseClickedInImage);
           
            h2 = imagesc(app.UIAxes2, zeros(100));
            set(h2,'ButtonDownFcn',@app.MouseClickedInImage);
            
        end
        
        function DisplayNewImage(app, index)
        %Initialises a new image. 
        %Input:
        %app - the RMSStudio app
        %index - index of the image in the AvailableImageBox
        
            app.view_axis                       = 3;
            app.AxialButton.BackgroundColor     = [.96 .96   0];
            app.SagittalButton.BackgroundColor  = [.96 .96 .96];
            app.CoronalButton.BackgroundColor   = [.96 .96 .96];
            app.zoomToggle                      = false;
            app.current_4d_idx  = 1;
            
            
            %Find correct slice
            if isempty(app.current_slice)
                app.current_slice   = round(size(                       ...
                                            app.data.img,               ...
                                            app.view_axis)/2);
            elseif app.current_slice == -1 ||                           ...
                   app.current_slice >= size(app.data.img,app.view_axis)
                app.current_slice   = round(size(                       ...
                                            app.data.img,               ...
                                            app.view_axis)/2);
            end
            
            %Reset zoom level
            ax  = [app.UIAxes1, app.UIAxes2];
            ax  = ax(app.current_view);
            ax.XLim = [-inf, inf];
            ax.YLim = [-inf, inf];
                        
            %Update all GUI elements
            app.UpdateSliceSlider();
            app.UpdateMinMaxSlider();
            ROI.UpdateROIBox(app);
            
            app.UpdateImage();
            pause(0.05);
            drawnow
            
%             fn = app.AvailableimagesListBox.Items{index};
%             app.WorkingonnothingloadedLabel.Text = ['Working on: ' fn];
            GUI.RevertControlsStatus(app);
            
        end        
        
        function DisplayError(app)
            %Changes the statuslamp to show an error has occurred
            app.AvailableimagesListBox.Enable = 'on';
            app.StatusLamp.Color     = [0.9100 0.4100 0.1700];
            app.StatusLampLabel.Text = 'Error';
        end
        
        function UpdateViewButtons(app)
            %Updates the view buttons to display the correct one.
            view    = app.current_view;
            
            %Reset the values
            app.View1Button.BackgroundColor     = [.96 .96 .96];
            app.View2Button.BackgroundColor  = [.96 .96 .96];
            
            if     view == 1
                app.View1Button.BackgroundColor   = [.96 .96 0];
            elseif view == 2
                app.View2Button.BackgroundColor  = [.96 .96 0];
            end
        end
        
        function UpdateAxisButtons(app)
            %Updates the axisview buttons to display the correct one.
            axis    = app.view_axis;
            
            %Reset the values
            app.AxialButton.BackgroundColor     = [.96 .96 .96];
            app.SagittalButton.BackgroundColor  = [.96 .96 .96];
            app.CoronalButton.BackgroundColor   = [.96 .96 .96];
            
            if     axis == 1
                app.CoronalButton.BackgroundColor   = [.96 .96 0];
            elseif axis == 2
                app.SagittalButton.BackgroundColor  = [.96 .96 0];
            elseif axis == 3
                app.CoronalButton.BackgroundColor   = [.96 .96 0];
            end
        end
        
        
        function SetButtonDownFcn(app)
           %Sets the button down function on all the UIAxes children, 
           %except for the last (the image), to trigger the
           %MouseClickedInImage function.
           
           %UIAxes1
           children     = get(app.UIAxes1,'Children');
           children     = children(1:end-1);
%            set(children,'HitTest','off')
           set(children,'ButtonDownFcn',@app.MouseClickedInImage);
           
           %UIAxes2
           children     = get(app.UIAxes2,'Children');
           children     = children(1:end-1);
%            set(children,'HitTest','off')
           set(children,'ButtonDownFcn',@app.MouseClickedInImage);
            
        end
        
        function RemoveButtonDownFcn(app)
           %Removes the button down function on all the UIAxes children, 
           %except for the last (the image).
           
           %UIAxes1
           children     = get(app.UIAxes1,'Children');
           children     = children(1:end-1);
%            set(children,'HitTest','off')
           set(children,'ButtonDownFcn','');
           
           %UIAxes2
           children     = get(app.UIAxes2,'Children');
           children     = children(1:end-1);
%            set(children,'HitTest','off')
           set(children,'ButtonDownFcn','');
            
        end
        
        
        
        % This prevents user interaction
        function RevertControlsStatus(app,only_non_action_buttons)
            if(nargin < 2 || only_non_action_buttons == false)
%                 app.SelectDeleteButton.Enable           = 'on';
%                 app.UndoButton.Enable                   = 'on';
%                 app.SelectionsensitivityButton.Enable   = 'on';
%                 app.DrawpolygonButton.Enable            = 'on';
%                 app.DeleteROIsALLButton.Enable          = 'on';
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
            
            if(~isempty(app.data) && ndims(app.data.img) > 3)
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
        
        
        % This enables it back (user interaction)
        function DisableControlsStatus(app,only_action_buttons)
            app.FileMenu.Enable                     = 'off';
            app.ViewMenu.Enable                     = 'off';
            app.AnalyseMenu.Enable                  = 'off';
            app.DrawMenu.Enable                     = 'off';
            app.SegmentMenu.Enable                  = 'off';
%             app.SelectDeleteButton.Enable           = 'off';
%             app.UndoButton.Enable                   = 'off';
%             app.SelectionsensitivityButton.Enable   = 'off';
%             app.DrawpolygonButton.Enable            = 'off';
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
            app.should_show_selection               = false;
            app.drawing.active                      = false;
            app.drawing.magic                       = false;
            app.drawing.measure_line                = false;
            app.drawing.edit                        = false;
            
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