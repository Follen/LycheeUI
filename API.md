# LycheeUI API

This document describes the public runtime API in LycheeUI 1.3.0, compatibility revision 46. Embed and load the library as described in [README.md](README.md). Theme tokens and visual rules are defined in [DESIGN.md](DESIGN.md).

## Call and ownership conventions

Call library factories with dot syntax: `C.Button(parent, ...)`, `C.Surface(parent, ...)`, `C.NativeInput(shell, box, ...)`. Call methods on a returned Context, Motion object, or widget with colon syntax: `ctx:Hide()`, `ctx.Motion:Stop(key)`, `button:SetVariant("primary")`. The examples use these conventions.

The consuming addon owns business state, data lookup, layout composition choices, and callbacks. LycheeUI owns the appearance and lifecycle of the controls it creates. Constructor return values are native WoW Frames, FontStrings, Textures, or small controller/lease tables as indicated below. Public subregions and extension points documented here are supported interfaces; callers may position them, add `HookScript` callbacks, and configure their documented appearance. Do not replace library-installed scripts with `SetScript` unless the API explicitly says the script is yours to install.

## Create a context

```lua
local ctx = LycheeUI:CreateContext({
    parent = UIParent,
    addon = "MyAddon",
    reducedMotion = function() return MyAddon.db.reduceMotion end,
    isHiding = function() return MyAddon.UI.hiding end,
    text = { on = "On", off = "Off" },
    inputs = {},
})
local C, T, M = ctx.C, ctx.Theme, ctx.Motion

ctx:SetWindow(MyAddon.UI.frame)
local button = C.Button(ctx.parent, "Open", 112, function()
    MyAddon:Open()
end, { variant = "primary" })
```

`CreateContext(options)` is a method on `LycheeUI`. It returns a context with independent theme, component factories, motion driver, input registry, and menu/native-control state. It creates Lua state, not control Frames or a running driver.

| Option | Default and contract |
| --- | --- |
| `parent` | `UIParent`; parent for context-owned popups and helper objects. |
| `addon` | Loaded addon folder name; sets media to `Interface\\AddOns\\<addon>\\Libs\\LycheeUI\\Media\\` (`LycheeUI` standalone uses `Interface\\AddOns\\LycheeUI\\Media\\`). |
| `media` | Full media directory, including trailing slash; takes precedence over `addon`. |
| `themeDefaults` | Optional read-only product token declaration directory. Extends the startup token schema. Values use the same scalar/color types as built-in tokens. Keep the directory unchanged after construction. |
| `onTablePreferenceChanged` | Optional `(header, changes)` callback for explicit table width/sort actions; never called by programmatic layout/state. |
| `theme` | Token overrides for this context. Derived states and aliases are resolved by `LycheeUI.ResolveTheme`. |
| `font` | Context font override. Otherwise `STANDARD_TEXT_FONT`. |
| `fontScale` | Text size multiplier, default `1`. Applies after the font and line-height deltas to existing base sizes, without scaling control geometry. |
| `ownsText` | Optional `(region) -> boolean` predicate limiting retained text updates by `SetFont` to application-owned regions; newly constructed text still uses the context policy. Native leases have their own ownership check. |
| `theme.fontSizeDelta`, `theme.lineHeightDelta` | Context-local offsets, both defaulting to `0`. For example `{theme={fontSizeDelta=3,lineHeightDelta=4}}` adds 3px to base font sizes and 4px to explicit base line heights without changing control geometry or other contexts. |
| `reducedMotion`, `isHiding` | Boolean or zero-argument function. |
| `inputs` | EditBox registry used by `ClearFocus`; defaults to a new table. |
| `text` | Optional control text dictionary; Check state labels read `on` and `off`, otherwise use On/Off. Numeric placeholders are supplied on the returned shell. |
| `frame` | Optional window used by Presence motion. May instead be assigned with `ctx:SetWindow`. Product artwork and its animation controllers remain caller-owned. |
| `onRowRelease`, `onRowLeave` | Optional callbacks receiving a list row when it is released or left. |
| `onMenuHover`, `onMenuClosed` | Optional menu lifecycle callbacks; hover receives `(row, entry)`, closed receives the former anchor (or nil). |

Each context gets its own top-level theme table. Default color arrays are shared tokens and read-only by convention; replace a token in an override rather than mutating an array. `media` resolution priority is context `media`, context `addon`, theme `media`, then the installed library default.

### Context methods

