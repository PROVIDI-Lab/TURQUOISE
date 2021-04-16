classdef Backups < handle
    methods (Static)
        
        function CreateBackup(app)
            %Creates a backupObj that stores the current state of the app.
            obj = BackupObj();
            
            obj.current_image_idx   = app.imIdx;
            obj.imagePerAxis        = app.imagePerAxis;
            obj.slicePerImage       = app.slicePerImage;
            obj.viewPerImage        = app.viewPerImage;
            obj.current_4d_idx      = app.current_4d_idx;
            obj.viewPerImage        = app.viewPerImage;
            obj.current_view        = app.current_view;
            obj.slicePerImage       = app.slicePerImage;
            obj.MinValue            = app.MinValue;
            obj.MaxValue            = app.MaxValue;
            obj.userObjects         = app.userObjects;
            
%             Cv  = app.current_view;
%             if isfield(app.segmentation, 'img')
%                 obj.segmentation        = Backups.To1DArray(            ...
%                                                 app.segmentation{Cv}.img);
%                 obj.seg_prop            = app.segmentation{Cv}.properties;
%                 obj.seg_names           = app.seg_names{Cv};
%                 obj.seg_shape           = size(app.segmentation{Cv}.img);
%                 obj.roiPoints           = app.roiPoints{Cv};
%                 obj.roiPointIndex       = app.roiPointIndex{Cv};
%             end
%             
%             if ~isempty(app.measure_lines)
%                 obj.measurements    = app.measure_lines{Cv};
%                 obj.measure_names   = app.measure_names{Cv};
%             end

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
            app.imagePerAxis    = obj.imagePerAxis;
            app.slicePerImage   = obj.slicePerImage;
            app.viewPerImage    = obj.viewPerImage;

            %If view is different
            if app.current_view ~= obj.current_view
                button = ['View' num2str(obj.current_view) 'Button'];
                Interaction.SwitchViewAndFocus(app,                  ...
                                              obj.current_view,     ...
                                              button);

            %If image is different
            elseif app.imIdx ~= obj.current_image_idx
                Interaction.ChangeListBoxValue(app,                  ...
                                              obj.current_image_idx)
            end

            app.current_4d_idx       = obj.current_4d_idx;
            %            app.view_axis            = obj.view_axis;
            %            app.current_slice        = obj.current_slice;
            app.MinValue             = obj.MinValue;
            app.MaxValue             = obj.MaxValue;

            Cv   = app.current_view;
            if ~isequaln(obj.segmentation, app.segmentation{Cv})
               if isempty(obj.segmentation)
                   app.segmentation{Cv}         = [];
                   app.seg_names{Cv}            = [];
               else
                   app.segmentation{Cv}.img = Backups.ToNDArray(...
                                     obj.segmentation, obj.seg_shape);
                   app.seg_names{Cv}                = obj.seg_names;
                   app.segmentation{Cv}.properties  = obj.seg_prop;
                   app.roiPoints{Cv}                = obj.roiPoints;
                   app.roiPointIndex{Cv}            = obj.roiPointIndex;
               end

            end

            if any(size(obj.measurements) ~= size(app.measure_lines{Cv}))
               app.measure_lines{Cv}            = obj.measurements;
               app.measure_names{Cv}            = obj.measure_names;
            end

            %Remove from list
            app.backup_list(end)     = [];

            Graphics.UpdateImage(app);


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