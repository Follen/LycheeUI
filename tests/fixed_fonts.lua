return function(S,Library,check,near)
 local ctx=Library:CreateContext({reducedMotion=true,elementDefaults={text={slotKinds={root="text"}},late={slotKinds={root="box",label="text"}}},elements={text={states={hover={root={fontSize="heading",lineHeight="heading",flags="OUTLINE"}}}},late={instances={key={base={label={alpha=.43}}}}}}})
 local C=ctx.C;local host=CreateFrame("Frame",nil,UIParent);local label=C.Text(host,"State font","label");C.SetLineHeight(label,"label",true)
 C.Element(label,"text",{stateOwner=host});host:Fire("OnEnter")
 local theme=ctx.Theme;local heading=theme.headingFontSize;local nodeCount=#S.nodes
 for _,scale in ipairs({.7,1,1.3,1,.7,1}) do
  ctx:SetFont("test-font",scale)
  check(near(select(2,label:GetFont()),heading*scale) and near(label:GetHeight(),theme.headingLineHeight*scale) and select(3,label:GetFont())=="OUTLINE","active state font metrics and flags scale from unscaled references")
 end
 host:Fire("OnLeave");check(select(2,label:GetFont())==theme.labelFontSize and label:GetHeight()==theme.labelLineHeight and select(3,label:GetFont())=="","leaving a scaled state recovers its current base role and flags")
 check(ctx.fontPath=="test-font","scale-only font updates retain the configured font path")
 check(ctx.Theme==theme and theme.font~=ctx.fontPath and #S.nodes==nodeCount,"font controls never rewrite startup Theme or allocate replacement native text")
 C.SetFont(label,17);C.SetLineHeight(label,23,true);host:Fire("OnEnter");ctx:SetFont(nil,1.3);host:Fire("OnLeave")
 check(near(select(2,label:GetFont()),17*1.3) and near(label:GetHeight(),23*1.3),"a business font change becomes the next state exit baseline")
 local holder=CreateFrame("Frame",nil,UIParent);C.Element(holder,"late",{key="key"});holder.label=C.Text(holder,"Late","label");C.Element(holder,"late",{key="key"})
 check(holder.label:GetAlpha()==.43,"a completed construction binds slots that were absent during early measurement")
 ctx:Hide()
 local owned=true
 local guarded=Library:CreateContext({reducedMotion=true,ownsText=function(region)
  assert(region:GetObjectType()=="FontString","ownsText receives a retained text region")
  return owned
 end,elementDefaults={direct={slotKinds={root="text"}},parent={slotKinds={root="box",label="text"}}},elements={
  direct={base={root={fontSize=20,lineHeight=26,singleLine=true}}},
  parent={base={root={width=100},label={fontSize=18,lineHeight=24,singleLine=true}}},
 }})
 local G=guarded.C;local parent=CreateFrame("Frame",nil,UIParent)
 local direct=G.Text(parent,"Direct",14);parent.label=G.Text(parent,"Slot",14)
 local plain=G.Text(parent,"Plain",14)
 G.Element(direct,"direct");G.Element(parent,"parent")
 owned=false
 for _,text in ipairs({direct,parent.label,plain}) do text:SetFont("foreign-font",31,"OUTLINE");text:SetSpacing(7);text:SetHeight(39) end
 guarded:SetFont("context-font",2)
 for _,text in ipairs({direct,parent.label,plain}) do
  check(text:GetFont()=="foreign-font" and select(2,text:GetFont())==31 and select(3,text:GetFont())=="OUTLINE" and text:GetSpacing()==7 and text:GetHeight()==39,"SetFont preserves externally owned plain, direct and parent-slot font metrics")
 end
 owned=true;guarded:SetFont(nil,1.5)
 check(direct:GetFont()=="context-font" and select(2,direct:GetFont())==30 and direct:GetHeight()==39,"reacquired direct text uses its fixed font and line references")
 check(select(2,parent.label:GetFont())==27 and parent.label:GetHeight()==36 and select(2,plain:GetFont())==21,"reacquired slot and plain text resume the current context font policy")
 owned=false;direct:SetFont("second-owner",29,"");guarded:SetFont(nil,.7)
 check(direct:GetFont()=="second-owner" and select(2,direct:GetFont())==29,"a second ownership loss also blocks fixed-rule font refresh")
 owned=true;guarded:SetFont(nil,1)
 check(select(2,direct:GetFont())==20 and direct:GetHeight()==26,"ownership round trips preserve unscaled fixed references")
 guarded:Hide()
end
