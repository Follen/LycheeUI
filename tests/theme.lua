return function(S,library,check,near)
 local schema=library:GetThemeSchema({productWidth=420})
 check(schema.font14.type=="number" and schema.primary.type=="color" and schema.productWidth.default==420,"the public schema includes built-in and product defaults")
 local field=library:GetThemeField("primary");local textField=library:GetThemeField("labelFontSize")
 check(field.type==schema.primary.type and field.group==schema.primary.group and field.default[1]==schema.primary.default[1] and textField.canonical==schema.labelFontSize.canonical,"single theme field exposes the same metadata as the full catalog")
 field.default[1]=0;textField.aliases[1]="changed"
 check(library:GetThemeField("primary").default[1]==schema.primary.default[1] and library:GetThemeField("labelFontSize").aliases[1]==schema.labelFontSize.aliases[1],"single field default colors and alias arrays are independent")
 check(library:GetThemeField("productWidth",{productWidth=420}).default==420 and library:GetThemeField("missing")==nil,"single theme field supports product defaults and unknown keys")
 check(library:ValidateTheme({productWidth=500},{productWidth=420}),"product tokens validate at the context boundary")
 check(not library:ValidateTheme({unknown=1}),"unknown overrides are rejected")
 check(not library:ValidateTheme({font14="large"}) and not library:ValidateTheme({primary={2,0,0,1}}),"invalid token values are rejected")
 check(not library:ValidateTheme({font14=math.huge}),"non-finite numeric tokens are rejected")
 check(not library:ValidateTheme({font14=0}) and not library:ValidateTheme({line20=-1}) and not library:ValidateTheme({disabledAlpha=1.1}),"text and alpha bounds match native presentation limits")
 check(not library:ValidateTheme({fontSizeDelta=-100}) and library:ValidateTheme({fieldRadius=0,presenceOffset=-4}),"effective text stays positive while legal zero radii and signed offsets remain available")
 local product={hostIconWidth=24,rowHeight2=40,cardRadius=8,memberNameFont=14,memberNameLine=18,anchorX=-12,anchorY=-4}
 check(not library:ValidateTheme({hostIconWidth=-1},product) and not library:ValidateTheme({rowHeight2=-1},product) and not library:ValidateTheme({cardRadius=-1},product),"product geometry suffixes reject the same negative dimensions as utility bindings")
 check(not library:ValidateTheme({memberNameFont=0},product) and not library:ValidateTheme({memberNameLine=1,lineHeightDelta=-1},product),"product Font and Line tokens validate positive effective typography before updates")
 check(library:ValidateTheme({hostIconWidth=0,anchorX=-30,anchorY=-50},product),"zero product dimensions and signed anchor offsets remain legal")
 check(not library:ValidateTheme({listRowHeight=0}) and not library:ValidateTheme({menuRowHeight=0}),"virtual list row strides reject zero before allocating pools")
 check(library:ValidateTheme({lineHeightDelta=-10,tableLineHeight=0}) and library:GetThemeSchema().tableLineHeight.unit==nil,"divider height is geometry and never constrains effective text line deltas")
 local getter=library.GetThemeSchema;local schemaCalls=0
 library.GetThemeSchema=function(...) schemaCalls=schemaCalls+1;return getter(...) end
 local valid=library:ValidateTheme({font14=18,primary={.2,.3,.4,1}})
 library.GetThemeSchema=getter
 check(valid and schemaCalls==0,"theme validation does not allocate the public metadata catalog")
 local ok,err,resolved=library:ValidateTheme({primary={.1,.3,.5},labelFontSize=17})
 check(ok and err==nil and resolved.primary[4]==1 and resolved.font14==17,"successful validation returns its existing resolved aliases as the third result")
 local resolver=library.ResolveTheme;local resolutions={}
 library.ResolveTheme=function(...) local result=resolver(...);resolutions[#resolutions+1]=result;return result end
 local plainContext=library:CreateContext()
 library.ResolveTheme=resolver
 check(#resolutions==1 and plainContext.Theme==resolutions[1],"absent extra defaults resolve and validate the builtin theme only once")
 resolutions={};library.ResolveTheme=function(...) local result=resolver(...);resolutions[#resolutions+1]=result;return result end
 local emptyContext=library:CreateContext({themeDefaults={},theme={labelFontSize=17}})
 library.ResolveTheme=resolver
 check(#resolutions==1 and emptyContext.Theme==resolutions[1] and emptyContext.Theme.font14==17,"empty extra defaults do not duplicate resolution or skip override aliases")
 check(plainContext.Theme~=emptyContext.Theme and plainContext.Theme.font14~=emptyContext.Theme.font14,"empty-default optimization preserves isolated resolved context themes")
 check(not pcall(library.CreateContext,library,{themeDefaults="invalid"}) and not pcall(library.CreateContext,library,{themeDefaults={font14=0},theme={font14=18}}),"invalid defaults remain rejected before valid overrides can mask them")
 local defaultsOnly={productWidth=420,labelFontSize=17,surface={.2,.3,.4},brand={.3,.4,.5}}
 local _,_,expectedDefaults=library:ValidateTheme({},defaultsOnly)
 resolutions={};library.ResolveTheme=function(...) local result=resolver(...);resolutions[#resolutions+1]=result;return result end
 local defaultsContext=library:CreateContext({themeDefaults=defaultsOnly,theme={}})
 library.ResolveTheme=resolver
 check(#resolutions==1 and defaultsContext.Theme==resolutions[1],"an empty override reuses this call's successfully validated defaults without a second resolved copy")
 for key,expected in pairs(expectedDefaults) do
  local actual=defaultsContext.Theme[key]
  if type(expected)=="table" then for index,value in ipairs(expected) do check(actual[index]==value,"default color derivation remains equivalent: "..key) end
  else check(actual==expected,"default aliases and tokens remain equivalent: "..key) end
 end
 local defaultsOther=library:CreateContext({themeDefaults=defaultsOnly})
 defaultsContext.Theme.productWidth=999
 check(defaultsOther.Theme~=defaultsContext.Theme and defaultsOther.Theme.productWidth==420,"reused defaults stay isolated between context instances")
 local defaultReads=0
 local dynamicDefaults=setmetatable({probeToken=1},{__index=function(_,key) if key=="labelFontSize" then defaultReads=defaultReads+1;return defaultReads==1 and 17 or 18 end end})
 local dynamicContext=library:CreateContext({themeDefaults=dynamicDefaults})
 check(defaultReads==2 and dynamicContext.Theme.font14==18,"default metatables preserve both original lookup passes")
 local dynamicOverride=setmetatable({},{__index=function(_,key) if key=="labelFontSize" then return 21 end end})
 local overrideContext=library:CreateContext({themeDefaults=defaultsOnly,theme=dynamicOverride})
 check(overrideContext.Theme.font14==21,"an empty override with a metatable still resolves its own values")
 resolutions={}
 library.ResolveTheme=function(...) local result=resolver(...);resolutions[#resolutions+1]=result;return result end
 local reused=library:CreateContext({themeDefaults={productWidth=420},theme={productWidth=460,labelFontSize=17}})
 library.ResolveTheme=resolver
 check(#resolutions==2 and reused.Theme==resolutions[2] and reused.Theme.productWidth==460 and reused.Theme.font14==17,"raw Context validates both layers and reuses the resolved override result without a third Resolve")
 local other=library:CreateContext({themeDefaults={productWidth=420},theme={productWidth=460,labelFontSize=17}})
 reused.Theme.productWidth=999
 check(other.Theme~=reused.Theme and other.Theme.productWidth==460,"resolved result reuse retains independent Context top-level tables")
 check(not pcall(library.CreateContext,library,{themeDefaults={customWidth=-1}}) and not pcall(library.CreateContext,library,{theme={fontSizeDelta=-100}}),"raw construction still rejects invalid defaults and nonpositive effective font sizes")
 local originalRed=library.Theme.text[1];local catalog=library:GetThemeSchema();catalog.text.default[1]=.123
 check(library.Theme.text[1]==originalRed and library:GetThemeSchema().text.default[1]==originalRed,"schema default color arrays are independent catalog values")
 local custom=library:CreateContext({themeDefaults={productWidth=420},theme={text={.2,.3,.4,1},fieldHeight=52,productWidth=460}})
 local normal=library:CreateContext();local C=custom.C
 local parent=CreateFrame("Frame",nil,UIParent);parent:SetSize(800,600)
 local plain=C.Text(parent,"Constructed","label","text");local field=C.Field(parent,240)
 check(plain.color[1]==.2 and field:GetHeight()==52 and custom.Theme.productWidth==460 and normal.Theme.fieldHeight==44,"constructors resolve one independent immutable startup theme")
 custom:SetFont("changed",1.3)
 check(custom.Theme.font~= "changed" and select(1,plain:GetFont())=="changed" and near(select(2,plain:GetFont()),18.2),"real font preferences do not modify the startup Theme table")
 local mask=C.GameIcon(parent,24);custom:RoundIcon(mask,"custom-mask");local nativeMask=mask._lycheeMask
 custom:RoundIcon(mask,"next-mask");custom:SetFont("changed",1)
 check(mask._lycheeMask==nativeMask and nativeMask:GetTexture()=="next-mask","explicit mask replacement reuses its native object independently of font updates")
 local crop=C.GameIcon(parent,24);local mask=crop._lycheeMask;local nodeCount=#S.nodes
 custom:SetGameTexture(crop,123,.1,.9,.2,.8)
 check(crop:GetTexture()==123 and near(crop.texCoords[1],.148) and near(crop.texCoords[4],.764),"file updates crop within the caller's current UV bounds")
 custom:SetGameAtlas(crop,"replacement")
 check(crop:GetAtlas()=="replacement" and near(crop.texCoords[1],.224) and near(crop.texCoords[4],.776),"atlas updates replace the former file crop with the current atlas bounds")
 custom:SetGameTexture(crop,456);custom:SetFont("another-font",1.1)
 check(crop:GetTexture()==456 and near(crop.texCoords[1],.06) and near(crop.texCoords[4],.94) and crop._lycheeMask==mask and #S.nodes==nodeCount,"reusing an icon resets omitted UV bounds and preserves its mask and crop through font changes without creating regions")
 local instant=library:CreateContext({theme={revealDuration=0,selectionDuration=0,switchDuration=0}})
 local target=CreateFrame("Frame",nil,parent);instant.Motion:Rect(target,0,0,100,100,0)
 check(target:GetWidth()==100 and instant.Motion:Count()==0,"zero-duration startup motion reaches its endpoint without a driver")
 check(not custom.SetTheme and not custom.PatchTheme and not custom.SetAppearance and not custom.SetRecipes and not custom.SetElements and not custom.SetElement and not custom.SetUtilities and not custom.BindStyle,"generic theme mutation interfaces do not remain as aliases")
 check(not C.ApplyStyle and not C.ClearStyle and not C.SetStyleLayer and not C.Utility and not custom.GetElement and not custom.GetElementInfo and not custom.ListElements,"generic overlays and public live-object queries are absent")
end
