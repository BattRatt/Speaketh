-- Speaketh native visual implementation of the approved sidebar preview.
-- No browser UI or legacy options-panel templates are used by this menu.
local U={views={},paint={},key="speak",selectedLanguage="Common",selectedDialect=nil}
Speaketh_ReviewUI=U
local W,H,CW=704,670,485
local VERSION=(C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("Speaketh","Version")) or "1.3.0"
local ART="Interface\\AddOns\\Speaketh\\Resources\\UI\\"
local BODY="Fonts\\ARIALN.TTF"
local SERIF="Fonts\\FRIZQT__.TTF"
local palettes={
    HallowsEnd={ink={.95,.90,.80},sub={.76,.70,.65},accent={1,.52,.16},edge={.43,.29,.19},well={.065,.047,.067},paper={.10,.073,.09},raised={.22,.12,.075}},
    Void={ink={.933,.906,.988},sub={.737,.690,.816},accent={.749,.588,.941},edge={.361,.259,.478},well={.063,.047,.094},paper={.090,.067,.133},raised={.161,.125,.216}},
    Classic={ink={.925,.882,.776},sub={.749,.694,.576},accent={.843,.702,.424},edge={.396,.325,.196},well={.078,.075,.067},paper={.125,.106,.078},raised={.188,.153,.106}},
}
local function theme() local k=Speaketh_Theme:Current();return palettes[k] and k or "Classic" end
local function colors() return palettes[theme()] end
local function bind(fn) U.paint[#U.paint+1]=fn;fn(colors()) end
local function safe(s) return tostring(s or ""):gsub("|","||") end
local function trim(s) return (s or ""):gsub("^%s+",""):gsub("%s+$","") end
local function frame(kind,parent,x,y,w,h)
    local f=CreateFrame(kind,nil,parent)
    f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y);f:SetSize(w,h);return f
end
local function label(parent,value,x,y,w,size,role,serif)
    local t=parent:CreateFontString(nil,"OVERLAY")
    t:SetFont(serif and SERIF or BODY,size or 14,"")
    t:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y);t:SetWidth(w)
    t:SetJustifyH("LEFT");t:SetJustifyV("TOP");t:SetText(value)
    bind(function(c)t:SetTextColor(unpack(c[role or "ink"]))end)
    return t
end
local function solid(parent,x,y,w,h,role,alpha)
    local t=parent:CreateTexture(nil,"BACKGROUND")
    t:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y);t:SetSize(w,h)
    bind(function(c)local a=c[role];t:SetColorTexture(a[1],a[2],a[3],alpha or 1)end)
    return t
end
local function box(parent,x,y,w,h)
    local f=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y);f:SetSize(w,h)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    bind(function(c)f:SetBackdropColor(unpack(c.well));f:SetBackdropBorderColor(unpack(c.edge))end)
    return f
end
-- Static decoration uses textures only and never intercepts input.
local function decorate(f,width,headerHeight)
    local surface=f:CreateTexture(nil,"BACKGROUND",nil,1);surface:SetAllPoints()
    bind(function()surface:SetTexture(ART.."Surface"..theme());surface:SetAlpha(theme()=="Classic"and .22 or .45)end)
    for i,anchor in ipairs({"TOPLEFT","TOPRIGHT","BOTTOMRIGHT","BOTTOMLEFT"})do
        local t=f:CreateTexture(nil,"OVERLAY");t:SetSize(20,20);t:SetAlpha(.65)
        t:SetPoint(anchor,f,anchor,(i==1 or i==4)and 3 or -3,(i<=2)and -3 or 3)
        t:SetRotation(-(i-1)*math.pi/2)
        bind(function()
            t:SetTexture(ART.."Corner"..(theme()=="HallowsEnd"and "Classic"or theme()))
        end)
    end
    -- A continuous divider sits behind the center ornament.
    local line=f:CreateTexture(nil,"ARTWORK");line:SetSize(width,1)
    line:SetPoint("TOPLEFT",f,"TOPLEFT",0,-headerHeight)
    bind(function(c)line:SetColorTexture(c.accent[1],c.accent[2],c.accent[3],1)end)
    local sigil=f:CreateTexture(nil,"OVERLAY");sigil:SetSize(16,16)
    sigil:SetPoint("TOP",f,"TOP",0,-headerHeight+8)
    bind(function()
        sigil:SetTexture(ART.."Sigil"..theme())
        local size=theme()=="HallowsEnd"and 34 or 16
        sigil:SetSize(size,size);sigil:ClearAllPoints();sigil:SetPoint("TOP",f,"TOP",0,-headerHeight+size/2)
    end)
end
local function button(parent,value,x,y,w,action,quiet)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y);b:SetSize(w,38)
    b:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    b.bg=b
    local marker=b:CreateTexture(nil,"ARTWORK");marker:SetPoint("TOPLEFT",2,-2);marker:SetSize(3,34);marker:Hide()
    b.text=label(b,value,10,11,w-20,14)
    b:SetScript("OnClick",action)
    local function paint()
        local c=colors();local fill=(b.selected or b.hover) and c.raised or c.well
        b.bg:SetBackdropColor(fill[1],fill[2],fill[3],quiet and not b.selected and not b.hover and 0 or 1)
        b.bg:SetBackdropBorderColor(c.edge[1],c.edge[2],c.edge[3],quiet and not b.selected and 0 or 1)
        b.text:SetTextColor(unpack(b.selected and c.accent or c.ink))
        marker:SetColorTexture(c.accent[1],c.accent[2],c.accent[3],theme()=="Void"and .9 or .8)
        marker:SetShown(b.selected==true);marker:SetHeight(math.max(1,b:GetHeight()-4))
        if b.hover then b.bg:SetBackdropBorderColor(unpack(c.accent))end
    end
    b.paint=paint;bind(paint)
    b:SetScript("OnEnter",function()b.hover=true;paint()end)
    b:SetScript("OnLeave",function()b.hover=false;paint()end)
    return b
