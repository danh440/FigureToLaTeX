# SVGedit.py
"""Python script reduces SVG page area to tightly fit non text elements"""
from bs4 import BeautifulSoup
import re
import sys

def SVGopen(fin):
    with open(fin) as f:
        content = f.read()
        soup = BeautifulSoup(content, "html.parser")
        gtags = soup.g.find_all('g')
        #print(soup.g)
        fig_height = soup.svg['height']
        fig_width = soup.svg['width']
        for fullPageTag in soup.g.find_all('rect', {'height':fig_height, 'width':fig_width}):
            fullPageTag.parent.decompose()
        
        for fullPagePath in soup.g.find_all('path'):
            fullPagePathd = fullPagePath.get_attribute_list('d')[0]
            if fig_height in fullPagePathd and fig_width in fullPagePathd:
                fullPagePath.parent.decompose()
        for clipPath in soup.g.find_all('clippath'):
            clipPath.decompose()
        # Matlab fades text colour in legend when series are hidden; revert this in SVG
        if fin[-8:-4]=="_leg":
            for ttag in soup.g.find_all('text'):
                ttagStyle = ttag.parent.get_attribute_list('style')[0]
                if ("fill:rgb(156,156,156)" in ttagStyle) and ("stroke:rgb(156,156,156)" in ttagStyle):
                    ttagStyle = re.sub(r"fill:rgb\(156,156,156\)", r"fill:rgb(38,38,38)", ttagStyle)
                    ttagStyle = re.sub(r"stroke:rgb\(156,156,156\)", r"stroke:rgb(38,38,38)", ttagStyle)
                    ttag.parent.attrs['style'] = ttagStyle;
        
        XLst = []
        YLst = []
        for svgPath in soup.g.find_all('path'):
            locStr = ' '.join(re.findall(r'-{0,1}\d*\.*\d*', svgPath.get_attribute_list('d')[0]))
            locLst = locStr.split()
            if svgPath.get_attribute_list('transform')[0] is not None:
                trStr = svgPath.attrs['transform']
                trVal = re.findall(r'translate\(-{0,1}\d*\.*\d*,-{0,1}\d*\.*\d*\)', trStr)[0][10:-1].split(",")
                Xtr= float(trVal[0])
                Ytr = float(trVal[1])
            else:
                Xtr = 0
                Ytr = 0
            
            if svgPath.parent.get_attribute_list('transform')[0] is not None:
                trStr = svgPath.parent.attrs['transform']
                trVal = re.findall(r'translate\(-{0,1}\d*\.*\d*,-{0,1}\d*\.*\d*\)', trStr)[0][10:-1].split(",")
                XPtr= float(trVal[0])
                YPtr = float(trVal[1])
            else:
                XPtr = 0
                YPtr = 0
            
            svgPathStyle = svgPath.get_attribute_list('style')[0]
            linVal = []
            if ("fill:none" in svgPathStyle) and (svgPath.parent.get_attribute_list('style')[0] is not None):
                linStr = svgPath.parent.attrs['style']
                linVal = re.findall(r"stroke-width:\d*\.*\d*", linStr)
                
            if len(linVal) > 0:
                linVal = linVal[0]
                strWidth = float(linVal[13:])/2
                XPair = list(map(float,locLst[0::2]))
                XPair_sub = [x+Xtr+XPtr-strWidth for x in XPair]
                XPair_add = [x+Xtr+XPtr+strWidth for x in XPair]
                XLst.extend(XPair_sub)
                XLst.extend(XPair_add)
                YPair = list(map(float,locLst[1::2]))
                YPair_sub = [y+Ytr+YPtr-strWidth for y in YPair]
                YPair_add = [y+Ytr+YPtr+strWidth for y in YPair]
                YLst.extend(YPair_sub)
                YLst.extend(YPair_add)
            else:
                XLst.extend([x + Xtr + XPtr for x in list(map(float,locLst[0::2]))])
                YLst.extend([y + Ytr + YPtr for y in list(map(float,locLst[1::2]))])
        
        for svgLine in soup.g.find_all('line'):
            linStr = svgLine.parent.get_attribute_list("style")[0]
            linVal = re.findall(r'stroke-width:\d*\.*\d*', linStr)[0]
            strWidth = float(linVal[13:])/2
            XPair = list(map(float,[svgLine.get_attribute_list('x1')[0],svgLine.get_attribute_list('x2')[0]]))
            XPair_sub = [x-strWidth for x in XPair]
            XPair_add = [x+strWidth for x in XPair]
            XLst.extend(XPair_sub)
            XLst.extend(XPair_add)
            YPair = list(map(float,[svgLine.get_attribute_list('y1')[0],svgLine.get_attribute_list('y2')[0]]))
            YPair_sub = [y-strWidth for y in YPair]
            YPair_add = [y+strWidth for y in YPair]
            YLst.extend(YPair_sub)
            YLst.extend(YPair_add)
        
        soup.svg['width'] = str(max(XLst) - min(XLst))
        soup.svg['height'] = str(max(YLst) - min(YLst))
        soup.g['transform'] = 'translate(' + str(-min(XLst)) + ',' + str(-min(YLst)) + ')'
    return soup

# accept command line arguments
svgFin = sys.argv[1]
svgFout = sys.argv[2]
SVGsoup = SVGopen(svgFin)

with open(svgFout, "w", encoding='utf-8') as fout:
    fout.write(str(SVGsoup))
