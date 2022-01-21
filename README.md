# PlotToLaTeX
Scripts to export MATLAB figures to vector pdf &amp; pdf_tex files for inclusion to LaTeX documents.

PlotToLaTeX is based on Plot2LaTeX v1.2 by Jan de Jong [1]. Due to the workflow breaking changes in behaviour, this is an unofficial fork rather than an unofficially updated version. PlotToLaTeX requires installations of MATLAB and Inkscape, and a Python installation with the Beautiful Soup library, bs4.

PlotToLaTeX offers the following benefits over Plot2LaTeX:
1. Improved text location, removing the need for manual correction factors and iteration of these manual adjustments
2. Individual files for axes, label and colorbar objects, allowing better PDF scaling _e.g._ enabling the same figures to be used at both figure and subfigure scales
3. SVG page area is clipped to form a tight box around non-text elements, simplifying matching the axis size of multiple figures within a LaTeX document. Text, including axis labels, will appear outside the LaTeX figure area and will not affect figure placement.

[1] [Plot2LaTeX](https://www.mathworks.com/matlabcentral/fileexchange/52700-plot2latex), MATLAB Central File Exchange. Retrieved January 20, 2022.

# Installation
- Requires Matlab, Inkscape and Python
- Requires bs4 python library (beautiful soup)
- Place PlotToLaTeX.m and SVGedit.py in Matlab directory
- Within PlotToLaTeX.m, edit DIR_INKSC and DIR_PY values to match your installation locations
