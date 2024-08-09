classdef HelloWorld
    properties
        app
    end

    methods (Access = public)
        function obj = HelloWorld(app)
            obj.app = app;
            uialert(app.UIFigure, 'Initializing', 'Hello World')
        end

        function Excecute(obj)
            uialert(obj.app.UIFigure, 'Hello World!', 'Hello World')
        end
    end

    methods (Access = private)

    end
       
end