end
local function closeButton(parent,width)
    local b=button(parent,"",width-48,18,26,function()parent:Hide()end)
    b:SetSize(26,26);b:SetFrameLevel(parent:GetFrameLevel()+10)
    b.text:Hide()
    -- Equal diagonals share the exact button center, avoiding font bearings
    -- and baseline offsets that make a centered text X appear displaced.
    for _,angle in ipairs({math.pi/4,-math.pi/4})do
        local stroke=b:CreateTexture(nil,"OVERLAY")
        stroke:SetTexture("Interface\\Buttons\\WHITE8X8")
        stroke:SetSize(16,1.5);stroke:SetPoint("CENTER",b,"CENTER",0,0)
        stroke:SetRotation(angle)
        bind(function(c)stroke:SetVertexColor(unpack(c.ink))end)
    end
    return b
end
local function field(parent,title,x,y,w,h,multiline)
    label(parent,title,x,y,w,12,"sub")
    local bg=box(parent,x,y+24,w,h)
    local e=frame("EditBox",bg,10,8,w-20,h-16)
    e:SetFont(BODY,14,"");e:SetAutoFocus(false);e:SetMultiLine(multiline==true)
    e:SetMaxLetters(multiline and 8192 or 64)
    e:SetScript("OnEscapePressed",function(self)self:ClearFocus()end)
    bind(function(c)e:SetTextColor(unpack(c.ink))end)
    return e
end
local function check(parent,title,x,y,key,default,after)
    local b=frame("Button",parent,x,y,CW,32)
    local square=box(b,0,7,16,16)
    b.mark=square:CreateTexture(nil,"OVERLAY")
    b.mark:SetPoint("CENTER");b.mark:SetSize(22,22)
    b.mark:SetTexture(ART.."Check")
    bind(function(c)b.mark:SetVertexColor(unpack(theme()=="Void"and {1,1,1}or c.accent))end)
    b.text=label(b,title,26,7,CW-26,14)
    b.refresh=function()
        local v=Speaketh_Char[key];if v==nil then v=default end
        b.checked=v==true;b.mark:SetShown(b.checked)
    end
    b:SetScript("OnClick",function()
        Speaketh_Char[key]=not b.checked;b.refresh()
        if after then after()end
        U:Refresh()
    end)
    b.refresh();return b
end
local function scroll(parent,x,y,w,h,contentHeight)
    local s=frame("ScrollFrame",parent,x,y,w,h)
    local body=frame("Frame",s,0,0,w,contentHeight or h)
    s:SetScrollChild(body)
    local bar=frame("Slider",parent,x+w+4,y,4,h)
    bar:SetOrientation("VERTICAL");bar:SetMinMaxValues(0,1);bar:SetValueStep(1)
    bar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local thumb=bar:GetThumbTexture();thumb:SetSize(4,36)
    bind(function(c)thumb:SetVertexColor(unpack(c.edge))end)
    local busy=false
    bar:SetScript("OnValueChanged",function(_,v)if not busy then s:SetVerticalScroll(v)end end)
    s.update=function()
        local max=math.max(0,body:GetHeight()-s:GetHeight())
        busy=true;bar:SetMinMaxValues(0,math.max(1,max));bar:SetShown(max>0)
        local value=math.min(max,s:GetVerticalScroll());bar:SetValue(value);s:SetVerticalScroll(value);busy=false
    end
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel",function(_,delta)
        local max=math.max(0,body:GetHeight()-s:GetHeight())
        bar:SetValue(math.max(0,math.min(max,s:GetVerticalScroll()-delta*38)))
    end)
    s:SetScript("OnSizeChanged",s.update)
    s.jump=function(value)s:SetVerticalScroll(value or 0);s.update()end
    s.update();return body,s
end
local function slider(parent,title,x,y,w,maximum,callback)
    local t=label(parent,title,x,y,w,12,"sub")
    local s=frame("Slider",parent,x,y+24,w,18)
    s:SetOrientation("HORIZONTAL");s:SetMinMaxValues(0,maximum);s:SetValueStep(1);s:SetObeyStepOnDrag(true)
    solid(s,0,7,w,4,"raised")
    s:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local thumb=s:GetThumbTexture();thumb:SetSize(20,26)
    bind(function()thumb:SetTexture(ART.."Thumb"..theme())end)
    s.title=t;s.sync=false
    s:SetScript("OnValueChanged",function(_,v)if not s.sync then callback(math.floor(v+.5))end end)
    s.display=function(v,caption,enabled)
        s.sync=true;s:SetValue(v);s.sync=false;t:SetText(caption)
        if enabled==false then s:Disable();s:SetAlpha(.4) else s:Enable();s:SetAlpha(1)end
    end
    return s
