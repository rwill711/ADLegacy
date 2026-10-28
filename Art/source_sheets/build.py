"""Slices monsters_sheet.jpg / heroes_sheet.jpg into per-character strips.
Run: python build.py   (writes assets/sprites/characters/*.png + meta.json)
SPEC maps blob indices in each sheet row to animations; FPS/LOOP set timing.
After re-running, regenerate scripts/units/unit_sprite_data.gd from meta.json."""
import sys, json, numpy as np
from PIL import Image
from scipy import ndimage as ndi
from extract import BANDS
from extract2 import masks, components

import os
HERE=os.path.dirname(os.path.abspath(__file__))
MON=os.path.join(HERE,'monsters_sheet.jpg')
HERO=os.path.join(HERE,'heroes_sheet.jpg')
OUT=sys.argv[1] if len(sys.argv)>1 else os.path.join(HERE,'..','..','assets','sprites','characters')
r=lambda a,b: list(range(a,b+1))
S=lambda i,n:[('split',i,n,k) for k in range(n)]
M=lambda *ids:[('merge',ids)]
# name: (sheet,row, {anim: [frames]}, scale)
SPEC={
 'slime':   (MON,0,{'idle':[0],'walk':[2,4],'attack':[5],'attack2':[5],'cast':[7],'hit':[8],'death':[9]}),
 'panther': (MON,1,{'idle':[0],'walk':[1,2],'run':[3,4],'attack':[5],'attack2':[6],'cast':[7],'hit':[8],'death':[9]}),
 'dragon':  (MON,2,{'idle':[0],'walk':[1],'run':[2,3],'attack':[5],'attack2':[4],'cast':[6],'hit':[7],'death':[8]}),
 'werewolf':(MON,3,{'idle':[0],'walk':[1,2,3],'run':[4,5],'attack':[6],'attack2':[7],'cast':[8],'hit':[9],'death':S(10,2)}),
 'wolf':    (MON,4,{'idle':[0,1,2],'walk':S(3,3),'run':[5,6],'attack':[8],'attack2':[8],'cast':S(11,2)[1:],'hit':[10],'death':S(12,3)}),
 'zombie':  (MON,5,{'idle':[0,1,2],'walk':r(3,7),'run':[8,9],'attack':[12,13,14],'attack2':[12,13,14],'cast':[15,16,17],'hit':[18,19,20],'death':[21,22,23]}),
 'knight_m':(HERO,0,{'idle':[0,1,2],'walk':r(3,7),'run':r(8,11),'attack':[12,13,14],'attack2':[15,16,17],'cast':[15,16,17],'hit':[18,19],'death':S(20,3)}),
 'knight_f':(HERO,1,{'idle':[0,1,2],'walk':r(3,7),'run':r(8,11),'attack':[12,13,14,15],'attack2':[16,17,18],'cast':[16,17,18],'hit':[19,20],'death':S(21,2)+[22]}),
 'wizard_m':(HERO,2,{'idle':[0,1,2],'walk':r(3,7),'attack':[8,9,10],'attack2':[12]+S(13,2)+[14],'cast':[15,16],'hit':[17,18],'death':[19]+S(20,2)}),
 'wizard_f':(HERO,3,{'idle':[0,1,2],'walk':r(3,7),'attack':[8,9,10,11],'attack2':[12,13,14,15],'cast':[16,17],'hit':[18,19],'death':[20,21,22]}),
 'rogue_m': (HERO,4,{'idle':[0,1,2],'walk':r(3,7),'run':[8,9,10,11],'attack':[12,13,14],'attack2':[15]+S(16,2),'cast':[15]+S(16,2),'hit':[17,18,19],'death':S(20,3)}),
 'rogue_f': (HERO,5,{'idle':[0,1,2],'walk':r(3,7),'run':[8,9,10,11],'attack':[12,13,14],'attack2':S(15,2)+[16],'cast':S(15,2)+[16],'hit':[17,18,19],'death':[20,21,22]}),
}
FPS={'idle':4,'walk':8,'run':10,'attack':9,'attack2':9,'cast':6,'hit':8,'death':6}
LOOP={'idle':True,'walk':True,'run':True}

