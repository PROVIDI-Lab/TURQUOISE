classdef PluginUtils < handle
    methods (Static)

        function populatePlugins(app)

            [turquoiseFolder, ~, ~]      = fileparts(which('TURQUOISE'));
            pluginFolder = fullfile(turquoiseFolder, 'plugins');

            plugins = dir(fullfile(pluginFolder, '*.m'));

            for i = 1:length(plugins)
                plugin = plugins(i);
                name = strrep(plugin.name, '.m', '');
                if strcmp(name, 'template')
                    continue
                end
                
                %create object
                evalStr = strcat(...
                    "pluginObj = ", name, '(app)');
                eval(evalStr)

                app.plugins{end+1} = pluginObj;

                %add menu
                app.pluginSubMenus{end+1} = uimenu(app.PluginsMenu, ...
                    "MenuSelectedFcn", {@PluginUtils.runPlugin, app}, ...
                    "Text", name);

            end

            %if no plugins found
            if length(plugins) == 1
               app.pluginSubMenus{end+1} = uimenu(app.PluginsMenu, ...
                    "Text", "No plugins found");
            end

        end

        function runPlugin(menu, ~, app)

            for i = 1:length(app.plugins)
                plugin = app.plugins{i};
                if strcmp(class(plugin), menu.Text)
                    plugin.Excecute()
                    break
                end
            end

        end
        
    end
end            