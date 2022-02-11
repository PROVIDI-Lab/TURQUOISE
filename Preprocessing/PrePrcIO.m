classdef PrePrcIO < handle
    methods (Static)

        function SelectData(app)
            
            fp = uigetdir('C:','Select a subject folder');
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
            app.outpath = op;
            app.OutputLabel2.Text = op;
        end

        function SelectT1(app)
            
            if isempty(app.filepath)
                t1p = uigetfile('C', 'Select T1 for registration');
            else
                t1p = uigetfile(app.filepath, 'Select T1 for registration');
            end
            app.t1_path = t1p;

        end

    end
end