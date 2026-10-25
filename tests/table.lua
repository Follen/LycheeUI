return function(S,library,check,near)
 local context=library:CreateContext()
 local frame=CreateFrame("Frame",nil,UIParent);frame:SetSize(800,600);frame:SetScale(.8)
 local oldCursor,oldMouse=GetCursorPosition,IsMouseButtonDown
 local cursor,pressed=400,false
 GetCursorPosition=function() return cursor,0 end
 IsMouseButtonDown=function() return pressed end
 local layouts,sorts,preferences=0,0,0
 local state={}
 local defs={{key="name",label="Name",width=240,min=120},{key="score",label="Score",width=120,min=70,sortable=true},{key="age",label="Age",width=80,min=60,sortable=true}}
 local h=context.C.TableHeader(frame,defs,{onLayout=function() layouts=layouts+1 end,onSort=function() sorts=sorts+1 end,onPreferenceChanged=function() preferences=preferences+1 end})
 h:SetState(state);h:Layout(440)
 check(near(h.columns.name.width,240) and near(h.columns.score.width,120),"default column boundaries fill the host")
 check(not h.handles[1].line:IsShown() and not h:GetScript("OnUpdate"),"resting headers have no dividers or sampler")
 h.mouseOver=true;h:Fire("OnEnter")
 check(h.handles[1].line:IsShown() and not h.handles[3]:IsShown(),"hover reveals only internal dividers")
 local restAlpha=h.handles[1].line:GetAlpha()
 h.handles[1].mouseOver=true;h.handles[1]:Fire("OnEnter")
 check(h.handles[1].line:GetAlpha()>restAlpha and h.handles[2].line:GetAlpha()==restAlpha,"divider hover highlights only its own handle")
 h.handles[1].mouseOver=false;h.handles[1]:Fire("OnLeave")
 check(h.handles[1].line:GetAlpha()==restAlpha,"leaving the divider restores the subtle header state")
 pressed=true;h.handles[1]:Fire("OnMouseDown","LeftButton")
 cursor=cursor+32;h:Fire("OnUpdate",.016)
 check(near(h.columns.name.width,280) and near(h.columns.score.width,80),"physical cursor delta is converted once at the drag scale")
 check(near(h.columns.age.width,80) and not state.widths,"only the adjacent pair changes before release")
 local before=layouts;h:Fire("OnUpdate",.016);check(layouts==before,"stationary drag does not relayout")
 pressed=false;h:Fire("OnUpdate",.016)
 check(state.widths and near(state.widths.name,280/440) and not h:GetScript("OnUpdate"),"release outside the divider saves proportions and removes sampling")
 h:Layout(880)
 check(near(h.columns.name.width,560) and near(h.columns.score.width,160),"saved widths follow host resizing")
 h.buttons[2]:Fire("OnClick")
 check(state.sortKey=="score" and state.descending==false and h.buttons[2].arrow==nil,"first numeric click sorts ascending without an arrow")
 h.buttons[2]:Fire("OnClick")
 check(state.descending and sorts==2,"repeated numeric click reverses direction")
 h.buttons[1]:Fire("OnClick");check(sorts==2,"text-only headings do not request numeric sorting")
 h:SetSort("age",false);check(sorts==2,"programmatic sort selection does not reenter the application")
 local saved=state.widths
 pressed=true;h.handles[1]:Fire("OnMouseDown","LeftButton");cursor=cursor+100;h:Fire("OnUpdate",.016)
 context:Hide();pressed=false
 check(h.drag==nil and not h:GetScript("OnUpdate") and state.widths==saved and near(h.columns.name.width,560),"context close cancels an uncommitted drag and restores geometry")
 context:Resume()
 pressed=true;h.handles[1]:Fire("OnMouseDown","LeftButton");cursor=cursor-16;pressed=false
 h.handles[1]:Fire("OnMouseUp","LeftButton")
 check(near(h.columns.name.width,540) and not h:GetScript("OnUpdate"),"a fast drag samples its final cursor on release even without an update frame")
 pressed=true;h.handles[1]:Fire("OnMouseDown","LeftButton");cursor=cursor+20;h:Fire("OnUpdate",.016)
 h.handles[1]:Fire("OnMouseDown","RightButton");pressed=false
 check(not state.widths and not h.drag and not h:GetScript("OnUpdate"),"right-click restores default widths and ends an active drag")
 check(near(h.columns.name.width,480) and near(h.columns.score.width,240) and near(h.columns.age.width,160),"reset uses default proportions at the current host width")
 check(state.sortKey=="age" and not state.descending and sorts==2,"restoring widths preserves sorting without dispatching a sort")
 h:SetColumns({defs[1],defs[3]});h:Layout(440)
 check(near(h.columns.name.width+h.columns.age.width,440) and not h.buttons[3]:IsShown(),"hidden columns release their header and boundaries")
 h:SetColumns(defs);h:Layout(440)
 check(near(h.columns.name.width+h.columns.score.width+h.columns.age.width,440),"restored columns fit together with saved proportions")
 local combined={widths={name=.5,score=.25,age=.25},sortKey="score",descending=true}
 before=layouts;h:SetColumns(defs,600,combined)
 check(layouts==before+1 and h.state==combined and h.layoutWidth==600 and near(h.columns.name.width,300),"atomic columns, host width and preference replacement paints the final geometry once")
 check(h.buttons[2].label._color==context.Theme.text and h.labels.score==h.buttons[2].label,"atomic replacement applies the supplied sort state to the same public labels")
 pressed=true;h:StartDrag(1);cursor=cursor+16;h:UpdateDrag()
 local committed=h.columns.name.width/600;local replacement={};local previousPreferences=preferences
 before=layouts;h:SetColumns({defs[1],defs[3]},500,replacement);pressed=false
 check(layouts==before+1 and near(combined.widths.name,committed) and preferences==previousPreferences,"atomic column replacement commits a drag to its previous state without a preference notification or intermediate layout")
 check(h.state==replacement and replacement.widths==nil and not h.drag and not h:GetScript("OnUpdate") and not h.buttons[3]:IsShown(),"atomic replacement clears drag sampling and uses only the new state and visible definitions")
 h.mouseOver=false;h:Fire("OnLeave");check(not h.handles[1].line:IsShown(),"leaving removes the divider highlight")
 local weak=setmetatable({},{__mode="v"});local changing
 do
  local oldDefinition={key="retired",label="Retired",width=100,sortable=true,payload={}}
  weak[1]=oldDefinition
  changing=context.C.TableHeader(frame,{{key="first",label="First",width=100},oldDefinition})
  changing:Layout(200)
 end
 local spareButton,spareHandle=changing.buttons[2],changing.handles[2]
 for i=1,24 do changing:SetColumns({{key="current"..i,label="Current "..i,width=100}},200) end
 collectgarbage("collect")
 local columnCount=0;for _ in pairs(changing.columns) do columnCount=columnCount+1 end
 check(weak[1]==nil and columnCount==1 and changing.columns.current24 and not changing.columns.retired,"column replacement releases retired definitions and keeps geometry only for current keys")
 check(not spareButton:IsShown() and spareButton.definition==nil and spareButton.label:GetText()=="","spare header buttons keep native objects without retaining retired data")
 local previousSort=changing.state.sortKey;spareButton:Fire("OnClick")
 check(changing.state.sortKey==previousSort,"a stale click on a retired header cannot sort its former column")
 changing:SetColumns({},200)
 check(next(changing.columns)==nil and next(changing.labels)==nil and changing.buttons[1].definition==nil,"an empty header releases all current column definitions and geometry")
 changing:SetColumns({{key="first",label="First again",width=100},{key="retired",label="Returned",width=100}},200)
 check(changing.buttons[2]==spareButton and changing.handles[2]==spareHandle and changing.labels.retired==spareButton.label and spareButton.label:GetText()=="Returned","retired columns reuse spare controls with the new definitions")
 GetCursorPosition,IsMouseButtonDown=oldCursor,oldMouse
end
