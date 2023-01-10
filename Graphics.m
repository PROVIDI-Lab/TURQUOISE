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
            if isempty(app.slicePerImage)
                return
            end         
            if length(app.slicePerImage) < app.imagePerAxis(app.current_view)
                return
            end   
            imID        = app.imagePerAxis(app.current_view);
            view        = app.viewPerImage(imID);
            if app.slicePerImage{imID}{view} == -1
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
            Graphics.DrawUserObjects(app, axID);
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
            end
        end
        
        
        function DrawUserObjects(app, axID)
        %Redraw all visible UserObjects.
        
            for idx = 1:length(app.userObjects)
                obj     = app.userObjects{idx};

                %First, reset the alpha of all UOs
                set(app.UORenderer{axID}{obj.ID},'AlphaData', 0);

                %Next, draw it again, if necessary
                if obj.imageIdx ~= app.imagePerAxis(axID)...
                        || ~obj.visible || obj.deleted
                    continue
                end

                switch obj.type 
                   case {1, 3, 4}
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

        %Retired, tbd

            return
            for idx = 1:length(app.userObjects)
                obj     = app.userObjects{idx};

                %First, reset the alpha of all UOs
                set(app.UORenderer{axID}{obj.ID},'AlphaData', 0);

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
                
                %Get interpolated image slice at reference location
                imSlice     = Graphics.InterpolateImSlice(app, axID);

                set(app.imageRenderer{axID},'CData',imSlice);
            end          
        end

        function UpdateAxisParams(app, axID)
            %Update parameters of the axis, such as the limits, aspect
            %ratios, contrast scaling.
            %Adds letter showing the image orientation

            %To be called when either a new image is loaded, or a new
            %viewing axis is used.

            the_axis    = app.GetAxis(axID);
            imID        = app.imagePerAxis(axID);
            view        = app.viewPerImage(imID);

            the_axis.XLim = [0, size(app.imageRenderer{axID}.CData, 2)];
            the_axis.YLim = [0, size(app.imageRenderer{axID}.CData, 1)];
            pixdim = app.data{imID}.hdr.dime.pixdim(2:4);
            pixdim(view) = [];
            daspect(the_axis,[flip(pixdim) 1])

            %Adjust scaling
            if isempty(app.cScalePerImage{imID})
                app.cScalePerImage{imID} = [0 10];
            end
            try
                set(the_axis, 'CLim', app.cScalePerImage{imID});
            catch
                set(the_axis, 'CLim', [0,10]);
            end

            %Write axis info
            delete(app.textRenderer{axID})
            axisSizeX = the_axis.XLim(2);
            axisSizeY = the_axis.YLim(2);
            orr = NiftiUtils.FindOrientationWithAxis(...
                app.transMatPerImage{imID}, view);
            t1 = text(the_axis, 5, round(axisSizeY/2), orr(1),...
                'Color', 'Yellow', 'FontSize', 15);
            t2 = text(the_axis, axisSizeX-5, round(axisSizeY/2), orr(2),...
                'Color', 'Yellow', 'FontSize', 15);
            t3 = text(the_axis, round(axisSizeX/2), 5, orr(3),...
                'Color', 'Yellow', 'FontSize', 15);
            t4 = text(the_axis, round(axisSizeX/2), axisSizeY-5, orr(4),...
                'Color', 'Yellow', 'FontSize', 15);

            app.textRenderer{axID} = [t1, t2, t3, t4];

        end
        
        function slice = InterpolateImSlice(app, axID)
            imID        = app.imagePerAxis(axID);
            d4          = app.d4PerImage(imID);
            imData      = app.data{imID}.img(:,:,:,d4);

            viewAxis    = app.viewPerImage(imID); 
            tm          = app.transMatPerImage{imID};
            or          = NiftiUtils.FindOrientation(tm);
            imageOr     = strfind('sca', or(5)); 

            %Create meshgrid for view
            try
                [xq, yq, zq] = NiftiUtils.GetDisplayGrid(app, axID);
            catch err
                disp('Unexpected interpolation error');
            end

%             NiftiUtils.showGrid(app, axID, xq, yq, zq)

            try
                slice = squeeze(interp3(imData, xq,yq,zq, 'linear', 0));
            catch err
                disp('Unexpected interpolation error');
            end
