function PlotToLaTeX( h, filename, options )
%PLOTTOLATEX saves matlab figure as a pdf file in vector format for
%inclusion into LaTeX. Requires free and open-source vector graphics 
%editor Inkscape and an installation of Python with bs4 library. (Based on
%PLOT2LATEX by J.J. de Jong, K.G.P. Folkersma.)
%
%   PLOTTOLATEX(h,filename) saves figure with handle h to a file specified by
%   filename, without extention. Filename can contain a relative location
%   (e.g. 'images\title') to save the figure to different location. 
%
%   PLOTTOLATEX(h,filename, options) saves figure with specified options. 
%   With options.Renderer the renderer of the figure can be specified: 
%   ('opengl', 'painters').
%
%   PLOTTOLATEX requires a installation of Inkscape. The program's 
%   location has to be 'hard coded' into this matlab file if it differs 
%   from 'c:\Program Files (x86)\Inkscape\Inkscape.exe'. Please specify 
%   your inscape file location by modifying DIR_INKSC variable on the 
%   first line of the actual code.
%
%   PLOTTOLATEX requires a installation of Python. The program's 
%   location has to be 'hard coded' into this matlab file. Please specify 
%   your Python file location by modifying the DIR_PY variable on the 
%   second line of the actual code. 
%
%   PLOTTOLATEX saves the figures to .svg format. It invokes Inkscape to
%   save the svg to a .pdf and .pdf_tex file to be incorporated into LaTeX
%   document using \begin{figure} \input{image.pdf_tex} \end{figure}. 
%   More information on the svg to pdf conversion can be found here: 
%   ftp://ftp.fu-berlin.de/tex/CTAN/info/svg-inkscape/InkscapePDFLaTeX.pdf
%   
%   PLOTTOLATEX produces three types of image files: .svg, .pdf, .pfd_tex.
%   The .svg file contains vector image, .pdf file contains figure without
%   text, and .pdf_tex file contains the text and specifies its location 
%   and type setting.
%
%   The produced .svg file can be manually modified in Inkscape and
%   included into the .tex file using the using the built-in "save to pdf" 
%   functionality of Inkscape.
%
%   PLOTTOLATEX saves the figure to a svg and pdf file with the
%   approximately the same width and height. Font is determined by LaTeX.
%
%   Workflow
%   - Matlab renames all strings of the figure to labels. The strings are
%   stored to be used later. To prevent a change in texbox size, labels are
%   padded to match the size of the texbox.
%   - Matlab saves the figure with labels to a svg file.
%   - Matlab opens the svg file and restores the labels with the original
%   string
%   - Matlab invokes Python to edit the svg file and clip page to axes.
%   - Matlab invokes Inkscape to save the svg file to a pdf + pdf_tex file.
%   - The pdf_tex is to be included into LaTeX.
%
%   Features:
%   - It parses LaTeX code, even if it is not supported by Matlab LaTeX.
%   - Supports real transparency.
%   - SVG is a better supported, maintained and editable format than eps
%   - SVG allows simple manual modification into Inkscape.
%
%   Limitation:
%   - Older versions than matlab 2014b are not supported.
%   - PLOTTOLATEX does not work with 3d plots (Matlab exports text, axes
%     in single image object)
%   - PLOTTOLATEX only partially supports yyaxis
%   - PLOTTOLATEX currently does not work with titles consisting of multiple 
%   lines.
%       (can be manually achieved by editing title line in pdf_tex file to
%       resemble the following:
%       \put(0,0){\makebox(0,0)[t]{\lineheight{1.25}\smash{
%       \begin{tabular}[b]{c}\textbf{\raisebox{0.5\height}{
%       Exceedingly long but necessarily verbose title which}}\\ \textbf{
%       \raisebox{0.5\height}{should overflow onto a second line}}
%       \end{tabular}}}}%
%       )
%   - PLOTTOLATEX does not work with annotation textbox objects.
%   - PLOTTOLATEX more consistent legends will be achieved with box off
%   - PLOTTOLATEX does not support coloured text (Inkscape 'save to pdf'
%     limitation).
%   - PLOTTOLATEX does not support contour labels (check if this could be
%     made to work with SVG textPath element?).
%
%   Trouble shooting from PLOT2LATEX - not tested for PLOTTOLATEX
%   - For Unix users: use the installation folder such as:
%   '/Applications/Inkscape.app/Contents/Resources/script ' as location. 
%   - For Unix users: For some users the bash profiles do not allow to call 
%   Inkscape in Matlab via bash. Therefore change the bash profile in Matlab 
%   to something similar as setenv('DYLD_LIBRARY_PATH','/usr/local/bin/').
%   The bash profile location can be found by using '/usr/bin/env bash'
%
%   To do:
%   - Restore Interpreter instead of putting it to LaTeX
%   - Annotation textbox objects
%   - Allow multiple line text
%   - Use findall(h,'-property','String')
%   - Speed up code by smarter string replacent of SVG file
%   - Resize of legend box using: [h,icons,plots,str] = legend(); (not so simple)
%   
%   Based on Plot2LaTeX:
%       Version:  1.2
%       Autor:    J.J. de Jong, K.G.P. Folkersma
%       Date:     20/04/2016
%       Contact:  j.j.dejong@utwente.nl
%       Change log
%       v 1.1 - 02/09/2015 (not released)
%       - Made compatible for Unix systems
%       - Added a waitbar
%       - Corrected the help file
%       v 1.2 - 20/04/2016
%       - Fixed file names with spaces in the name. (Not adviced to use in latex though)
%       - Escape special characters in XML (<,>,',",&) -> (&lt;,&gt;,&apos;,&quot;,&amp;)
%   Fork - PlotToLaTeX - 07/01/2022
%   - Baseline property of text introduced to correctly align tick marker
%     with tick label
%   - Axis label location determined without tick labels, offset then 
%     applied in LaTeX
%   - Manual offset correction no longer required in default case, and label
%     offset in LaTeX document is independent of image scaling
%   - Axis, label, colorbar components saved into individual files to allow for
%     consistent sizing of one axis relative to another in LaTeX document

%% Config and checks
% Specify location of your inkscape and python installation
%DIR_INKSC = 'C:\Program Files (x86)\Inkscape\Inkscape.exe'; 
DIR_INKSC = 'C:\Program Files\Inkscape\bin\Inkscape.exe';
%DIR_PY = "C:\Python39\python.exe"
DIR_PY = "C:/Users/USER/Anaconda3/python.exe"; % or direct to specific environment
% initize waitbar
nStep = 7; Step = 0;
hWaitBar = waitbar(Step/nStep,'Initializing');

%test if installation is correct
if ~exist(DIR_INKSC, 'file')
    error([DIR_INKSC, ' cannot be found, check installation location'])
end
if ~exist(DIR_PY, 'file')
    error([DIR_PY, ' cannot be found, check installation location'])
end
if verLessThan('matlab', '8.4.0.')
	error('Older versions than Matlab 2014b are not supported')
end
if ~strcmp(h.Type,'figure')
    error('h object is not a figure')
end

%% process options, first set default
% do not set default renderer
if nargin > 2
    if isfield(options,'Renderer') %WARNING: large size figures can become very large
        h.Renderer = options.Renderer; % set render
    end
end

%% Find target objects with text
TexObj = findall(h,'Type','Text'); % normal text, titles, x y z labels
LegObj = findall(h,'Type','Legend'); % legend objects
AxeObj = findall(h,'Type','Axes');  % axes containing x y z ticklabel
AxeObj = AxeObj(convertCharsToStrings(get(AxeObj, 'type'))~='axestoolbar');
ColObj = findall(h,'Type','Colorbar'); % containing colorbar tick
PosAnchSVG      = {'start', 'middle', 'end'};
PosAligmentSVG  = {'start', 'center', 'end'};
PosAligmentMAT  = {'left', 'center', 'right'};
PosBaselineSVG  = {'alphabet', 'middle', 'hanging'};
iXLabel = [];
iYLabel = [];
iCLabel = [];

n_Axe = length(LegObj);
for i = 1:n_Axe % scale text omit in next version
    LegPos(i,:) = LegObj(i).Position;
end
ChangeInterpreter(h,'Latex')
h.PaperPositionMode = 'auto'; % Keep current size
%% Replace text with a label
Step = Step + 1;
waitbar(Step/nStep,hWaitBar,'Replacing text with labels');
iLabel = 0; % generate label iterator
n_TexObj = length(TexObj);

for i = 1:n_TexObj % do for text, titles and axes labels
    iLabel = iLabel + 1;
    
    % find text string, flatten multi-line labels
    if iscell(TexObj(i).String)
        Labels(iLabel).TrueText = TexObj(i).String;
        for loop_val = 1:length(Labels(iLabel).TrueText)-1
            Labels(iLabel).TrueText{loop_val} = [Labels(iLabel).TrueText{loop_val}, ' '];
        end
        Labels(iLabel).TrueText = cat(2, Labels(iLabel).TrueText{:});
    else
        Labels(iLabel).TrueText = TexObj(i).String;
    end
    
    % find text aligment
    Labels(iLabel).Alignment = PosAligmentSVG(...
                                    find(ismember(...
                                        PosAligmentMAT,...
                                        TexObj(i).HorizontalAlignment)));
	% find achor aligment svg uses this
    Labels(iLabel).Anchor = PosAnchSVG(...
                                find(ismember(...
                                    PosAligmentMAT,...
                                    TexObj(i).HorizontalAlignment)));
    
    % set baseline, baseline offset and rotation, determine if axis label
    Labels(iLabel).AddBaselineSVG = 0;
    if TexObj(i) == TexObj(i).Parent.XLabel
        Labels(iLabel).Baseline = PosBaselineSVG(3);
        Labels(iLabel).Rotation = TexObj(i).Rotation;
        iXLabel = iLabel;
    elseif TexObj(i) == TexObj(i).Parent.YLabel
        Labels(iLabel).Baseline = PosBaselineSVG(1);
        Labels(iLabel).Rotation = TexObj(i).Rotation;
        iYLabel = iLabel;
    elseif TexObj(i) == TexObj(i).Parent.ZLabel
        Labels(iLabel).Rotation = TexObj(i).Rotation;
    elseif TexObj(i) == TexObj(i).Parent.Title
        Labels(iLabel).Baseline = PosBaselineSVG(1);
        Labels(iLabel).AddBaselineSVG = -0.5;
        Labels(iLabel).Rotation = TexObj(i).Rotation;
    else
        Labels(iLabel).Rotation = TexObj(i).Rotation;
        Labels(iLabel).Baseline = PosBaselineSVG(1);
    end
    
    % generate label
    Labels(iLabel).LabelText = LabelText(iLabel);
    
    % find text position
    Labels(iLabel).Position = TexObj(i).Position;
    
    % replace string with label
    TexObj(i).String = LabelText(iLabel);
end

% do similar for legend objects
n_LegObj = length(LegObj);
for i = 1:n_LegObj
    n_Str = length(LegObj(i).String);
    iLabel = iLabel + 1;
    Labels(iLabel).TrueText = LegObj(i).String{1};
    Labels(iLabel).Alignment = PosAligmentSVG(1); % legends are always left aligned
    Labels(iLabel).Anchor = PosAnchSVG(1);
    Labels(iLabel).Baseline = PosBaselineSVG(2);
    Labels(iLabel).AddBaselineSVG = 0;
    Labels(iLabel).Rotation = 0;
    
    % generate legend label padded with dots to fill text box
    LegObj(i).String{1} = strcat('X', LegText(iLabel));
    while LegPos(i,3) >= LegObj(i).Position(3) % first label of legend should match box size
        LegObj(i).String{1} = [LegObj(i).String{1},'.'];
    end
    LegObj(i).String{1} = [LegObj(i).String{1},'.']; % add one more
    LegObj(i).String{1} = LegObj(i).String{1}(1:end-1);
    Labels(iLabel).LabelText = LegObj(i).String{1}; % write as label
    
    for j = 2:n_Str % do short as possible label for other entries
       iLabel = iLabel + 1;
       Labels(iLabel).TrueText = LegObj(i).String{j};
       Labels(iLabel).Rotation = 0;
       Labels(iLabel).Alignment = PosAligmentSVG(1);
       Labels(iLabel).Anchor = PosAnchSVG(1);
       Labels(iLabel).Baseline = PosBaselineSVG(2);
       Labels(iLabel).AddBaselineSVG = 0;
       LegObj(i).String{j} = strcat('X', LegText(iLabel));
       Labels(iLabel).LabelText = LegObj(i).String{j};
    end
end

% do similar for axes objects, XTick, YTick, ZTick
n_AxeObj = length(AxeObj);
storeXTicks = {};
storeYTicks = {};
storeZTicks = {};
for i = 1:n_AxeObj
    storeXTicks{i} = AxeObj(i).XTickLabel;
    storeYTicks{i} = AxeObj(i).YTickLabel;
    storeZTicks{i} = AxeObj(i).ZTickLabel;
end
for i = 1:n_AxeObj
    n_Str = length(AxeObj(i).XTickLabel);
    for j = 1:n_Str
        iLabel = iLabel + 1;
        Labels(iLabel).TrueText = AxeObj(i).XTickLabel{j};
        Labels(iLabel).Rotation = AxeObj(i).XTickLabelRotation;
        Labels(iLabel).Alignment = PosAligmentSVG(2);
        Labels(iLabel).Anchor = PosAnchSVG(2);
        Labels(iLabel).Baseline = PosBaselineSVG(3);
        Labels(iLabel).AddBaselineSVG = 0;
        Labels(iLabel).LabelText = LabelText(iLabel);
        AxeObj(i).XTickLabel{j} = LabelText(iLabel);
    end
    if ~isempty(iXLabel)
        Labels(iXLabel).AddBaselineSVG = 1.75;
    end
    
    isRightAx = strcmp(AxeObj(i).YAxisLocation,'right'); % exception for yyaxis
    n_Str = length(AxeObj(i).YTickLabel);
    YAddBaselineSVG = 0;
    for j = 1:n_Str
        iLabel = iLabel + 1;
        Labels(iLabel).TrueText = AxeObj(i).YTickLabel{j};
        Labels(iLabel).Rotation = AxeObj(i).YTickLabelRotation;
        Labels(iLabel).Baseline = PosBaselineSVG(2);
        Labels(iLabel).AddBaselineSVG = 0;
        if isRightAx % exception for yyaxis
            Labels(iLabel).Alignment = PosAligmentSVG(1);
            Labels(iLabel).Anchor = PosAnchSVG(1);
        else % normal y labels are right aligned
            Labels(iLabel).Alignment = PosAligmentSVG(3);
            Labels(iLabel).Anchor = PosAnchSVG(3);
        end
        Labels(iLabel).LabelText = LabelText(iLabel);
        AxeObj(i).YTickLabel{j} = LabelText(iLabel);
        if length(Labels(iLabel).TrueText) > YAddBaselineSVG
            YAddBaselineSVG = length(Labels(iLabel).TrueText);
        end
    end
    if ~isempty(iYLabel) % exception for yyaxis
        Labels(iYLabel).AddBaselineSVG = YAddBaselineSVG;
        if isRightAx
            Labels(iYLabel).Baseline = PosBaselineSVG(3);
        end
    end
end

% do similar for color bar objects
n_ColObj = length(ColObj); 
for i = 1:n_ColObj
    isAxIn = strcmp(ColObj(i).AxisLocation,'in'); % find internal external text location
    isAxEast = strcmp(ColObj(i).Location,'east')||strcmp(ColObj(i).Location,'eastoutside'); % find location
    isRightAx = isAxIn ~= isAxEast;
    
    n_Str = length(ColObj(i).TickLabels);
    CAddBaselineSVG = 0;
    for j = 1:n_Str
        iLabel = iLabel + 1;
        Labels(iLabel).TrueText = ColObj(i).TickLabels{j};
        Labels(iLabel).Rotation = 0;
        Labels(iLabel).Baseline = PosBaselineSVG(2);
        Labels(iLabel).AddBaselineSVG = 0;
        if isRightAx % if text is right aligned
            Labels(iLabel).Alignment = PosAligmentSVG(1);
            Labels(iLabel).Anchor = PosAnchSVG(1);
        else % if text is left aligned
            Labels(iLabel).Alignment = PosAligmentSVG(3);
            Labels(iLabel).Anchor = PosAnchSVG(3);
        end
        Labels(iLabel).LabelText = LabelText(iLabel);
        ColObj(i).TickLabels{j} = LabelText(iLabel);
        if length(Labels(iLabel).TrueText) > CAddBaselineSVG
            CAddBaselineSVG = length(Labels(iLabel).TrueText);
        end
    end
    
    if ~isempty(ColObj(i).Label.String)
        iLabel = iLabel + 1;
        Labels(iLabel).TrueText = ColObj(i).Label.String;
        Labels(iLabel).Rotation = ColObj(i).Label.Rotation;
        Labels(iLabel).Baseline = PosBaselineSVG(3);
        Labels(iLabel).Alignment = PosAligmentSVG(2);
        Labels(iLabel).Anchor = PosAnchSVG(2);
        Labels(iLabel).LabelText = LabelText(iLabel);
        ColObj(i).Label.String = LabelText(iLabel);
        iCLabel = iLabel;
        Labels(iCLabel).AddBaselineSVG = CAddBaselineSVG;
    end
    
end
nLabel = iLabel;

% set text interpreter to plain text
ChangeInterpreter(h,'none');

%% Save figure components to SVG
Step = Step + 1;
waitbar(Step/nStep,hWaitBar,'Saving figure to .svg file');
% savefig(h,[filename,'_temp']); % to see the intermediate situation

% save legend (if exists), then hide
for loop_val1 = 1:n_LegObj
    for loop_val2 = 1:n_ColObj % hide colorbar if it exists
        ColObj(loop_val2).Visible = 'off';
    end
    saveLegendToSVG(h, AxeObj(1), filename)
    for loop_val2 = 1:n_ColObj % show colorbar if it exists
        ColObj(loop_val2).Visible = 'on';
    end
    LegObj(loop_val1).Visible = 'off';
end

% store tick labels for axes and colorbar, then remove
for loop_val1 = 1:n_AxeObj
    set(AxeObj(loop_val1),'xtick',[],'ytick',[]);
end
for loop_val1 = 1:n_ColObj
    store_CLabels{loop_val1} = get(ColObj(loop_val1),'TickLabels');
    set(ColObj(loop_val1),'TickLabels',[]);
end

% export tick label free plot to svg - used to better determine appropriate
% axis label positions - then recover tick labels
saveas(h,[filename, '_notick'],'svg'); 
for loop_val1 = 1:n_AxeObj
    set(AxeObj(loop_val1),'xtick',str2double(storeXTicks{loop_val1}),'ytick',str2double(storeYTicks{loop_val1}));
end
for loop_val1 = 1:n_ColObj
    set(ColObj(loop_val1),'TickLabels',store_CLabels{loop_val1});
end

% save colorbar (if exists) then hide
for loop_val1 = 1:n_ColObj
    saveCBarToSVG(h, AxeObj(1), filename)
    ColObj(loop_val1).Visible = 'off';
end

% save axes (no legend or colorbar)
saveas(h,filename,'svg'); % export to svg

% recover legend or colorbar
for loop_val1 = 1:n_LegObj
    LegObj(loop_val1).Visible = 'on';
end
for loop_val1 = 1:n_ColObj
    ColObj(loop_val1).Visible = 'on';
end

%% Fetch axis and colorbar label position from *_notick.svg
Step = Step + 1;
waitbar(Step/nStep,hWaitBar,'Fixing text position');
for iLabel = 1:nLabel
    Labels(iLabel).XMLText = EscapeXML(Labels(iLabel).TrueText);
end

fin = fopen([filename,'_notick.svg']); % open svg file
StrLine2 = fgetl(fin); %skip first two lines
StrLine3_mod = fgetl(fin);%skip first line
iLine = 2; % Line number
nFoundLabel = 0; % Counter of number of found labels
while ~feof(fin)
    StrLine1 = StrLine2;
    StrLine2 = StrLine3_mod; % process new line
    iLine = iLine + 1;
    StrLine3 = fgetl(fin);
    
    FoundLabelText = regexp(StrLine3,'>\S*</text','match'); %try to find label
    StrLine3_mod = StrLine3;
    if ~isempty(FoundLabelText)
        if FoundLabelText{1}(2) == 'X'
            nFoundLabel = nFoundLabel + 1;
            iLabel = find(ismember(...
                {Labels.LabelText},...
                FoundLabelText{1}(2:end-6))); % find label number
            
            if iLabel == iXLabel
                XLabelStrLine1 = StrLine1;
                XLabelStrLine2 = StrLine2;
            elseif iLabel == iYLabel
                YLabelStrLine1 = StrLine1;
                YLabelStrLine2 = StrLine2;
            elseif iLabel == iCLabel
                CLabelStrLine1 = StrLine1;
                CLabelStrLine2 = StrLine2;
            end
        end
    end
end
fclose(fin);

%% Modify SVG files to replace labels with original text
Step = Step + 1;
waitbar(Step/nStep,hWaitBar,'Restoring text in .svg file');
% apply to each plot component svg
flist = [string(filename)];
if n_LegObj>0
    flist = [flist, string([filename, '_leg'])];
end
if n_ColObj>0
    flist = [flist, string([filename, '_cbar'])];
end
for fcount = 1:length(flist)
    fname = char(flist(fcount));
    fin = fopen([fname,'.svg']); % open svg file
    fout = fopen([fname,'_temp.svg'],'w'); % make a temp file for modification
    StrLine2 = fgetl(fin); %skip first two lines
    StrLine3_mod = fgetl(fin);
    iLine = 2; % Line number
    nFoundLabel = 0; % Counter of number of found labels
    while ~feof(fin)
        StrLine1 = StrLine2;
        StrLine2 = StrLine3_mod; % process new line
        iLine = iLine + 1;
        StrLine3 = fgetl(fin);

        FoundLabelText = regexp(StrLine3,'>\S*</text','match'); %try to find label
        StrLine3_mod = StrLine3;
        if ~isempty(FoundLabelText)
            if FoundLabelText{1}(2) == 'X'
                nFoundLabel = nFoundLabel + 1;
                iLabel = find(ismember(...
                    {Labels.LabelText},...
                    FoundLabelText{1}(2:end-6))); % find label number
                if iLabel == iXLabel
                    StrLine1 = XLabelStrLine1;
                    StrLine2 = XLabelStrLine2;
                elseif iLabel == iYLabel
                    StrLine1 = YLabelStrLine1;
                    StrLine2 = YLabelStrLine2;
                elseif iLabel == iCLabel
                    StrLine1 = CLabelStrLine1;
                    StrLine2 = CLabelStrLine2;
                end

                % Append text alignment in prevous line
                StrLine2Temp = [StrLine2(1:end-1),...
                    'text-align:', Labels(iLabel).Alignment{1},...
                    ';text-anchor:', Labels(iLabel).Anchor{1},...
                    ';dominant-baseline:',Labels(iLabel).Baseline{1},'"'];

                % correct x - position offset
                StrLine2Temp = regexprep(StrLine2Temp,'x="\S*"','x="0"');

                % correct y - position offset
                [startIndex,endIndex] = regexp(StrLine2Temp,'y="\S*"');
                yCorrFactor=0;
                yOffset = 0*str2double(StrLine2Temp((startIndex+3):(endIndex-1)));
                StrLine2Temp = regexprep(...
                    StrLine2Temp,...
                    'y="\S*"',...
                    ['y="', num2str(yOffset*yCorrFactor), '"']);

                % Replace label with original string
                if Labels(iLabel).Rotation == 90 || Labels(iLabel).Rotation == 270
                    if string(Labels(iLabel).Baseline{1}) == string(PosBaselineSVG{3})
                        StrCurrTemp = strrep(StrLine3, ...
                            FoundLabelText,...
                            ['>\raisebox{-',char(string(2+Labels(iLabel).AddBaselineSVG)),'ex}{',Labels(iLabel).XMLText,'}</text']);
                    elseif string(Labels(iLabel).Baseline{1}) == string(PosBaselineSVG{2})
                        StrCurrTemp = strrep(StrLine3, ...
                            FoundLabelText,...
                            ['>\raisebox{-',char(string(1.5+Labels(iLabel).AddBaselineSVG)),'ex}{',Labels(iLabel).XMLText,'}</text']);
                    else
                        StrCurrTemp = strrep(StrLine3, ...
                            FoundLabelText,...
                            ['>\raisebox{',char(string(1+Labels(iLabel).AddBaselineSVG)),'ex}{',Labels(iLabel).XMLText,'}</text']);
                    end
                else
                    if string(Labels(iLabel).Baseline{1}) == string(PosBaselineSVG{3})
                        StrCurrTemp = strrep(StrLine3, ...
                            FoundLabelText,...
                            ['>\raisebox{-',char(string(1+Labels(iLabel).AddBaselineSVG)),'\height}{',Labels(iLabel).XMLText,'}</text']);
                    elseif string(Labels(iLabel).Baseline{1}) == string(PosBaselineSVG{2})
                        StrCurrTemp = strrep(StrLine3, ...
                            FoundLabelText,...
                            ['>\raisebox{-',char(string(0.5+Labels(iLabel).AddBaselineSVG)),'\height}{',Labels(iLabel).XMLText,'}</text']);
                    else
                        StrCurrTemp = strrep(StrLine3, ...
                            FoundLabelText,...
                            ['>\raisebox{-',char(string(Labels(iLabel).AddBaselineSVG)),'\height}{',Labels(iLabel).XMLText,'}</text']);
                    end
                end
                StrLine3_mod = StrCurrTemp{:};
                StrLine2 = StrLine2Temp;
            end
        end
        fprintf(fout,'%s\n',StrLine1);
    end
    fprintf(fout,'%s\n',StrLine2);
    fprintf(fout,'%s\n',StrLine3_mod);
    fclose(fin);
    fclose(fout);
    movefile([fname,'_temp.svg'],[fname,'.svg'])

    %% Python script reduces SVG page area to tightly fit non text elements
    Step = Step + 1;
    waitbar(Step/nStep,hWaitBar,'Clip .svg page area for tight fit');
    
    svgFin = string(fname);
    svgFout = string(fname);
    system(strcat(DIR_PY, " edit_svg.py ", svgFin, ".svg ", svgFout, ".svg"));

    %% Invoke Inkscape to generate PDF + LaTeX
    Step = Step + 1;
    waitbar(Step/nStep,hWaitBar,'Saving .svg to .pdf file');
    %DIR_FIG = [pwd,'\'];
    DIR_FIG = fname;
    % Use Inkscape to update Matlab generated SVG version from 1.0 to current
    [status,cmdout] = system(['"', DIR_INKSC, '"',...
                              ' "', DIR_FIG,'.svg"', ...
                              ' ','--export-type="svg"',...
                              ' ','--export-filename=',DIR_FIG,'.svg"'...
                              ' ','--export-area-drawing']);
                          
    % Export to pdf + latex                     
    [status,cmdout] = system(['"', DIR_INKSC, '"',...
                              ' "', DIR_FIG,'.svg"', ...
                              ' ','--export-type="pdf"',...
                              ' ','--export-latex',...
                              ' ','--export-area-page']);

    % test if a .pdf and .pdf_tex file exist
    %if exist([filename,'.pdf'],'file')~= 2 || exist([filename,'.pdf_tex'],'file')~= 2
    if ~isfile([fname,'.pdf']) || ~isfile([fname,'.pdf_tex'])
        disp(status)
        disp(cmdout)
        warning('No .pdf or .pdf_tex file produced, please check your Inkscape installation and specify installation directory correctly.')
    end
end

%% Restore figure in matlab
% for nicety replace labels with the original text
Step = Step + 1;
waitbar(Step/nStep,hWaitBar,'Restoring Matlab figure');
iLabel = 0;
n_TexObj = length(TexObj);
for i = 1:n_TexObj % 
    iLabel = iLabel + 1;                           
    TexObj(i).String = Labels(iLabel).TrueText;
end
n_LegObj = length(LegObj);
for i = 1:n_LegObj
    n_Str = length(LegObj(i).String);
    for j = 1:n_Str
       iLabel = iLabel + 1;
       LegObj(i).String{j} = Labels(iLabel).TrueText;
    end
end
n_AxeObj = length(AxeObj);
for i = 1:n_AxeObj
    n_Str = length(AxeObj(i).XTickLabel);
    for j = 1:n_Str
        iLabel = iLabel + 1;
        AxeObj(i).XTickLabel{j} = Labels(iLabel).TrueText;
    end
    
    n_Str = length(AxeObj(i).YTickLabel);
    for j = 1:n_Str
        iLabel = iLabel + 1;
        AxeObj(i).YTickLabel{j} = Labels(iLabel).TrueText;
    end
    
    n_Str = length(AxeObj(i).ZTickLabel);
    for j = 1:n_Str
        iLabel = iLabel + 1;
        AxeObj(i).ZTickLabel{j} = Labels(iLabel).TrueText;
    end
end
n_AxeObj = length(ColObj);
for i = 1:n_AxeObj
    n_Str = length(ColObj(i).TickLabels);
    for j = 1:n_Str
        iLabel = iLabel + 1;
        ColObj(i).TickLabels{j} = Labels(iLabel).TrueText;
    end
    if ~isempty(ColObj(i).Label.String)
        iLabel = iLabel + 1;
        ColObj(i).Label.String = Labels(iLabel).TrueText;
    end
end
% restore interpreter
ChangeInterpreter(gcf,'Latex')
close(hWaitBar);
end
function Str = LabelText(iLabel)
% LABELTEXT generates labels based on label number
    Str = 'X000';
    idStr = num2str(iLabel);
    nStr = length(idStr);
    Str(end - nStr + 1 : end ) = idStr;
end
function Str = LegText(iLedEntry)
% LEGTEXT generates legend labels based on legend entry number
    Str = num2str(iLedEntry);
end
function ChangeInterpreter(h,Interpreter)
% CHANGEINTERPRETER puts interpeters in figure h to Interpreter
    TexObj = findall(h,'Type','Text');
    LegObj = findall(h,'Type','Legend');
    AxeObj = findall(h,'Type','Axes');  
    ColObj = findall(h,'Type','Colorbar');
    
    Obj = [TexObj;LegObj]; % Tex and Legend opbjects can be treated similar
    
    n_Obj = length(Obj);
    for i = 1:n_Obj
        Obj(i).Interpreter = Interpreter;
    end
    
    Obj = [AxeObj;ColObj]; % Axes and colorbar opbjects can be treated similar
    
    n_Obj = length(Obj);
    for i = 1:n_Obj
        if get(Obj(i), 'type') ~= "axestoolbar"
            Obj(i).TickLabelInterpreter = Interpreter;
        end
    end
end
function strXML = EscapeXML(str)
% ESCAPEXML repaces special characters(<,>,',",&) -> (&lt;,&gt;,&apos;,&quot;,&amp;)
    escChar = {'&','<','>','''','"'};
    repChar = {'&amp;','&lt;','&gt;','&apos;','&quot;'};
    strXML = regexprep(str,escChar,repChar);
end
function saveLegendToSVG(h_fig, h_ax, filename)
    % make all contents in figure invisible, except legend
    h_children = h_ax.Children;
    for i = 1:length(h_children)
        h_children(i).Visible = 'off';
    end
    axis off;
    h_ax.Title.Visible = 'off';
    
    saveas(h_fig, [filename, '_leg.svg'], 'svg');
    
    for i = 1:length(h_children)
        h_children(i).Visible = 'on';
    end
    axis on;
    h_ax.Title.Visible = 'on';
end
function saveCBarToSVG(h_fig, h_ax, filename)
    %make all contents in figure invisible, except colorbar
    h_children = h_ax.Children;
    for i = 1:length(h_children)
        h_children(i).Visible = 'off';
    end
    axis off
    h_ax.Title.Visible = 'off';
    
    saveas(h_fig, [filename, '_cbar.svg'], 'svg');
    
    for i = 1:length(h_children)
        h_children(i).Visible = 'on';
    end
    axis on;
    h_ax.Title.Visible = 'on';
end