end
local function langName(k)return Speaketh:GetLanguageDisplayName(k)end
local function languageItems()
    local rows={{key="None",name="None"}}
    for _,k in ipairs(Speaketh_LanguageOrder or {})do rows[#rows+1]={key=k,name=langName(k)}end
    return rows
end
local function dialectItems(effect,includeNone)
    local data,order
    if effect then data,order=Speaketh_Dialects:GetEffects()else data,order=Speaketh_Dialects:GetAll()end
    local rows={};if includeNone then rows[1]={key=false,name="None"}end
    for _,k in ipairs(order)do
        rows[#rows+1]={key=k,name=data[k].name}
    end
    return rows
end
function U:Menu(anchor,items,select)
    if self.menu and self.menu:IsShown() and self.menuAnchor==anchor then self.menu:Hide();return end
    self.menuAnchor=anchor
    if not self.menu then
        self.menuDismiss=CreateFrame("Button",nil,UIParent)
        self.menuDismiss:SetAllPoints(UIParent);self.menuDismiss:SetFrameStrata("DIALOG")
        self.menuDismiss:SetFrameLevel(self.root:GetFrameLevel()+18)
        self.menuDismiss:RegisterForClicks("AnyDown")
        self.menuDismiss:SetScript("OnClick",function()U.menu:Hide()end)
        self.menuDismiss:Hide()
        self.menu=box(UIParent,0,0,300,320);self.menu:SetFrameStrata("DIALOG")
        self.menu:SetFrameLevel(self.root:GetFrameLevel()+20)
        self.menuBody,self.menuScroll=scroll(self.menu,6,6,278,300,300)
        self.menuRows={}
        _G.SpeakethMatchedDropdown=self.menu
        table.insert(UISpecialFrames,"SpeakethMatchedDropdown")
        self.menu:EnableMouse(true)
        self.menu:SetScript("OnHide",function()U.menuDismiss:Hide();U.menuAnchor=nil end)
        self.menu:Hide()
    end
    local menu=self.menu;menu:ClearAllPoints();menu:SetPoint("TOPLEFT",anchor,"BOTTOMLEFT",0,-4)
    local wide=false;for _,item in ipairs(items)do if item.note then wide=true;break end end
    local rowWidth=wide and 520 or 278
    menu:SetWidth(rowWidth+22);self.menuScroll:SetWidth(rowWidth);self.menuBody:SetWidth(rowWidth)
    menu:SetClampedToScreen(true)
    local height=math.min(300,#items*38)
    menu:SetHeight(height+12);self.menuScroll:SetHeight(height);self.menuBody:SetHeight(#items*38)
    for i,v in ipairs(items)do
        local b=self.menuRows[i]
        if not b then b=button(self.menuBody,"",0,(i-1)*38,278,function(btn)menu:Hide();select(btn.key)end,true);self.menuRows[i]=b end
        -- Replace callback when the shared popup is used by another field.
        b:SetScript("OnClick",function(btn)if btn.disabled then return end;menu:Hide();select(btn.key)end)
        b.key=v.key;b.disabled=v.disabled;b:SetWidth(rowWidth);b.text:SetWidth(wide and 190 or rowWidth-20)
        if not b.note then b.note=label(b,"",205,11,305,12,"sub")end
        b.note:SetText(v.note or "");b.note:SetShown(v.note~=nil)
        if v.disabled then b:Disable();b:SetAlpha(.45)else b:Enable();b:SetAlpha(1)end
        b.text:SetText(safe(v.name));b:Show()
    end
    for i=#items+1,#self.menuRows do self.menuRows[i]:Hide()end
    self.menuScroll:SetVerticalScroll(0);self.menuScroll.update();self.menuAnchor=anchor;self.menuDismiss:Show();menu:Show()
end
local function dropdown(parent,title,x,y,w,items,onSelect)
    label(parent,title,x,y,w,12,"sub")
    local b=button(parent,"",x,y+24,w,function(btn)U:Menu(btn,items(),onSelect)end)
    local arrow=b:CreateTexture(nil,"OVERLAY");arrow:SetPoint("RIGHT",b,"RIGHT",-10,0);arrow:SetSize(16,16)
    bind(function()arrow:SetTexture(ART.."Chevron"..theme())end)
    b.text:SetWidth(w-40);return b
end
local function heading(p,title)label(p,title,0,0,CW,21,"accent",true)end
-- StaticPopup formats its text. Pass the message as a %s argument so literal
-- percentage signs and user-provided names cannot become format directives.
StaticPopupDialogs.SPEAKETH_MATCHED_CONFIRM={text="%s",button1="Confirm",button2=CANCEL or "Cancel",timeout=0,whileDead=true,hideOnEscape=true,OnAccept=function(_,action)if type(action)=="function"then action()end end}
local function confirm(message,action)
    StaticPopup_Show("SPEAKETH_MATCHED_CONFIRM",message,nil,action)
end
function U:Message(value)self.status:SetText(safe(value))end
function U:Refresh()
    if self.quickRefresh then self.quickRefresh()end
    if not self.root then return end
    self.status:SetText(safe(langName(Speaketh:GetLanguage())))
    if self.active and self.active.refresh then self.active.refresh()end
    if Speaketh_UI.RefreshLanguageHUD then Speaketh_UI:RefreshLanguageHUD()end
end
local builders={}
builders.speak=function(p)
    heading(p,"Your voice")
    local lang=dropdown(p,"Language",0,42,CW,languageItems,function(k)Speaketh:SetLanguage(k);U:Refresh()end)
    local dialect=dropdown(p,"Dialect",0,120,234,function()return dialectItems(false,true)end,function(k)Speaketh_Dialects:SetActive(k or nil);U:Refresh()end)
    local effect=dropdown(p,"Speech effect",252,120,233,function()return dialectItems(true,true)end,function(k)Speaketh_Dialects:SetActiveEffect(k or nil);U:Refresh()end)
    solid(p,0,205,CW,1,"edge")
    local dialectRow=frame("Frame",p,0,222,CW,60)
    local effectRow=frame("Frame",p,0,222,CW,60)
    local ds=slider(dialectRow,"Dialect",0,0,CW,3,function(v)local k=Speaketh_Dialects:GetActive();if k then Speaketh_Dialects:SetLevel(k,v)end;U:Refresh()end)
    local es=slider(effectRow,"Effect",0,0,CW,3,function(v)local k=Speaketh_Dialects:GetActiveEffect();if k then Speaketh_Dialects:SetLevel(k,v)end;U:Refresh()end)
    local lower=frame("Frame",p,0,222,CW,90)
    local auto=check(lower,"Automatic chat translation",0,0,"autoChat",true)
    button(lower,"Next known language",0,45,210,function()Speaketh:CycleLanguage();U:Refresh()end)
    p.refresh=function()
        local k=Speaketh:GetLanguage();lang.text:SetText(safe(langName(k)))
        local dk=Speaketh_Dialects:GetActive();local ek=Speaketh_Dialects:GetActiveEffect()
        dialect.text:SetText(safe(dk and Speaketh_Dialects:GetData(dk).name or "None"))
        dialect:SetAlpha(1)
        effect.text:SetText(safe(ek and Speaketh_Dialects:GetData(ek).name or "None"))
        local y=222
        for _,a in ipairs({{ds,dk,"Dialect",dialectRow},{es,ek,"Effect",effectRow}})do
            local v=a[2] and Speaketh_Dialects:GetLevel(a[2]) or 0;local data=a[2] and Speaketh_Dialects:GetData(a[2])
            a[1].display(v,a[3].." intensity  "..(a[2] and Speaketh_Dialects:GetSliderLabel(a[2],v) or "Off"),data and data.usesSlider or false)
            local visible=data and data.usesSlider==true or false
            a[4]:SetShown(visible)
            if visible then a[4]:ClearAllPoints();a[4]:SetPoint("TOPLEFT",p,"TOPLEFT",0,-y);y=y+66 end
        end
        lower:ClearAllPoints();lower:SetPoint("TOPLEFT",p,"TOPLEFT",0,-y)
        p:SetHeight(y+100);p.scroll.update();auto.refresh()
    end
    p.controls={language=lang,dialect=dialect,effect=effect,effectSlider=es,dialectRow=dialectRow,effectRow=effectRow}
    p:SetHeight(368)
end
builders.languages=function(p)
    heading(p,"Language library")
    local choose=dropdown(p,"Language",0,55,CW,languageItems,function(k)U.selectedLanguage=k;U:Refresh()end)
    local state=label(p,"",0,141,CW,14,"sub")
    local s=slider(p,"Fluency",0,183,CW,100,function(v)if U.selectedLanguage~="None"then Speaketh_Fluency:Set(U.selectedLanguage,v)end;U:Refresh()end)
    button(p,"Learn at 100%",0,252,148,function()if U.selectedLanguage~="None"then Speaketh_Fluency:Set(U.selectedLanguage,100)end;U:Refresh()end)
    button(p,"Unlearn",158,252,108,function()Speaketh_Fluency:Set(U.selectedLanguage,0);if Speaketh:GetLanguage()==U.selectedLanguage then Speaketh:SetLanguage("None")end;U:Refresh()end)
    local passive=check(p,"Learn passively from other speakers",0,320,"passiveLearn",true)
    local function bulk(v)confirm(v==100 and "Learn all languages at 100%?" or "Reset all fluency to 0%?",function()for _,k in ipairs(Speaketh_LanguageOrder)do Speaketh_Fluency:Set(k,v)end;U:Refresh()end)end
    button(p,"Learn all",0,374,155,function()bulk(100)end)
    button(p,"Reset all fluency",167,374,195,function()bulk(0)end)
    p.refresh=function()local k=U.selectedLanguage;local v=Speaketh_Fluency:Get(k);choose.text:SetText(safe(langName(k)));state:SetText((v>0 and "Learned" or "Unlearned").."  |  "..math.floor(v).."%");s.display(v,"Fluency  "..math.floor(v).."%",k~="None");passive.refresh()end
    p.controls={choose=choose,fluency=s,passive=passive}
end
builders.appearance=function(p)
    heading(p,"Appearance & display")
    local choose=dropdown(p,"Interface theme",0,55,CW,function()local rows={};for _,k in ipairs(Speaketh_Theme:List())do rows[#rows+1]={key=k,name=k=="HallowsEnd"and "Hallow's End"or k}end;return rows end,function(k)Speaketh_Theme:Set(k);U:Refresh()end)
    local rows={}
    local prefs={{"Floating language HUD","showLangHUD",true,function()Speaketh_UI:ApplyLanguageHUDVisibility()end},{"Minimap button","showMinimap",true,function()Speaketh_UI:ApplyMinimapVisibility()end},{"Overhead language glyphs","showGlyphs",false},{"Login splash","showSplash",false},{"Lockdown notifications","showLockdownNotify",false}}
    for i,a in ipairs(prefs)do rows[i]=check(p,a[1],0,132+(i-1)*38,a[2],a[3],a[4])end
    p.refresh=function()choose.text:SetText(theme()=="HallowsEnd" and "Hallow's End" or theme());for _,c in ipairs(rows)do c.refresh()end end
    p.controls={theme=choose,checks=rows}
end
builders.channels=function(p)
    heading(p,"Chat channels")
    local rows={}
    label(p,"TRANSLATE IN",0,55,CW,12,"sub")
    local prefs={{"Say","chanSay"},{"Yell","chanYell"},{"Party","chanParty"},{"Raid / Raid warning","chanRaid"},{"Guild","chanGuild"},{"Officer","chanOfficer"},{"Instance","chanInstance"},{"Whisper","chanWhisper"},{"Emote (quoted speech)","chanEmote"}}
    for i,a in ipairs(prefs)do rows[#rows+1]=check(p,a[1],0,88+(i-1)*38,a[2],true)end
    p.refresh=function()for _,c in ipairs(rows)do c.refresh()end end
    p.controls=rows
end
builders.modules=function(p)
    heading(p,"Compatibility modules")
    local fields={}
    for i,a in ipairs({{"Chattery","ChatteryCompatibilityActive"},{"EmoteScribe","EmoteScribeCompatibilityActive"},{"Listener","ListenerCompatibilityActive"},{"WIM","WIMCompatibilityActive"}})do
        label(p,a[1],0,58+(i-1)*60,220,14)
        fields[i]={label(p,"",260,58+(i-1)*60,225,12,"sub"),a[2]}
        solid(p,0,91+(i-1)*60,CW,1,"edge")
    end
    p.refresh=function()for _,a in ipairs(fields)do
        local status=a[2]=="WIMCompatibilityActive" and Speaketh.GetWIMCompatibilityStatus and Speaketh:GetWIMCompatibilityStatus()
        a[1]:SetText(status or (Speaketh[a[2]] and "Active" or "Not detected"))
    end end
end
local commands={
    {"/sp or /speaketh","Open the welcome screen"},
    {"/sp help","Open the welcome screen"},
    {"/spui","Open Speak"},
    {"/sp window","Toggle Speak"},
    {"/sp options","Open Appearance"},
    {"/sp cycle","Next known language"},
    {"/sp none","Disable language translation"},
    {"/sp <language>","Speak a known language"},
    {"/sp list","List language fluency"},
    {"/sp theme classic|void","Change interface theme"},
    {"/sp dialect <name>","Choose a dialect"},
    {"/sp drunk 0-3","Set drunken speech intensity"},
    {"/sp learn <language> <0-100>","Set language fluency"},
    {"/sp share <language>","Export a custom language"},
    {"/sp import <code>","Import a custom language"},
    {"/sp import-overwrite <code>","Import and replace a language"},
    {"/sp resetdialects","Reset built-in dialect rules"},
}
builders.about=function(p)
    heading(p,"Help & commands")
    for i,a in ipairs(commands)do
        label(p,a[1],0,55+(i-1)*52,255,13)
        label(p,a[2],263,55+(i-1)*52,222,13,"sub")
        solid(p,0,91+(i-1)*52,CW,1,"edge")
    end
    p:SetHeight(65+#commands*52)
end
-- Editors below use real Speaketh data and code formats, not demo data.
builders.newlanguage=function(p)
    heading(p,"Custom languages & sharing")
    local function customData(k)
        return type(k)=="string" and k:sub(1,11)=="CustomLang_" and Speaketh_Char.customLanguages and Speaketh_Char.customLanguages[k]
    end
    local function customItems()
        local items={}
        for k,data in pairs(Speaketh_Char.customLanguages or {})do
            if customData(k)then items[#items+1]={key=k,name=data.name}end
        end
        table.sort(items,function(a,b)return a.name:lower()<b.name:lower()end)
        return items
    end
    local editing
    local name,words
    local choose=dropdown(p,"Selected custom language",0,55,CW,customItems,function(k)
        if not customData(k)then return end
        U.selectedCustomLanguage=k;editing=nil;name:Enable();name:SetText("");words:SetText("");U:Refresh()
    end)
    name=field(p,"Name",0,138,CW,38)
    words=field(p,"Word pool - 6–500 comma-separated words",0,222,CW,76,true)
    words:SetMaxLetters(0) -- Preserve long imported word pools when editing.
    local save=button(p,"Save language",0,337,150,function()
        if editing and not customData(editing)then U:Message("Select a custom language first.");return end
        local n=trim(name:GetText());local list={}
        for w in words:GetText():gmatch("[^,]+")do
            w=trim(w):lower()
            if not w:match("^[%w'%-]+$")then U:Message("Words may contain letters, numbers, apostrophes or hyphens.");return end
            list[#list+1]=w
        end
        if #list>500 then U:Message("Use no more than 500 words.");return end
        if #list<6 then U:Message("Enter at least six words.");return end
        if n==""or #n>64 or n:find(":",1,true) or n:find("|",1,true) or n:find("%c") then U:Message("Use a name of 1–64 bytes without colons, pipes or control characters.");return end
        for key,data in pairs(Speaketh_Languages)do
            if key~=editing and (data.name or key):lower()==n:lower() then U:Message("Choose a unique language name.");return end
        end
        local k=editing or "CustomLang_"..n:gsub("%s+","_"):gsub("[^%w_]","")
        if k=="CustomLang_"or(not editing and Speaketh_Languages[k])then U:Message("Choose a unique language name.");return end
        Speaketh_Char.customLanguages=Speaketh_Char.customLanguages or {}
        Speaketh_Char.customLanguages[k]={name=n,words=list};Speaketh_RegisterCustomLanguage(k,n,list)
        if not editing then Speaketh_Fluency:Set(k,0)end
        editing=nil;name:Enable();name:SetText("");words:SetText("");U.selectedCustomLanguage=k;U:Refresh();U:Message("Language saved.")
    end)
    local edit=button(p,"Edit selected",160,337,145,function()
        local k=U.selectedCustomLanguage;local data=customData(k)
        if not data then U:Message("Select a custom language first.");return end
        editing=k;name:SetText(data.name);name:Disable();words:SetText(table.concat(data.words,", "));p.scroll.jump(0);words:SetFocus();words:HighlightText()
    end)
    local delete=button(p,"Delete selected",315,337,170,function()
        local k=U.selectedCustomLanguage;if not customData(k)then U:Message("Only custom languages can be deleted.");return end
        confirm("Delete this custom language?",function()
            Speaketh_Char.customLanguages[k]=nil;Speaketh_Char.fluency[k]=nil;Speaketh_UnregisterCustomLanguage(k)
            if Speaketh:GetLanguage()==k then Speaketh:SetLanguage("None")end
            editing=nil;name:Enable();name:SetText("");words:SetText("");U.selectedCustomLanguage=nil;U:Refresh()
        end)
    end)
    local code=field(p,"Speaketh share code",0,408,CW,90,true)
    code:SetMaxLetters(0) -- Share codes can exceed the editor word-pool limit.
    local export=button(p,"Generate code",0,537,185,function()
        if not customData(U.selectedCustomLanguage)then U:Message("Select a custom language first.");return end
        local value,err=Speaketh_Share:ExportCode(U.selectedCustomLanguage)
        if value then code:SetText(value);code:SetFocus();code:HighlightText()else U:Message(err)end
    end)
    button(p,"Import code",197,537,160,function()
        local pendingCode=code:GetText()
        local function import(overwrite)
            local n,err=Speaketh_Share:ImportCode(pendingCode,overwrite)
            if not n then
                if err and err:sub(1,10)=="COLLISION:"then confirm("Replace the existing custom language?",function()import(true)end)
                else U:Message(err)end
                return
            end
            for k,data in pairs(Speaketh_Char.customLanguages)do if data.name==n then U.selectedCustomLanguage=k;break end end
            U:Refresh();U:Message("Imported "..n)
        end
        import(false)
    end)
    p.refresh=function()
        local items=customItems()
        if not customData(U.selectedCustomLanguage)then U.selectedCustomLanguage=items[1] and items[1].key or nil end
        local data=customData(U.selectedCustomLanguage)
        choose.text:SetText(data and safe(data.name) or "No custom languages yet")
        for _,control in ipairs({choose,edit,delete,export})do control:SetEnabled(data~=nil and data~=false);control:SetAlpha(data and 1 or .4)end
    end
    p.controls={name=name,words=words,save=save,code=code,choose=choose,edit=edit,delete=delete,export=export}
    p:SetHeight(600)
end
local function dialectPicker(p,onSelect)
    return dropdown(p,"Dialect to edit",0,55,CW,function()return dialectItems(false,false)end,onSelect)
end
builders.dialectrules=function(p)
    heading(p,"Words & dialects")
    local choose=dialectPicker(p,function(k)U.selectedDialect=k;U:Refresh()end)
    local from=field(p,"Replace",0,137,234,38);local to=field(p,"With",252,137,233,38)
    local rows={}
    local add=button(p,"Add word rule",0,220,175,function()
        if p.editing and p.editDialect~=U.selectedDialect then
            p.editing=nil;from:SetText("");to:SetText("");U:Refresh();return
        end
        local k=U.selectedDialect;local old
        if p.editing then
            old=Speaketh_Dialects:GetCustomSubstitutes(k)[p.editing]
            Speaketh_Dialects:RemoveCustomSubstitute(k,p.editing)
        end
        local ok,err=Speaketh_Dialects:AddCustomSubstitute(k,from:GetText(),to:GetText())
        if not ok and old then table.insert(Speaketh_Char.dialectSubstitutes[k],p.editing,old)end
        if not ok then U:Message(err);return end
        p.editing=nil;from:SetText("");to:SetText("");U:Refresh()
    end)
    p.refresh=function()
        local list=dialectItems(false,false);U.selectedDialect=U.selectedDialect or(list[1]and list[1].key)
        local data=Speaketh_Dialects:GetData(U.selectedDialect);choose.text:SetText(safe(data and data.name or "None"))
        if p.lastDialect~=U.selectedDialect then
            p.editing=nil;from:SetText("");to:SetText("");p.lastDialect=U.selectedDialect
        end
        add.text:SetText(p.editing and "Save word rule" or "Add word rule")
        local rules=Speaketh_Dialects:GetCustomSubstitutes(U.selectedDialect)
        for i,r in ipairs(rules)do
            local row=rows[i]
            if not row then
                row=frame("Frame",p,0,280+(i-1)*48,CW,46)
                row.text=label(row,"",0,12,285,14)
                row.edit=button(row,"Edit",291,2,80,function()local v=Speaketh_Dialects:GetCustomSubstitutes(U.selectedDialect)[i];p.editing=i;p.editDialect=U.selectedDialect;from:SetText(v[1]);to:SetText(v[2]);add.text:SetText("Save word rule");p.scroll.jump(0);from:SetFocus();from:HighlightText()end)
                row.remove=button(row,"Remove",379,2,106,function()Speaketh_Dialects:RemoveCustomSubstitute(U.selectedDialect,i);p.editing=nil;from:SetText("");to:SetText("");U:Refresh()end)
                rows[i]=row
            end
            row.text:SetText(safe(r[1].."  >  "..r[2]));row:Show()
        end
        for i=#rules+1,#rows do rows[i]:Hide()end
        p:SetHeight(math.max(420,295+#rules*48));p.scroll.update()
    end
    p.controls={from=from,to=to,save=add,choose=choose,rows=rows}
end
builders.newdialect=function(p)
    heading(p,"Custom dialects")
    local function customItems()
        local rows={}
        for _,item in ipairs(dialectItems(false,false))do
            if Speaketh_Dialects:IsCustomDialect(item.key)then rows[#rows+1]=item end
        end
        return rows
    end
    local choose=dropdown(p,"Custom dialect",0,55,CW,customItems,function(k)
        if not Speaketh_Dialects:IsCustomDialect(k)then return end
        U.selectedCustomDialect=k;U.selectedDialect=k;U:Refresh()
    end)
    local name=field(p,"Dialect name",0,138,CW,38)
    local create=button(p,"Create dialect",0,222,175,function()
        local ok,key=Speaketh_Dialects:AddCustomDialect(name:GetText())
        if not ok then U:Message(key);return end
        U.selectedCustomDialect=key;U.selectedDialect=key;name:SetText("");U:Select("dialectrules");U.active.scroll.jump(0);U.active.controls.from:SetFocus()
    end)
    local remove=button(p,"Delete selected custom",187,222,244,function()
        local k=U.selectedCustomDialect;if not Speaketh_Dialects:IsCustomDialect(k)then U:Message("Select a custom dialect first.");return end
        confirm("Delete this custom dialect and its rules?",function()
            Speaketh_Dialects:RemoveCustomDialect(k);U.selectedCustomDialect=nil
            if U.selectedDialect==k then U.selectedDialect=nil end
            U:Refresh()
        end)
    end)
    p.refresh=function()
        local list=customItems()
        if not Speaketh_Dialects:IsCustomDialect(U.selectedCustomDialect)then U.selectedCustomDialect=list[1]and list[1].key end
        local d=U.selectedCustomDialect and Speaketh_Dialects:GetData(U.selectedCustomDialect)
        choose.text:SetText(safe(d and d.name or "No custom dialects"))
        if d then choose:Enable();remove:Enable()else choose:Disable();remove:Disable()end
    end
    p.controls={name=name,create=create,choose=choose,remove=remove}
end
builders.passthrough=function(p)
    heading(p,"Passthrough words")
    local input=field(p,"Word",0,55,300,38)
    local rows={}
    local add=button(p,"Add word",315,79,170,function()
        local w=trim(input:GetText()):lower()
        if not w:match("^[%a'%-]+$")then U:Message("Use one word: letters, apostrophes or hyphens.");return end
        Speaketh_Char.customWords=Speaketh_Char.customWords or {};Speaketh_Char.customWords[w]=true;input:SetText("");U:Refresh()
    end)
    p.refresh=function()
        local words={};for w in pairs(Speaketh_Char.customWords or {})do words[#words+1]=w end;table.sort(words)
        for i,w in ipairs(words)do
            local row=rows[i]
            if not row then row=frame("Frame",p,0,146+(i-1)*48,CW,44);row.text=label(row,"",0,12,340,14);row.del=button(row,"Remove",370,0,115,function()Speaketh_Char.customWords[row.word]=nil;U:Refresh()end);rows[i]=row end
            row.word=w;row.text:SetText(safe(w));row:Show()
        end
        for i=#words+1,#rows do rows[i]:Hide()end
        p:SetHeight(math.max(420,160+#words*48));p.scroll.update()
    end
    p.controls={input=input,add=add}
end
local navGroups={{"VOICE",{{"speak","Speak"}}},{"LANGUAGES",{{"languages","Languages"},{"newlanguage","Custom & sharing"}}},{"WORD RULES",{{"dialectrules","Dialect rules"},{"newdialect","Custom dialects"},{"passthrough","Passthrough"}}},{"SETTINGS",{{"appearance","Appearance"},{"channels","Channels"},{"modules","Modules"},{"about","Help"}}}}
function U:LayoutSidebar()
    local y=0
    for i,group in ipairs(navGroups)do
        local expanded=self.expandedGroup==i
        local header=self.groupHeaders[i]
        header:ClearAllPoints();header:SetPoint("TOPLEFT",self.navBody,"TOPLEFT",0,-y)
        header.text:SetText((expanded and "v  " or ">  ")..group[1])
        header.selected=expanded;header.paint();y=y+38
        for _,item in ipairs(group[2])do
            local b=self.nav[item[1]];b:SetShown(expanded)
            if expanded then b:ClearAllPoints();b:SetPoint("TOPLEFT",self.navBody,"TOPLEFT",0,-y);y=y+42 end
        end
        y=y+10
    end
    self.navBody:SetHeight(y);self.sidebar.update()
end
function U:ToggleGroup(index)
    if self.menu then self.menu:Hide()end
    if self.expandedGroup==index then self.expandedGroup=nil else self.expandedGroup=index end
    self:LayoutSidebar()
end
function U:Select(key)
    if self.menu then self.menu:Hide()end
    if self.active then self.active.scroll:Hide();self.active.scrollBarParent:Hide()end
    if not self.views[key]then
        local holder=frame("Frame",self.root,197,134,CW+8,476)
        local p,s=scroll(holder,0,0,CW,476,476);p.scroll=s;p.scrollBarParent=holder
        self.views[key]=p;builders[key](p)
    end
    self.expandedGroup=self.navGroupFor[key];self:LayoutSidebar()
    self.key=key;self.active=self.views[key];self.active.scrollBarParent:Show();self.active.scroll:Show()
    for k,b in pairs(self.nav)do b.selected=k==key;b.paint()end
    self:Refresh();self.active.scroll.update()
end
function U:Build()
    if self.root then return end
    local f=CreateFrame("Frame","SpeakethMatchedFrame",UIParent)
    self.root=f;f:SetSize(W,H);f:SetPoint("CENTER");f:SetFrameStrata("HIGH");f:SetToplevel(true)
    f:SetScale(math.min(1,(UIParent:GetHeight()-50)/H,(UIParent:GetWidth()-50)/W))
    f:SetMovable(true);f:EnableMouse(true);f:SetClampedToScreen(true)
    local background=f:CreateTexture(nil,"BACKGROUND");background:SetAllPoints();background:SetTexCoord(0,W/1024,0,H/1024)
    bind(function()background:SetTexture(ART.."Window"..theme())end)
    decorate(f,W,112)
    local title=label(f,"SPEAKETH",50,38,W-100,32,"accent",true);title:SetSpacing(3);title:SetJustifyH("CENTER")
    local drag=frame("Frame",f,0,0,W-42,112);drag:EnableMouse(true);drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart",function()f:StartMoving()end)
    drag:SetScript("OnDragStop",function()f:StopMovingOrSizing();local a,_,b,x,y=f:GetPoint();Speaketh_Char.matchedPosition={a,b,x,y}end)
    local pos=Speaketh_Char.matchedPosition
    if type(pos)=="table"and type(pos[1])=="string"and type(pos[2])=="string"and type(pos[3])=="number"and type(pos[4])=="number"then f:ClearAllPoints();f:SetPoint(pos[1],UIParent,pos[2],pos[3],pos[4])end
    closeButton(f,W)
    local nav,s=scroll(f,10,130,151,485,485)
    self.sidebar=s;self.navBody=nav;self.nav={};self.groupHeaders={};self.navGroupFor={}
    for i,group in ipairs(navGroups)do
        local index=i
        local header=button(nav,group[1],0,0,151,function()U:ToggleGroup(index)end,true)
        header.isGroup=true;header:SetHeight(32);header.text:SetFont(BODY,11,"")
        self.groupHeaders[i]=header
        for _,item in ipairs(group[2])do
            local key=item[1]
            self.navGroupFor[key]=i
            self.nav[key]=button(nav,item[2],0,0,151,function()U:Select(key)end,true)
            self.nav[key].text:ClearAllPoints();self.nav[key].text:SetPoint("TOPLEFT",16,-11)
            self.nav[key].text:SetWidth(130)
        end
    end
    self.status=label(f,"",34,646,490,12,"sub")
    local version=label(f,VERSION,578,646,92,12,"sub");version:SetJustifyH("RIGHT")
    table.insert(UISpecialFrames,"SpeakethMatchedFrame")
    f:SetScript("OnHide",function()if U.menu then U.menu:Hide()end end)
    self:Select("speak")
end
function U:Open(key)self:Build();self.root:Show();self.root:Raise();self:Select(key or "speak")end
function Speaketh_UI:ToggleSpeakWindow()if U.root and U.root:IsShown()and U.key=="speak"then U.root:Hide()else U:Open("speak")end end
function Speaketh_Options:Open()U:Open("appearance")end
function Speaketh_Options:Close()if U.root then U.root:Hide()end end
function Speaketh_Options:RefreshCustomLanguages()if U.root and U.key=="newlanguage"then U:Refresh()end end
hooksecurefunc(Speaketh,"SetLanguage",function()if U.root then U:Refresh()end end)
hooksecurefunc(Speaketh_Dialects,"SetActive",function()if U.root then U:Refresh()end end)
hooksecurefunc(Speaketh_Dialects,"SetActiveEffect",function()if U.root then U:Refresh()end end)
Speaketh_Theme:Register(function()for _,paint in ipairs(U.paint)do paint(colors())end;if U.root then U:Refresh()end end)
SLASH_SPEAKETHMATCHED1="/spui"
SlashCmdList.SPEAKETHMATCHED=function()U:Open("speak")end

-- Uses the same palette, fonts and controls as the options window.
function Speaketh_UI:ShowSplash()
    if self.SplashFrame then self.SplashFrame:SetShown(not self.SplashFrame:IsShown());return end
    local f=box(UIParent,0,0,560,490);self.SplashFrame=f
    _G.SpeakethStyledSplash=f;table.insert(UISpecialFrames,"SpeakethStyledSplash")
    f:ClearAllPoints();f:SetPoint("CENTER");f:SetFrameStrata("DIALOG")
    f:SetScale(math.min(1,(UIParent:GetHeight()-50)/490,(UIParent:GetWidth()-50)/560))
    f:EnableMouse(true);f:SetMovable(true);f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton");f:SetScript("OnDragStart",function()f:StartMoving()end)
    f:SetScript("OnDragStop",function()f:StopMovingOrSizing()end)
    solid(f,1,1,558,106,"raised",.55)
    solid(f,0,108,560,1,"edge")
    local logo=f:CreateTexture(nil,"ARTWORK");logo:SetPoint("TOPLEFT",24,-18);logo:SetSize(72,72);logo:SetAlpha(.62)
    bind(function()logo:SetTexture("Interface\\AddOns\\Speaketh\\Resources\\Logos\\"..theme())end)
    decorate(f,560,108)
    label(f,"SPEAKETH",116,34,350,25,"accent",true)
    label(f,VERSION,117,68,180,12,"sub")
    closeButton(f,560)
    label(f,"Choose your voice",26,132,508,21,"accent",true)
    label(f,"Select a language and shape your dialect.",26,167,508,14,"sub")
    for i,index in ipairs({1,3,5,6,7})do
        local item=commands[index]
        label(f,item[1],26,207+(i-1)*33,225,13)
        label(f,item[2],255,207+(i-1)*33,280,13,"sub")
    end
    button(f,"Open Speak",26,401,158,function()f:Hide();U:Open("speak")end)
    button(f,"Options",201,401,158,function()f:Hide();U:Open("appearance")end)
    button(f,"All commands",376,401,158,function()f:Hide();U:Open("about")end)
    local login=check(f,"Show on every login",26,449,"showSplash",false)
    f:SetScript("OnShow",login.refresh)
    f:Show()
end

-- Compact companion to the sidebar, opened from the floating HUD.
function Speaketh_UI:ToggleQuickSpeakWindow()
    if U.quick then U.quick:SetShown(not U.quick:IsShown());if U.quick:IsShown()then U:Refresh()end;return end
    if not U.root then U:Build();U.root:Hide()end
    local f=box(UIParent,0,0,368,328);U.quick=f
    _G.SpeakethQuickFrame=f;table.insert(UISpecialFrames,"SpeakethQuickFrame")
    f:ClearAllPoints();f:SetPoint("CENTER",UIParent,"CENTER",0,100)
    f:SetFrameStrata("HIGH");f:SetToplevel(true);f:SetClampedToScreen(true);f:EnableMouse(true);f:SetMovable(true)
    f:SetScale(math.min(1,(UIParent:GetHeight()-50)/520,(UIParent:GetWidth()-50)/368))
    local header=frame("Frame",f,0,0,330,68);header:EnableMouse(true);header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart",function()f:StartMoving()end)
    header:SetScript("OnDragStop",function()f:StopMovingOrSizing()end)
    solid(f,1,1,366,67,"raised",.55);solid(f,0,68,368,1,"edge")
    decorate(f,368,68)
    local title=label(f,"SPEAKETH",38,22,292,27,"accent",true);title:SetJustifyH("CENTER")
    closeButton(f,368)
    local lang=dropdown(f,"Language",20,83,328,languageItems,function(k)Speaketh:SetLanguage(k);U:Refresh()end)
    local dialect=dropdown(f,"Dialect",20,159,158,function()return dialectItems(false,true)end,function(k)Speaketh_Dialects:SetActive(k or nil);U:Refresh()end)
    local effect=dropdown(f,"Speech effect",190,159,158,function()return dialectItems(true,true)end,function(k)Speaketh_Dialects:SetActiveEffect(k or nil);U:Refresh()end)
    local fluencyRow=frame("Frame",f,20,239,328,60)
    local dialectRow=frame("Frame",f,20,239,328,60)
    local effectRow=frame("Frame",f,20,239,328,60)
    local fluency=slider(fluencyRow,"Fluency",0,0,328,100,function(v)local k=Speaketh:GetLanguage();if k~="None"then Speaketh_Fluency:Set(k,v)end;U:Refresh()end)
    local ds=slider(dialectRow,"Dialect intensity",0,0,328,3,function(v)local k=Speaketh_Dialects:GetActive();if k then Speaketh_Dialects:SetLevel(k,v)end;U:Refresh()end)
    local es=slider(effectRow,"Effect intensity",0,0,328,3,function(v)local k=Speaketh_Dialects:GetActiveEffect();if k then Speaketh_Dialects:SetLevel(k,v)end;U:Refresh()end)
    local options=button(f,"Options",254,239,94,function()f:Hide();U:Open("appearance")end)
    U.quickRefresh=function()
        local y=239
        local function place(row,visible)
            row:SetShown(visible)
            if visible then row:ClearAllPoints();row:SetPoint("TOPLEFT",f,"TOPLEFT",20,-y);y=y+66 end
        end
        local k=Speaketh:GetLanguage();lang.text:SetText(safe(langName(k)))
        dialect:SetAlpha(1)
        local v=Speaketh_Fluency:Get(k);fluency.display(v,"Fluency  "..math.floor(v).."%",k~="None")
        place(fluencyRow,k~="None")
        for _,a in ipairs({{dialect,ds,Speaketh_Dialects:GetActive(),"Dialect",dialectRow},{effect,es,Speaketh_Dialects:GetActiveEffect(),"Effect",effectRow}})do
            local data=a[3] and Speaketh_Dialects:GetData(a[3]);local level=a[3] and Speaketh_Dialects:GetLevel(a[3])or 0
            local enabled=data and data.usesSlider==true or false
            a[1].text:SetText(safe(data and data.name or "None"))
            a[2].display(level,a[4].." intensity  "..(a[3] and Speaketh_Dialects:GetSliderLabel(a[3],level)or "Off"),enabled)
            place(a[5],enabled)
        end
        options:ClearAllPoints();options:SetPoint("TOPLEFT",f,"TOPLEFT",254,-y)
        f:SetHeight(y+56)
    end
    f.controls={language=lang,dialect=dialect,effect=effect,fluency=fluency,effectSlider=es,fluencyRow=fluencyRow,dialectRow=dialectRow,effectRow=effectRow}
    f:SetScript("OnHide",function()if U.menu then U.menu:Hide()end end)
    U:Refresh();f:Show()
end

