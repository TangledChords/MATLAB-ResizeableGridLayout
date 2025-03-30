classdef ResizeableGridLayout < matlab.ui.componentcontainer.ComponentContainer
properties
    GridLayout                                      = matlab.ui.container.GridLayout.empty;
    RowSpacing      (1,1)   {mustBeScalarOrEmpty}   = 4;
    ColumnSpacing   (1,1)   {mustBeScalarOrEmpty}   = 4;
    Padding         (1,4)   {mustBeVector}   = [0 0 0 0];
    RowHeight       (1,:)   {mustBeVector}   = {'1x' '1x'};
    ColumnWidth     (1,:)   {mustBeVector}   = {'1x' '1x'};
end

events (HasCallbackProperty, NotifyAccess = protected)
    StartResizing
    Resizing
    EndResizing
    RightButtonDown
end

properties (Access = private, Transient, NonCopyable)
    DragFlag        (1,1)   {logical}   = false;
    StartPoint      (1,2)   {double}    = [0 0];
    CurrentPoint    (1,2)   {double}    = [0 0];
    PostInit        (1,1)   {logical}   = false;
    RedrawGrid      (1,1)   {logical}   = false;

    % Storage
    OldWindowButtonMotionFcn = [];
    OldWindowButtonUpFcn     = [];
    OldGrid                  = [];
    OldUnits                 = [];
end

% Public Methods
methods (Access = public)
    function obj = addChild(rsgl,obj,row,col) % Helper Fcn to position children
        obj.Parent = rsgl.GridLayout;
        obj.Layout.Row = 2 * (row - 1) + 1;
        obj.Layout.Column = 2 * (col - 1) + 1;
    end
end

% Superclass Req. Methods
methods (Access = protected)
    function setup(ResizeableGridLayout)
        ResizeableGridLayout.GridLayout = uigridlayout("Parent",ResizeableGridLayout,'RowSpacing',0,'ColumnSpacing',0,'Padding',ResizeableGridLayout.Padding);
        % ResizeableGridLayout.BusyAction = 'cancel';
        fig = ancestor(ResizeableGridLayout,'matlab.ui.Figure');
        set(fig,'WindowButtonMotionFcn',@(src,event)MouseMoving(ResizeableGridLayout));
    end

    function update(ResizeableGridLayout)
        if ~ResizeableGridLayout.DragFlag
            set(ResizeableGridLayout.GridLayout,"BackgroundColor",ResizeableGridLayout.BackgroundColor,"ColumnWidth",ResizeableGridLayout.ColumnWidth,'RowHeight',ResizeableGridLayout.RowHeight,'ColumnSpacing',0,'RowSpacing',0,'Padding',ResizeableGridLayout.Padding);
            ResizeableGridLayout.RowHeight = ResizeableGridLayout.RowHeight;
            ResizeableGridLayout.ColumnWidth = ResizeableGridLayout.ColumnWidth;
        end
    end
end

% Property Getters/Setters
methods
    function set.RowHeight(ResizeableGridLayout,val)
        if ~(numel(val) == numel(ResizeableGridLayout.RowHeight))
            ResizeableGridLayout.RedrawGrid = true;
        end
        tmpRH = vertcat(val,repmat({ResizeableGridLayout.RowSpacing},1,numel(val)));
        ResizeableGridLayout.RowHeight = val;
        ResizeableGridLayout.GridLayout.RowHeight = tmpRH(1:end-1);

        addSpacers(ResizeableGridLayout);
    end

    function set.ColumnWidth(ResizeableGridLayout,val)
        if ~(numel(val) == numel(ResizeableGridLayout.ColumnWidth))
            ResizeableGridLayout.RedrawGrid = true;
        end
        tmpCW = vertcat(val,repmat({ResizeableGridLayout.ColumnSpacing},1,numel(val)));
        ResizeableGridLayout.ColumnWidth = val;
        ResizeableGridLayout.GridLayout.ColumnWidth = tmpCW(1:end-1);
        addSpacers(ResizeableGridLayout);
    end
end

