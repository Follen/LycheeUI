# LycheeUI

LycheeUI 是可嵌入魔兽世界插件的原生 UI 库，提供主题、控件、布局、菜单、动效和原生控件借用接口。组件使用 WoW 的 Frame、Button、Texture、FontString 和 EditBox；插件负责业务数据、页面组合、偏好存储与窗口入口。

当前发布为 **V1.0.0**，目标客户端为 **Retail 12.1.5（Interface 120105）**。源码仓库：[Follen/LycheeUI](https://github.com/Follen/LycheeUI)。固定版本入口为 [`v1.0.0`](https://github.com/Follen/LycheeUI/tree/v1.0.0)，运行文件与素材的冻结清单见 [.lock](.lock)。

## 现有能力

- **主题与文字**：启动时配置颜色、尺寸 token、组件配方和文字角色；支持 Context 字体与字号比例调整。
- **原生控件**：按钮、图标按钮、选择器、分段选项、导航、开关、输入框、数值控件、滑条、列表、表头及菜单。
- **布局**：基础 Row／Column、显式 flex、Box 组合、内容测量、百分比、增长与收缩、最小／最大尺寸、控件换行及逐字段几何管理。布局直接组合现有对象，不为 Texture 或 FontString 增加代理 Frame。
- **声明式样式**：元素、命名类、变体、交互状态、业务实例键和祖先容器条件；增强布局按实际依赖刷新，空闲或隐藏时停止更新任务。
- **列表复用**：可见行池、固定或可变行高；文字变高模式可显式开启，分批构建高度索引并保留滚动锚点。
- **动效与原生借用**：交互反馈、选择层和窗口动效，支持减少动态效果；借用已有原生控件时保留其身份，并在仍持有所有权时归还布局、脚本和文字样式。

库无需额外 UI 框架，不管理 SavedVariables，也不注册登录业务流程。动画和布局驱动按需运行，业务逻辑仍由消费插件维护。

## 嵌入插件

从同一个版本标签取得 `embeds.xml`、全部十个 Lua 文件及完整 `Media` 目录，放入消费插件：

```text
MyAddon/
├─ MyAddon.toc
├─ UI.lua
└─ Libs/
   └─ LycheeUI/
      ├─ embeds.xml
      ├─ Core.lua
      ├─ Theme.lua
      ├─ Motion.lua
      ├─ Styles.lua
      ├─ Components.lua
      ├─ Layouts.lua
      ├─ Responsive.lua
      ├─ Elements.lua
      ├─ Native.lua
      ├─ Menu.lua
      └─ Media/
```

消费插件的 TOC 先加载库入口，再加载使用库的文件：

```text
## Interface: 120105
## Title: MyAddon

Libs/LycheeUI/embeds.xml
UI.lua
```

`embeds.xml` 的加载顺序为：

```text
Core → Theme → Motion → Styles → Components
     → Layouts → Responsive → Elements → Native → Menu
```

保留这份完整清单及顺序，不按需拆开加载定义文件。产品包内嵌运行文件和素材即可；仓库中的 `LycheeUI.toc` 用于单独加载库进行开发，不需要一并嵌入消费插件。

`CreateContext` 的 `addon` 应传消费插件的目录名。默认素材路径为 `Interface\AddOns\<addon>\Libs\LycheeUI\Media\`。若目录结构不同，使用 `media` 传入完整素材路径并保留末尾的反斜杠。

## 最小示例

把以下内容保存为上述 `UI.lua`。它创建一个窗口、两个按钮和一个显式 flex 行；窗口与 Context 保存在插件命名空间中，后续打开时复用。

```lua
local addonName, ns = ...

local window = CreateFrame("Frame", nil, UIParent)
window:SetSize(360, 160)
window:SetPoint("CENTER")
window:SetFrameStrata("DIALOG")
window:EnableMouse(true)

local ctx = LycheeUI:CreateContext({
    parent = window,
    addon = addonName,
    reducedMotion = true,
})
local C = ctx.C
ctx:SetWindow(window)

C.Panel(window, "panel", 24)
local title = C.Text(window, "LycheeUI 示例", 18)
title:SetPoint("TOPLEFT", window, "TOPLEFT", 16, -16)

local body = CreateFrame("Frame", nil, window)
body:SetPoint("TOPLEFT", window, "TOPLEFT", 16, -56)
body:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -16, 16)

local confirm = C.Button(body, "确认", 112, function()
    print("LycheeUI：已确认")
end, { variant = "primary" })
local close = C.Button(body, "关闭", 96, function()
    window:Hide()
end)

