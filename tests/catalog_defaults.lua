-- Metadata-only registration must retain identities without building style rules.
return function(S,Library,check,near)
 local ctx=Library:CreateContext({reducedMotion=true,elementDefaults={
  plain={scope="catalog",slotKinds={root="box",label="text"}},
  routed={template=true,slotKinds={root="box",label="text"}},
  anchor={slotKinds={root="box"}},classed={slotKinds={root="box"}},
 },elements={
  routed={base={root={width=60}},instances={[42]={base={root={height=45}}}},states={hover={label={alpha=.4}}},variants={wide={base={root={width=90}}}}},
  classed={classes={base={root={width=75}}}},
  anchor={base={root={points={{"LEFT","@plain#label","RIGHT",4,0}}}}},
 }})
 local C=ctx.C;local host=CreateFrame("Frame",nil,UIParent);host:SetSize(20,20)
 check(ctx:GetElementValue("routed","root","width",123)==60 and ctx:GetElementValue("routed","root","width",123)==ctx:ResolveElementValue("routed","root","width",123),"static helper aliases resolve the same base declaration")
 check(ctx:GetElementValue("routed","root","height",123,42)==45 and ctx:GetElementValue("routed","root","height",123,42)==ctx:ResolveElementValue("routed","root","height",123,42),"static helper aliases preserve business instance keys")
 check(ctx:GetElementValue("routed","root","width",123,42,"wide")==90 and ctx:GetElementValue("routed","root","width",123,42,"wide")==ctx:ResolveElementValue("routed","root","width",123,42,"wide"),"static helper aliases forward the variant together with the instance key")
 check(ctx:GetElementValue("plain","root","height",123,42,"wide")==123 and ctx:GetElementValue("plain","root","height",123,42,"wide")==ctx:ResolveElementValue("plain","root","height",123,42,"wide"),"static helper aliases retain the caller fallback for an unset variant property")
 local label=C.Text(host,"Catalog","label");local source=CreateFrame("Frame",nil,UIParent)
 local slots={root=host,label=label};C.Element(host,"plain",{scope="catalog",slots=slots,key=42,stateOwner=source})
 check(C.ElementValue(host,"root","width",123)==123,"catalog declarations preserve the caller's current measured fallback")
 check(ctx:GetMenuOwnerKey(host)=="plain/number:42","catalog identities preserve stable menu owner keys")
 C.Element(host,"plain",{scope="catalog",slots=slots,stateOwner=source})
 local anchor=CreateFrame("Frame",nil,UIParent);C.Element(anchor,"anchor")
 check(select(2,anchor:GetPoint())==label,"a catalog-only element remains a valid semantic anchor target")
 local pointWrites=0;local setPoint=anchor.SetPoint
 function anchor:SetPoint(...) pointWrites=pointWrites+1;return setPoint(self,...) end
 ctx:ApplyElements("catalog");check(pointWrites==0,"an inactive catalog scope never reapplies another scope")
 check(host:GetWidth()==20,"default scope application performs no layout writes")
 C.RekeyElement(host,42,"routed")
 check(host:GetWidth()==60 and host:GetHeight()==45,"a catalog registration can rebind to a configured template and instance")
 source:Fire("OnEnter");check(label:GetAlpha()==.4,"rebind preserves an explicit foreign state owner and custom slots")
 source:Fire("OnLeave");check(label:GetAlpha()==1,"configured state exit restores the existing label baseline")
 host:SetWidth(30);ctx:ApplyElements("catalog");check(host:GetWidth()==60,"configured promotion keeps its original scope for explicit reapplication")
 host.styleController:SetVariant("wide");check(host:GetWidth()==90,"normal variants retain their geometry after catalog promotion")
 C.ReleaseElement(host);check(host:GetWidth()==30 and host:GetHeight()==20,"release restores current business geometry after configured promotion")
 local native=CreateFrame("Frame",nil,UIParent);native:SetSize(10,10)
 C.Style(native,{style={root={width=80}}});C.Element(native,"plain")
 check(C.ElementValue(native,"root","width",123)==80,"catalog measurement still sees the native target's fixed constructor rule")
 local classed=CreateFrame("Frame",nil,UIParent);C.Element(classed,"classed")
 check(classed:GetWidth()==75,"structured construction classes remain an effective rule rather than catalog metadata")
 local schema=ctx:GetElementSchema("plain",{"plain.base.label.alpha"})
 check(schema["plain.base.label.alpha"].inherited,"catalog metadata remains queryable without an effective style rule")
 ctx:Hide()
end