| Method | Contract |
| --- | --- |
| `ctx:IsReducedMotion()` | Returns the configured setting evaluated as a boolean. |
| `ctx:IsHiding()` | Returns true while `ctx:Hide()` is active or the configured setting is true. |
| `ctx:SetText(region, value)` | Writes `tostring(value or "")` only when changed. |
| `ctx:SetFont(path, scale)` | Changes the context font path and optional size multiplier; reapplies recorded base font/line styles to retained component text and refreshes currently owned native leases. New and reused controls use the same policy. Does not walk global frames. Callers remeasure their application layout afterward. `ctx.fontScale` exposes the active multiplier. |
| `ctx:Color(region, color)` | Sets FontString text color only when the color table identity changes. |
| `ctx:Hex(color)` | Returns a cached `|cffRRGGBB` prefix for an RGB color table. |
| `ctx:ClearFocus()` | Clears focus on registered inputs. |
| `ctx:Hide()` | Marks the context as hiding; closes menus, releases native leases, clears input focus, and stops all motion. It does not hide the application window. |
| `ctx:Resume()` | Clears the context hiding flag. |
| `ctx:SetWindow(frame)` | Sets the window region and captures its motion endpoint. |
| `ctx:ReleaseRow(row)` / `ctx:LeaveRow(row)` | Calls the respective configured row callback; release also closes a menu anchored to the row. |
| `ctx:ReleaseNativeControls()` | Releases all active native leases owned by this context. |
| `ctx:RoundIcon(icon, texture?)` | Adds one shared rounded mask. An explicit mask texture replaces its art and remains bound for the context lifetime; repeated calls reuse the existing mask. |
| `ctx:SetGameTexture(texture, file, left, right, top, bottom)` | Sets a file texture, applies the rounded mask and 6% crop within the supplied UV bounds (defaults to the full texture). |
| `ctx:SetGameAtlas(texture, atlas)` | Sets an atlas and crops within its actual atlas UV bounds. |
| `ctx:SetIconState(textureOrGlyph, selected, hovered)` | Applies shared selected/hovered grayscale, tint, and alpha treatment. Reads the current native state to skip unchanged writes, comparing color/alpha at eight-bit storage precision while tolerating float readback roundoff. External native style changes, including adjacent stored channel values, are corrected on the next call. |
| `ctx:OpenMenu(anchor, entries, onPick, options)` | Opens this context’s menu; see [Menus](#menus). |
| `ctx:CloseMenu()` / `ctx:CloseMenuFor(anchor)` | Closes the current menu, optionally only when owned by `anchor`. |
| `ctx:GetMenu()` | Returns the created menu Frame or nil if the menu has not yet been created. |
| `ctx:IsMenuOpen(anchor)` | Reports whether a menu is open, optionally only for `anchor`. |
| `ctx:IsMenuHovered(anchor)` | Reports whether the open menu is under the pointer, optionally requiring the given anchor. |
| `ctx:GetMenuAnchor()` | Returns the current menu anchor or nil. |

The menu inspection methods expose the menu Frame as a public extension point. Use them for deliberate extensions such as applying the application font to its title rows; do not assume a menu exists before `GetMenu()` returns one.

`LycheeUI.ResolveTheme(overrides)` returns an independent theme table with aliases and derived interaction tokens recomputed from overridden base colors. `LycheeUI.Theme` is the library default theme; `LycheeUI.media`, `LycheeUI.version`, and `LycheeUI.versionString` expose the installed media path and release identifiers.

## Components

All factories below are methods on `ctx.C` and use dot syntax. A returned widget’s methods use colon syntax. Unless stated otherwise, `parent` is required, dimensions are logical UI units, and callbacks are optional.

### Foundation and surfaces

| Factory | Return and public contract |
| --- | --- |
| `C.Text(parent, text, size, color, width, lineHeight)` | FontString. Defaults to 14px body text and theme text color. Width and line height are optional. `lineHeight` sets FontString spacing only; the FontString keeps automatic height. |
| `C.SetFont(region, baseSizeOrToken, flags)` | Sets the context font and `(baseSize + theme.fontSizeDelta) * ctx.fontScale`; size defaults to the theme body size and flags to an empty string. Repeated calls with the same base size do not accumulate the offset or multiplier. |
| `C.SetLineHeight(fontStringOrEditBox, height, singleLine)` | Sets measured line spacing. `singleLine=true` fixes the control height and vertically centers it; without it, height remains automatic. Reapply after changing font or size. Other object types raise an error. |
| `C.Fill(parent, color, layer)` | Full-parent Texture using `color={r,g,b,a}`; layer defaults to `BACKGROUND`. |
| `C.Panel(parent, color, radius, inset, layer)` | Rounded fill controller with public `.regions`, `:SetColor(color)`, `:SetColorTexture(r,g,b,a)`, `:SetAlpha(alpha)`, `:GetAlpha()`, `:SetShown(bool)`, `:IsShown()`, `:Show()`, `:Hide()`, `:SetRadius(radius)`. Tracks parent size. `GetAlpha` reports animation alpha; material alpha is multiplied by it. |
| `C.Shadow(parent, radius)` | Shadow controller with `.regions`, `:SetAlpha(alpha)`, `:SetShown(bool)`, `:Show()`, `:Hide()`. Radius selects the nearest 12/16/24/28 asset. |
| `C.Surface(parent, options)` | Mouse-transparent Frame covering `parent`, with `.fill` Panel and `:SetHovered(bool)`, `:SetColors(rest, hover)`. `options.variant="floating"` defaults to 60% black, RGB .04 at 66% alpha on hover, radius 16. Otherwise it uses `options.color` or `T.panel`, the same color on hover unless `hoverColor` is given, and panel radius 24 unless overridden. |
| `C.Draggable(frame, options)` | Drag controller with `:AddHandle(frame)` and `:Stop()`. Left button only; bind passive regions. `options.onStart(frame)` may return false to block the drag; `options.onStop(frame)` runs when it ends. Hiding the frame stops it. Dragging the context window updates its motion endpoint. |
| `C.CheckMark(parent, color)` | 16×20 Frame with public `.strokes` and `:SetColor(color)`. Caller positions and shows it. |

### Buttons and choices

Font sizes passed to `C.Text`, `C.SetFont`, button label/style options, and list title style options are **base sizes**. Explicit line heights passed to `C.SetLineHeight` and component style options are also base values; their effective height is `(baseHeight + theme.lineHeightDelta) * ctx.fontScale`. Do not pre-add the offsets, pre-multiply sizes, or pass an adjusted `GetFont()` size back as a base size. `Button:SetStyle` preserves the other base value when only font size or line height is supplied. Ordinary edits, menu measurement/labels, and borrowed native inputs use the owning context font policy; native input release restores the original font, including after a font-scale change. Only owned leases are refreshed; release preserves a new host's font after a foreign handoff. Geometry, icons, and default contexts remain unchanged.

`C.Button(parent, text, width, onClick, options)` returns a native Button with public `.label`, `.fill`, `.hover`, `.icon` when configured, and `:SetPrimary(bool)`, `:SetActive(bool)`, `:SetAvailable(bool)`, `:SetSurfaceColors(rest, hover, pressed)`, `:SetTextColors(rest, hover, selected)`, `:SetFeedbackColors(hover, pressed)`, `:SetRadius(radius)`, `:SetLabelStyle(size, lineHeight)`, `:SetVariant(name)`, `:SetStyle(options)`, and `:SetExpanded(bool)`. The constructor defaults to 100×40 with a 20px radius and 14/20 label. Options are `{recipe, variant, height, radius, fontSize, lineHeight, surfaceColors, hoverColor, pressedColor, textColor, hoverTextColor, selectedTextColor, selectionFill}`. `selectionFill=false` keeps the button text state while a shared parent selection layer paints the active background. Variants are `ghost` (default transparent button with transient hover/press layer), `primary` (brand filled), `tonal` (secondary container), `compact` (30 high, radius 8, 14/20 label), and `text` (transparent with brand text feedback). Text variant uses brand-colored text for hover, press, and active/selected states; its surface stays transparent. `recipe` selects the fixed constructor recipe and cannot be changed by `SetStyle`. Public `.styleController` exposes the constructor binding. `SetStyle` applies the same finite component options to an existing button. It changes only supplied properties; when `variant` is supplied, it first resets the base dimensions and colors for that variant, then applies the remaining options. Selection, availability, and the click callback are retained. `SetSurfaceColors(nil)` clears a custom surface palette. `SetAvailable(false)` disables it, dims it to 38%, clears pressed state, and closes its owned menu. `onClick(button, mouseButton)` runs only for a valid enabled click.

`SetValue` methods on widgets are silent setters unless stated otherwise: they update presentation/state but do not invoke the business change callback. User interaction invokes that callback.

Segmented values preserve an explicit `false`; positional entry values are used only when the named `value` is nil. Hiding Navigation and Check controls settles their mark or knob at the current state and stops those child transitions.

| Factory | Return and public contract |
| --- | --- |
| `C.IconButton(parent, icon, size, action, options)` | Button using a glyph name, or `icon=nil` for a raw Texture caller can configure. `size` defaults to 40 and is the button width/height; `options.iconSize` defaults to 20 and `options.height` can override height. It inherits Button options and methods, but its icon keeps its own color/alpha when the button becomes active; this differs from selectable Button/Navigation icons. |
| `C.ChoiceTrigger(parent, width, action, options)` | Button styled as a choice field; exposes `.label`, `.value`, `:SetValue(value, label)`, `:SetSurfaceVariant("dark" or nil)`, and normal Button methods. The action receives `(button, mouseButton)`. |
| `C.Choice(parent, width, entries, onChange)` | ChoiceTrigger that opens the context menu. `entries` is an array or function returning an array. `onChange(value)` runs after a user selects an entry. `:SetValue(value, label)` changes value and label without invoking `onChange`. |
| `C.Selection(parent, options)` | Passive Frame with `.fill`, optional `.mark`, `:Select(x, y, width, height, animate)`, and `:Clear(animate)`. Coordinates use the parent's top-left. Options are `radius`, `color`, and `mark`; `animate=false` applies the endpoint immediately. The frame reuses its geometry and opacity tasks and clears them when its parent hides. |
| `C.Segmented(parent, width, entries, onChange)` | Frame with `.buttons`, `.selection`, `.value`, `:SetValue(value)`. Entries are `{value, label, icon?}` or positional `{value,label}`. One passive background moves between fixed buttons. The user callback is `onChange(value)`; programmatic `SetValue` is silent. |
| `C.Navigation(parent, text, width, onClick, iconName, options)` | Button with public `.label`, `.icon` when provided, `.mark`; supports Button options as the sixth argument. Defaults to 48 high, radius 24, 16/22 label. `:SetActive(bool)` sets selected styling and animates the selection mark. |
| `C.Check(parent, label, onChange)` | Switch Button with `.label`, `.track`, `.knob`, `.value`; `:SetValue(bool, animate)` updates silently, `:SetAvailable(bool)` changes availability. `onChange(value)` runs on user toggle. |
| `C.Checkbox(parent, onChange, options)` | CheckButton with `.fill`, `.mark`, `:SetValue(bool)`, `:GetValue()`, `:SetAvailable(bool)`, `:RefreshStyle()`. Options: `{size=32, boxSize=18, radius=5}`. `onChange(value, button)` runs on user click; `SetValue` is silent. |

### Inputs and notices

| Factory | Return and public contract |
| --- | --- |
| `C.Field(parent, width, height, search, variant)` | Frame shell with `.fill`, `.focus`, optional `.inner`, `:SetFocused(focused, hovered)`, and backdrop-compatible `:SetBackdropColor(...)`/`:SetBackdropBorderColor(...)`. It does not create an EditBox. Defaults to 44 high and radius 4; `search=true` uses radius 24; `variant="modal"` uses modal field colors. |
| `C.Edit(parent, width, height, multiline, search, variant)` | Field shell with `.box`, optional `.scroll`, and `:SetPlaceholder(text)`. Registers its EditBox in the context input list. Default font 14, no autofocus, no max-letter limit. Use `.box:HookScript(...)` to add callbacks. `SetPlaceholder` also uses hooks, so install any required first `SetScript` handler before calling it. |
| `C.Number(parent, width, height, onChange)` | Numeric Edit shell with `.box` and an empty default placeholder. Set a label with `shell:SetPlaceholder(text)`. `onChange(text)` runs on text changes; the caller interprets empty text and numeric limits. |
| `C.Notice(parent, width, onClose)` | Hidden Frame with `.text`, `.close`, `.fill`, and `:SetMessage(message, actionWidth)`. Empty message hides it; nonempty message wraps and sets height. Caller reserves layout space and any action area. |
| `C.Tooltip(parent, width)` | Initially hidden text-tooltip Frame; parent defaults to `UIParent`, width to 300. `:SetOwner(owner, anchor)` resets the lines, `:AddLine(text, r, g, b, wrap)` adds 12/16 text with wrapping enabled unless false, and `:Show()` measures and places it. `anchor="ANCHOR_TOP"` anchors above the owner; other values use the owner's bottom-right. `:IsOwned(owner)` checks visible ownership; `:LeaveOwner(owner)` hides a matching tooltip. The caller connects owner enter/leave events. `.lines` contains reusable FontStrings. |
| `C.Modal(parent, width, height, title, onClose)` | Initially hidden Frame with `.title`, `.close`, `.content`, `.scrim`. Defaults to context parent, 480×300; close button or scrim calls `onClose(frame)` when provided, otherwise hides the frame. The scrim covers the supplied `parent`. Caller owns modal content and final close lifecycle. |

### Lists, columns, and numeric controls

`C.List(parent, width, height, rowHeight, onSelect, onHover, options?)` returns a Frame with `.rows`, `.slider`, `.clip`, `.canvas`, `.offset`, `.pixelOffset`, `.selectedKey`, and `:SetItems(keys, render)`, `:SetRowInitializer(initialize)`, `:Select(key, locate)`, `:Refresh(positionOnly)`, `:RefreshKeys(keys, resolve)`, `:Clear()`, `:SetPixelOffset(pixel, animate)`, `:SetViewport(height)`, `:SetRowHeight(stride,bodyHeight?,viewportHeight?)`, `:SetRowHeightResolver(resolve?)`, `:RefreshGeometry()`, `:GetContentHeight()`, `:GetElementKey(key,index?)`, `:SetGutter(width)`, and `:SetStyle(style)`. The optional construction options are `{recipe,initializeRow,onGeometryChanged}`; `initializeRow(row)` creates custom slots before the fixed row recipe is bound. The initial pool is visible capacity plus two spare rows. Callbacks are `onSelect(key, mouseButton, row)` and `onHover(row, key)`. In variable-height mode, `onGeometryChanged(list,contentHeight)` runs synchronously after a refresh when the complete content height changes; ordinary fixed-height lists retain their arithmetic fast path.

List style options accepted by `:SetStyle` are `alternateRows`, `selectionFill`, `selectionMark`, `selectionMotion`, `hoverFill`, `idleTextColor`, `hoverColor`, `rowHeight`, `radius`, `titleSize`, `titleLineHeight`, `singleLine`, `titleX`, and `titleWidth`. `selectionMotion=true` creates one reusable `.indicator` instead of animating each row fill and mark. Scrolling snaps or clears it before row reuse; hidden refreshes apply selection immediately. `rowHeight` changes the visual Frame height only; the list’s construction `rowHeight` continues to determine row indexing and scroll steps. `singleLine=true` hides metadata and centers the title vertically; `singleLine=false` restores the metadata and places the title at the top-left. The list’s public row extension points include `.title`, `.meta`, `.noteDot`, `.alternate`, `.selected`, `.hover`, `.mark`, `.key`; callers may add row textures/regions and custom columns. Optional `.symbol` is passed through shared icon-state styling. Use the callbacks/context row hooks to release external tooltip ownership.

`Select(key, locate)` changes selection styling. With `locate=true`, it scrolls the row into view; it does not refresh the bound data. `Refresh()` redraws currently bound data. `Refresh(true)` updates position/selection and renders newly bound rows. `SetItems` replaces keys and render callback. `RefreshKeys(keys, resolve)` rerenders visible keys that match the supplied changed keys. `SetPixelOffset` animates only when `animate=true` and reduced motion is off. `SetGutter` sets the right-side scroll gutter.

For a resizable viewport, call `SetRowInitializer(initialize)` once after construction. It immediately calls `initialize(row)` for every existing row and then for each newly allocated row before rendering it. Put custom row regions and handlers in this callback. `SetItems` and `SetViewport` can then grow the pool to the smaller of visible capacity and actual item count, plus two spare rows. An empty larger viewport does not allocate new rows. Shrinking retains the high-water pool for reuse. Without an initializer, `SetViewport` retains the original fixed pool limit. Set the list width before changing its viewport so new rows inherit the current width and gutter; callers still own the positions of custom regions. `C.Columns` only initializes existing rows, so resizable custom columns belong in the row initializer.

Use `SetRowHeight(stride,bodyHeight?,viewportHeight?)` instead of manually changing row positions/capacity. Stride must be finite and positive; body height must be finite and nonnegative and defaults to the existing row-style height or stride. The optional viewport is applied in the same final refresh. A list with no height overrides retains fixed arithmetic and creates no prefix arrays. For an element-backed list (`elementTemplate`/`elementScope`, or Element's `rowTemplate`), template/instance/class rules for root height/minHeight/maxHeight participate before placement. State height changes update the owning list synchronously; paint changes do not rebuild geometry. The existing nonnegative gap between bodies is retained. Width remains a property of the individual row and does not resize the entire table.

Nonuniform heights reuse numeric prefix offsets and visible-index arrays for the existing IDs. Scroll lookup uses binary search; positions, content height, clipping/hit insets, selection and `Select(key,true)` use the same offsets. Height zero collapses the item and omits it from the visible pool. Offscreen heights affect the scroll range without creating offscreen frames or registering all business keys. The pool grows only as needed for the actual visible rows plus overscan; custom row regions must be supplied through the initializer. Reset/rebind returns to the appropriate current key and baseline. No idle sampler is added. `SetRowHeightResolver(function(key,index,defaultBodyHeight) return height end)` offers the same geometry for non-element data; return nil for the default or a finite nonnegative height. Call `RefreshGeometry()` when external resolver data changes; SetItems and shared element updates invalidate it automatically.

`GetContentHeight()` includes offscreen items and internal gaps, with zero-height items collapsed. `C.Element(list,id,{rowTemplate=templateId,rowElementKey=map})` can map each business key and its one-based data index to an element instance key. `GetElementKey(key,index?)` uses this mapping, or returns the original key when no mapping exists; a nil key stays nil. Without an index, a mapped list locates the key in its current items. The same mapping is used for visible and offscreen geometry. Selection and callbacks continue to use the business key.

The optional Element list option `rowElementState(key,index,stateName)` supplies stable `checked` and `disabled` states before rows are allocated. Only those two state names are queried. A boolean overrides the corresponding native state; nil preserves the visible controller's state, or false offscreen. Variable-height lists use the same states in geometry and synchronize bound rows during full or position-only refresh. Selection follows `selectedKey`; visible hover, pressed and focus states remain local to the current controller, with disabled suppressing hover and pressed. Full `Refresh()` still renders changed business content. Lists without height rules retain the fixed path and create no geometry-state table.

| Factory | Return and public contract |
| --- | --- |
| `C.Columns(list, columns, titleWidth)` | Adds columns to each existing row. Each descriptor is `{key, x, width, size?, lineHeight?, align?}`; explicit `lineHeight` wins, otherwise the default is 20, or `size+6` when `size` is set. Result FontStrings are available at `row.columns[key]`; callers may re-anchor them and change width through those FontStrings. |
| `C.Header(parent, text, x, y, width, align)` | 14/20 FontString anchored at the supplied top-left offset; `align` defaults to left. |
| `C.TableHeader(parent, definitions, options)` | Interactive header with `.columns[key]={x,width}`, `.labels[key]`, `.buttons`, `.handles` and `.state`. Definitions are ordered `{key,label,width,min?,align?,sortable?}`; width is the default allocation weight. `options.onLayout(header)` applies geometry to rows; `options.onSort(key,descending)` handles numeric sorting. |
| `C.ScrollBar(parent)` | Native vertical Slider with 6px width and themed thumb. Caller sets anchors, range, value, and callbacks. |
| `C.Slider(parent, width, min, max, step, onChange, options)` | 40px Frame with `.slider`, `.track`, `.thumb`, `.progress`, `:SetValue(value)`, `:GetValue()`, `:IsDragging()`, and `:FinishDrag(commit)`. Defaults are min 0, max 100, step 1. Without `commitOnRelease`, it wraps a native Slider and `onChange(value)` follows native value changes; programmatic `SetValue` is silent. With `{commitOnRelease=true}`, dragging previews the stepped value through `options.onPreview(value)` and commits once through `onChange(value)` on release. `:FinishDrag(false)` cancels and restores the starting value; hiding cancels. |

For commit-on-release sliders, `options.onPreview(value)` runs while the value changes, including programmatic `SetValue`; `onChange(value)` runs only when the drag commits. The preview callback may cancel the drag or hide the control; cancellation restores the initial value and leaves no frame sampler. `:IsDragging()` identifies an active drag. `:FinishDrag(true)` commits an active drag; `false` cancels it. The ordinary native-slider variant reports `false` from `:IsDragging()` and has a no-op `:FinishDrag()`. Both slider variants support a zero range (`min == max`) with finite empty progress; the manual variant fixes its thumb at the track origin.

Table headers expose `SetState(state)`, `SetColumns(definitions,width?,state?)`, `Layout(width)`, `SetSort(key,descending,notify?)`, `ResetWidths()` and `StopDrag(commit)`. `SetColumns` accepts a host width and preference state together, commits any active drag to its previous state without notification, replaces the definitions/state, and performs one final layout using the supplied or previous width. Omitting both optional arguments preserves the original behavior. Geometry maps retain only current column keys; spare buttons/handles are reused with their old definition and label cleared. The application supplies a table `{widths?,sortKey?,descending?}`; the component writes normalized widths once on release and sort state on clicks. `SetSort` updates state and the selected heading color without invoking `onSort`; its optional third argument only notifies preference listeners when `true`; it does not create an arrow or reserve arrow space. `Layout` fills the available width using saved proportions or default weights, respecting descriptor minima and translated label widths; call it after a host size or font change. `onLayout` must not call `Layout` recursively. A drag changes only the adjacent pair and samples at the scale captured on mouse-down. Right-clicking a divider calls `ResetWidths()`: it cancels the current drag, removes only `state.widths`, and reapplies the current definitions at the current host width without changing sorting. Hiding the header or Context cancels and restores unsaved widths; applications should also call `StopDrag(false)` when beginning a close animation or opening an overlay. No sampler exists while idle. The library never reads or sorts application data, persists settings, or creates business subscriptions.

### Icons

| Factory or method | Return and public contract |
| --- | --- |
| `C.Icon(parent, size)` | Native Texture sized to `size`; caller sets the texture and anchors. |
| `C.GameIcon(parent, size)` | Native Texture with the shared rounded mask. Set its art with `ctx:SetGameTexture` or `ctx:SetGameAtlas`. |
| `C.Glyph(parent, name, size, color)` | Frame with `.texture`, `:SetSelected(selected, hovered)`, `:SetTexture(file)`, `:SetColor(color)`. The glyph uses the context media directory. Style and Element color reads use the internal texture, while dimensions and anchors remain on the public Frame and resolve against its parent. |

### Native control extension points

Use native leases when the addon must preserve an existing control’s object identity. A lease exposes documented fields and methods; it does not copy input text or call application business APIs.

| Factory | Contract |
| --- | --- |
| `C.NativeInput(shell, editBox, options)` | Returns a lease with `.box`, `.shell`, `:IsOwned()`, `:Release()`, and `:RefreshStyle()`. Applies a `C.Field`/`C.Edit` shell to the existing registered EditBox, preserving the object and native text. Options include `container`, `padding`, `contentInset`, `textInsets`, `scripts`, `hide`, `onLost`, and `owner`. `scripts[event]` is a replacement callback or `false` to suppress that event; unspecified scripts remain. Focus/hover updates the shell after forwarding the original callback. `onLost()` runs when another UI takes ownership. |
| `C.NativeFrame(frame, parent, options)` | Returns a lease with `.region`, `.layout`, `:IsOwned()`, `:Release()`, `:Quiet(region)`, `:QuietTextures(frame)`, and `:Bind(frame, event, handler)`. It borrows parent/layout; caller positions the region. `Bind` handler receives `(frame, previousHandler, ...)`. `options.restoreShown` sets visibility on release. |
| `C.NativeButton(button, options)` | Returns a lease with `.fill`, `:IsOwned()`, and `:Release()`. Applies the shared primary button appearance while retaining the native button’s parent and click behavior. Options: `text`, `minWidth`, `owner`, `onLost`. Caller positions it. |
| `ctx:ReleaseNativeControls()` | Releases context leases, children before parents. `ctx:Hide()` invokes it automatically. |

Native input acquisition identifies and hides existing full-field fills and four-strip borders before changing the native parent. This preserves detection while their original anchor dimensions are resolved; reparenting can temporarily report 1x1 fills or 0x0 borders. Cursor/selection art remains intact, and no delayed polling or permanent skin hooks are installed. `lua tests/native_background_probe.lua` replays that captured transition for search, single-line and multiline inputs.

Lease release restores saved layout, scripts, font presentation, and temporarily hidden decoration when the lease still owns the control. If another interface moved the native control, the lease stops overriding its new parent or scripts and relinquishes its input registration.

Every acquisition creates a fresh public lease and fresh script wrappers capturing that lease; neither identity nor old wrappers are recycled. Binding records use one flat internal array, and quiet-region alpha/visibility use parallel maps instead of one table per region. A text snapshot stores original and actual applied font/color/shadow values together; focus refresh overwrites only its applied scalar fields. Native region/child enumeration does not build temporary Lua arrays. These are internal representations, not new public fields or permanent hooks. Stale callbacks still refer to their original lease and cannot act on a later acquisition.

`lua tests/native_allocations.lua` isolates Lua lease bookkeeping with stable native-like setters/getters. On 2026-10-23, 100 rounds of three inputs, each acquired, refreshed again and released, fell from 2904.078 to 1761.891 KiB allocated (39.33%). This is an offline transaction measurement, not native-client memory. `tests/native_reacquire.lua` covers the existing native lifecycle suite plus stale callbacks, fresh identities, foreign fonts and decoration handoff.

An input or native-button callback may release its lease, hide its context, or transfer the control to another host. The old callback handler then stops its visual work. Release remains idempotent when a focus callback also releases the lease, and checks ownership again after clearing focus before restoring layout.

The same applies to synchronous focus, layout, and show callbacks during acquisition, including focus loss and hiding of a shell's ordinary input. Moving the native container or EditBox to another parent, or releasing its owner lease, stops initialization and returns an inactive lease; it does not register the input or leave borrowed styling behind. Closing the context also stops acquisition. Check `lease:IsOwned()` before using a lease whose acquisition can trigger those callbacks.

`NativeInput` options: `container` identifies the ScrollFrame to move for a multiline edit; default is the EditBox itself. `padding` defaults to `{10,7,10,7}` in left/top/right/bottom order. `contentInset` defaults to 36 and sets the multiline EditBox width relative to the shell. Its `Instructions` placeholder uses the same content width while leased. The existing container `OnSizeChanged` binding updates both widths when the viewport grows or shrinks, without polling; release restores the original width unless a new host has already changed it. `textInsets` changes native text insets only when provided. `hide` is an array of native decorations to hide. `owner` can be another lease whose ownership must remain valid. For a native `MinimalScrollBar`, the lease recolors its thumb while preserving native range, sizing, position, and input behavior. On release, it restores saved styles and layout where the lease still owns those regions.

## Menus

All menus enter after layout with a 0.16s reveal from 8 units above the final position. Closing remains immediate and clears the pending placement before the owner callback runs.

`ctx:OpenMenu(anchor, entries, onPick, options)` opens the lazily created context menu. Entries are `{value, label, icon?, disabled?, header?, checked?, color?, onClick?}`. `options` supports `width`, `selectedValue`, `locate`, `kind="select"`, and `cursor`. An explicit `width` takes precedence over label measurement and is still clamped to the available screen width. Without it, labels determine the natural width. Cursor placement opens at the pointer with screen-edge adjustment. Select menus size to the trigger when possible and mark `selectedValue`; checked entries work in either menu kind. At most the visible row pool is rebound as the menu scrolls.

An entry’s `onClick(value, label)` takes precedence over `onPick(value, label, entry)`. The menu closes and releases ownership before the callback runs. Disabled and header entries do not invoke the callback. `C.Choice` supplies select-menu options automatically. `anchor.isChoice` opts a custom Button into the choice expanded outline behavior.

Menu rows use the shared list geometry, including template, instance, class and state height rules. Initial selection, checked entries and disabled/header entries participate before measurement; zero-height rows collapse, and offscreen heights contribute to the scroll range. The popup follows the actual content height within its viewport bounds. Element keys retain the owner/value identity while selection callbacks retain their entry values. The positive default row stride remains independent of a configured zero body height.

Menu extension and lifecycle methods are `ctx:GetMenu()`, `ctx:IsMenuOpen(anchor?)`, `ctx:IsMenuHovered(anchor?)`, `ctx:GetMenuAnchor()`, `ctx:CloseMenu()`, and `ctx:CloseMenuFor(anchor)`. `GetMenu()` returns nil before first use and the native menu Frame thereafter; its public `.list`, `.fill`, and `.measure` regions may be extended by the caller. Optional `onMenuHover(row, entry)` and `onMenuClosed(anchor)` context callbacks observe row hover and close.

When replacing an open menu, `onMenuClosed` runs after the old menu is cleared. If that callback opens another menu, hides the context, hides the requested anchor, or disables the requested Choice, the pending replacement stops. A menu opened by the callback retains its own entries and anchor. Disabled Choice anchors cannot open menus; ordinary Frame anchors retain their existing behavior.

## Motion

`ctx.Motion` is a per-context finite task driver. Methods use colon syntax. `Start(key, job, onStop?)` runs `job(elapsed)` each frame until it returns true; `IsRunning(key)`, `Stop(key)`, `Count()`, `Tick(elapsed, now)`, and `StopAll()` inspect or manage tasks. A task is keyed by its region or a caller-owned key; starting the same key replaces its previous task. The optional zero-argument `onStop()` runs exactly once when that run completes naturally, is stopped, is replaced, or is removed by `StopAll()`. Removal or replacement happens before cleanup, so cleanup can start a new task. A task started during a callback begins on the next tick, including when it reuses the same key and function; the previous run's completion cannot stop it.

`StopAll()` detaches its batch of old tasks and settles their built-in visual endpoints before running cleanup callbacks. Tasks started by those callbacks survive the completed batch. If one cleanup raises an error, the remaining cleanups still run, then the first error is raised. Custom artwork, trajectories and reset behavior belong to the caller and can use `Start` with `onStop`; the library does not hold a product logo or brand animation.

Window motion uses a private task key, so caller-owned keys cannot replace or preserve it by name. `Tick` releases its temporary task snapshot before propagating a job or cleanup error; tasks not yet processed remain registered until the caller continues or stops them. An explicitly nested `Tick` has its own snapshot; ordinary driver ticks reuse the existing buffer.

| Method | Contract |
| --- | --- |
| `M:Spin(region, enabled, period)` | Starts/stops a full rotation; period defaults to 0.9s. |
| `M:Reveal(region, point, parent, relative, x, y, dx, dy, duration)` | Animates placement and opacity from the offset start to the requested endpoint. Duration defaults to 0.18s; zero applies the endpoint immediately, including after caller layout changes. Repeating an active identical target continues it while its position is unchanged; changing a target or externally moving the region with the same anchor retargets from the displayed position and opacity. |
| `M:FinishPlacement(region)` | Lands a region at its saved placement endpoint. |
| `M:Rect(region, x, y, width, height, duration)` | Moves and resizes a region relative to its current parent's top-left. Duration defaults to 0.18s; zero applies the endpoint, including after caller layout changes. Reuses a geometry task independent of opacity, retargets from displayed geometry, and skips unchanged pixel-aligned writes. A changed parent or anchor basis starts at the requested endpoint. |
| `M:FinishRect(region)` | Lands an active geometry transition at its endpoint and stops its task. |
| `M:Busy(region, enabled)` | Shows and pulses a region while enabled; `enabled=false` hides it and restores the alpha captured when enabled. The pulse has a 0.9s period. `M:Stop(region)` restores alpha without changing visibility. |
| `M:Waiting(region, enabled)` | Shows a waiting region with a 1.2s size/alpha/position wave. `enabled=false` hides it and restores the size, alpha, and anchor captured on enable. `M:Stop(region)` restores geometry/alpha without changing visibility. |
| `M:Alpha(region, target, duration, initial, finished)` | Animates alpha; optional initial alpha is applied at start; zero-argument `finished()` runs at completion. Zero duration applies the target and invokes the callback immediately. |
| `M:Color(panel, target, duration)` | Animates a Panel color while preserving its independent alpha. |
| `M:Selection(region, selected, duration)` | Animates selection opacity without restarting an unchanged target; reversal keeps the current opacity. Duration defaults to 0.10s; zero applies the state immediately. |
| `M:CapturePosition()` | Captures the configured window’s current anchor and origin coordinates for Presence motion; it does not set a motion endpoint. |
| `M:SetPresence(value)` | Applies a Presence phase from 0 to 1 as window position and alpha only. The caller controls whether the frame is shown or hidden. |
| `M:Presence(shown, finished)` | Animates the configured window’s position and alpha toward the shown/hidden phase; it does not call `Show()` or `Hide()`. Caller sets visibility and uses the zero-argument completion callback at the appropriate lifecycle point. |
| `M:StopPresence()` | Cancels only the configured window's active Presence task and its completion callback, preserving the displayed position and alpha. Other caller-owned tasks are unaffected. |
| `M:Switch(region, from, to)` | Animates a switch knob between horizontal positions. |

`Busy(region, enabled)` captures the region’s starting alpha when enabled. `Waiting(region, enabled)` captures its starting size, alpha, and first anchor; each frame is based on that captured geometry, so that single anchor is its positioning contract. `Stop(key)` restores captured Busy alpha or Waiting geometry/alpha. For Reveal it discards the saved endpoint without moving the region; use `FinishPlacement(region)` to land at that endpoint. `StopAll()` performs the same restoration for active Busy and Waiting regions and settles still-active placement, switch, alpha, and color transitions at their recorded endpoints. The context supplies reduced-motion state to components. Motion owns visual transitions only; application events and business task completion remain application responsibilities.

## Lifecycle example

`Rect` state is reused per region and uses a separate task key from opacity. `Stop(region)` cancels both channels; `FinishRect(region)` settles only geometry. `StopAll()` also settles active rectangle and selection transitions. Reduced motion applies endpoints immediately.

```lua
local function Open()
    ctx:Resume()
    MyAddon.UI.frame:Show()
    ctx.Motion:Presence(true)
end

local function Close()
    ctx.Motion:Presence(false, function()
        MyAddon.UI.frame:Hide()
        ctx:Hide()
    end)
end
```

If no exit animation is needed, hide the application window and call `ctx:Hide()` directly. Reuse the context and its controls on later opens.


## Startup Theme and validation

Theme data is resolved once by `CreateContext`. The caller supplies the active startup snapshot; importing or selecting another Theme takes effect after `/reload`. Treat the context Theme, recipe, element and utility inputs as immutable for the lifetime of the context. Do not edit their tables after construction.

```lua
local ctx = LycheeUI:CreateContext({
    themeDefaults={resultInset=12,resultWidth=360},
    theme={primary={.7,.2,.3,1}},
    recipeDefaults=MyRecipes, recipes=StartupTheme.recipes,
    elementDefaults=MyElements, elements=StartupTheme.elements,
    utilities=StartupTheme.utilities,
})
local title=ctx.C.Text(parent,"Title","title","text")
ctx.C.Box(title,{width="resultWidth"})
ctx.C.SetPoint(title,"TOPLEFT",parent,"TOPLEFT","resultInset",-8)
```

`ResolveTheme(overrides,extraDefaults?)` resolves library defaults, product defaults and startup overrides, including aliases and derived colors. `ResolveRecipes(defaults,overrides)` composes immutable recipe data. These pure functions do not require controls or install live queries.

`GetThemeField(key,extraDefaults?)` returns one declared token descriptor or nil. `GetThemeSchema(extraDefaults?)` returns the full descriptor map. Context versions include the product defaults. Descriptors expose `type,default,min?,max?,exclusiveMin?,unit?`; returned metadata and nested color/alias arrays are independent copies. `ValidateTheme(values,extraDefaults?)`, `ValidateRecipes(overrides,defaults?,theme?)`, `ValidateElements(overrides,defaults?,theme?,utilities?)`, and `ValidateUtilities(directory,theme?)` return `true` or `false,message` without constructing native controls. Successful `ValidateTheme` additionally returns its resolved theme as the third result, allowing startup validation to reuse that work.

Unknown tokens, unknown IDs/slots/classes, unsupported properties and non-finite values fail at the startup boundary. Fonts and line heights must be positive after their context deltas, alpha is 0..1, sizes/radii are nonnegative, and list/menu default strides are positive. Signed offsets remain legal. Product ranges beyond the declared schema are owned by the product.

`ctx:GetToken(key)` returns a raw token. `ctx:ResolveValue(value)` resolves a token or passes through a literal. `GetFontSize(ref)` and `GetLineHeight(ref)` calculate `(base+delta)*fontScale`. `ctx:SetFont(path,scale?)` remains live (nil path retains the current path): it refreshes registered text, fixed active font rules, layouts, open-menu measurements and owned native leases. It changes `ctx.fontPath`/`ctx.fontScale`, never the startup Theme. The application remeasures its own page layout afterward. A font update does not activate a pending Theme.

The generic hot writers `SetTheme`, `PatchTheme`, `SetAppearance`, `SetRecipes`, `SetElements`, `SetElement`, `SetElementAppearance`, `SetUtilities`, `BindStyle`, `C.ApplyStyle`, `C.ClearStyle`, `C.SetStyleLayer`, `C.Utility`, and controller `SetStyle`/`ClearStyle` are removed. They have no aliases or empty implementations. No generic mutation notification callback remains.

### Five text roles and compatibility aliases

| Role | Font / line | Canonical tokens | Default use |
| --- | --- | --- | --- |
| `caption` | 12 / 16 | `captionFontSize`, `captionLineHeight` | Short supplementary text and tooltips |
| `label` | 14 / 20 | `labelFontSize`, `labelLineHeight` | Buttons, inputs, compact options, list metadata |
| `body` | 16 / 22 | `bodyFontSize`, `bodyLineHeight` | Reading text, navigation and menus |
| `title` | 18 / 24 | `titleFontSize`, `titleLineHeight` | List titles and section titles |
| `heading` | 24 / 32 | `headingFontSize`, `headingLineHeight` | Page/modal headings |

`LycheeUI.TextStyles[role]` is the read-only descriptor `{fontSize=canonicalKey,lineHeight=canonicalKey}`. `C.Text(parent,text,role,...)` and `C.SetFont(label,role,flags?)` bind both measurements. `C.SetTextStyle(label,role,singleLine?)` explicitly applies the pair, optionally selecting fixed single-line height; when omitted it keeps the label's current height mode. A later `C.SetLineHeight` overrides only the line reference and survives font scale changes. Applying a role again rebinds its pair. Numeric and token font arguments retain font-only semantics. `ctx:GetFontSize(role)` and `ctx:GetLineHeight(role)` apply deltas and scale once.

`LycheeUI:GetTypographySchema(extraDefaults?)` returns `{[role]={fontSize=field,lineHeight=field}}`, using independent fields from `GetThemeSchema`. Fields include `key,type,default,unit,role,canonical,representative,aliases` and ordinary range metadata. `LycheeUI.TypographyAliases[canonicalKey]` is the read-only `{role,unit,representative,aliases}` source. The ordered alias array excludes the canonical key and begins with its representative. Within one input layer canonical wins, then representative, then the remaining aliases in array order; explicit overrides are resolved before `themeDefaults`. All keys in a group expose the winning base value. Consumers with more storage layers must select the highest supplied layer before applying that ranking.

Font aliases map `font12` to caption; `font13/14/15` to label (representative `font14`); `font16` to body; `font17/18/20` to title (representative `font18`); `font24` to heading. Line aliases map `line14/16` to caption (representative `line16`); `line18/19/20` to label (`line20`); `line21/22` to body (`line22`); `line24/28` to title (`line24`); `line32` to heading. Literal numbers do not remap. Component tokens remain independent overrides: button/compact/list-meta/native defaults derive from label, navigation/menu from body, list-title from title and tooltip from caption. Legacy `bodySize/metaSize` still mean label, `titleSize` means heading, and `headingSize` means title.

### Color roles and derived feedback

`LycheeUI:GetColorSchema(extraDefaults?)` filters `GetThemeSchema` to all color fields, including aliases and derived states. Each field includes an independent `default` RGBA/RGB array and `group` (`palette`, `text`, `semantic`, or `state`). Aliases identify `aliasOf`; derived colors identify `derivedFrom={sourceKeys...}` and `overlay`. `primary` and `brand` are semantic base roles, `surface*` are palette roles, and `text/muted/dim/on*` are text roles. Schema getters return fresh metadata arrays and do not implement a second validator; `ValidateTheme` remains the configuration boundary.

`primaryHover` overlays white using `rowHover[4]`; `primaryPressed` overlays black using `pressed[4]`. Neutral hover/pressed colors retain their owning surface and white state layer. `positiveHover/positivePressed` take RGB from `good`; negative equivalents take RGB from `primary`. Their alpha comes from `actionHoverAlpha=.14` / `actionPressedAlpha=.22`. `floatingHover` takes RGB from its base surface with the white hover layer and alpha `baseAlpha+(1-baseAlpha)*actionHoverAlpha`. Explicit color tokens, including derived states and aliases, always win. Base semantic/palette changes do not reinterpret class colors, scores, or supplied image assets.

### Native layout and image updates

Use native `SetWidth`/`SetHeight`/`SetSize`/`SetPoint`/`SetTexture`/`SetAtlas` and finite component setters for ordinary business refresh. `C.Box` supplies composition constraints and optional existing-content fit. `C.SetPoint(target,point,relative,relativePoint,x,y)` is a one-shot native point convenience: numeric offsets or declared numeric tokens are resolved on that call. It preserves other native points and retains no style layer or rollback history. `C.ApplyElement(target)` reapplies that target's already fixed startup rules after an explicit business render boundary.

Image decoration belongs to the consuming addon: compose existing Textures, Box, native color/layer setters and `ctx:RoundIcon(icon,maskTexture?)`. The library has no product-specific avatar, role, roster, recruitment or asset resolver.

## Native composition and fixed rules

### Box and measurement

```lua
C.Box(icon, 24)                         -- square, same Texture returned
C.Box(icon, "avatarSize")
C.Box(icon, {width="avatarWidth", height="avatarHeight", minWidth=16})
C.Box(holder, {width=40, height=32, padding=4, fit="contain", content=texture})
local width, height = C.MeasureText(label)
local optionWidth = C.MeasureText(label, "Candidate text")
```

`C.Box(target,spec)` returns `target`, retains its identity, texture/atlas, crop, mask, layer, font and decorations, and allocates no native Frame. A scalar/token means a square. A table supports `width,height,minWidth,maxWidth,minHeight,maxHeight,padding,align,fit,content` (or width/height at indices 1/2). Table axes are independent: `{width=20}` or `{20}` leaves height untouched; only a scalar/token is square shorthand. A later Box call replaces its prior Box specification; unrelated native properties remain. Width/height and constraints accept numbers/token names. Padding is a scalar/token or left/top/right/bottom array/named table. Alignment is start/center/end/stretch. Optional existing `content` is centered inside the padded rectangle with contain/cover/none fit; aspect ratio is captured on that Box call, using 1:1 when either content axis has no positive measured size. Cover extends content outside the rectangle; the caller owns clipping. Fit changes size/anchor, never UV coordinates. Box dimensions are independent of text sizes.

Layout consumes these Box constraints and alignment. Active states can change the same dimensions and constraints. A changed state width or height reflows only its owning Row/Column; leaving the state restores the lower-layer Box value. A Box can be attached to any existing Frame/Texture/FontString; capability-specific properties remain opt-in.

Nonempty text whose native width/height is temporarily 0 is remeasured on the next call, preserving existing deferred-font layout callbacks. Each label retains one current-text record and at most 16 candidate records. Font changes and `C.InvalidateTextMetrics(label?)` advance a revision and reuse the existing records; omitted label invalidates all context measurements. Candidate eviction reuses its slot instead of preserving unlimited text history. This adds no task or timer.

`C.MeasureTextWidth(label,text?)` returns only unbounded width, without reading allocated width or measuring wrapped height. `C.MeasureText(label,text?)` returns that same width and the height at the label's current allocated width and native word-wrap setting. Both share one cache. It never changes visible label text. Default current-text measurement retains one record per label; explicitly supplied candidates retain at most 16 records per label. Path, size, flags, spacing, word-wrap and registered line-height/mode changes invalidate the record; allocated width invalidates only its wrapped height. Cache keys compare fields, without constructing a font-key string per call. Candidate measurement lazily creates one hidden FontString per context. Cached measurement performs no native text/font/size writes. Ordinary dynamic text does not accumulate a history of names. Add application-specific rounding/insets after measurement, for example `math.ceil(C.MeasureText(label))+2`.

### Row and Column

```lua
local row = C.Row(parent, {
    {frame=settings, gapAfter=10},
    {frame=autoApply, gapAfter=20},
    {frame=autoJoin},
}, {anchor="TOPRIGHT", width="content", height=44,
    padding={right=16}, align="center"})
row:Layout()
local stack = C.Column(parent, {
    {frame=title, width="fill", height="content"},
    {frame=body, width="fill", height="content", grow=1, shrink=1},
}, {width=300, height=200, gap=8, padding=12})
stack:Layout()
```

`C.Row(parent,items,options?)` and `C.Column(...)` return a controller; neither replaces nor reparents items. An item may be the native object directly, or `{frame,width,height,minWidth,maxWidth,minHeight,maxHeight,grow,shrink,align,hidden,gapAfter}`. **Omitted item axes retain current native GetWidth/GetHeight**, including previously measured text padding and fixed line boxes. Explicit `content` measures natural text/content, `fill` uses the available main-axis budget (default grow=1) or cross-axis width/height. Explicit numeric/token axes set that size. Grow/shrink weights divide surplus/shortage; default shrink=0. Constraints clamp the resulting item size; constrained surplus is left for justify, rather than iteratively redistributed like browser flexbox.

Options are `width,height,gap,padding,align,justify,anchor,x,y,includeHidden`. Width/height accept numbers/tokens or `content`; omitted dimensions use `Layout(w?,h?)` arguments or the parent's current size. `content` measures the item rectangle without resizing the parent. Padding order is left/top/right/bottom, either array or named. Gap defaults to 0; per-item gapAfter replaces it and is ignored after the final item. Align defaults to start; justify is start/center/end/space-between. Center/end alignment allows a negative cross offset for an oversized line box. Anchors are TOPLEFT (default), TOPRIGHT, BOTTOMLEFT, BOTTOMRIGHT or CENTER relative to parent; x/y use native directions, positive y up. Items use a single TOPLEFT point inside that rectangle.

Hidden (`item.hidden` or native `not IsShown()`) items consume neither size nor gaps; `includeHidden=true` includes native hidden items. Layout uses local visibility, so an entire hidden page can still measure its retained rows. Container padding defaults to its Box padding when options omit it.

`SetItems(items)` replaces the list; `SetOptions(patch)` merges options; both return the controller and wait for explicit layout. `Measure(w?,h?)` measures without retaining item placement. Repeated measurement keeps only the current items and earlier placements still owned by this controller; replacing items or measuring an empty list releases unowned historical records. `Layout(w?,h?)` returns contentWidth/contentHeight including padding and stores both fields. It synchronously allocates sizes and owns item anchors. `Release()` relinquishes that ownership and clears current and cached item references, even when the caller retains the controller; repeated release is harmless and preserves a newer layout's ownership. A component skips its default label anchor once layout owns it. Records, active arrays, ownership tables and placement closures are reused for current items; completing Layout releases removed Lua records and descriptor references. Identical dimensions and anchors produce no native geometry writes. Stable non-content items use a single input/child-size validation pass instead of the full distribution passes, then verify owned anchors. Mutable options/padding/item order/constraints, child visibility/dimensions, parent size and font refresh invalidate it. Explicit content items retain natural text measurement rather than caching stale content geometry. Font refresh reflows registered layouts. There is no OnUpdate or automatic native resize hook: application changes to text, visibility or container size should call Layout explicitly.

### Recipes, slots and states

```lua
local ctx=LycheeUI:CreateContext({recipeDefaults={
    quietAction={
        base={surface={shown=false},hover={shown=false},label={color="muted"}},
        states={hover={label={color="brand"}}},
        variants={emphasis={base={label={color="good"}}}},
    },
}})
local button=ctx.C.Button(parent,"Action",100,onClick,{recipe="quietAction",variant="emphasis"})
local style=button.styleController
style:Bind(otherSource,{hover=true})
-- For an existing native object, bind once during construction:
local nativeStyle=ctx.C.Style(nativeFrame,{
    slots={root=nativeFrame,label=nativeLabel},
    style={label={fontSize="caption"}},
    states={pressed={label={alpha=.8}}},
})
```

Recipes use `{slotKinds?,base={slot={properties}},states={state={slot={properties}}},variants={name={base=...,states=...}}}`. `Library.ComponentRecipes` is the read-only default catalog. `recipeDefaults` adds application recipes; `recipes` supplies startup overrides. Button/IconButton options select their recipe during construction. Their public `styleController` is the same fixed binding used by the component's normal state machine.

`recipe.slotKinds={slotName="kind"}` declares immutable capability metadata; it is not an editable override leaf. Standard names infer their established kind; custom names default to box or can explicitly declare a kind. Kinds are: box (geometry/constraints/padding/align/fit/alpha/shown), roundedBox (box plus radius), text (box plus fontSize/lineHeight/singleLine/flags/color), texture (box plus color/desaturated), shape (box plus color, for composite glyph/check marks), and surface (only color/radius/alpha/shown, for existing Panels). Bare root defaults to box; Button/Navigation roots explicitly support roundedBox. A background or border is an existing surface/outline/border slot, never an automatically created decoration on a bare Frame. Schema metadata exposes slotKind; validation rejects unsupported imported properties before mutation, and binding checks the actual object at construction.

The r34 property set is `width,height,minWidth,maxWidth,minHeight,maxHeight,padding,align,fit,fontSize,lineHeight,singleLine,flags,color,alpha,radius,shown,desaturated`. Number dimensions accept token refs; font/line also accept the five text roles. Color is a token or 3/4-channel RGBA array. Native art/text/anchor properties are `texture,atlas,texCoord,blendMode,drawLayer,rotation,font,justifyH,justifyV,wordWrap,spacing,scale,frameStrata,frameLevel,points`; their availability follows the target kind. Points require native anchor methods. `shown` is local native visibility. States affect only supported properties on existing target slots; layout position stays owned by Row/Column.

Native component setters supply the normal business baseline. Fixed configured rules then apply their declared base and current states. State-only geometry can temporarily replace `Box(icon,20)` and return to the current business width on leave. Disabled clears hover/pressed contributions; re-enabling does not resurrect stale hover. Multiple sources OR their contributions, and source hide clears that source. Bind uses HookScript and preserves business scripts, tooltip hooks and click callbacks.

`Style` options `immediate=true` retain instantaneous feedback; optional `duration=numberOrToken` selects the period for the existing Color/Alpha transitions, with 0 immediate. These do not replace business animation hooks or add an animation driver.

`C.Style(host,options)` binds a construction declaration once. Repeating the same declaration is idempotent; a different declaration is rejected. `style` and `states` are fixed constructor data, not later patches. `SetState(name,bool)`, `SetStates(table)`, `SetVariant(nameOrNil)` and `Bind(source,{hover?,pressed?,focus?,checked?})` select existing rules or state sources. `SetStates` replaces the logical state set. `Apply(immediate?)` applies the current fixed state. `Release()` relinquishes the binding and restores its actually affected native values when still owned. It also removes every active state subscription. Each source/event retains one native dispatcher across controllers, contexts and embedded revisions; released controllers are not retained by that hook. Existing business scripts and foreign hooks remain installed. Active style subscribers run in binding order, and a subscriber added during delivery starts with the next event.

Effective configured base order is recipe, constructor style, then element/template/instance/classes. Configured states overlay in selected, checked, hover, pressed, focus, disabled order; disabled clears transient hover/pressed. An element is composed from template, ID, template instance and ID instance in that order. A direct element root wins its configured properties over a parent slot referring to the same native object; unrelated parent properties remain effective.

Consecutive state contributions from the same controller and source are applied together. Interleaved controllers keep their binding order. A dispatcher installed by an older embedded revision keeps its original application count and continues consuming compatible subscription entries.

Only actual affected properties retain a current business baseline and last applied value, for state exit, pooled key changes and ownership release. A business/native change observed at an explicit apply boundary becomes the next baseline. Releasing a lost Native lease never writes into the new owner. Texture/atlas/crop are captured together for correct art rebinding. Shared compiled rules cannot be changed by one instance. This is not a general undo engine or a history of previous Themes.

### Static rule metadata

`GetStyleField(path,recipeDefaults?)` and `GetStyleSchema(recipeDefaults?,paths?)` describe supported recipe leaves. `GetElementField(path,elementDefaults?)`, `GetElementSchema(elementDefaults,id?,paths?)` and `ListElementDefinitions(elementDefaults,scope?)` describe static IDs, slots and sparse editable leaves. Optional requested paths may expose inherited fields without expanding the stored directory. Metadata copies are independent from runtime declarations. ID dots are legal; `.base.`, `.states.`, `.variants.` delimit field paths.

## Elements, instances and named classes

```lua
local definitions={
    row={template=true,scope="list",slotKinds={root="box",label="text",icon="texture"}},
    detail={slotKinds={root="box"}},
}
local ctx=LycheeUI:CreateContext({
    elementDefaults=definitions,
    utilities={quiet={base={label={color="muted"}}}},
    elements={row={classes="quiet h-40",instances={
        [42]={base={root={height=70}}},
    },states={hover={label={color="good"}}}}},
})
ctx.C.Element(row,"row",{template="row",key=businessKey,scope="list",slots={root=row,label=row.title,icon=row.icon}})
-- After changing the data represented by the same pooled object:
ctx.C.RekeyElement(row,nextBusinessKey)
ctx.C.ApplyElement(row)
```

| API | Contract |
| --- | --- |
| `C.Element(target,id,options?)` | Registers a normal constructed object against a fixed definition. Options: `template,key,scope,slots,classes,variant,stateOwner,owner,rowTemplate,rowSlots,rowElementKey,rowElementState`. Missing slots create no decoration; repeating construction after adding a slot binds that actual new object. |
| `C.RekeyElement(target,key,template?)` | Rebinds a pooled object to the next business key/template, dropping previous key contributions. |
| `C.ReleaseElement(target)` | Removes its registration and affected fixed rules while respecting Native ownership. |
| `C.ApplyElement(target)` | Reapplies its current fixed rules at a genuine business/layout endpoint. |
| `C.SetElementState(target,name,value)` | Selects an existing fixed state. |
| `C.ElementValue(target,slot,property,fallback)` | Returns the current fixed override, including variant/state; otherwise the caller's fresh fallback. |
| `ctx:ResolveElementValue(id,slot,property,fallback,key?,variant?)` | Resolves static configured data before a native instance exists. `GetElementValue` accepts the same arguments and returns the same static value. |
| `ctx:ApplyElements(scope?)` | Reapplies registered active fixed rules at an explicit application layout boundary. |

All existing business keys remain legal; number `1` and string `"1"` are different keys. No temporary-ID syntax restriction is introduced. The library does not create native controls for every configured instance. Public live-object queries `GetElement`, `GetElementInfo`, and `ListElements` are removed. Only IDs used by cross-element anchors receive a private target lookup index.

Static `points` rules support native target objects, `$root`, `$parent`, `$slot`, `@elementId` and `@elementId#slot` references. Late targets reconnect on normal registration. A Row/Column owns its child anchors, so fixed point rules do not compete with layout placement.

Named utilities are startup data referenced by `classes` on element definitions, instance declarations or construction registration. Inputs are class strings or string arrays. Named definitions may contain plain root properties or structured slots/states/variants. Built-ins include `w-N`, `h-N`, `size-N`, `p-N`, `text-<role/color>`, `bg-<surface>`, `alpha-N`, `single-line`, `wrap`, `hidden`, and `shown`; state prefixes such as `hover:text-good` use the normal state order. Equal rule combinations reuse immutable compiled results. There is no public class replacement API after construction.

List row root height/minHeight/maxHeight may be configured at template, variant, instance or state scope. The same numeric prefix offsets govern placement, range, clipping, hit rectangles and selection location. Offscreen instance heights participate without a live row. Zero-height instances collapse; short rows extend only visible capacity and overscan. `SetRowHeight`, `SetRowHeightResolver`, and normal selection/hover remain live business controls.

### Instance storage and deferred surfaces

Plain Text retains its base font/line references. Its startup color and width are applied directly, without retaining a separate defaults declaration. It has no full style state or interaction controller. Base-only configured text installs no source/event structures. Capability-only catalog entries retain their identity for menus, anchors and normal rekeying, while sharing the empty effective rule and skipping rule compilation and inactive application bookkeeping. Interaction hooks are installed only for states used by fixed rules and reused during normal rebinds.

Nonempty compiled rule sets are shared by recipe/variant/element/class combinations. An instance holds its native targets, current logical state and values needed for normal state/key transitions. No all-target style snapshot, temporary hot-write layer, old Theme cache or public live-query directory is retained.

Public `C.Panel` eagerly provides seven native Textures. Hidden Button/list-row/field-focus surfaces defer those seven Textures until first show or explicit `.regions` read; their Panel identity, current color/alpha/radius, draw layers and resizing behavior remain supported. Created Textures are reused through later hide/show cycles. One parent resize dispatcher supports panels from different contexts.

## Verification boundary

`lua tests/run.lua` covers normal components, motion, native ownership, schemas, fixed declarations, rekeying, anchors and active-state font scaling. `lua tests/list_geometry.lua`, `lua tests/elements_ownership.lua`, `lua tests/native_reacquire.lua`, and `lua tests/setpoint-cost.lua` cover the focused lifecycle/geometry contracts. Old hot-theme transaction and hot-overlay cost tests were removed because those APIs no longer exist. Offline substitute allocations are not a Retail natural-memory peak; the consuming application must measure its complete runtime and visual baseline in the client.
