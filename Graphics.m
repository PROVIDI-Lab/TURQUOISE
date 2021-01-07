classdef Graphics < handle
    %This static class deals with displaying the image and any user objects
    %on the screen. If a function does a lot with app.drawing, it belongs
    %here.
    
    methods (Static)
        
                
        % Handles all graphics updates. Todo: split in multiple sub-calls
        function UpdateImageForAxis(app,the_axis)
%             if(length(app.current_image) < img_idx)
%                 return
%             end

            Graphics.DrawImageInAxis(app,the_axis);
            
            %Draw user-objects
            Graphics.DrawROIsInAxis(app,the_axis);
            Graphics.DrawPointsInAxis(app,the_axis);
            Graphics.DrawMeasurementsInAxis(app,the_axis);
            Graphics.UpdateUIAxesLabel(app);
            
        end
        
        function UpdateUserObjectsForAxis(app, the_axis)
            %Draw user-objects
            Graphics.DrawROIsInAxis(app,the_axis);
            Graphics.DrawPointsInAxis(app,the_axis);
            Graphics.DrawMeasurementsInAxis(app,the_axis);
            Graphics.UpdateUIAxesLabel(app);
        end
        
        % This draws the image slice
        function DrawImageInAxis(app,the_axis)
            if(isprop(app,'data'))
                SL = app.data;
                if(app.view_axis == 3)
                    SL = SL.img(:,:,app.current_slice,app.current_4d_idx);
                elseif(app.view_axis == 2)
                    SL = SL.img(:,app.current_slice,:,app.current_4d_idx);
                    SL = squeeze(SL);
                    SL = permute(SL,[2 1]);
                elseif(app.view_axis == 1)
                    SL = SL.img(app.current_slice,:,:,app.current_4d_idx);
                    SL = squeeze(SL);
                    SL = permute(SL,[2 1]);
                end

                h = imagesc(the_axis,SL);
                if (isempty(app.cMinValue) || isempty(app.cMaxValue))
                    app.cMinValue = 0;
                    app.cMaxValue = 10;
                elseif(any(~isfinite([app.cMinValue app.cMaxValue])) ||     ...
                        app.cMinValue == app.cMaxValue)
                    app.cMinValue = 0;
                    app.cMaxValue = 10;
                end
                set(the_axis,'CLim',[app.cMinValue app.cMaxValue]);
                set(h,'ButtonDownFcn',@app.MouseClickedInImage);
            end          
        end
        
        % This draws ROIs and the points during drawing
        function DrawROIsInAxis(app,the_axis)          
            % Draw the ROIs
            if(~isfield(app.segmentation, 'img'))
                return
            end
            
            if(~isempty(app.segmentation.img))
                for l_id=1:max(app.segmentation.img(:))
                    L = app.segmentation.img == l_id;
                    if(app.view_axis == 3)
                        SL = L(:,:,app.current_slice);
                    elseif(app.view_axis == 2)
                        SL = squeeze(L(:,app.current_slice,:));
                    elseif(app.view_axis == 1)
                        SL = squeeze(L(app.current_slice,:,:));
                    end
                    
                    SL = permute(SL,[2 1]);
                    if(~isempty(find(SL,1)))
                        hold(the_axis,'on');
                        % Actually draw the contours
                        if(app.should_show_selection == true)
                            contour(the_axis,                       ...
                            SL,                                     ...
                            'r',                                    ...
                            'HitTest',                              ...
                            'on',                                   ...
                            'ButtonDownFcn',                        ...
                            @app.MouseClickedInImage);
                        else
                            contour(the_axis,                       ...
                            SL,                                     ...
                            'LineWidth',                            ...
                            2,                                      ...
                            'Color',                                ...
                            app.colors_list(l_id,:),                ...
                            'HitTest',                              ...
                            'on',                                   ...
                            'ButtonDownFcn',                        ...
                            @app.MouseClickedInImage);

                            % Now draw the annotations
                            VS       = min(                         ...
                                        app.data.hdr.dime.pixdim(2:4));
                            Area     = length(find(SL))*VS^2;
                            Prop     = app.segmentation.properties;
                            Name     = Prop{l_id}{1}{2};
                            Volume   = Prop{l_id}{2}{2};
                            MeanSig  = Prop{l_id}{3}{2};

                            String   = strcat(Name,                 ...
                                        '\nArea: %.2fmm^2\nVolume:',...
                                        '%.2fmm^3\nMean: %.2f');
                            String   = sprintf(String,              ...
                                               Area,                ...
                                               Volume,              ...
                                               MeanSig);

                            [Mx,My,MX,MY] =                         ...
                                    MathUtils.WeightedCenterOfROI(SL);

                            %Add label to image
                            t = text(the_axis,                      ...
                                MY,                                 ...
                                MX,                                 ...
                                String,                             ...
                                'Color',                            ...
                                app.colors_list(l_id,:),            ...
                                'HitTest',                          ...
                                'on',                               ...
                                'ButtonDownFcn',                    ...
                                @app.MouseClickedInImage,           ...
                                'BackgroundColor',                  ...
                                'k');
                        end
                        hold(the_axis,'off');
                    end
                end
            end
        end         
        
        function DrawPointsInAxis(app,the_axis)
            %Draws all the points stored in app.drawing.points and 
            %app. roiPoints on the screen. 
            %Input:
            %   the_axis - UIAxes objects of the view currently in focus
            
            
                        
            if(~isfield(app.drawing,'handles'))
                app.drawing.handles = [];
            else
                Graphics.DeleteAllDrawingPoints(app);
            end

            %Plot app.drawing.points
            if(isfield(app.drawing,'points') &&                     ...
                            ~isempty(app.drawing.points))
                tmp = app.drawing.points;
                tmp(:,app.view_axis)    = [];
                x                       = tmp(:,1);
                y                       = tmp(:,2);
                hold(the_axis,'on');
                h = plot(the_axis, x, y, '.-g');
                hold(the_axis,'off');
                app.drawing.handles = [app.drawing.handles; h];
            end
            
            %Plot app.roiPoints
            if(~isempty(app.roiPoints))
                tmp = app.roiPoints;
                
                %Only display points in the current slice
                idx     = tmp(:, app.view_axis) == app.current_slice;
                tmp     = tmp(idx,:);
                
                %Get x and y coordinate (of current view)
                tmp(:,app.view_axis)    = [];
                x2                      = tmp(:,1);
                y2                      = tmp(:,2);
                hold(the_axis,'on');
                h2 = plot(the_axis, x2, y2, '*r');
                hold(the_axis,'off');
                app.drawing.handles = [app.drawing.handles; h2];
            end
        end
        
        function DrawMeasurementsInAxis(app,the_axis) 
        % This draws the measurements
        
        % Parameters:
        % app       - rmsstudio app
        % the_axis  - 
        % img_idx   - current image view (?)
        
            if(isfield(app.drawing,'measurement_lines'))