%             imshow(slice,[])
            if(viewAxis ~= imageOr)
                slice = rot90(slice);
            end

        end
        
        %% Individual User Object draw methods
        function DrawROIInAxis(app, axID, obj)          
        %This draws the countour of a visible segmentation stored in obj.
        %TODO: split function
        
            the_axis    = app.GetAxis(axID);
            imID        = app.imagePerAxis(axID);
            img         = obj.data;
            view        = app.viewPerImage(imID);
            slice       = app.slicePerImage{imID}{view};
            if(view == 3)
                imSlice = img(:,:,slice);
            elseif(view == 2)
                imSlice = squeeze(img(:,slice,:));
            elseif(view == 1)
                imSlice = squeeze(img(slice,:,:));
            end


            col = app.colors_list(obj.ID,:);
            CData  = cat(3, ones(size(imSlice)) * col(1),...
                             ones(size(imSlice)) * col(2),...
                             ones(size(imSlice)) * col(3));
            set(app.UORenderer{axID}{obj.ID},'CData', CData);
            set(app.UORenderer{axID}{obj.ID},'AlphaData', imSlice*0.8);
            
            return

%             imSlice = permute(imSlice,[2 1]);
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
                        'k',                                ...
                        'Visible',                          ...
                        'off');
                    
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
            view        = app.viewPerImage(imID);
            slice       = app.slicePerImage{imID}{view};
            
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
                imID        = app.imagePerAxis(axID);
                view        = app.viewPerImage(imID);
                slice       = app.slicePerImage{imID}{view};
                
                idx             = tmp(:, view) ~= slice;
                tmp(idx,:)      = [];
                tmp(:, view)    = [];
                x               = tmp(:,1);
                y               = tmp(:,2);
                hold(the_axis,'on');
                h = plot(the_axis, x, y, '.-g',...
                    'HitTest',                              ...
                    'on',                                   ...
                    'ButtonDownFcn',                        ...
                    @app.MouseClickedInImage);
                hold(the_axis,'off');
                app.tempDrawings = [app.tempDrawings; h];
            end
        end
        
        function DrawROIPointsInAxis(app, axID)
        %Plot app.roiPoints
            the_axis    = app.GetAxis(axID);
            imID        = app.imagePerAxis(axID);
            view        = app.viewPerImage(imID);
            slice       = app.slicePerImage{imID}{view};
        
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
                h2  = plot(the_axis, x2, y2, '*r',          ...
                    'HitTest',                              ...
                    'on',                                   ...
                    'ButtonDownFcn',                        ...
                    @app.MouseClickedInImage);
                hold(the_axis,'off');
                app.tempDrawings = [app.tempDrawings; h2];
            end
        end

        function DrawCrosshairInAxis(app, axID, ijk, sz)
            %First, remove the previous drawing
            delete(app.crosshairRenderer{axID});
            
            the_axis    = app.GetAxis(axID);    
            hold(the_axis,'on');

            %Draw two lines
            l1  = plot(the_axis, ...
                [1, sz(1)], [ijk(2), ijk(2)], '--c',...
                'HitTest',                              ...
                'on',                                   ...
                'ButtonDownFcn',                        ...
                @app.MouseClickedInImage);
        
            l2  = plot(the_axis, ...
                [ijk(1), ijk(1)], [1, sz(2)], '--c',...
                'HitTest',                              ...
                'on',                                   ...
                'ButtonDownFcn',                        ...
                @app.MouseClickedInImage);

            hold(the_axis,'off');
            app.crosshairRenderer{axID} = [l1, l2];
        end
        

%% Other

        function UpdateUIAxesLabel(app, axID)
            %Updates the label on the UIAxes containing the name and slice
            %number of the current image.
            
            imID        = app.imagePerAxis(axID);
            view        = app.viewPerImage(imID);   %sag, cor, ax
            ijkView     = NiftiUtils.GetIJKView(app);
            slice       = app.slicePerImage{imID}{view};
            maxSize     = size(app.data{imID}.img, ijkView);
            sliceString = strcat(num2str(slice), " / ", num2str(maxSize));
            nameString  = app.studyNames{imID};
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
        