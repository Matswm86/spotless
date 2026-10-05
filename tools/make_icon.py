"""Draws icon.png (512x512): teal gradient, a yellow-and-green sponge, bubbles and sparkles.

This is the exact PIL script that made the shipped icon on 2026-09-30 (recovered from the
build session; re-running it gives a byte-identical file). No outside art is used.
Run from the repo root: python3 tools/make_icon.py
"""

from PIL import Image, ImageDraw, ImageFilter
S=2048
im=Image.new('RGBA',(S,S)); d=ImageDraw.Draw(im)
for y in range(S):
    t=y/S; d.line([(0,y),(S,y)],fill=(int(70+40*t),int(200-30*t),int(190-20*t),255))
bl=Image.new('RGBA',(S,S)); bd=ImageDraw.Draw(bl)
for (x,y,r) in [(1450,520,260),(1700,900,150),(1250,300,110),(420,1500,170),(620,1720,90)]:
    bd.ellipse((x-r,y-r,x+r,y+r),fill=(255,255,255,60),outline=(255,255,255,210),width=16)
    bd.ellipse((x-r*0.6,y-r*0.62,x-r*0.22,y-r*0.3),fill=(255,255,255,210))
im.alpha_composite(bl)
sp=Image.new('RGBA',(S,S)); sd=ImageDraw.Draw(sp)
sd.rounded_rectangle((520,820,1500,1300),radius=140,fill=(255,214,70,255))
sd.rounded_rectangle((520,1180,1500,1400),radius=110,fill=(60,170,100,255))
for (x,y) in [(700,950),(900,1050),(1150,930),(1300,1100),(820,1150),(1050,1130)]:
    sd.ellipse((x-30,y-22,x+30,y+22),fill=(225,175,40,255))
sh=sp.filter(ImageFilter.GaussianBlur(40)); shadow=Image.new('RGBA',(S,S)); shadow.paste((0,0,0,90),mask=sh.split()[3])
sp=sp.rotate(-18,resample=Image.BICUBIC,center=(1010,1110)); shadow=shadow.rotate(-18,resample=Image.BICUBIC,center=(1010,1110))
im.alpha_composite(shadow,(30,60)); im.alpha_composite(sp)
d=ImageDraw.Draw(im)
def star(cx,cy,R,w):
    d.polygon([(cx,cy-R),(cx+w,cy-w),(cx+R,cy),(cx+w,cy+w),(cx,cy+R),(cx-w,cy+w),(cx-R,cy),(cx-w,cy-w)],fill=(255,255,255,255))
star(1560,1480,260,55); star(1260,1720,120,26); star(420,560,170,36)
im.resize((512,512),Image.LANCZOS).convert('RGB').save('icon.png')