def patch_cuts(rgb, fg, gl):
    # fill 1-3px transparent gaps on grid lines that have sprite on both sides
    fg=fg.copy(); rgb=rgb.copy()
    H,W=fg.shape
    for _ in range(3):
        L=np.zeros_like(fg); R=np.zeros_like(fg); U=np.zeros_like(fg); D=np.zeros_like(fg)
        for k in (1,2,3):
            L[:,k:]|=fg[:,:-k]; R[:,:-k]|=fg[:,k:]; U[k:,:]|=fg[:-k,:]; D[:-k,:]|=fg[k:,:]
        gap=(~fg)&gl&((L&R)|(U&D))
        if not gap.any(): break
        ys,xs=np.nonzero(gap)
        for y,x in zip(ys,xs):
            for dx,dy in ((-1,0),(1,0),(0,-1),(0,1),(-2,0),(2,0)):
                yy,xx=y+dy,x+dx
                if 0<=yy<H and 0<=xx<W and fg[yy,xx]:
                    rgb[y,x]=rgb[yy,xx]; break
        fg|=gap
    return rgb, fg

cache={}
def row(sheet,ri):
    k=(sheet,ri)
    if k not in cache:
        img=np.asarray(Image.open(sheet).convert('RGB')).astype(int)
        y0,y1=BANDS[ri]; b=img[y0:y1+1]
        fg0,gl=masks(b); lab,cs=components(fg0)
        b,fg=patch_cuts(b,fg0,gl)
        added=fg&~fg0
        if added.any():
            _,(iy,ix)=ndi.distance_transform_edt(lab==0,return_indices=True)
            lab=np.where(added,lab[iy,ix],lab)
        cache[k]=(b,fg,lab,cs)
    return cache[k]

def frame(sheet,ri,f):
    b,fg,lab,cs=row(sheet,ri)
    if isinstance(f,int): ids=[f]; part=None
    elif f[0]=='merge': ids=list(f[1]); part=None
    else: ids=[f[1]]; part=(f[2],f[3])
    x0=min(cs[i]['x0'] for i in ids); x1=max(cs[i]['x1'] for i in ids)
    y0=min(cs[i]['y0'] for i in ids); y1=max(cs[i]['y1'] for i in ids)
    m=np.isin(lab,[j for i in ids for j in cs[i]['ids']])
    if part:
        n,k=part; w=(x1-x0)/n
        # split at the emptiest column near each boundary
        cols=m[:,x0:x1].sum(0)
        cuts=[0]
        for j in range(1,n):
            c=int(w*j); lo,hi=max(1,c-int(w*.25)),min(len(cols)-1,c+int(w*.25))
            cuts.append(lo+int(np.argmin(cols[lo:hi])))
        cuts.append(x1-x0)
        sx0,sx1=x0+cuts[k],x0+cuts[k+1]
        mm=np.zeros_like(m); mm[:,sx0:sx1]=m[:,sx0:sx1]; m=mm
    ys,xs=np.nonzero(m)
    y0,y1,x0,x1=ys.min(),ys.max()+1,xs.min(),xs.max()+1
    rgba=np.zeros((y1-y0,x1-x0,4),np.uint8)
    rgba[...,:3]=b[y0:y1,x0:x1]; rgba[...,3]=np.where(m[y0:y1,x0:x1],255,0)
    # anchor: feet = bottom; horizontal = opaque-mass center of the lower 60%
    sub=m[y0:y1,x0:x1]; low=sub[int(sub.shape[0]*0.4):]
    cx=float(np.nonzero(low)[1].mean()) if low.any() else sub.shape[1]/2
    return rgba,cx,y1  # y1 = bottom in band coords

meta={}
for name,(sheet,ri,anims) in SPEC.items():
    frames=[];index={}
    for an,fl in anims.items():
        index[an]=[len(frames),len(fl)]
        for f in fl: frames.append(frame(sheet,ri,f))
    ground=max(f[2] for f in frames)  # common ground line for the row
    left=max(f[1] for f in frames); right=max(f[0].shape[1]-f[1] for f in frames)
    top=max(f[0].shape[0]+(ground-f[2]) for f in frames)
    cw=int(np.ceil(left+right))+4; ch=int(top)+2
    # standing-frame bottom rests on ground line; frames above ground (jumps) keep offset
    strip=Image.new('RGBA',(cw*len(frames),ch),(0,0,0,0))
    for i,(rgba,cx,bot) in enumerate(frames):
        im=Image.fromarray(rgba,'RGBA')
        px=i*cw+int(round(2+left-cx)); py=ch-(ground-bot)-rgba.shape[0]
        strip.paste(im,(px,py),im)
    strip.save(f'{OUT}/{name}.png')
    meta[name]={'w':cw,'h':ch,'anchor_x':round(2+left,1),'anims':{a:[s,c,FPS[a],LOOP.get(a,False)] for a,(s,c) in index.items()}}
    print(name,cw,ch,len(frames))
json.dump(meta,open(f'{OUT}/meta.json','w'),indent=1)
