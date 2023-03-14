classdef Database < handle
    methods (Static)
        
        function PrepareDatabase(app, varargin)
           %Prepares a new database
           
           GUI.DisableControlsStatus(app)

           if nargin == 3
               app.datasetPath      = varargin{1};
               app.user_profile     = varargin{2};

           elseif nargin == 2
               app.datasetPath      = varargin{1};
               app.user_profile     = '';
%                Interaction.PromptProfile(app)

           else
               %Prompt for a database location
               Launcher(app, ...
                    getpref('rmsstudio', 'datasets'), ...
                    getpref('rmsstudio', 'profiles'));
               return
           end
           
           %Create a list of subfolders with the studies
           app.dataset     = [];
           Database.FindStudies(app, app.datasetPath)
           Database.AddStudies(app, app.datasetPath)
           
           IOUtils.PrepareStudy(app, app.dataset{1})
           GUI.RevertControlsStatus(app)
        end
        
        function FindStudies(app, fp)
            %Finds all the subfolders in the database directory and sets
            %them in the app.
            
            %Go over the first layer, this is likely individual patients
            folders    = dir(fp);
            folders    = folders(~ismember({folders.name},{'.','..'}));
            for i   = 1:length(folders)
                if folders(i).isdir
                    
                    path = fullfile(folders(i).folder, folders(i).name);
                    
                    if isfolder(fullfile(path, 'rmsstudio'))
                        app.dataset{end+1} = path;
                    else
                        Database.FindStudies(app, path)
                    end
                end
            end            
        end
        
        function AddStudies(app, fp)
            %Add items to listbox
            
            app.AvailableStudiesListBox.Items = {};
            for idx=1:length(app.dataset)
                text    = app.dataset{idx};
                text    = erase(text, [fp '\']);
                text    = erase(text, '\rmsstudio');
                app.AvailableStudiesListBox.Items{idx} = text;
            end
            
        end
        
        function SwitchToStudy(app, varargin)
            %Called when a new study is selected in the availablestudies
            %listbox. Switches to that study.
            %inputs:    app - the RMSStudio app
            %varargin:  optional, the index to switch to.
            
            if app.unsavedProgress
               proceed = Interaction.PromptSave(app);
               if ~proceed
                   return
               end
            end
            
            GUI.DisableControlsStatus(app)
            
            if ~isempty(varargin)
                index   = varargin{1};
                app.AvailableStudiesListBox.Value =                     ...
                    app.AvailableStudiesListBox.Items{index};
            else            
                %Find index 
                index   = -1;
                for idx=1:length(app.dataset)
                    text    = app.dataset{idx};
                    text    = erase(text, [app.datasetPath '\']);
                    text    = erase(text, '\rmsstudio');
%                     [~,name,~] = fileparts(text);
                    if strcmp(app.AvailableStudiesListBox.Value, text)
                        index   = idx;
                        break;
                    end
                end
            end
            
            %Load the study at the index
            if index <= size(app.dataset,2) && index > 0
                IOUtils.PrepareStudy(app, ...
                    fullfile(app.dataset{index},'rmsstudio'))
            end
            
            GUI.RevertControlsStatus(app)
        end
            
            
    end
end
