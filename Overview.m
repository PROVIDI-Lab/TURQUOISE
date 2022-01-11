classdef Overview < handle
    %This static class deals with displaying an overview of the current
    %dataset.
    
    methods (Static)
        
        function Init(app)
           
            if isempty(app.dataset)
                return
            end
            
            f=uifigure('MenuBar','None');
            
            stats = Overview.GetStats(app);
            
            Overview.DisplayStats(f, stats)
            
        end
        
        function stats = GetStats(app)
            
            stats = cell(length(app.dataset), 3);
            
            for i = 1:length(app.dataset)
                parts = strsplit(app.dataset{i}, '\');
                acc     = parts{end};
                ID      = parts{end - 1};
                
                segmentations    = Overview.FindSegmentations(...
                    fullfile(app.dataset{i}, 'rmsstudio'));
                
                
                stats{i, 1} = ID;
                stats{i, 2} = acc;
                
                for ii = 1:size(segmentations,1)
                   seg = segmentations(ii,:);
                   stats{i, 4*ii}       = seg{1};
                   stats{i, 4*ii + 1}   = seg{2};
                   stats{i, 4*ii + 2}   = seg{3};
                end
                
            end
            
            maxEntries  = (size(stats,2)-2)/4;
            varNames    = {'ID', 'Accession'};
            for i = 1:maxEntries
                id = num2str(i);
                varNames = [varNames,...
                    {id, ['Image ' id], ['Profile ' id], ['#seg ', id]}]; 
            end
            stats = cell2table(stats, 'VariableNames', varNames);
            
        end
        
        function DisplayStats(f, stats)
           
            uit = uitable(f,'Data',stats);
            uit.Position = [0,0,f.Position(3), f.Position(4)];
            
            
        end
        
        
        function segPaths = FindSegmentations(path)
            %Find the paths to all the segmentation .json files located in 
            %subfolders of the current path. 
            
            segPaths = [];
           
            subfolders = dir(path);
            subfolders = subfolders([subfolders.isdir]);
            subfolders = subfolders(~ismember({subfolders.name},{'.','..'}));

            %Go over subfolders, find .json files
            for i = 1:length(subfolders)
                subfolder = subfolders(i);

                jsonFiles = dir(fullfile(...
                    subfolder.folder, subfolder.name, '*.json'));
                
                if isempty(jsonFiles)
                    continue
                end
                
                res     = Overview.ConstructSegEntry(jsonFiles, 'none');
                segPaths = [segPaths; res];
                
                %look for profiles
                
                profiles    = dir(fullfile(...
                    subfolder.folder, subfolder.name));
                profiles = profiles([profiles.isdir]);
                profiles = profiles(~ismember({profiles.name},{'.','..'}));
                
                for ii = 1:length(profiles)
                    profile = profiles(ii);
                    
                    jsonFiles = dir(fullfile(...
                        profile.folder, profile.name, '*.json'));
                    
                    if isempty(jsonFiles)
                        continue
                    end
                    res     = Overview.ConstructSegEntry(...
                        jsonFiles, profile.name);
                    segPaths = [segPaths; res];
                end
            end
        end
        
        
        
        function entry = ConstructSegEntry(files, profile)
            %Takes the list of files and the profile and returns a list of
            %the image names, the profile and the amount of segmentations.
                            
            [path, folder, ~] = fileparts(files(1).folder);
            if strcmp(folder, profile)
                [~, folder, ~] = fileparts(path);
            end
            
            entry = {folder, profile, length(files)};            
        end
        
        
    end
end
        