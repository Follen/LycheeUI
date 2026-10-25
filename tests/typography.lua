return function(S,library,check,near)
 local roles={caption={12,16},label={14,20},body={16,22},title={18,24},heading={24,32}}
 local schema=library:GetTypographySchema();local roleCount=0
 for role,values in pairs(roles) do
  roleCount=roleCount+1
  check(schema[role].fontSize.key==role.."FontSize" and schema[role].lineHeight.key==role.."LineHeight" and schema[role].fontSize.default==values[1] and schema[role].lineHeight.default==values[2],"typography schema describes the canonical pair for "..role)
 end
 check(roleCount==5 and library.TextStyles.label.fontSize=="labelFontSize","the public text style catalog contains the five named roles")
 local defaults=library.ResolveTheme()
 check(defaults.font13==14 and defaults.font15==14 and defaults.font17==18 and defaults.font20==18 and defaults.line14==16 and defaults.line18==20 and defaults.line28==24,"legacy numeric tokens map to the five canonical scales")
 local preferred=library.ResolveTheme({labelFontSize=15,font14=17,font13=19})
 check(preferred.font14==15 and preferred.font13==15 and preferred.labelFontSize==15,"an explicit canonical size wins all old aliases at the same layer")
 preferred=library.ResolveTheme({font13=19,font15=21,font14=17})
 check(preferred.labelFontSize==17 and preferred.font15==17,"the representative old alias wins the remaining aliases")
 preferred=library.ResolveTheme({font13=19,font15=21},{labelFontSize=15})
 check(preferred.labelFontSize==19,"an explicit legacy override wins a canonical context default before alias ranking")
 preferred=library.ResolveTheme({buttonFontSize=19,labelFontSize=15})
 check(preferred.buttonFontSize==19 and preferred.compactSize==15,"component typography remains independently configurable")
 local aliases=library:GetThemeSchema().labelFontSize.aliases;aliases[1]="changed"
 check(library.TypographyAliases.labelFontSize.representative=="font14" and library:GetTypographySchema().label.fontSize.aliases[1]=="font14","schema aliases are independent copies of the read-only alias catalog")

 local ctx=library:CreateContext({theme={fontSizeDelta=3,lineHeightDelta=4},fontScale=1.25,reducedMotion=true})
 local C=ctx.C;local parent=CreateFrame("Frame",nil,UIParent)
 local body=C.Text(parent,"Body","body")
 check(near(select(2,body:GetFont()),19*1.25) and near(body:GetLineHeight(),26*1.25) and body.h==0,"role Text binds the whole base pair and applies context adjustments once")
 check(near(ctx:GetFontSize("heading"),27*1.25) and near(ctx:GetLineHeight("caption"),20*1.25),"context metric helpers accept named roles")
 C.SetTextStyle(body,"title",true)
 check(near(select(2,body:GetFont()),21*1.25) and near(body:GetHeight(),28*1.25),"SetTextStyle explicitly binds a role and single-line box")
 local count=#S.nodes
 ctx:SetFont(nil,1);ctx:SetFont(nil,1.25)
 check(near(select(2,body:GetFont()),21*1.25) and near(body:GetHeight(),28*1.25) and #S.nodes==count,"live font scale updates existing role pairs without adding controls")
 C.SetLineHeight(body,30,true);ctx:SetFont(nil,1.25)
 check(near(body:GetHeight(),34*1.25),"an explicit business line height retains its unscaled reference")
 C.SetFont(body,"caption")
 check(near(select(2,body:GetFont()),15*1.25) and near(body:GetHeight(),20*1.25),"SetFont with a role rebinds both measurements and retains the current single-line mode")
 local legacy=C.Text(parent,"Legacy","font14");local numeric=C.Text(parent,"Numeric",13)
 check(legacy.spacing==nil and numeric.spacing==nil and select(2,numeric:GetFont())==16*1.25,"legacy token and numeric SetFont calls keep their font-only semantics")
 local compact=C.Button(parent,"Compact",100,nil,{variant="compact"})
 local tip=C.Tooltip(parent)
 tip:SetOwner(compact);tip:AddLine("Caption")
 check(select(2,compact.label:GetFont())==17*1.25 and near(tip.lines[1]:GetLineHeight(),20*1.25),"compact controls use label while shared tooltip text uses caption")

 local colors=library:GetColorSchema()
 check(colors.primary.group=="semantic" and colors.brand.group=="semantic" and colors.surface.group=="palette" and colors.muted.group=="text" and colors.primaryHover.group=="state","the color schema classifies palette text semantic and state roles")
 check(colors.accent.aliasOf=="primary" and colors.primaryHover.derivedFrom[1]=="primary" and colors.positiveHover.derivedFrom[2]=="actionHoverAlpha","color aliases and derived entry points are discoverable")
 check(colors.modalScrim.derivedFrom[1]=="modalScrimAlpha","modal scrim declares its existing alpha derivation for editable theme templates")
 colors.primary.default[1]=0;colors.primaryHover.derivedFrom[1]="changed"
 check(library.Theme.primary[1]~=0 and library:GetColorSchema().primaryHover.derivedFrom[1]=="primary","color schema defaults and derivation metadata are independent copies")
 local primary,good={.2,.3,.4,1},{.5,.6,.7,1}
 local palette=library:CreateContext({reducedMotion=true,theme={primary=primary,good=good,rowHover={1,1,1,.1},pressed={1,1,1,.2},actionHoverAlpha=.16,actionPressedAlpha=.24}});local T=palette.Theme
 local action=palette.C.Button(parent,"Action",100,nil,{variant="primary"});action:Fire("OnEnter")
 check(near(T.primaryHover[1],.28) and near(T.primaryPressed[1],.16) and action.fill.color==T.primaryHover,"primary feedback derives at construction from the primary base and state alpha")
 check(T.positiveHover[1]==good[1] and T.positiveHover[4]==.16 and T.negativePressed[1]==primary[1] and T.negativePressed[4]==.24,"semantic action feedback takes its RGB and alpha from standard roles")
 check(near(T.surfaceLowHover[1],T.surfaceLow[1]+(1-T.surfaceLow[1])*.1) and near(T.floatingHover[4],.6+.4*.16),"neutral and floating feedback follows the same state sources")
 local explicit={.8,.7,.6,.5}
 local explicitTheme=library.ResolveTheme({primaryHover=explicit,primary={.4,.5,.6,1},accent=explicit})
 check(explicitTheme.primaryHover==explicit and explicitTheme.accent==explicit and explicitTheme.negativeHover[1]==.4,"explicit derived colors and color aliases retain independent priority")
 check(not library:ValidateTheme({actionHoverAlpha=1.1}),"state-alpha configuration shares the standard theme validation")
 local menuItems={{value=1,label="Token",color="accent"},{value=2,label="Literal",color=explicit},{value=3,label="Default"}}
 palette:OpenMenu(action,menuItems)
 local popup=palette:GetMenu();local first=popup.list.rows[1];local second=popup.list.rows[2]
 check(first.title._color==T.accent and second.title._color==explicit,"menu items accept bound color tokens and explicit color arrays")
 local menuNodes=#S.nodes
 palette:CloseMenu();palette:OpenMenu(action,menuItems)
 check(popup.list.rows[1]==first and first.title._color==T.accent and #S.nodes==menuNodes,"reopening reuses rows with frozen startup colors")
 local reused={};for i=1,20 do reused[i]=menuItems[(i-1)%3+1] end
 palette:OpenMenu(action,reused);popup.list:SetPixelOffset(40,false)
 check(first.title._color==explicit,"a recycled token-colored row adopts its next literal item color")
 popup.list:SetPixelOffset(80,false)
 check(first.title._color==T.text,"a recycled default-colored row uses text rather than retaining its former accent")
 ctx:Hide();palette:Hide()
end
