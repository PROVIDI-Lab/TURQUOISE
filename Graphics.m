classdef Graphics < handle
    %This static class deals with displaying the image and any user objects
    %on the screen. If a function does a lot with app.drawing, it belongs
    %here.
    
    methods (Static)
        
        %%Main call order for drawing in specific circumstances.
        
        function UpdateImage(app)
        %Updates the image for the current view
            Graphics.UpdateImageForAxis(app, app.current_view)
        end
        
        function UpdateUserObjects(app)
        %Updates the image for the current view
            %Don't draw anything if the image isn't drawn yet.
            if app.slicePerImage(app.imagePerAxis(app.current_view)) == -1
                return
            end
        
            Graphics.UpdateUserObjectsForAxis(app, app.current_view)
        end
        
        function UpdateUserInteractions(app)
        %Updates the user interactions for the current view
            Graphics.UpdateUserInteractionsForAxis(app, app.current_view)
        end
        
        function UpdateImageForAxis(app, axID)
        %Called when everything is redrawn
            Graphics.DrawImageInAxis(app, axID);
            %Draw user-objects
            Graphics.DrawUserObjects(app, axID);
            Graphics.UpdateUserInteractionsForAxis(app, axID);
            Graphics.UpdateUIAxesLabel(app, axID);
        end
        
        function UpdateUserObjectsForAxis(app, axID)
        %Called when the image isn't updated, but the UOs are. Doesn't 
        %redraw everything. Should be a lot quicker this way.
            Graphics.DrawChangedUserObjects(app, axID);
            Graphics.DrawPointsInAxis(app, axID);
        end
        
        function UpdateUserInteractionsForAxis(app, axID)
        %Called when the user interacts with the image (draws points, 
        %circle, etc.). Only the necessary functions are called in order
        %to have the updates be very quick.
        
            Graphics.DeleteAllTempDrawings(app);
            if app.drawing.mode == 1
                Graphics.DrawPointsInAxis(app,axID);
            elseif app.drawing.mode == 2
                Graphics.DrawROIPointsInAxis(app, axID);
            elseif app.drawing.mode == 5
                Graphics.DrawCircleInAxis(app, axID)
            end
        end
        
        function DrawUserObjects(app, axID)
        %Redraw all visible UserObjects.
        
            for idx = 1:length(app.userObjects)
                obj     = app.userObjects{idx};
                if obj.imageIdx ~= app.imagePerAxis(axID)...
                        || ~obj.visible
                    continue
                end

                switch obj.type 
                   case {1, 3}
                       Graphics.DrawROIInAxis(app, axID, obj)
                   case 2
                       Graphics.DrawMeasurementInAxis(...
                           app, axID, obj)
                   otherwise
                       continue
               end
               app.userObjects{idx}.set('changed', false);

            end
        end        
        
        
        function DrawChangedUserObjects(app, axID)
        %Draws any UserObj in app.userObjects that is both changed and 
        %visible.
            for idx = 1:length(app.userObjects)
                obj     = app.userObjects{idx};
                if obj.imageIdx ~= app.imagePerAxis(axID)...
                        || ~obj.changed ...
                        || ~obj.visible
                    continue
                end
                
                switch obj.type
                   case {1, 3}
                       Graphics.DrawROIInAxis(app, axID, obj)
                   case 2
                       Graphics.DrawMeasurementInAxis(...
                           app, axID, obj)
                   otherwise
                       continue
               end
               app.userObjects{idx}.set('changed', false);
                
            end
        end        
        
        
        %% Draw the image
        
        function DrawImageInAxis(app,axID)  
        % This draws the image slice
            if(isprop(app,'data'))
                
                the_axis    = app.GetAxis(axID);
                imID        = app.imagePerAxis(axID);
                slice       = app.slicePerImage(imID);
                view        = app.viewPerImage(imID);
                d4          = app.d4PerImage(imID);
                SL = app.data{imID};
                if(view == 3)
                    SL = SL.img(:,:,slice, d4);
                elseif(view == 2)
                    SL = SL.img(:,slice, :, d4);
                    SL = squeeze(SL);
                    SL = permute(SL,[2 1]);
                elseif(view == 1)
                    SL = SL.img(slice, :,:, d4);
                    SL = squeeze(SL);
                    SL = permute(SL,[2 1]);
                end
                
                h = imagesc(the_axis,SL);
                if isempty(app.cScalePerImage{imID})
                    app.cScalePerImage{imID} = [0 10];
