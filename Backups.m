classdef Backups < handle
    methods (Static)
        
        function CreateBackup(app)
            %Creates a backupObj that stores the current state of the app.
            %Also flags the unsavedProgress to true.
            
            obj = BackupObj();
            
            %Set the UnsavedProgress to true
            Study.ToggleUnsavedProgress(app, true);
            
            obj.imID                = app.imID;
            obj.imagePerAxis        = app.imagePerAxis;
            obj.slicePerImage       = app.slicePerImage;
            obj.viewPerImage        = app.viewPerImage;
            obj.d4PerImage          = app.d4PerImage;
            obj.viewPerImage        = app.viewPerImage;
            obj.axID                = app.axID;
            obj.cScalePerImage      = app.cScalePerImage;
            obj.userObjects         = Objects.CreateObjectBackup(app);

            %Remove any backups beyond the current index
            app.backup_list(app.backup_idx + 1: end) = [];
            
            %Add new backup            
            app.backup_list{end+1}  = obj;
            app.backup_idx          = length(app.backup_list);
        end
        
        function RestoreBackup(app)
            
            %Restore the app to the state as saved in the latest backup
            %object in backup_list.
            
            %TODO: only restore things that are different, speed up
            %process.

            bck = app.backup_list{app.backup_idx};

            %If views are different
            app.imagePerAxis    = bck.imagePerAxis;
            app.slicePerImage   = bck.slicePerImage;
            app.viewPerImage    = bck.viewPerImage;

            %If view is different
            if app.axID ~= bck.axID
                Interaction.SwitchViewAndFocus(app,                  ...
                                              bck.axID);

            %If image is different
            elseif app.imID ~= bck.imID
                Study.SwitchImage(app, bck.imID)
            end

            app.d4PerImage          = bck.d4PerImage;
            app.cScalePerImage      = bck.cScalePerImage;

            Objects.RestoreObjectBackup(app, bck.userObjects)
            GUI.InitUORenderer(app, app.axID)

            Graphics.UpdateAxes(app);
            GUI.UpdateUOBox(app);

        end
        
        function ClearBackups(app)
        %Clears all backups     - currently unused.
            app.backup_list     = {};
            app.backup_idx      = 0;
        end
        
        function Undo(app)
           %Lowers the backup_idx by one, if possible. Calls for backup to
           %be restored.
           
           idx  = app.backup_idx;
           
           if idx > 1
               app.backup_idx = app.backup_idx - 1;
               Backups.RestoreBackup(app)
           end
            
        end
        
        function Redo(app)
            %Raises the backup_idx by one, if possible. Calls for backup to
            %be restored.
            
            idx = app.backup_idx;
            
            if idx < length(app.backup_list)
                app.backup_idx = app.backup_idx + 1;
                Backups.RestoreBackup(app)
            end         
            
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