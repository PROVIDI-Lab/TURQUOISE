classdef Graphics < handle
    %This static class deals with displaying the image and any user objects
    %on the screen. If a function does a lot with app.drawing, it belongs
    %here.
    
    methods (Static)
        
        %%Main call order for drawing in specific circumstances.
        
        function UpdateAxes(app)   
        %Updates all axes
            Graphics.UpdateImageForAxis(app, 1)
            Graphics.UpdateImageForAxis(app, 2)
        end

        function UpdateImage(app)   
        %Updates the image for the current view
            Graphics.UpdateImageForAxis(app, app.axID)
        end
        
        function UpdateUserObjects(app)
        %Updates the image for the current view
            %Don't draw anything if the image isn't drawn yet.
            if isempty(app.slicePerImage)
                return
            end         
            if length(app.slicePerImage) < app.imagePerAxis(app.axID)
                return
            end   
   
            imID        = app.imagePerAxis(app.axID);
            view        = app.viewPerImage(imID);
            
            if isempty(app.slicePerImage{imID})
                return
            end
            if app.slicePerImage{imID}{view} == -1
                return
            end
        
            Graphics.UpdateUserObjectsForAxis(app, app.axID)
        end
        
        function UpdateUserInteractions(app)
        %Updates the user interactions for the current view
            Graphics.UpdateUserInteractionsForAxis(app, app.axID)
        end
        
        function UpdateImageForAxis(app, axID)
        %Called when everything is redrawn
            Graphics.DrawImageInAxis(app, axID);

            %Draw user-objects
            Graphics.DrawUserObjects(app, axID);
            Graphics.UpdateUserInteractionsForAxis(app, axID);
            Graphics.UpdateUIAxesLabel(app, axID);

            %Important line: If we don't block callbacks while drawing the
            %image, the view can freeze permanently :(
            drawnow limitrate nocallbacks

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
        

            if isempty(app.UORenderer{axID})
                return
            end

            for idx = Objects.GetAllUOIdxForImage(app, ...
                    app.imagePerAxis(axID))

                obj     = app.userObjects{idx};

                %draw the UO, if necessary
                if ~obj.visible
                    continue
                end

                %reset the alpha of all UOs on the axis
                set(app.UORenderer{axID}{obj.ID},'AlphaData', 0);

                switch obj.type 
                   case {1, 3, 4}
                       Graphics.DrawROIInAxis(app, axID, obj, idx)
                   case 2
                       Graphics.DrawMeasurementInAxis(...
                           app, axID, obj)
                   otherwise
                       continue
                end
            end
        end        
           
        
        
        %% Draw the image
        
        function DrawImageInAxis(app,axID)  
        % This draws the image slice
            if isempty(app.data)
                return
            end
                
            imID        = app.imagePerAxis(axID);
            d4          = app.d4PerImage(imID);
            viewAxis    = app.viewPerImage(imID); %1=cor, 2=sag, 3=ax
            tm          = app.transMatPerImage{imID};
            or          = NiftiUtils.FindOrientation(tm);
            imageOr     = strfind('csa', or(5)); %1=cor, 2=sag, 3=ax
            slice       = app.slicePerImage{imID}{viewAxis};

            imSlice     = MathUtils.ApplyProjection(...
                app, true, imID, d4, imageOr, viewAxis, slice);

            % figure;
            % imshow(imSlice,[])
            set(app.imageRenderer{axID}, 'CData', imSlice);

        end
        
        
        %% Individual User Object draw methods
        function DrawROIInAxis(app, axID, obj, idx)          
        %This draws the mask of a visible segmentation stored in obj.

            imID        = app.imagePerAxis(axID);
            viewAxis    = app.viewPerImage(imID); 
            tm          = app.transMatPerImage{imID};
            or          = NiftiUtils.FindOrientation(tm);
            imageOr     = strfind('csa', or(5)); 
            slice       = app.slicePerImage{imID}{viewAxis};

            maskSlice   = MathUtils.ApplyProjection(...
                app, false, idx, 1, imageOr, viewAxis, slice);

            col = app.colors_list(obj.ID,:);

            %Very ugly expression..
            %Basically creates an RGB version of imslice multiplied by the
            %colour vector
            set(app.UORenderer{axID}{obj.ID},'CData', ...
                repmat(reshape(col, [1,1,3]), size(maskSlice)) .*...
                    repmat(maskSlice, 1,1,3));
            %Set the UO to be slightly transparent
            %TODO, get transparency from a setting
            set(app.UORenderer{axID}{obj.ID},'AlphaData', maskSlice*0.4);
        end

        function DrawTmpROIInAxis(app, axID, segmentation, opacity, color)

            imID        = app.imagePerAxis(axID);
            viewAxis    = app.viewPerImage(imID); 
            tm          = app.transMatPerImage{imID};
            or          = NiftiUtils.FindOrientation(tm);
            imageOr     = strfind('csa', or(5)); 
            slice       = app.slicePerImage{imID}{viewAxis};

            maskSlice   = MathUtils.ApplyProjectionToArray(segmentation, imageOr, viewAxis, slice);

            %Set the roi to be slightly transparent
            set(app.tmpRenderer{axID},'CData', ...
                repmat(reshape(color, [1,1,3]), size(maskSlice)) .*...
                    repmat(maskSlice, 1,1,3));
            set(app.tmpRenderer{axID},'AlphaData', maskSlice*opacity);

        end

        function ResetTmpROI(app, axID)
            set(app.tmpRenderer{axID},'AlphaData', 0);
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
            
            if ~isempty(app.tempDrawings)
                Graphics.DeleteAllTempDrawings(app);
            end
            
            %Plot app.points
            if isempty(app.points{app.axID})
                return
            end
                
            %Get display coords
            imID     = app.imagePerAxis(axID);
            viewAxis = app.viewPerImage(imID);
            slice   = app.slicePerImage{imID}{viewAxis};
            [x,y]   = NiftiUtils.ijk2rc(app, axID, ...
                app.points{app.axID}, slice);
               
            %plot points
            hold(the_axis,'on');
            h = plot(the_axis, x, y, '.-g',...
                'HitTest',                              ...
                'on',                                   ...
                'ButtonDownFcn',                        ...
                @app.MouseClickedInImage);
            hold(the_axis,'off');
            app.tempDrawings = [app.tempDrawings; h];
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

        function DrawCrosshairInAxis(app, axID, x, y, sz)


            %Adjust the crosshair plots
            set(app.crosshairRenderer{axID}(1), 'XData',...
                [1, sz(2)]);
            set(app.crosshairRenderer{axID}(1), 'YData',...
                [y, y]);

            set(app.crosshairRenderer{axID}(2), 'XData',...
                [x, x]);
            set(app.crosshairRenderer{axID}(2), 'YData',...
                [1, sz(1)]);

        end

        function SetMotionGraphics(app)
            %When the user is scrolling through the image, changes settings
            %to display smoother animations.

            %TODO: for each axis...

            Graphics.ToggleCrosshairsInAxis(app, 1, 'on')
            Graphics.ToggleCrosshairsInAxis(app, 2, 'on')

            % set(app.imageRenderer{1}, "MaxRenderedResolution", 300)
            % set(app.imageRenderer{2}, "MaxRenderedResolution", 300)

        end

        function SetStaticGraphics(app)
            %When the user stops scrolling, changes settings back to
            %display static, high-detail graphics.

            %TODO: for each axis...

            Graphics.ToggleCrosshairsInAxis(app, 1, 'off')
            Graphics.ToggleCrosshairsInAxis(app, 2, 'off')

            % set(app.imageRenderer{1}, "MaxRenderedResolution", "None")
            % set(app.imageRenderer{2}, "MaxRenderedResolution", "None")

        end

        function ToggleCrosshairsInAxis(app, axID, state)

            app.crosshairRenderer{axID}(1).Visible = state;
            app.crosshairRenderer{axID}(2).Visible = state;
        end

                        
        

%% Other

        function UpdateUIAxesLabel(app, axID)
            %Updates the label on the UIAxes containing the name and slice
            %number of the current image.
            
            imID        = app.imagePerAxis(axID);
            view        = app.viewPerImage(imID);   %sag, cor, ax
            viewDim     = NiftiUtils.FindViewingDimension(app, imID);
            slice       = app.slicePerImage{imID}{view};
            maxSize     = size(app.data{imID}.img, viewDim);
            sliceString = [int2str(slice), ' / ', int2str(maxSize)];
            nameString  = app.sessionNames{imID};
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
        
        function ResetTextRenderer(app)
            %Resets the AP/SI/LR labels to the default color

            numAxes = 2;    %can be changed when dynamic axes are supported
            for axID = 1:numAxes

                the_axis    = app.GetAxis(axID);
                imID        = app.imagePerAxis(axID);
                view        = app.viewPerImage(imID);

                %Write axis info
                delete(app.textRenderer{axID})
                axisSizeX = the_axis.XLim(2);
                axisSizeY = the_axis.YLim(2);
    
                col = 'Yellow';
                orr = NiftiUtils.FindOrientationWithAxis(...
                    app.transMatPerImage{imID}, view);
                t1 = text(the_axis, 5, round(axisSizeY/2), orr(1),...
                    'Color', col, 'FontSize', 15);
                t2 = text(the_axis, axisSizeX-5, round(axisSizeY/2), orr(2),...
                    'Color', col, 'FontSize', 15);
                t3 = text(the_axis, round(axisSizeX/2), 5, orr(3),...
                    'Color', col, 'FontSize', 15);
                t4 = text(the_axis, round(axisSizeX/2), axisSizeY-5, orr(4),...
                    'Color', col, 'FontSize', 15);
    
                app.textRenderer{axID} = [t1, t2, t3, t4];
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
            viewDim     = NiftiUtils.FindViewingDimension(app, imID);
            sz          = size(app.imageRenderer{axID}.CData);

            the_axis.XLim = [0, sz(2)];
            the_axis.YLim = [0, sz(1)];

            pixdim = app.data{imID}.hdr.dime.pixdim(2:4);
            pixdim(viewDim) = [];
            
            if sz(2) > sz(1)
                daspect(the_axis,[max(pixdim), min(pixdim) 1])
            elseif sz(2) < sz(1)
                daspect(the_axis,[min(pixdim), max(pixdim) 1])
            else
                daspect(the_axis, [1,1,1])
            end


            Graphics.UpdateOrientationInfoOnAxis(app, axID)

        end

        function UpdateOrientationInfoOnAxis(app, axID)

            %Write axis info
            delete(app.textRenderer{axID})
            
            the_axis    = app.GetAxis(axID);
            axisX0 = the_axis.XLim(1);
            axisX1 = the_axis.XLim(2);
            axisY0 = the_axis.YLim(1);
            axisY1 = the_axis.YLim(2);

            axisXMid = axisX0 + (axisX1-axisX0) / 2;
            axisYMid = axisY0 + (axisY1-axisY0) / 2;

            col = 'Green';
            imID        = app.imagePerAxis(axID);
            view        = app.viewPerImage(imID);
            orr = NiftiUtils.FindOrientationWithAxis(...
                app.transMatPerImage{imID}, view);
            t1 = text(the_axis, axisX0, axisYMid, orr(1),...
                'Color', col, 'FontSize', 15);
            t2 = text(the_axis, axisX1, axisYMid, orr(2),...
                'Color', col, 'FontSize', 15);
            t3 = text(the_axis, axisXMid, axisY0, orr(3),...
                'Color', col, 'FontSize', 15);
            t4 = text(the_axis, axisXMid, axisY1, orr(4),...
                'Color', col, 'FontSize', 15);

            app.textRenderer{axID} = [t1, t2, t3, t4];

        end

        function UpdateAxisScaling(app, axID)

            the_axis    = app.GetAxis(axID);
            imID        = app.imagePerAxis(axID);

            %Adjust scaling
            if isempty(app.cScalePerImage{imID})
                app.cScalePerImage{imID} = [0 10];
            end
            try
                set(the_axis, 'CLim', app.cScalePerImage{imID});
            catch
                app.cScalePerImage{imID} = [0 10];
                set(the_axis, 'CLim', app.cScalePerImage{imID});
            end
        end


    end
    
end
        