return function(S,Library,check,near)
 local ctx=Library:CreateContext({reducedMotion=true,elementDefaults={plain={slotKinds={root="text"}},interactive={slotKinds={root="text"}}},elements={plain={base={root={alpha=.9}}},interactive={base={root={alpha=.9}},states={hover={root={alpha=.7}},focus={root={alpha=.4}}}}}})
 local C=ctx.C;local parent=CreateFrame("Frame",nil,UIParent);parent:SetSize(240,100)
 local first=C.Text(parent,"First","label","text");local second=C.Text(parent,"Second","label","text")
 check(not first._lycheeStyleState and not first._lycheeStyleController,"plain text has no historical style or interaction state")
 ctx:SetFont(nil,1.3);check(near(select(2,first:GetFont()),14*1.3) and first._color==ctx.Theme.text,"plain text font scale remains live with startup colors")
 ctx:SetFont(nil,1)
 local owner=CreateFrame("EditBox",nil,parent);local hooks=0;local hook=owner.HookScript
 owner.HookScript=function(self,...) hooks=hooks+1;return hook(self,...) end
 C.Element(first,"plain",{stateOwner=owner});local controller=first.styleController
 check(not next(controller.sources) and not controller.bindings and hooks==0,"base text rules create no interaction sources or hooks")
 C.Element(second,"interactive",{stateOwner=owner});owner:Fire("OnEnter");check(second:GetAlpha()==.7,"configured text receives explicit owner hover")
 local bound=hooks;for i=1,5 do C.Element(second,"interactive",{stateOwner=owner}) end
 check(hooks==bound,"repeated business binding does not stack hooks")
 owner:Fire("OnEditFocusGained");check(second:GetAlpha()==.4,"focus wins hover in the shared state order")
 owner:Fire("OnEditFocusLost");owner:Fire("OnLeave");check(second:GetAlpha()==.9,"leaving states reveals the configured base")
 local button=C.Button(parent,"Deferred",100);local surface=button.hover
 check(not rawget(surface,"regions"),"hidden feedback allocates no native slices")
 surface:SetColor(ctx.Theme.good);surface:SetRadius(11);surface:SetAlpha(.6);button:SetSize(140,46)
 check(not rawget(surface,"regions"),"normal hidden surface setters preserve deferred native allocation")
 surface:Show();local regions=surface.regions;local corner=regions[4]
 check(#regions==7 and corner:GetWidth()==11 and near(select(2,corner:GetVertexColor()),ctx.Theme.good[2]) and near(corner:GetAlpha(),.6),"first reveal uses current radius color opacity and dimensions")
 corner:SetDrawLayer("OVERLAY",3);surface:Hide();surface:Show()
 check(surface.regions==regions and regions[4]==corner and select(1,corner:GetDrawLayer())=="OVERLAY","later reveal reuses native slices and consumer draw layers")
 local cold=C.Button(parent,"Inspect",100).hover;local slices=cold.regions
 check(#slices==7 and not slices[1]:IsShown(),"explicit region reads materialize a complete hidden slice array")
 local other=Library:CreateContext();local sibling=other.C.Button(parent,"Other context",80).hover;sibling:SetRadius(5);parent:SetSize(300,120);sibling:Show()
 check(sibling.regions[4]:GetWidth()==5 and surface.regions[4]==corner,"panels from separate contexts share a parent without replacing its layout dispatcher")
 local host=CreateFrame("Frame",nil,parent);local declaration={style={root={alpha=.8}}};local fixed=C.Style(host,declaration)
 check(C.Style(host,declaration)==fixed and not pcall(C.Style,host,{style={root={alpha=.4}}}),"same construction declaration is idempotent and cannot become a replacement API")
 check(not fixed.SetStyle and not fixed.ClearStyle and not C.ApplyStyle and not C.Utility,"no generic hot overlay engine remains on components or controllers")
 ctx:Hide();other:Hide()
end
