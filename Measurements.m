classdef Measurements < handle
    %This static class deals with all functions that deal with (user-made) 
    %measurements.
    
    methods (Static)
        
        function MouseMeasurementLines(app,hit,hitx,hity)
        %Description:
        %Finishes drawing a measurement.

        %Parameters:
        %app - the rmsstudio app
        %hit - event handler 
        %hitx - x-coordinate of click
        %hity - y-coordinate of click       
            
            Cv      = app.current_view;
            imID    = app.imagePerAxis(Cv);
            slice   = app.slicePerImage(imID);
            view    = app.viewPerImage(imID);
            %Add points to list
            if(hit.Button == 1) 
                if(view == 3)
                    app.points{Cv} = [app.points{Cv};   hitx hity slice];
                elseif(view == 2)
                    app.points{Cv} = [app.points{Cv};   hitx slice hity];
                elseif(view == 1)
                    app.points{Cv} = [app.points{Cv};   slice hitx hity];
                end
                
            else
                %Reset
                app.drawing.mode        = 0;
                app.points{Cv}          = [];
            end
            
            %Perform measurement
            if(size(app.points{Cv},1) == 2)
                Measurements.AddMeasurementToApp(app, [])
            end 
        end
        
        function AddMeasurementToApp(app, name)
            % Adds new measurement to app
            %Input:
            %   name - name of the new measurement
            
            %Add name to list, if no name is specified, prompt for one.
            if size(name,1) == 0
                name    = Interaction.PromptName(app);
            end
            Cv  = app.current_view;
            Objects.AddNewUserObj(app,...
                    "type", 2, ...
                    "points", app.points{Cv}, ...
                    "name", name{1})
            
%             if ~isempty(name) && strcmp(name, ' ') ~= 1
%                 app.measure_names{Cv}{end+1} = name{1};
%             else %if the user presses cancel, remove the measurement
%                 app.points{Cv} = [];
%                 Graphics.UpdateImage();
%                 return
%             end
%             
%             %Add measurement to app
%             NP = app.points{Cv};
%             app.measure_lines{Cv} = [app.measure_lines{Cv};NP];
%             app.points{Cv} = [];
%             
%             %Calculate length
%             P1        = NP(1,:);
%             P2        = NP(2,:);
%             direction = P2-P1;
%             CL        = norm(direction,2);
%             L         = CL*min(app.data{app.imIdx}.hdr.dime.pixdim(2:4));
%             app.measure_length{Cv}(end+1)   = L;
%             
%             GUI.DisableAllButtonsAndActions(app);
        end
        
        function RemoveMeasurement(app, idx)
        %removes the measurement(s) at the indexes
        
            %TODO: work with objects instead of measure_lines;
            return
            
            Cv  = app.current_view;
            app.measure_lines{Cv}(2*idx,:)      = [];
            app.measure_lines{Cv}(2*idx-1,:)    = [];
            app.measure_names{Cv}(idx)          = [];
            app.measure_length{Cv}(idx)         = [];
        end
        
        
        function PerformAutomaticEllipseMeasurement(app, id)
            %Automatically fits an ellipse on the segmentation with the
            %corresponding id. Adds the minor and major axis as
            %userObjects.
            %TODO: rework for userobjects
            return
            
            Cv  = app.current_view;
            %Don't do anything if no segmentations exist.
            if ~isfield(app.segmentation{Cv}, 'img')
                return
            end
            
            obj             = app.userObjects{id};
            [view, slice]   = GetUOViewAndSlice(obj)
            
            if(view == 3)
                L = obj.data(:,:,slice);
            elseif(view == 2)
                L = squeeze(...
                    obj.data(:,slice,:));
            elseif(view == 1)
                L = squeeze(...
                    obj.data(slice,:,:));
            end
            
            %Fit ellipse
%             [Mx,My] = MathUtils.WeightedCenterOfROI(SL);
            Lc = imerode(L,strel('disk',3));
            IX = find(L-Lc > 0);
            [Xv,Yv] = ind2sub(size(L),IX);

            ellipse = fit_ellipse(Xv,Yv,app.UIAxes1);

            %Find major and minor components
            V = zeros(4,3);
            V(1:2,1) = ellipse.horz_line(2,:);
            V(3:4,1) = ellipse.ver_line(2,:);
            V(1:2,2) = ellipse.horz_line(1,:);
            V(3:4,2) = ellipse.ver_line(1,:);
            V(:,3) = app.current_slice;
            if(view == 3)
                V = V(:,[2 1 3]);
            elseif(view == 2)
                V = V(:,[2 3 1]);
            elseif(view == 1)
                V = V(:,[3 2 1]);
            end

            app.measure_lines{Cv}                           ...
                            = [app.measure_lines{Cv};V];     
            app.measurement_list{app.imIdx}     ...
                            = app.measure_lines{Cv};

            %The name of the new measurements is equal to the name of
            %the most recent segmentation + 'major' or 'minor'
            name        = app.seg_names{Cv}{seg_id};
            nameMajor   = strcat(name, ' major');
            nameMinor   = strcat(name, ' minor');

            %Next, find the larger line
            %line1
            P1          = V(1,:);
            P2          = V(2,:);
            CL          = norm(P2-P1,2);
            Length1     = CL*min(app.data{app.imIdx}.hdr.dime.pixdim(2:4));

            %line2
            P3          = V(3,:);
            P4          = V(4,:);
            CL2         = norm(P4-P3,2);
            Length2     = ...
                CL2*min(app.data{app.imIdx}.hdr.dime.pixdim(2:4));

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
            
            Graphics.UpdateImage(app);
            Graphics.UpdateSelectionContour(app);
            GUI.RevertControlsStatus(app);
        end
        
        
        function RemoveAllMeasurements(app)
            %Removes all current measurements
            
            %TODO: rework for measurements
            
            return
            
            Cv  = app.current_view;            
            %Don't do anything if no measurements exist
            if ~isempty(app.measure_lines)
                app.measure_names{Cv}                       = {};
                app.measure_lines{Cv}                       = [];
                app.points{Cv}                              = [];
            end
           
        end
        
        
    end
end