% Superclass Override Methods
methods
    % Get Children of Grid
    function c = getChildren(ResizableGridLayout)
        c = findall(ResizableGridLayout.GridLayout.Children);
    end

    % Get all children of top level grid
    function c = getAllChildren(ResizeableGridLayout)
        rsgl = ResizeableGridLayout.getTopGrid;
        c = rsgl.getChildren;
        sc = findall(c,'Type','resizeablegridlayout');
        for i = 1:length(sc)
            c = [c; sc(i).getChildren];
        end
        c = unique(c);
    end

    % Get all sliders from top level grid
    function sgl = getAllSliders(ResizeableGridLayout)
        rsgl = ResizeableGridLayout.getTopGrid;
        sgl = rsgl.getSliders;
    end

    % Get all sliders from grid
    function sliders = getSliders(ResizeableGridLayout)
        sc = findall(ResizeableGridLayout.getChildren,'Type','resizeablegridlayout');
        sliders = [findall(ResizeableGridLayout.getChildren,'Tag','RSGLSliderVertical') findall(ResizeableGridLayout.getChildren,'Tag','RSGLSliderHorizontal') findall(ResizeableGridLayout.getChildren,'Tag','RSGLSliderCorner')];
        for i = 1:length(sc)
           sliders = [sliders sc(i).getSliders]; %#ok
        end
    end

    % Is Grid a child of another grid
    function bool = isChildGrid(ResizeableGridLayout)
        c = ResizeableGridLayout.Parent;
        bool = false;
        while ~(c.Type == "figure")
            c = c.Parent;
            if (c.Type == "resizeablegridlayout")
                bool = true;
            end
        end
    end

    % Get Top Level Grid
    function rsgl = getTopGrid(ResizeableGridLayout)
        rsgl = ResizeableGridLayout;
        c = rsgl;
        while rsgl.isChildGrid
            if (c.Type == "resizeablegridlayout")
                rsgl = c;
            end
            c = c.Parent;
        end
    end
end

