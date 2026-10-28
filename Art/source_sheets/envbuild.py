"""Slices ground_sheet.jpg + objects_sheet.jpg into game textures.
Run: python envbuild.py [out_dir]   (default: assets/sprites/environment)
Ground: fixed tile crops -> ground/<name>_<i>.png and animated strips.
Objects: background removed, frames cut -> objects.png atlas + objects.json."""
import os, sys, json, numpy as np
from PIL import Image
from scipy import ndimage as ndi
from extract2 import masks, components

HERE=os.path.dirname(os.path.abspath(__file__))
GROUND=os.path.join(HERE,'ground_sheet.jpg'); OBJ=os.path.join(HERE,'objects_sheet.jpg')
OUT=sys.argv[1] if len(sys.argv)>1 else os.path.join(HERE,'..','..','assets','sprites','environment')
os.makedirs(os.path.join(OUT,'ground'),exist_ok=True)
TILE=64

# ---- ground -----------------------------------------------------------------
# column starts of the 94px tiles; each crop is inset 3px to drop grid lines
COLS=[2,96,189,283]; FLOW=[610,705,799,893,987]
ROW={'grass':(26,125),'burned':(162,255),'gravel':(292,381),'water':(541,634),'magma':(671,765)}
g=Image.open(GROUND).convert('RGB')
TOP={'grass':27,'burned':22}  # rows whose top edge is blade tips over background
def tile(x,row):
    y0,y1=ROW[row]; w=91
    return g.crop((x+5,y0+TOP.get(row,9),x+w-5,y1-7)).resize((TILE,TILE),Image.LANCZOS)
def inpaint(im, green=False):
    # replace sheet background / grid-line pixels with the nearest real pixel
    a=np.asarray(im).astype(int)
    bad=(np.abs(a-[86,102,110]).sum(2)<40)|(np.abs(a-[31,42,47]).sum(2)<30)
    if green: bad|=(a[...,1]-np.maximum(a[...,0],a[...,2]))<14
    if not bad.any(): return im
    _,(iy,ix)=ndi.distance_transform_edt(bad,return_indices=True)
    return Image.fromarray(a[iy,ix].astype(np.uint8))
for name,row in (('grass','grass'),('gravel','gravel'),('burned','burned')):
    for i,x in enumerate(COLS):
        t=tile(x,row)
        if name!='burned': t=inpaint(t, green=(name=='grass'))
        t.save(f'{OUT}/ground/{name}_{i}.png')
for name,row in (('water_flow','water'),('lava_flow','magma')):
    strip=Image.new('RGB',(TILE*len(FLOW),TILE))
    for i,x in enumerate(FLOW): strip.paste(tile(x,row),(i*TILE,0))
    strip.save(f'{OUT}/ground/{name}.png')

# ---- objects ----------------------------------------------------------------
BANDS={'trees':(25,138),'rocks':(292,381),'chests':(418,503),'misc':(671,765)}
S=lambda i,n,k:('split',i,n,k)
SPEC={'trees':{'oak_idle':0,'oak_sway':1,'oak_hit':2,'pine_idle':4,'pine_sway':5,'pine_hit':6,
               'birch_idle':8,'birch_sway':9,'birch_hit':10,'dead_tree':12},
      'rocks':{'rock_a':1,'rock_b':0,'rock_small':2,'rock_shattered':3,'iron_ore':4,'iron_ore_b':5,'iron_ore_c':6,
               'gold_ore':9,'gold_ore_b':10,'gold_ore_c':11,'gold_nuggets':12,'gem_rock':13,'gem_rock_b':14,'gem_rock_c':15},
      'chests':{'chest_closed':0,'chest_unlocked':1,'chest_open':2,'chest_open_gold':3,'chest_open_key':4,
                'iron_chest_closed':5,'iron_chest_unlocked':6,'iron_chest_open':7,'iron_chest_weapon':8,
                'golden_chest_closed':9,'golden_chest_open':10,'golden_chest_gems':11,'golden_chest_potion':12,
                'lockbox_closed':14,'lockbox_open':15},
      'misc':{'torch_0':0,'torch_1':1,'torch_2':2,'torch_3':3,'torch_4':4,'book_open':5,'book_blue':6,'book_brown':7,
              'skeleton':8,'skeleton_sitting':9,'urn':10,'urn_broken':11,'crate_stack':12,'crate':13,
              'crate_b':14,'barrel':15,'plank':16,'barrel_b':17,'barrel_broken':18,'barrel_open':19}}

