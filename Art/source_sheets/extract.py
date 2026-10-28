import sys, json, numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

BANDS=[(25,116),(162,255),(292,381),(418,504),(541,633),(671,765)]
BG=np.array([86,102,110]); LINE=np.array([31,42,47])

def fg_mask(b):
    d_bg=np.sqrt(((b-BG)**2).sum(2)); d_ln=np.sqrt(((b-LINE)**2).sum(2))
    bgish=d_bg<30
    lineish=d_ln<22
    # grid lines: columns/rows where most pixels are line colored
    H,W=lineish.shape
    linecols=lineish.mean(0)>0.35; linerows=lineish.mean(1)>0.35
    gl=np.zeros_like(lineish); gl[:,linecols]=True; gl[linerows,:]=True
    # also dark divider columns: dark & lowish saturation, majority of column
    dark=(b.mean(2)<60)
    divcols=dark.mean(0)>0.6
    gl[:,divcols]=True
    passable=bgish|(gl&(lineish|dark))|(gl&(d_bg<45))
    # mild halo: pixels moderately close to bg mix
    passable|=d_bg<38
    # flood from border
    lab,_=ndi.label(passable)
    border=set(np.unique(np.concatenate([lab[0],lab[-1],lab[:,0],lab[:,-1]])))-{0}
    outside=np.isin(lab,list(border))
    fg=~outside
    # also kill pixels that are on grid lines & line colored even if enclosed? no.
    fg=ndi.binary_opening(fg,iterations=1)
    # remove tiny specks
    lab2,n=ndi.label(fg)
    sizes=ndi.sum(fg,lab2,range(1,n+1))
    keep=np.isin(lab2,[i+1 for i,s in enumerate(sizes) if s>=25])
    return keep

def clusters(fg,gap=3):
    col=fg.sum(0)>0
    out=[];x=0;W=len(col)
    while x<W:
        if col[x]:
            s=x
            while x<W and col[x]: x+=1
            out.append([s,x-1])
        else: x+=1
    # merge clusters separated by < gap
    m=[]
    for c in out:
        if m and c[0]-m[-1][1]<=gap: m[-1][1]=c[1]
        else: m.append(c)
    return m

if __name__=='__main__':
    p,tag=sys.argv[1],sys.argv[2]
    img=np.asarray(Image.open(p).convert('RGB')).astype(int)
    res=[]
    for i,(y0,y1) in enumerate(BANDS):
        b=img[y0:y1+1]; fg=fg_mask(b)
        cs=clusters(fg)
        res.append([(c[0],c[1],int(fg[:,c[0]:c[1]+1].sum())) for c in cs])
        # debug image
        rgba=np.dstack([b,np.where(fg,255,0)]).astype('uint8')
        im=Image.new('RGBA',(b.shape[1],b.shape[0]+14),(255,0,255,255))
        im.paste(Image.fromarray(rgba,'RGBA'),(0,14),Image.fromarray(rgba,'RGBA'))
        d=ImageDraw.Draw(im)
        for k,c in enumerate(cs):
            d.rectangle([c[0],14,c[1],b.shape[0]+13],outline=(255,255,0))
            d.text((c[0],0),str(k),fill=(0,0,0))
        im.save(f'dbg_{tag}_{i}.png')
    print(json.dumps(res))
