classdef PrePrcIO < handle
    methods (Static)

        function SelectData(app)
            
            if ~isempty(app.filepath)
                fp = uigetdir(app.filepath, 'Select a subject folder');
            else
                fp = uigetdir('C:','Select a subject folder');
            end
            if isempty(fp)
                return
            end
            drawnow;
            figure(app.UIFigure)

            app.filepath = fp;
            app.InputLabel2.Text = fp;

            if ~isempty(app.outpath)
                app.ProcessButton.Enable = true;
            end

        end
        
        
        function SelectOutPath(app)

            if ~isempty(app.filepath)
                op = uigetdir(fileparts(app.filepath),...
                    'Select an output folder');
                app.ProcessButton.Enable = true;
            else
                op = uigetdir('C', 'Select an output folder');
            end
            if isempty(op)
                return
            end

            drawnow;
            figure(app.UIFigure)

            app.outpath = op;
            app.OutputLabel2.Text = op;
        end

        function SelectT1(app)
            
            if isempty(app.filepath)
                t1p = uigetfile('C', 'Select T1 for registration');
            else
                t1p = uigetfile(app.filepath, 'Select T1 for registration');
            end

            if isempty(t1p)
                app.RegistertostructuralCheckBox.Value = false;
                return
            end

            app.t1_path = t1p;

        end

        function makeRMSStudioDir(app)

            if app.MultipleimagesCheckBox.Value
                folders = dir(app.filepath);
                folders = folders(~ismember({folders.name},{'.','..'}));

                for i = 1:length(folders)
                    folder = folders(i);

                    if ~folder.isdir
                        continue
                    end

                    path = fullfile(app.filepath, folder.name, 'rmsstudio');
                    if ~exist(path, 'dir')
                        mkdir(path);
                    end   
                end

                app.outpath = app.filepath;
                app.OutputLabel2.Text = app.filepath;
            else
                %Single folder
                path = fullfile(app.filepath, 'rmsstudio');
                if ~exist(path, 'dir')
                    mkdir(path);
                end
    
                app.outpath = path;
                app.OutputLabel2.Text = path;
                app.ProcessButton.Enable = true;

            end
        end

    end
end