# LycheeUI

LycheeUI is an embeddable visual component library for Retail World of Warcraft addons. It provides shared theme tokens, controls, menus, native-control leases, and motion. The consuming addon owns its data, business rules, and page composition.

Product window tokens, artwork, brand trajectories and numeric field labels belong to the consuming addon. `ctx:SetWindow(frame)` configures generic window motion; custom visual tasks use `ctx.Motion:Start(key, job, onStop)` with caller-owned cleanup.

Current source: **1.3.0** (compatibility revision **46**). [.lock](.lock) records the maintenance scope, freeze status and recorded runtime/media hashes. Runtime text files use LF so source, Git checkouts and embedded packages remain byte-identical. `versionString` is the display release; `version` is the increasing compatibility revision used when multiple embedded copies are loaded. The optional theme tokens `fontSizeDelta` and `lineHeightDelta` default to zero; consumers continue passing base sizes to component APIs. The optional context `fontScale` defaults to `1`; `ctx:SetFont(path, scale)` updates retained component text and owned native leases from their base styles. Full API contracts and examples are in [API.md](API.md); component appearance and interaction guidance are in [DESIGN.md](DESIGN.md).

Read [.lock](.lock) before changing or synchronizing the library; it records the current maintenance scope and runtime file hashes.

## Embed

Copy `embeds.xml`, the nine Lua files, and the complete `Media` directory into the consuming addon:

```text
MyAddon/
  MyAddon.toc
  UI.lua
  Libs/LycheeUI/
    embeds.xml
    Core.lua
    Theme.lua
    Motion.lua
    Styles.lua
    Components.lua
    Layouts.lua
    Elements.lua
    Native.lua
    Menu.lua
    Media/
```

Load the XML before any file that uses the library:

```text
Libs/LycheeUI/embeds.xml
UI.lua
```

The XML order is Core, Theme, Motion, Styles, Components, Layouts, Elements, Native, Menu. Load the complete XML entry point; do not load individual definition files on demand or reorder them. Product packages should include those runtime files and media, not the standalone `LycheeUI.toc`, tests, or documentation. `LycheeUI.toc` is for developing the library as a standalone addon.

## Create and keep a context

```lua
local ctx = LycheeUI:CreateContext({
    parent = UIParent,
    addon = "MyAddon",
    reducedMotion = function() return MyAddon.db.reduceMotion end,
})
local C, T, M = ctx.C, ctx.Theme, ctx.Motion

local open = C.Button(UIParent, "Open", 112, function()
    MyAddon:Open()
end, { variant = "primary" })
```

Create a context for each UI owner and retain it while that UI is reused. Contexts keep their menus, registered inputs, native leases, and motion state separate. Call `ctx:Hide()` when closing immediately; call `ctx:Resume()` before using it again. If the window plays an exit animation, call `Hide()` after that animation completes.

The default embedded media path is `Interface\\AddOns\\<addon>\\Libs\\LycheeUI\\Media\\`. Set `addon` to the consumer folder name to use that path. Set `media` to a complete alternate media directory, including its trailing slash, when assets live elsewhere. The standalone development addon uses `Interface\\AddOns\\LycheeUI\\Media\\`.

## Multiple embedded copies

Once the nine files finish loading, the library publishes `LycheeUI.version` and `LycheeUI.versionString`. A later copy with the same or lower revision reuses the installed library. A higher revision updates the shared factories while preserving already-created contexts and their objects; new contexts use the updated defaults. Reload the UI after replacing embedded files so existing contexts are recreated from the new definitions.

The library has no external dependency, SavedVariables, login handler, or idle polling task. Context construction creates Lua state; controls and the motion driver are created when needed. Contexts and their UI objects are explicitly owned and reused by the consuming addon.

## Offline checks

From the library source directory, run the offline suite with:

```sh
lua tests/run.lua
lua tests/list_geometry.lua
lua tests/menu_geometry.lua
lua tests/menu_font_writes.lua
lua tests/elements_ownership.lua
lua tests/native_reacquire.lua
lua tests/setpoint-cost.lua
lua tests/fixed_writes.lua
lua tests/list_clear.lua
lua tests/layout_release.lua
lua tests/layout_measure_records.lua
lua tests/style_release.lua
lua tests/style_events.lua
```

These checks run against local test doubles. They do not represent Retail client rendering, secure execution, or in-game compatibility verification.


## Startup Theme and live interaction

Contexts accept immutable startup token, recipe, element and named-class data. Schema and validation helpers work before UI creation. The consuming addon owns Theme import, storage and selection; a new Theme takes effect after `/reload`. Late-built controls use the same startup snapshot. There is no generic hot appearance writer or live-object query API.

Normal window dragging/resizing, column dragging, interface scale, font scale and component states remain live. `ctx:SetFont(path,scale)` refreshes registered text and owned native leases from base font/line references; fixed hover/selected font metrics scale correctly while active. Business updates use native/finite component setters, followed by explicit fixed-element reapplication where needed. Row/Column compose existing objects; Box creates no wrapper Frame. Business instance keys, cross-element anchors and variable state row heights remain supported.

Named utilities compose static `classes` declarations; they are not replaceable during the session. Equal fixed rule combinations share compiled data. Plain Text does not retain a full style engine or interaction controller. Only actual configured slots keep values needed to leave states or rebind pooled keys. Fixed-state sources share one native hook per event across contexts; releasing a controller removes its active subscriptions, so repeated binding and native-control handoff do not retain old controllers or add hooks. See [API.md](API.md#elements-instances-and-named-classes) for the construction, ownership and measurement contracts.

An event dispatcher applies consecutive state contributions from the same controller and source together, so leaving clears hover and pressed in one application. Interleaved controllers keep their binding order. An older embedded copy's already-installed dispatcher remains installed and keeps its previous application count while consuming the same subscription records correctly.

Repeated fixed-rule application reads the current native target and avoids rewriting a configured slot while its requests and actual native fields are unchanged, including native-normalized font and opacity values. External edits to settled targets still update the business baseline and are corrected by the active rule. Font metrics preserve explicitly controlled native spacing, text height and vertical justification across state and font changes; releasing that ownership restores the current remaining rule. Dimension checks include active min/max constraints, including changes owned by another controller. Texture/atlas/UV restoration keeps its grouped behavior; semantic anchors reconnect when their referenced object changes. An explicit immediate apply settles an owned transition, and releasing a binding cancels its owned visual work. Per-slot request records, affected native font fields and dimension bounds remain bounded by the configured slots; stable applications do not build patch or art-snapshot tables. Lists release temporary table-key geometry references after measurement and when cleared or returned to fixed-height mode.

Five standard text roles are caption 12/16, label 14/20, body 16/22, title 18/24 and heading 24/32. Pass a role to `C.Text`/`C.SetFont`, or use `C.SetTextStyle`, to retain both references. Numeric font sizes remain numeric. `GetTypographySchema` and `GetColorSchema` return independent metadata. Product component typography may override these generic defaults at startup.