%                 disp(app.drawing.measurement_lines);
                hold(the_axis,'on');
                
                for line_id = 1 : 2 : size(app.drawing.measurement_lines,1)
                    
                    P1        = app.drawing.measurement_lines(line_id,:);
                    P2        = app.drawing.measurement_lines(line_id+1,:);
                    direction = P2-P1;
%                     CL        = norm(direction,2);
%                     L         = CL*min(app.data.hdr.dime.pixdim(2:4));
                    L       = app.measure_length(round(line_id/2));
                    name    = app.measure_names{round(line_id/2)};
                    
                    %deal with various ways of storing the string
                    while iscell(name)
                        name        = name{1};
                    end
                    
                    labelText   = strcat(name,'\nLength: %.2fmm');
                    
                    
                    %Plot lines that are visible in current view
                    ax = app.view_axis;
                    if P1(ax) == P2(ax) && P1(ax) == app.current_slice
                        P1(ax) = [];
                        P2(ax) = [];
                        
                        plot(the_axis,                                  ...
                            [P1(1) P2(1)],                              ...
                            [P1(2) P2(2)],                              ...
                            '.-',                                       ...
                            'LineWidth',                                ...
                            2,                                          ...
                            'HitTest',                                  ...
                            'on',                                       ...
                            'ButtonDownFcn',                            ...
                            @app.MouseClickedInImage,                   ...
                            'Color',                                    ...
                            app.colors_list(line_id,:));
                        % Annotate it as well
                        text(the_axis,                                  ...
                            P1(1)-1*direction(2),                       ...
                            P1(2)-0.4*direction(1),                     ...
                            sprintf(labelText, L),                      ...
                            'Color',                                    ...
                            app.colors_list(line_id,:),                 ...
                            'HitTest',                                  ...
                            'on',                                       ...    
                            'ButtonDownFcn',                            ...
                            @app.MouseClickedInImage,                   ...
                            'BackgroundColor',                          ...
                            'k');
                    end
                end
                hold(the_axis,'off');
            end
        end
        
        
        function UpdateUIAxesLabel(app)
            %Updates the label on the UIAxes containing the name and slice
            %number of the current image.
            
            sliceString = strcat(num2str(app.current_slice), " / ",     ...
                             num2str(size(app.data.img, app.view_axis)));
            nameString  = app.AvailableimagesListBox.Items{             ...
                            app.current_image_idx};
            string      = sprintf('%s\n%s',sliceString, nameString);
            
            if app.current_view == 1
                app.UIAxes1Label.Text = string;
            else
                app.UIAxes2Label.Text = string;
            end
        end        
        
        
        % Delete all points of manual drawing
        function DeleteAllDrawingPoints(app)
            if(isfield(app.drawing,'handles'))
                for ij=1:length(app.drawing.handles)
                    delete(app.drawing.handles(ij));
                end
            end
            app.drawing.handles = [];
        end
        
        % Manages the vertices during manual drawing
        function UpdateSelectionContour(app)
            if(app.selection_contour ~= -1)
                delete(app.selection_contour);
                app.selection_contour = -1;
            end
            if(app.should_show_selection == true)
                hold(app.UIAxes1,'on');
                vert = [5 20 2*app.selector_size 2*app.selector_size];
                app.selection_contour = plot(app.UIAxes1,               ...
                    [vert(1) vert(1)+vert(3) vert(1)+vert(3) vert(1)],  ...
                    [vert(2) vert(2) vert(2)+vert(4) vert(2)+vert(4)],  ...
                    'Color',                                            ...
                    'r');
                hold(app.UIAxes1,'off');
            end
        end                                     
    end
    
end
        