def patch_cuts(rgb, fg, gl):
    fg=fg.copy(); rgb=rgb.copy(); H,W=fg.shape
    for _ in range(3):
        L=np.zeros_like(fg); R=np.zeros_like(fg); U=np.zeros_like(fg); D=np.zeros_like(fg)
        for k in (1,2,3):
            L[:,k:]|=fg[:,:-k]; R[:,:-k]|=fg[:,k:]; U[k:,:]|=fg[:-k,:]; D[:-k,:]|=fg[k:,:]
        gap=(~fg)&gl&((L&R)|(U&D))
        if not gap.any(): break
        for y,x in zip(*np.nonzero(gap)):
            for dx,dy in ((-1,0),(1,0),(0,-1),(0,1),(-2,0),(2,0)):
                yy,xx=y+dy,x+dx
                if 0<=yy<H and 0<=xx<W and fg[yy,xx]: rgb[y,x]=rgb[yy,xx]; break
        fg|=gap
    return rgb,fg

o=np.asarray(Image.open(OBJ).convert('RGB')).astype(int)
frames=[]
for band,(y0,y1) in BANDS.items():
    b=o[y0:y1+1]; fg0,gl=masks(b); lab,cs=components(fg0)
    # drop grid-line remnants: line pixels only survive inside solid regions
    solid=ndi.binary_opening(fg0,structure=np.ones((4,4)))
    fg0=fg0&~(gl&~ndi.binary_dilation(solid,iterations=1))
    # and any 1-2px line anywhere that isn't hugging a solid shape
    thick=ndi.binary_opening(fg0,structure=np.ones((3,3)))
    fg0=fg0&ndi.binary_dilation(thick,iterations=2)
    lab,cs=components(fg0)
    b,fg=patch_cuts(b,fg0,gl); added=fg&~fg0
    if added.any():
        _,(iy,ix)=ndi.distance_transform_edt(lab==0,return_indices=True); lab=np.where(added,lab[iy,ix],lab)
    for name,f in SPEC[band].items():
        if isinstance(f,int): ids=[f]; part=None
        elif f[0]=='merge': ids=list(f[1]); part=None
        else: ids=[f[1]]; part=(f[2],f[3])
        m=np.isin(lab,[j for i in ids for j in cs[i]['ids']])
        if part:
            x0=min(cs[i]['x0'] for i in ids); x1=max(cs[i]['x1'] for i in ids)
            cols=m[:,x0:x1].sum(0); n,k=part; w=(x1-x0)/n; cuts=[0]
            for j in range(1,n):
                c=int(w*j); lo,hi=max(1,c-int(w*.25)),min(len(cols)-1,c+int(w*.25)); cuts.append(lo+int(np.argmin(cols[lo:hi])))
            cuts.append(x1-x0); mm=np.zeros_like(m); mm[:,x0+cuts[k]:x0+cuts[k+1]]=m[:,x0+cuts[k]:x0+cuts[k+1]]; m=mm
        ys,xs=np.nonzero(m); t,bt,l,r=ys.min(),ys.max()+1,xs.min(),xs.max()+1
        rgba=np.zeros((bt-t,r-l,4),np.uint8); rgba[...,:3]=b[t:bt,l:r]; rgba[...,3]=np.where(m[t:bt,l:r],255,0)
        sub=m[t:bt,l:r]; low=sub[int(sub.shape[0]*0.7):]
        ax=float(np.nonzero(low)[1].mean()) if low.any() else sub.shape[1]/2
        frames.append((name,Image.fromarray(rgba,'RGBA'),ax))

# shelf-pack into an atlas
AW=1024; x=y=sh=0; meta={}
for name,im,ax in frames:
    if x+im.width+2>AW: x=0; y+=sh+2; sh=0
    meta[name]=[x,y,im.width,im.height,round(ax,1)]; x+=im.width+2; sh=max(sh,im.height)
atlas=Image.new('RGBA',(AW,y+sh),(0,0,0,0))
for name,im,ax in frames: atlas.paste(im,tuple(meta[name][:2]))
atlas.save(f'{OUT}/objects.png'); json.dump(meta,open(os.path.join(HERE,'objects.json'),'w'),indent=1)
print('objects',len(meta),atlas.size)
