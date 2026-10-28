import sys, json, numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
from extract import BANDS, BG, LINE

def thin(m,maxlen=4):
    out=m.copy(); x=0
    while x<len(m):
        if m[x]:
            s=x
            while x<len(m) and m[x]: x+=1
            if x-s>maxlen: out[s:x]=False
        else: x+=1
    return out

def masks(b):
    d_bg=np.sqrt(((b-BG)**2).sum(2)); d_ln=np.sqrt(((b-LINE)**2).sum(2))
    lineish=d_ln<22; dark=b.mean(2)<60
    gl=np.zeros_like(lineish)
    gl[:,thin(lineish.mean(0)>0.35)]=True; gl[thin(lineish.mean(1)>0.35),:]=True
    gl[:,thin(dark.mean(0)>0.6)]=True
    passable=(d_bg<38)|(gl&(lineish|dark|(d_bg<45)))
    lab,_=ndi.label(passable)
    border=set(np.unique(np.concatenate([lab[0],lab[-1],lab[:,0],lab[:,-1]])))-{0}
    fg=~np.isin(lab,list(border))
    fg=ndi.binary_opening(fg,iterations=1)
    # patch grid-line cuts through sprites
    closed=ndi.binary_closing(fg,structure=np.ones((5,5)))
    fg=fg|(closed&gl)
    # enclosed background holes (bg-colored regions fully inside): remove big ones
    holes=(~fg)
    hl,n=ndi.label(holes)
    # bg-colored enclosed pockets inside sprite fg
    pocket=fg&(d_bg<14)
    pl,pn=ndi.label(pocket)
    if pn:
        sz=ndi.sum(pocket,pl,range(1,pn+1))
        fg&=~np.isin(pl,[i+1 for i,s in enumerate(sz) if s>=150])
    lab2,n=ndi.label(fg)
    sz=ndi.sum(fg,lab2,range(1,n+1))
    fg=np.isin(lab2,[i+1 for i,s in enumerate(sz) if s>=25])
    return fg, gl

def components(fg):
    lab,n=ndi.label(ndi.binary_dilation(fg,iterations=1))
    lab=lab*fg
    objs=ndi.find_objects(lab)
    comps=[]
    for i,sl in enumerate(objs):
        if sl is None: continue
        area=int((lab[sl]==i+1).sum())
        comps.append(dict(id=i+1,x0=sl[1].start,x1=sl[1].stop,y0=sl[0].start,y1=sl[0].stop,area=area))
    comps.sort(key=lambda c:c['x0'])
    # merge small comps into nearest big one if close
    big=[c for c in comps if c['area']>=500]; small=[c for c in comps if c['area']<500]
    for c in big: c['ids']=[c['id']]
    loose=[]
    for s in small:
        cx=(s['x0']+s['x1'])/2
        best=None;bd=1e9
        for c in big:
            gap=max(c['x0']-s['x1'], s['x0']-c['x1'], 0)
            if gap<bd: bd=gap;best=c
        if best is not None and bd<=12:
            best['ids'].append(s['id'])
            for k,f in (('x0',min),('y0',min),('x1',max),('y1',max)): best[k]=f(best[k],s[k])
        else:
            s['ids']=[s['id']]; loose.append(s)
    out=sorted(big+loose,key=lambda c:c['x0'])
    return lab,out

if __name__=='__main__':
    p,tag=sys.argv[1],sys.argv[2]
    img=np.asarray(Image.open(p).convert('RGB')).astype(int)
    allrows=[]
    rows=[]
    for r,(y0,y1) in enumerate(BANDS):
        b=img[y0:y1+1]; fg,_=masks(b); lab,cs=components(fg)
        rows.append([(c['x0'],c['x1'],c['area']) for c in cs])
        rgba=np.dstack([b,np.where(fg,255,0)]).astype('uint8')
        im=Image.new('RGBA',(b.shape[1],b.shape[0]+14),(255,0,255,255))
        sp=Image.fromarray(rgba,'RGBA'); im.paste(sp,(0,14),sp)
        d=ImageDraw.Draw(im)
        for k,c in enumerate(cs):
            d.rectangle([c['x0'],c['y0']+14,c['x1']-1,c['y1']+13],outline=(255,255,0) if c['area']>=500 else (0,255,255))
            d.text((c['x0']+1,0),str(k),fill=(0,0,0))
        allrows.append(im)
    W=max(i.width for i in allrows); H=sum(i.height for i in allrows)
    c=Image.new('RGBA',(W,H)); y=0
    for i in allrows: c.paste(i,(0,y)); y+=i.height
    c.save(f'dbg2_{tag}.png')
    for r in rows: print(len(r), r)
