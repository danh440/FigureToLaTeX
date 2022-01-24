# edit_svg.py
"""Python script reduces SVG page area to tightly fit non text elements"""
from bs4 import BeautifulSoup
import re
import sys


def clip_svg(fin):
    with open(fin) as f:
        content = f.read()
        soup = BeautifulSoup(content, "html.parser")
        fig_height = soup.svg['height']
        fig_width = soup.svg['width']
        for rect_fullpage in soup.g.find_all('rect', {'height': fig_height, 'width': fig_width}):
            rect_fullpage.parent.decompose()

        for path_fullpage in soup.g.find_all('path'):
            path_fullpage_d = path_fullpage.get_attribute_list('d')[0]
            if fig_height in path_fullpage_d and fig_width in path_fullpage_d:
                path_fullpage.parent.decompose()

        for clippath in soup.g.find_all('clippath'):
            clippath.decompose()

        # MATLAB fades text colour in legend when series are hidden; revert this in SVG
        if fin[-8:-4] == "_leg":
            for text in soup.g.find_all('text'):
                text_style = text.parent.get_attribute_list('style')[0]
                if ("fill:rgb(156,156,156)" in text_style) and ("stroke:rgb(156,156,156)" in text_style):
                    text_style = re.sub(r"fill:rgb\(156,156,156\)", r"fill:rgb(38,38,38)", text_style)
                    text_style = re.sub(r"stroke:rgb\(156,156,156\)", r"stroke:rgb(38,38,38)", text_style)
                    text.parent.attrs['style'] = text_style

        x_lst = []
        y_lst = []
        for path in soup.g.find_all('path'):
            path_d_lst = ' '.join(re.findall(r'-{0,1}\d*\.*\d*', path.get_attribute_list('d')[0])).split()
            x_tr = 0
            y_tr = 0
            if path.get_attribute_list('transform')[0] is not None:
                path_tr_str = path.attrs['transform']
                path_tr_lst = re.findall(r'translate\(-{0,1}\d*\.*\d*,-{0,1}\d*\.*\d*\)', path_tr_str)[0][10:-1] \
                    .split(",")
                x_tr = x_tr + float(path_tr_lst[0])
                y_tr = y_tr + float(path_tr_lst[1])

            if path.parent.get_attribute_list('transform')[0] is not None:
                path_tr_str = path.parent.attrs['transform']
                path_tr_lst = re.findall(r'translate\(-{0,1}\d*\.*\d*,-{0,1}\d*\.*\d*\)', path_tr_str)[0][10:-1] \
                    .split(",")
                x_tr = x_tr + float(path_tr_lst[0])
                y_tr = y_tr + float(path_tr_lst[1])

            path_style = path.get_attribute_list('style')[0]
            path_stroke_width_str = []
            if ("fill:none" in path_style) and (path.parent.get_attribute_list('style')[0] is not None):
                path_style_str = path.parent.attrs['style']
                path_stroke_width_str = re.findall(r"stroke-width:\d*\.*\d*", path_style_str)

            if len(path_stroke_width_str) > 0:
                path_stroke_width = float(path_stroke_width_str[0][13:]) / 2
                x_path_lst = list(map(float, path_d_lst[0::2]))
                x_path_lst_sub = [x + x_tr - path_stroke_width for x in x_path_lst]
                x_path_lst_add = [x + x_tr + path_stroke_width for x in x_path_lst]
                x_lst.extend(x_path_lst_sub)
                x_lst.extend(x_path_lst_add)
                y_path_lst = list(map(float, path_d_lst[1::2]))
                y_path_lst_sub = [y + y_tr - path_stroke_width for y in y_path_lst]
                y_path_lst_add = [y + y_tr + path_stroke_width for y in y_path_lst]
                y_lst.extend(y_path_lst_sub)
                y_lst.extend(y_path_lst_add)
            else:
                x_lst.extend([x + x_tr for x in list(map(float, path_d_lst[0::2]))])
                y_lst.extend([y + y_tr for y in list(map(float, path_d_lst[1::2]))])

        for line in soup.g.find_all('line'):
            line_style_str = line.parent.get_attribute_list("style")[0]
            line_stroke_width = float(re.findall(r'stroke-width:\d*\.*\d*', line_style_str)[0][13:]) / 2
            x_line_lst = list(map(float, [line.get_attribute_list('x1')[0], line.get_attribute_list('x2')[0]]))
            x_line_lst_sub = [x - line_stroke_width for x in x_line_lst]
            x_line_lst_add = [x + line_stroke_width for x in x_line_lst]
            x_lst.extend(x_line_lst_sub)
            x_lst.extend(x_line_lst_add)
            y_line_lst = list(map(float, [line.get_attribute_list('y1')[0], line.get_attribute_list('y2')[0]]))
            y_line_lst_sub = [y - line_stroke_width for y in y_line_lst]
            y_line_lst_add = [y + line_stroke_width for y in y_line_lst]
            y_lst.extend(y_line_lst_sub)
            y_lst.extend(y_line_lst_add)

        soup.svg['width'] = str(max(x_lst) - min(x_lst))
        soup.svg['height'] = str(max(y_lst) - min(y_lst))
        soup.g['transform'] = 'translate(' + str(-min(x_lst)) + ',' + str(-min(y_lst)) + ')'
    return soup


# accept command line arguments
fin_svg = sys.argv[1]
fout_svg = sys.argv[2]
soup_svg = clip_svg(fin_svg)

with open(fout_svg, "w", encoding='utf-8') as fout:
    fout.write(str(soup_svg))