local row = C.Row(body, {
    { frame = confirm, width = "fill", minWidth = 112, height = 40 },
    { frame = close, width = 96, height = 40 },
}, {
    mode = "flex",
    gap = 8,
    align = "center",
    track = true,
})

window:HookScript("OnHide", function()
    ctx:Hide()
end)

ns.LycheeDemo = { context = ctx, frame = window, layout = row }
function ns.LycheeDemo:Show()
    ctx:Resume()
    window:Show()
    row:Layout()
end
ns.LycheeDemo:Show()
```

工厂使用点号调用，例如 `C.Button(...)`；Context、控件和布局的方法使用冒号调用，例如 `ctx:Hide()`、`row:Layout()`。

`mode="flex"` 显式开启增强求解。示例的确认按钮占据剩余宽度，关闭按钮保持固定宽度；`track=true` 让父容器尺寸变化进入 Context 的按需布局队列。Row／Column 本身不改变父 Frame 的尺寸；需要内容尺寸驱动容器时，可使用 `C.Box(target, {layout="row", items=..., width="content", height="content"})`。

增强布局的条目或参数变化通过 `SetItems`、`SetOptions` 或 `Invalidate` 声明。控件换行使用 `flowWrap`，文字换行使用各自的文字样式。具体尺寸、约束和失效合同见 [API.md](API.md#enhanced-rowcolumn-mode)。

## 生命周期与对象复用

为一组共同管理的界面创建并保留一个 Context，重复打开时复用 Context 和原生对象。`ctx:Hide()` 会关闭菜单、归还其原生控件租约、清除输入焦点、停止动效并暂停布局任务；它不隐藏业务窗口，所以示例由窗口的 `OnHide` 调用它。重新打开前调用 `ctx:Resume()`。需要退出动画时，在动画完成后隐藏窗口并调用 `Hide()`。

布局、列表、元素和原生租约分别通过对应的释放接口结束使用。布局的 `Release()` 保留最终几何，只解除仍归自己管理的字段；原生租约的 `Release()` 按所有权恢复借用前的状态。释放旧控制器不会覆盖已交给新所有者的字段。具体接口见 [API.md](API.md)。

WoW 原生 Frame 按页面和行池复用；关闭窗口时不重新创建整套控件。列表换绑业务数据时同步更新实例键和状态，终止使用时释放绑定及引用业务数据的回调。Context 没有销毁全部原生对象的通用接口，原生对象的隐藏、数据解绑与复用由消费插件负责。

## 主题与交互

Theme、recipe、元素和命名类属于启动声明，构建后保持不变；主题导入、存储与选择由消费插件实现，切换启动主题后通过 `/reload` 生效。每个 Context 保留自己的主题结果与交互状态，默认颜色表按只读使用。

窗口和列宽拖动、容器尺寸、控件状态、内容更新及字体调整可在会话中变化。使用控件的公开 setter、`ctx:SetText` 和 `ctx:SetFont(path, scale)` 更新现有对象，并重排产品自己的页面。库只处理已登记的对象和槽，不扫描全局 Frame，也不为缺失槽自动增加装饰。

## 版本与冻结

- 对外发布版本为 **V1.0.0**，`LycheeUI.versionString` 为 `"1.0.0"`，对应 Git 标签为 `v1.0.0`。
- [.lock](.lock) 记录冻结状态、运行文件、素材和 SHA-256。嵌入时保持同一标签的文件完整，升级时整体替换；修改或同步库前先阅读冻结约定。
- 运行文本采用 LF，Git 属性见 [.gitattributes](.gitattributes)。替换内置文件后执行 `/reload`，让 Context 和控件按新定义重新建立。

## 文档

- [API.md](API.md)：公开方法、参数、声明式样式、布局、列表、原生租约与生命周期合同。
- [DESIGN.md](DESIGN.md)：颜色、文字角色、组件外观和交互规范。
- [CHANGELOG.md](CHANGELOG.md)：发布变更与维护记录。
- [.lock](.lock)：当前发布的冻结范围及运行文件校验清单。

## 核心验证

在库根目录使用 Lua 5.1 运行离线检查：

```sh
lua tests/run.lua
lua tests/flex_layouts.lua
lua tests/flex_recursive_prepare.lua
lua tests/responsive.lua
lua tests/fixed_context_values.lua
lua tests/flow_list.lua
lua tests/list_memory.lua
lua tests/native_reacquire.lua
```

这些检查使用本地原生对象替身，验证布局、状态、回调、复用和所有权逻辑。客户端渲染、字体与缩放、受保护操作及完整插件的性能和内存仍需在目标 Retail 客户端验证。