% Callback
methods (Access= public)

    function addSpacers(ResizeableGridLayout)
        % If number of spacers doesn't change, don't do anything
        if ~(ResizeableGridLayout.RedrawGrid)
            return
        else
            ResizeableGridLayout.RedrawGrid = false;
        end

        % Delete any old spacers 
        findall(ResizeableGridLayout.GridLayout.Children,'Tag','RSGLSliderCorner').delete
        findall(ResizeableGridLayout.GridLayout.Children,'Tag','RSGLSliderVertical').delete
        findall(ResizeableGridLayout.GridLayout.Children,'Tag','RSGLSliderHorizontal').delete

        for i = 1:length(ResizeableGridLayout.GridLayout.RowHeight)
            for j = 1:length(ResizeableGridLayout.GridLayout.ColumnWidth)
                if (~mod(i,2) && ~mod(j,2))    % Corner - Fleur
                    uip = uipanel(ResizeableGridLayout.GridLayout,'BorderType','none','BackgroundColor',ResizeableGridLayout.BackgroundColor,'Tag','RSGLSliderCorner','ButtonDownFcn',@(src,event)startDragFcn(ResizeableGridLayout,src,event),'Units','normalized');
                    uip.Layout.Row = i; uip.Layout.Column = j;
                elseif ~mod(i,2) && mod(j,2)  % Vertical
                    uip = uipanel(ResizeableGridLayout.GridLayout,'BorderType','none','BackgroundColor',ResizeableGridLayout.BackgroundColor,'Tag','RSGLSliderVertical','ButtonDownFcn',@(src,event)startDragFcn(ResizeableGridLayout,src,event),'Units','normalized');
                    uip.Layout.Row = i; uip.Layout.Column = j;
                elseif mod(i,2) && ~mod(j,2)  % Horizontal
                    uip = uipanel(ResizeableGridLayout.GridLayout,'BorderType','none','BackgroundColor',ResizeableGridLayout.BackgroundColor,'Tag','RSGLSliderHorizontal','ButtonDownFcn',@(src,event)startDragFcn(ResizeableGridLayout,src,event),'Units','normalized');
                    uip.Layout.Row = i; uip.Layout.Column = j;
                end
                
            end
        end
    end

    function startDragFcn(ResizeableGridLayout,src,event)
        fig = ancestor(ResizeableGridLayout,'matlab.ui.Figure');

        % Disable any currently mouse capturing events
        ax = unique(findall(ResizeableGridLayout.getAllChildren,'Type','axes'));
        if ~isempty(ax)
            for i = 1:length(ax)
                rotate3d(ax(i),'off');
                pan(ax(i),'off');
                zoom(ax(i),'off');
            end
        end

        % Convert weights to pixels
        applyWeights(ResizeableGridLayout);

        ResizeableGridLayout.DragFlag = true;
        ResizeableGridLayout.StartPoint = get(fig,'CurrentPoint');
        ResizeableGridLayout.OldWindowButtonMotionFcn = get(fig,'WindowButtonMotionFcn');
        ResizeableGridLayout.OldWindowButtonUpFcn = get(fig,'WindowButtonUpFcn');
        set(fig,'WindowButtonMotionFcn',@(src,event)draggingFcn(ResizeableGridLayout,src,event));
        set(fig,'WindowButtonUpFcn',@(src,event)stopDragFcn(ResizeableGridLayout,src,event));
    end

    function applyWeights(ResizeableGridLayout)
        pos = getpixelposition(ResizeableGridLayout);
        ColumnWeights = double(strrep(string(ResizeableGridLayout.ColumnWidth),"x",""));
        RowWeights = double(strrep(string(ResizeableGridLayout.RowHeight),"x",""));
        ResizeableGridLayout.ColumnWidth = num2cell((pos(3) - (ResizeableGridLayout.ColumnSpacing*(numel(ResizeableGridLayout.ColumnWidth)-1))) / sum(ColumnWeights) * ColumnWeights);
        ResizeableGridLayout.RowHeight   = num2cell((pos(4) - (ResizeableGridLayout.RowSpacing*   (numel(ResizeableGridLayout.RowHeight)-1)))   / sum(RowWeights) * RowWeights);
    end

    function calculateWeights(ResizeableGridLayout)
        CW = ResizeableGridLayout.ColumnWidth;
        RH = ResizeableGridLayout.RowHeight;
        ResizeableGridLayout.ColumnWidth = num2cell(append(string(cell2mat(CW) / sum(cell2mat(CW))),'x'));
        ResizeableGridLayout.RowHeight = num2cell(append(string(cell2mat(RH) / sum(cell2mat(RH))),'x'));
    end

    function draggingFcn(ResizeableGridLayout,src,event)
        fig = ancestor(ResizeableGridLayout,'matlab.ui.Figure');
        ResizeableGridLayout.OldUnits = fig.Units;
        set(fig,'Units','pixels');
        ResizeableGridLayout.CurrentPoint = get(fig,'CurrentPoint');
        d = (ResizeableGridLayout.CurrentPoint(1:2) - ResizeableGridLayout.StartPoint(1:2));
        
        ResizeableGridLayout.StartPoint = ResizeableGridLayout.CurrentPoint;

        currSlider = src.CurrentObject;
        if isempty(currSlider), return, end
        switch currSlider.Tag
            case "RSGLSliderHorizontal"
                idx = floor(currSlider.Layout.Column/2);
                newSize = num2cell([ResizeableGridLayout.ColumnWidth{idx:idx+1}]+[1 -1].*d(1));
                if newSize{1} > 10 && newSize{2} > 10
                    ResizeableGridLayout.ColumnWidth(idx:idx+1) = newSize;
                end
            case "RSGLSliderVertical"
                idx = floor(currSlider.Layout.Row/2);
                newSize = num2cell([ResizeableGridLayout.RowHeight{idx:idx+1}]+[-1 1].*d(2));
                if newSize{1} > 10 && newSize{2} > 10 % Ensure window not < 10 px
                    ResizeableGridLayout.RowHeight(idx:idx+1) = newSize;
                end
            case "RSGLSliderCorner"
                idx = floor(currSlider.Layout.Column/2);
                newSize = num2cell([ResizeableGridLayout.ColumnWidth{idx:idx+1}]+[1 -1].*d(1));
                if newSize{1} > 10 && newSize{2} > 10 % Ensure window not < 10 px
                    ResizeableGridLayout.ColumnWidth(idx:idx+1) = newSize;
                end
                idx = floor(currSlider.Layout.Row/2);
                newSize = num2cell([ResizeableGridLayout.RowHeight{idx:idx+1}]+[-1 1].*d(2));
                if newSize{1} > 10 && newSize{2} > 10 % Ensure window not < 10 px
                    ResizeableGridLayout.RowHeight(idx:idx+1) = newSize;
                end
        end
        set(fig,'Units',ResizeableGridLayout.OldUnits);
    end

    function stopDragFcn(ResizeableGridLayout,src,event)
        fig = ancestor(ResizeableGridLayout,'matlab.ui.Figure');
        ResizeableGridLayout.DragFlag = false;
        set(fig,'WindowButtonMotionFcn',ResizeableGridLayout.OldWindowButtonMotionFcn);
        set(fig,'WindowButtonUpFcn',ResizeableGridLayout.OldWindowButtonUpFcn);
        calculateWeights(ResizeableGridLayout);
    end

    function MouseMoving(ResizeableGridLayout)
        fig = ancestor(ResizeableGridLayout,'matlab.ui.Figure');
        p = get(fig,'CurrentPoint');
        panels = ResizeableGridLayout.getAllSliders;
        positions = zeros(length(panels),4);
        for i = 1:length(panels)
            positions(i,:) = getpixelposition(panels(i),true);
        end
        panelIdx = (p(1) > positions(:,1)) & (p(1) < positions(:,1) + positions(:,3)) & (p(2) > positions(:,2)) & (p(2) < positions(:,2) + positions(:,4));
        poi = panels(panelIdx);
        if isempty(poi)
            set(fig,'Pointer','arrow');
        else
            switch poi.Tag
                case "RSGLSliderHorizontal"
                    set(fig,'Pointer','left');
                case "RSGLSliderVertical"
                    set(fig,'Pointer','top');
                case "RSGLSliderCorner"
                    set(fig,'Pointer','fleur');
            end
        end


    end

end
end