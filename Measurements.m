classdef Measurements < handle
    %This static class deals with all functions that deal with (user-made) 
    %measurements.
    
    methods (Static)
        
        function MouseMeasurementLines(app,hit,hitx,hity)
        %Description:
        %

        %Parameters:
        %app - the rmsstudio app
        %hit - event handler 
        %hitx - x-coordinate of click
        %hity - y-coordinate of click

        %Returns:            
            
            %Change coordinates depending on view
            if(app.view_axis == 3)
            elseif(app.view_axis == 2)
%                 tmp = hitx;
%                 hitx = hity;
%                 hity = tmp;
            elseif(app.view_axis == 1)
%                 tmp = hitx;
%                 hitx = hity;
%                 hity = tmp;
            end
            
            %Setup for first point
            if(~isfield(app.drawing,'points')       ||                  ...
                    ~isfield(app.data,'img')        ||                  ...
                    isempty(app.data.img)           ||                  ...
                    ~isfield(app.drawing,'measurement_lines'))
                app.drawing.points              = [];
                app.drawing.measurement_lines   = [];
            end
            
            %Add points to list
            if(hit.Button == 1) 
                if(app.view_axis == 3)
                    app.drawing.points = [app.drawing.points;           ...
                                            hitx hity app.current_slice];
                elseif(app.view_axis == 2)
                    app.drawing.points = [app.drawing.points;           ...
                                            hitx app.current_slice hity];
                elseif(app.view_axis == 1)
                    app.drawing.points = [app.drawing.points;           ...
                                            app.current_slice hitx hity];
                end
                
            else
                %Reset
                app.drawing.measure_line    = false;
                app.drawing.points          = [];
            end
            
            %Perform measurement
            if(size(app.drawing.points,1) == 2)
                Backups.CreateBackup(app);
                Measurements.AddMeasurementToApp(app, [])
            end 
        end
        
        function AddMeasurementToApp(app, name)
            % Adds new measurement to app
            %Input:
            %   name - name of the new measurement
            
            %Add name to list, if no name is specified, prompt for one.
            if size(name,1) == 0
                name    = Interaction.PromptName();
            end
            
            if ~isempty(name) && strcmp(name, ' ') ~= 1
                app.measure_names{end+1} = name{1};
            else %if the user presses cancel, remove the measurement
                app.drawing.points = [];
                app.UpdateImage();
                return
            end
            
            %Add measurement to app
            NP = app.drawing.points;
            app.drawing.measurement_lines                               ...
                                = [app.drawing.measurement_lines;NP];
            app.drawing.points = [];
            
            %Calculate length
            P1        = NP(1,:);
            P2        = NP(2,:);
            direction = P2-P1;
            CL        = norm(direction,2);
            L         = CL*min(app.data.hdr.dime.pixdim(2:4));
            app.measure_length(end+1)   = L;
            
            GUI.DisableAllButtonsAndActions(app);
        end
        
        
        function PerformAutomaticEllipseMeasurement(app)
            %Automatically fits an ellipse on the most recently drawn
            %segmentation and adds the major and minor axis to the measurement
            %list. 
            
            %Don't do anything if no segmentations exist.
            if ~isfield(app.segmentation, 'img')
                return
            end
            
            %TODO: Split
            GUI.DisableControlsStatus(app);
            drawnow
            
            if(app.view_axis == 3)
                L = app.segmentation.img(:,:,app.current_slice);
            elseif(app.view_axis == 2)
                L = squeeze(app.segmentation.img(:,app.current_slice,:));
            elseif(app.view_axis == 1)
                L = squeeze(app.segmentation.img(app.current_slice,:,:));
            end
            
            %Find latest segmentation
            seg_id  = max(L(:));
            SL      = L == seg_id;
                            
            if(seg_id == 0 || sum(SL(:)) == 0)
                return
            end

            %Fit ellipse
%             [Mx,My] = MathUtils.WeightedCenterOfROI(SL);
            SLc = imerode(SL,strel('disk',3));
            IX = find(SL-SLc > 0);
            [Xv,Yv] = ind2sub(size(SL),IX);

            ellipse = fit_ellipse(Xv,Yv,app.UIAxes1);

            %Find major and minor components
            V = zeros(4,3);
            V(1:2,1) = ellipse.horz_line(2,:);
            V(3:4,1) = ellipse.ver_line(2,:);
            V(1:2,2) = ellipse.horz_line(1,:);
            V(3:4,2) = ellipse.ver_line(1,:);
            V(:,3) = app.current_slice;
            if(app.view_axis == 3)
                V = V(:,[2 1 3]);
            elseif(app.view_axis == 2)
                V = V(:,[2 3 1]);
            elseif(app.view_axis == 1)
                V = V(:,[3 2 1]);
            end

            app.drawing.measurement_lines                               ...
                            = [app.drawing.measurement_lines;V];     
            app.measurement_list{app.current_image_idx}                 ...
                            = app.drawing.measurement_lines;

            %The name of the new measurements is equal to the name of
            %the most recent segmentation + 'major' or 'minor'
            name        = app.seg_names{seg_id};
            nameMajor   = strcat(name, ' major');
            nameMinor   = strcat(name, ' minor');

            %Next, find the larger line
            %line1
            P1          = V(1,:);
            P2          = V(2,:);
            CL          = norm(P2-P1,2);
            Length1     = CL*min(app.data.hdr.dime.pixdim(2:4));

            %line2
            P3          = V(3,:);
            P4          = V(4,:);
            CL2         = norm(P4-P3,2);
            Length2     = CL2*min(app.data.hdr.dime.pixdim(2:4));

            %Compare
            if(Length1 > Length2)
                names   = {nameMajor, nameMinor};
                %Update lengthlist
                app.measure_length(end+1)   = Length1;
                app.measure_length(end+1)   = Length2;
            else
                names   = {nameMinor, nameMajor};
                %Update lengthlist
                app.measure_length(end+1)   = Length2;
                app.measure_length(end+1)   = Length1;
            end

            %Add to namelist
            app.measure_names{end+1} = names{1};
            app.measure_names{end+1} = names{2};
            
            app.UpdateImage();
            Graphics.UpdateSelectionContour(app);
            GUI.RevertControlsStatus(app);
        end
        
        
        function RemoveAllMeasurements(app)
            %Removes all current measurements
           
            %Don't do anything if no measurements exist
            if isfield(app.drawing, 'measurement_lines')
                app.measure_names                           = {};
                app.drawing.measurement_lines               = [];
                app.drawing.points                          = [];
            end
           
        end
        
        
    end
end