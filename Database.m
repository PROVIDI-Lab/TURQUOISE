classdef Database < handle
    methods (Static)
        
        function PrepareDatabase(app, varargin)
           %Prepares a new database

           if app.unsavedProgress
               proceed = Interaction.PromptSave(app);
               if ~proceed
                   return
               end
           end
           
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
           Database.FindPatients(app, app.datasetPath)

           %check if any patients were found. If not, throw exception
           if isempty(app.PatientsListBox.Items)
               errordlg(strjoin('No patients were found. ', ...
                   'Check if folder is accessible.'));
               GUI.RevertControlsStatus(app)
               return
           end
           Database.FindSessions(app, app.datasetPath)
           Database.SwitchPatient(app, 1)
           GUI.RevertControlsStatus(app)
        end
        
        function FindPatients(app, fp)
            %Adds all patients in the database directory to a list
            
            %Go over the first layer, this is likely individual patients
            folders     = dir(fp);
            folders     = folders(~ismember({folders.name},{'.','..'}));
            names       = {folders.name};
            idx = [folders.isdir];
            app.PatientsListBox.Items = names(idx);            
        end

        function FindSessions(app, fp)
            %Adds all patients in the database directory to a list

            for i = 1:length(app.PatientsListBox.Items)
                folder = app.PatientsListBox.Items{i};

                subfolders = dir(fullfile(fp, folder));
                subfolders = subfolders( ...
                    ~ismember({subfolders.name},{'.','..'}));
                
                for ii = 1:length(subfolders)
                    subfolder = subfolders(ii);
                    rmsPath = fullfile(subfolder.folder, subfolder.name, ...
                            'rmsstudio');
                    if exist(rmsPath, 'dir')
                        app.dataset{end+1} = rmsPath;
                    elseif strcmp(subfolder.name, 'rmsstudio')
                        app.dataset{end+1} = ...
                            fullfile(subfolder.folder, subfolder.name);
                    end
                end
            end
        end
        
        function SwitchPatient(app, varargin)
            %Called when a new study is selected in the availablestudies
            %listbox. Switches to that study.
            %inputs:    app - the RMSStudio app
            %varargin:  optional, the index to switch to.
            
            if ~isempty(varargin)
                index   = varargin{1};
                app.PatientsListBox.Value =                     ...
                    app.PatientsListBox.Items{index};
            end

            % update the sessionbox
            items = {};
            for i = 1:length(app.dataset)
                item = app.dataset{i};
                if contains(item, app.PatientsListBox.Value)
                    [folder, ~, ~] = fileparts(item);
                    [~, name, ~] = fileparts(folder);
                    items{end+1} = name;
                end
            end
            app.SessionsListBox.Items = items;
            
        end

        function SwitchSession(app, varargin)
            %Called when a new study is selected in the availablestudies
            %listbox.             
            
            
            if ~isempty(varargin)
                val   = varargin{1};
                app.SessionsListBox.Value = val;
            end
        end

        function SwitchToNewSession(app)
            %Called to actually switch to a new session

            if app.unsavedProgress
               proceed = Interaction.PromptSave(app);
               if ~proceed
                   return
               end
            end
            
            GUI.DisableControlsStatus(app)

            %find index in database
            for i = 1:length(app.dataset)
            item = app.dataset{i};
                if contains(item, app.PatientsListBox.Value) && ...
                        contains(item, app.SessionsListBox.Value)
                    IOUtils.PrepareStudy(app, app.dataset{i})
                    break
                end
            end
            
            GUI.RevertControlsStatus(app)
        end
    end
end
