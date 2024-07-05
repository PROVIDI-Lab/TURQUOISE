classdef CopyRegisterSeg < handle
    methods (Static)

        function CopySegmentations(app)

            fig = uifigure('Name', 'Copy segmentations', ...
                'Position',[500 500 600 400]);

            btn = uibutton(fig,...
                'Position',[250 50 100 22],...
                'Text','Copy');
            
            slctSegLbl = uilabel(fig,...
                'Position', [40, 300, 150, 22],...
                'Text', 'Select segmentations');
            slctSeg = uilistbox(fig,...
                'Position', [25, 100, 150, 200]);
            slctSeg.Multiselect = 'on';
            slctAllSeg= uicheckbox(fig,...
                'Position', [25, -50, 150, 200],...
                'Text', 'Select all',...
                'ValueChangedFcn', @SelectAllSeg);

            slctTargetLbl = uilabel(fig,...
                'Position', [470, 300, 150, 22],...
                'Text', 'Select target');
            slctTarget = uilistbox(fig,...
                'Position', [425, 100, 150, 200]);
            slctTarget.Multiselect = 'on';
            slctAllTargets = uicheckbox(fig,...
                'Position', [425, -50, 150, 200],...
                'Text', 'Select all',...
                'ValueChangedFcn', @SelectAllTargets);

            %Button callback
            btn.ButtonPushedFcn = {@CopyRegisterSeg.StartCopy, app};


            %Fill listboxes
            segs = Objects.GetAllUOsForImage(app, app.imIdx);
            slctSeg.Items = segs;

            targets = app.sessionNames;
            targets(app.imIdx) = [];
            slctTarget.Items = targets;

            function SelectAllTargets(src, event)
                if src.Value
                    src.Parent.Children(2).Value = ...
                        src.Parent.Children(2).Items;
                else
                    src.Parent.Children(2).Value = {};
                end
            end

            function SelectAllSeg(src, event)
                if src.Value
                    src.Parent.Children(5).Value = ...
                        src.Parent.Children(5).Items;
                else
                    src.Parent.Children(5).Value = {};
                end
            end
        end

        function StartCopy(src, ~, app)
            
            targets = src.Parent.Children(2).Value;
            segs = src.Parent.Children(5).Value;
            for i = 1:length(targets)
                target = targets{i};

                %Todo: fix actual copy & registration.
                    %For now, it just does copyfile
                    path = fullfile(app.sessionPath,              ...
                                        app.sessionNames{app.imIdx},   ...
                                         app.user_profile);

                    outpath = fullfile(app.sessionpath,          ...
                                        target,                     ...
                                         app.user_profile);


                    files = dir(path);
                    for j = 1:length(files)
                        file = files(j);
                        if file.isdir
                            continue
                        end

                        [~, name, ext] = fileparts(...
                            fullfile(file.folder, file.name));
                        name = strrep(name,'-segmentation', '');

                        if ~strcmp(ext, '.json')
                            continue
                        end

                        for k = 1:length(segs)
                            if ~strcmp(name, segs{k})
                                continue
                            end
                            copyfile(...
                                fullfile(path,file.name),...
                                fullfile(outpath, file.name))  
                            break
                        end
                    end




            end


            
        end

        
    end
end            