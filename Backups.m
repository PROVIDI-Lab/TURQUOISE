classdef Backups < handle
    methods (Static)
        
        function CreateBackup(app)
            %Creates a backupObj that stores the current state of the app.
            obj = BackupObj();
            
            obj.current_image_idx   = app.current_image_idx;
            obj.image_per_view      = app.image_per_view;
            obj.current_4d_idx      = app.current_4d_idx;
            obj.view_axis           = app.view_axis;
            obj.current_view        = app.current_view;
            obj.current_slice       = app.current_slice;
            obj.MinValue            = app.MinValue;
            obj.MaxValue            = app.MaxValue;
            
            if isfield(app.segmentation, 'img')
                obj.segmentation        = Backups.To1DArray(            ...
                                                app.segmentation.img);
                obj.seg_prop            = app.segmentation.properties;
                obj.seg_names           = app.seg_names;
                obj.seg_shape           = size(app.segmentation.img);
                obj.roiPoints           = app.roiPoints;
                obj.roiPointIndex       = app.roiPointIndex;
            end
            
            if isfield(app.drawing, 'measurement_lines')
                obj.measurements         = app.drawing.measurement_lines;
                obj.measure_names        = app.measure_names;
            end

            %Add to list
            app.backup_list{end+1}   = obj;
   
        end
        
        function RestoreBackup(app)
            %Restore the app to the state as saved in the latest backup
            %object in backup_list.
            
            %TODO: only restore things that are different, speed up
            %process.
           
           if isempty(app.backup_list)
               return
           end
           obj = app.backup_list{end};
           
           %If views are different
           app.image_per_view   = obj.image_per_view;
               
           %If view is different
           if app.current_view ~= obj.current_view
               button = ['View' num2str(obj.current_view) 'Button'];
               Interaction.SwitchViewAndFocus(app,                  ...
                                              obj.current_view,     ...
                                              button);

           %If image is different
           elseif app.current_image_idx ~= obj.current_image_idx
               Interaction.ChangeListBoxValue(app,                  ...
                                              obj.current_image_idx)
           end

           
           app.current_4d_idx       = obj.current_4d_idx;
           app.view_axis            = obj.view_axis;
           app.current_slice        = obj.current_slice;
           app.MinValue             = obj.MinValue;
           app.MaxValue             = obj.MaxValue;
           
           if ~isequaln(obj.segmentation, app.segmentation)
               if isempty(obj.segmentation)
                   app.segmentation         = [];
                   app.seg_names            = [];
               else
                   app.segmentation.img     = Backups.ToNDArray(        ...
                                         obj.segmentation, obj.seg_shape);
                   app.seg_names                = obj.seg_names;
                   app.segmentation.properties  = obj.seg_prop;
                   app.roiPoints                = obj.roiPoints;
                   app.roiPointIndex            = obj.roiPointIndex;
               end
               
           end
           
           if any(size(obj.measurements) ~=                             ...
                  size(app.drawing.measurement_lines))
               app.drawing.measurement_lines = obj.measurements;
               app.measure_names             = obj.measure_names;
           end
           
           %Remove from list
           app.backup_list(end)     = [];
           
           app.UpdateImage();
           
                                                 
        end
        
        function ClearBackups(app)
        %Clears all backups     - currently unused.
            app.backup_list     = [];
        end
        
        function arrOut = To1DArray(arrIn)
        %Converts the ndarray to a 1darray.
           arrOut   = reshape(arrIn, [numel(arrIn),1]); 
           if class(arrOut) == 'single'
               arrOut   = double(arrOut);
           end
           arrOut   = sparse(arrOut);
        end
        
        function arrOut = ToNDArray(arrIn, shape)
        %Converts the 1darray to an ndarray with given shape.
            arrOut = reshape(full(arrIn), shape);
        end
        
    end
end