%                 elseif(any(~isfinite([app.cMinValue app.cMaxValue])) ||...
%                         app.cMinValue == app.cMaxValue)
%                     app.cMinValue = 0;
%                     app.cMaxValue = 10;
                end
                try
                    set(the_axis, 'CLim', app.cScalePerImage{imID});
                catch
                    set(the_axis, 'CLim', [0,10]);
                end
                set(h,'ButtonDownFcn', @app.MouseClickedInImage);
            end          
        end
        
        
        %% Individual User Object draw methods
        function DrawROIInAxis(app, axID, obj)          
        %This draws the countour of a visible segmentation stored in obj.
        %TODO: split function
        
            the_axis    = app.GetAxis(axID);
            imID        = app.imagePerAxis(axID);
            slice       = app.slicePerImage(imID);
            img         = obj.data;
            view        = app.viewPerImage(imID);
            if(view == 3)
                imSlice = img(:,:,slice);
            elseif(view == 2)
                imSlice = squeeze(img(:,slice,:));
            elseif(view == 1)
                imSlice = squeeze(img(slice,:,:));
            end
                    
            imSlice = permute(imSlice,[2 1]);
            if(~isempty(find(imSlice,1)))
                hold(the_axis,'on');
                %First draw the contours
                if(app.should_show_selection == true)
                    [~,c]   = contour(the_axis,             ...
                    imSlice,                                     ...
                    'r',                                    ...
                    'HitTest',                              ...
                    'on',                                   ...
                    'ButtonDownFcn',                        ...
                    @app.MouseClickedInImage);
                else
                    [~,c]   = contour(the_axis,             ...
                    imSlice,                                     ...
                    'LineWidth',                            ...
                    2,                                      ...
                    'Color',                                ...
                    app.colors_list(obj.ID,:),              ...
                    'HitTest',                              ...
                    'on',                                   ...
                    'ButtonDownFcn',                        ...
                    @app.MouseClickedInImage);

                    % Now draw the annotations
                    
                    if isempty(obj.prop)
                        obj.prop.volume = 0;
                        obj.prop.mean   = 0;
                    end
                    VS       = min(app.data{imID}.hdr.dime.pixdim(2:4));
                    Area     = length(find(imSlice))*VS^2;
                    Name     = obj.name;
                    Volume   = obj.prop.volume;
                    MeanSig  = obj.prop.mean;

                    String   = strcat(Name,                 ...
                                '\nArea: %.2fmm^2\nVolume:',...
                                '%.2fmm^3\nMean: %.2f');
                    String   = sprintf(String,              ...
                                       Area,                ...
                                       Volume,              ...
                                       MeanSig);

                    [~,~,MX,MY] =                         ...
                            MathUtils.WeightedCenterOfROI(imSlice);

                    %Add label to image
                    t = text(the_axis,                      ...
                        MY,                                 ...
                        MX,                                 ...
                        String,                             ...
                        'Color',                            ...
                        app.colors_list(obj.ID,:),          ...
                        'HitTest',                          ...
                        'on',                               ...
                        'ButtonDownFcn',                    ...
                        @app.MouseClickedInImage,           ...
                        'BackgroundColor',                  ...
                        'k');
                end
                obj.graphics    = {c,t};
                hold(the_axis,'off');
            end
        end
        
        function DrawMeasurementInAxis(app, axID, obj) 
        % This draws a measurement.
            the_axis    = app.GetAxis(axID);
            hold(the_axis,'on');
            imID        = app.imagePerAxis(axID);
            slice       = app.slicePerImage(imID);
            
            P1          = obj.points(1,:);
            P2          = obj.points(2,:);
            direction   = P2-P1;
            L           = obj.prop.length;
            name        = obj.name;

            labelText   = strcat(name,'\nLength: %.2fmm');

            %Plot lines that are visible in current view
            ax = app.viewPerImage(imID);
            if P1(ax) == P2(ax) && P1(ax) == slice
                P1(ax) = [];
                P2(ax) = [];

                l   = plot(the_axis,                            ...
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
                    app.colors_list(obj.ID,:));
                % Annotate it as well
                t   = text(the_axis,                            ...
                    P1(1)-1*direction(2),                       ...
                    P1(2)-0.4*direction(1),                     ...
                    sprintf(labelText, L),                      ...
                    'Color',                                    ...
                    app.colors_list(obj.ID,:),                  ...
                    'HitTest',                                  ...
                    'on',                                       ...
                    'ButtonDownFcn',                            ...
                    @app.MouseClickedInImage,                   ...
                    'BackgroundColor',                          ...
                    'k');
                obj.graphics    = {l,t};
            end
            hold(the_axis,'off');            
        end
        
        %% Drawing the interactions of the user (points, circles etc)
        %These should update very quickly.
        
        function DrawPointsInAxis(app, axID)
            %Draws all the points stored in app.drawing.points and 
            %app. roiPoints on the screen. 
            %Input:
            %   the_axis - UIAxes objects of the view currently in focus
            
            the_axis = app.GetAxis(axID);
            
            Cv  = app.current_view;
            if ~isempty(app.tempDrawings)
                Graphics.DeleteAllTempDrawings(app);
            end
            
            %Plot app.drawing.points
            if(~isempty(app.points{Cv}))
                tmp = app.points{Cv};
                
                %only plot points on current slice
                imID    = app.imagePerAxis(axID);
                view    = app.viewPerImage(imID);
                slice   = app.slicePerImage(imID);
                
                idx             = tmp(:, view) ~= slice;
                tmp(idx,:)      = [];
                tmp(:, view)    = [];
                x               = tmp(:,1);
                y               = tmp(:,2);
                hold(the_axis,'on');
                h = plot(the_axis, x, y, '.-g');
                hold(the_axis,'off');
                app.tempDrawings = [app.tempDrawings; h];
            end
        end
        
        function DrawROIPointsInAxis(app, axID)
        %Plot app.roiPoints
            the_axis    = app.GetAxis(axID);
            imID        = app.imagePerAxis(axID);
            view        = app.viewPerImage(imID);
            slice       = app.slicePerImage(imID);
        
            for i = 1:length(app.userObjects)
                obj     = app.userObjects{i};
                if obj.imageIdx ~= imID...
                        || ~obj.visible...
                        || (obj.type ~= 1 && obj.type ~= 3)...
                        || isempty(obj.points)
                    continue
                end
            
                tmp     = obj.points;
                %Only display points in the current slice
                idx     = tmp(:, view) == slice;
                tmp     = tmp(idx,:);

                %Get x and y coordinate (of current view)
                tmp(:, view)            = [];
                x2                      = tmp(:,1);
                y2                      = tmp(:,2);
                hold(the_axis,'on');
                h2  = plot(the_axis, x2, y2, '*r');
                hold(the_axis,'off');
                app.tempDrawings = [app.tempDrawings; h2];
            end
        end
        
        function DrawCircleInAxis(app, axID)
        %Plots a circle when the user is drawing a circular ROI.
            the_axis    = app.GetAxis(axID);
            if ~isempty(app.tempDrawings)
                Graphics.DeleteAllTempDrawings(app);
            end
            x0      = app.currentCircle(1);
            y0      = app.currentCircle(2);
            x1      = app.currentCircle(3);
            y1      = app.currentCircle(4);
            rad     = pdist([x0,y0; x1,y1],'euclidean');

            nPoints = round(2 * rad * pi); 
            angles  = linspace(0, 2*pi, nPoints);
            x       = round(rad * cos(angles) + x0);
            y       = round(rad * sin(angles) + y0);
            hold(the_axis,'on');
            h = plot(the_axis, x, y, 'b-');
            hold(the_axis,'off');
            app.tempDrawings = [app.tempDrawings; h];
            
        end
        

%% Other

        function UpdateUIAxesLabel(app, axID)
            %Updates the label on the UIAxes containing the name and slice
            %number of the current image.
            
            imID        = app.imagePerAxis(axID);
            slice       = app.slicePerImage(imID);
            view        = app.viewPerImage(imID);
            maxSize     = size(app.data{imID}.img, view);
            sliceString = strcat(num2str(slice), " / ", num2str(maxSize));
            nameString  = app.AvailableimagesListBox.Items{imID};
            string      = sprintf('%s\n%s',sliceString, nameString);
            
            if axID == 1
                app.UIAxes1Label.Text = string;
            else
                app.UIAxes2Label.Text = string;
            end
        end        
        
        % Delete all points of manual drawing
        function DeleteAllTempDrawings(app)
            for ij=1:length(app.tempDrawings)
                delete(app.tempDrawings(ij));
            end
            app.tempDrawings = [];
        end
        
        % Shows selection contour for deleting
        function UpdateSelectionContour(app)
            if(app.selection_contour ~= -1)
                delete(app.seleection_contour);
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
        