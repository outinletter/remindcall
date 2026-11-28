import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont
D="/Users/imac/Downloads/IMG_%d.PNG"
OUT="/Volumes/Data/Project/RemindCall/app-store/screenshots"
W,H=1206,2622
FONTS={"ko":("/System/Library/Fonts/AppleSDGothicNeo.ttc",(6,0)),  # bold idx, regular idx guessed
       "en":("/System/Library/Fonts/SFNS.ttf",None),
       "ja":("/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc","/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"),
       "zh-Hans":("/System/Library/Fonts/Hiragino Sans GB.ttc",(1,0))}
def font(lang,size,bold):
    f,x=FONTS[lang]
    if lang=="en":
        ft=ImageFont.truetype(f,size)
        try: ft.set_variation_by_name("Bold" if bold else "Regular")
        except Exception: pass
        return ft
    if lang=="ja":
        p=f if bold else x
        return ImageFont.truetype(p,size)
    return ImageFont.truetype(f,size,index=x[0] if bold else x[1])
SL={
"ko":[(8110,"번호만 눌러도 누군지 바로","뒷자리를 입력하면 연락처가 나타나요"),
      (8109,"스와이프로 바로 전화·메시지","생일·메모·태그를 이름 아래에 한눈에"),
      (8107,"소중한 사람을 한눈에","생일·메모·마지막 연락까지 카드로"),
      (8108,"연락 기록을 한곳에","RemindCall에서 건 통화와 메모"),
      (8111,"필요한 알림만 켜고 끄기","통화 후 메모 · 생일 · 모르는 번호 이름표")],
"en":[(8105,"Know who it is, instantly","Type a few digits to find the contact"),
      (8104,"Swipe to call or message","Birthdays, notes and tags under each name"),
      (8102,"Your favorites at a glance","Birthday, notes and last contact on a card"),
      (8103,"All your history in one place","Calls made from RemindCall and your notes"),
      (8106,"Only the alerts you want","After-call notes · Birthdays · Unknown labels")],
"ja":[(8115,"番号を押すだけで誰か分かる","下桁を入力すると連絡先が表示されます"),
      (8114,"スワイプで電話・メッセージ","誕生日・メモ・タグを名前の下に"),
      (8112,"大切な人をひと目で","誕生日・メモ・最後の連絡をカードで"),
      (8113,"連絡の記録をひとつに","RemindCallからの発信とメモ"),
      (8116,"必要な通知だけをオンに","通話後メモ・誕生日・不明な番号のラベル")],
"zh-Hans":[(8120,"按几位号码就知道是谁","输入号码后几位即可显示联系人"),
      (8119,"滑动即可拨打或发信息","生日、备忘录、标签一目了然"),
      (8117,"重要的人一目了然","生日、备忘录、最近联系都在卡片上"),
      (8118,"联系记录集中查看","从RemindCall拨出的电话和备忘录"),
      (8121,"只开启需要的提醒","通话后备忘 · 生日 · 陌生号码标签")],
}
STYLES={"indigo":((67,56,202),(15,23,42),(255,255,255),(199,210,254),(255,255,255)),
        "black":((28,28,30),(0,0,0),(255,255,255),(174,174,178),(72,72,74)),
        "light":((242,242,247),(229,229,234),(28,28,30),(99,99,102),(209,209,214)),
        "warm":((255,138,91),(162,28,175),(255,255,255),(255,228,240),(255,255,255)),
        "green":((22,101,52),(5,46,22),(255,255,255),(187,247,208),(134,239,172))}
STYLE=os.environ.get("STYLE","warm"); TOP,BOT,TC,SC,OC=STYLES[STYLE]
ONLY=os.environ.get("ONLY")
def gradient():
    top,bottom=TOP,BOT
    img=Image.new("RGB",(W,H)); d=ImageDraw.Draw(img)
    for y in range(H):
        t=y/(H-1); d.line([(0,y),(W,y)],fill=tuple(int(top[i]+(bottom[i]-top[i])*t) for i in range(3)))
    return img
def rmask(size,r):
    s=3; m=Image.new("L",(size[0]*s,size[1]*s),0)
    ImageDraw.Draw(m).rounded_rectangle((0,0,size[0]*s-1,size[1]*s-1),r*s,fill=255)
    return m.resize(size,Image.LANCZOS)
def center(d,y,text,f,fill):
    w=d.textlength(text,font=f); d.text(((W-w)/2,y),text,font=f,fill=fill)
for lang,slides in SL.items():
    if ONLY and lang!=ONLY.split(":")[0]: continue
    od=os.environ.get("OUTDIR") or os.path.join(OUT,lang); os.makedirs(od,exist_ok=True)
    if not ONLY:
        for f in os.listdir(od): os.remove(os.path.join(od,f))
    for i,(img,title,sub) in enumerate(slides,1):
        if ONLY and i!=int(ONLY.split(":")[1]): continue
        c=gradient()
        shot=Image.open(D%img).convert("RGB"); sw=935; sh=int(shot.height*sw/shot.width)
        shot=shot.resize((sw,sh),Image.LANCZOS); x,y=(W-sw)//2,487
        sd=Image.new("RGBA",(W,H),(0,0,0,0)); ImageDraw.Draw(sd).rounded_rectangle((x,y+24,x+sw,y+sh+24),84,fill=(0,0,0,120))
        c=Image.alpha_composite(c.convert("RGBA"),sd.filter(ImageFilter.GaussianBlur(36))).convert("RGB")
        c.paste(shot,(x,y),rmask((sw,sh),84))
        d=ImageDraw.Draw(c); d.rounded_rectangle((x-2,y-2,x+sw+2,y+sh+2),86,outline=OC,width=3)
        ts=92
        while d.textlength(title,font=font(lang,ts,True))>W-110: ts-=2
        center(d,190,title,font(lang,ts,True),TC)
        ss=46
        while d.textlength(sub,font=font(lang,ss,False))>W-140: ss-=2
        center(d,318,sub,font(lang,ss,False),SC)
        c.save(os.path.join(od,f"{STYLE}-{i:02d}.png" if ONLY else f"{i:02d}.png"))
print("ok")
