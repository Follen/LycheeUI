# LycheeUI 视觉与交互规范

本文定义 LycheeUI 公共组件的颜色角色、排版和交互表现。组件签名、参数、返回对象和生命周期见 [API.md](API.md)；嵌入方式见 [README.md](README.md)。消费插件可以组合组件和覆盖主题，但应让产品规则留在产品层，并为自定义尺寸同步调整文字、背景和命中区。

本规范对应 LycheeUI V1.0.0。元素与命名 utility 只改变已明确配置的原生对象或组合槽。没有覆盖时，默认布局、文字、图标素材和状态反馈继续采用本规范。每个产品公开稳定的元素 ID、模板与业务 key；重复行只给实际池对象登记身份，不为完整业务数据创建界面节点。尺寸覆盖先参与文字测量和所属布局，再绘制已有对象；不能仅拉宽外框而沿用旧内容宽度。

元素配置可覆盖尺寸、表面、字体、材质、锚点和状态；属性能力取决于已存在的槽对象。不会为缺失的图标、背景或边框自动增建装饰。图标的业务含义、职业色、职责素材和原生输入所有权仍由消费插件明确传入。使用 `elementIcon` 暴露纯展示 glyph 可避免把它接入 Button 原有的 `.icon` 选择着色行为。固定规则示例、优先级、测量读取、业务重绑和租约边界见 [API 的元素与命名类合同](API.md#elements-instances-and-named-classes)。

同一对象可以同时保留通用行 ID 和当前业务模板，覆盖按模板、ID、模板业务 key、ID 业务 key 的顺序合并。父元素槽和子元素根指向同一原生对象时，子元素根提供的属性优先，父槽的其他属性继续生效；测量和绘制采用相同结果，不依赖登记或遍历顺序。

Theme、recipe、元素和命名类在启动时固定；导入或切换主题在 /reload 后生效。会话内保留窗口与列宽拖动、界面缩放、字体大小调整和正常交互。字体变化重算现有文字、所属布局与打开菜单；产品负责显式重排专属页面，不通过通用外观刷新回调传播。

声明式排版复用当前原生对象，不因使用 Box、条件类或增强 Row/Column 自动增加表面、边框、阴影或代理 Frame。容器条件只改变预先声明的属性；条件退出后恢复当前剩余规则。普通状态顺序保持不变，文字换行与控件换行分别声明。排版只处理自己持有的宽、高与锚点，原生文字、输入光标和选择内容不因容器宽度变化被重建。

内容布局使用分配后的宽度测量文字，再共同提交几何。相邻项和表格使用累计边界取整，保留明确的最小尺寸，空间不足时报告溢出。变高文字列表沿用同一几何处理显示、裁切、命中和定位；重排保留首个可见条目及其项内位置。具体字段、所有权与延后完成规则见 [API](API.md#container-conditions-and-the-context-scheduler)。

## 1. 颜色体系

主题的五种常态中性色底构成表面层级。派生 hover／pressed 色是短暂交互反馈，不是新增常态底色。

| Token | 默认色 | 用途 |
| --- | --- | --- |
| `surface` | `#181818` | 最深容器、背景 |
| `surfaceLow` | `#242424` | 普通卡片、低层字段 |
| `surfaceContainer` | `#2C2C2C` | 嵌套卡片、分段容器 |
| `surfaceHigh` | `#343434` | 输入字段、raised 控件、Tooltip、Modal |
| `secondaryContainer` | `#444444` | 已选择项、tonal 操作 |

白色文字角色为 `text #F0F0F0`、`muted #C4C4C4`、`dim #A6A6A6`；品牌提示为 `brand #E87983`。主要动作使用 `primary #C84353`，hover `primaryHover` 由 primary 叠加 rowHover 白层，pressed `primaryPressed` 由 primary 叠加 pressed 黑层，其前景为 `onPrimary #FFFFFF`。正向、警告、链接蓝色分别为 `good #A8D5BA`、`warning #E6C48B`、`blue #AAC7FF`，只在确有对应语义时使用。

通用白色交互层按 alpha 叠加：行 hover `rowHover` 为 13/255，pressed 为 20/255，交替行 `rowAlternate` 为 3/255。`surfaceHighest`、`surfaceLowHover`、`surfaceLowPressed`、`refreshHover`、`secondaryPressed` 是由所属底色与交互层合成的结果；它们用于交互状态，不能用作额外常态面板底色。`selectHover`／`selectPressed` 是 Choice 浅底上的黑色状态层。深底字段与菜单由 `Choice:SetSurfaceVariant("dark")` 采用白色反馈。

`C.Surface(parent,{variant="floating"})` 专用于透明游戏场景：常态 `floatingSurface` 为黑色 alpha .60，hover `floatingHover` 的 RGB 为 rowHover 白层叠加结果（默认约 .051），alpha 为 baseAlpha+(1-baseAlpha)×actionHoverAlpha（默认 .656），默认圆角16。正向动作取 good 的 RGB，负向动作取 primary 的 RGB，hover／pressed 分别取 actionHoverAlpha=.14／actionPressedAlpha=.22；显式颜色覆盖优先。只在材质底面使用这些透明度，不能降低整个 Frame 的 alpha 来代替，否则文字也会变淡。透明背景需结合明亮游戏画面检查文字清晰度。

颜色目录按 palette／text／semantic／state 分组；GetColorSchema 标明别名来源和派生来源，GetTypographySchema 返回五套文字规范，详见 [API](API.md#five-text-roles-and-compatibility-aliases)。Theme 覆盖应替换颜色 token 数组，不原地修改共享数组。`ResolveTheme(overrides)` 会根据覆盖的底色及状态层重新计算派生值，并更新默认别名；显式传入的 token 优先。应用需要改变派生反馈时，应同时覆盖派生 token 或其来源。

### 常用尺寸 token

| 分组 | Token 与默认值 |
| --- | --- |
| 间距 | `gap=16` |
| 导航 | `railIconSize=24`、`selectionMarkHeight=18` |
| 控件 | `buttonHeight=40`、`buttonRadius=20`、`fieldHeight=44`、`fieldRadius=4`、`panelRadius=24`、`windowRadius=28` |
| 弹层 | `menuRadius=12`、`tooltipRadius=16`、`floatingRadius=16` |
| 选项 | `segmentHeight=36`、`segmentItemHeight=30`、`compactHeight=30`、`compactRadius=8`、`compactSize=14`、`compactLineHeight=20` |
| 开关与列表 | `switchWidth=44`、`switchHeight=26`、`scrollWidth=6`、`scrollGap=12` |
| 图像 | `iconCrop=.06`、`iconRadius=.22` |
| 文字 | `bodySize=14`、`metaSize=14`、`titleSize=24`、`headingSize=18`、`listTitleSize=18`、`listTitleLineHeight=24`、`listMetaSize=14`、`listMetaLineHeight=20` |

窗口尺寸、页头与侧栏构成、页面留白、产品导航字号和品牌图形尺寸由消费插件的 `themeDefaults` 声明。共享库只按普通 token 解析，不提供具体产品的窗口布局。

`bg`, `panel`, `field`, `fieldFocus`, `raised`, `hover`, `surfaceHover`, `accent`, `selected`, `border`, `focusBorder`, `notice`, `noticeText`, and `selectBackground` are aliases for the named surface, status, and text roles. Prefer the explicit token names in new themes.

## 2. 字体与排版

默认字体为 WoW 的 `STANDARD_TEXT_FONT`，不加描边和阴影。字号要服务于信息层级：

| 角色 | 默认字号／行盒 | 用途 |
| --- | --- | --- |
| caption | 12／16 | 短辅助信息、Tooltip |
| label | 14／20 | 按钮、输入、紧凑选项、列表次信息 |
| body | 16／22 | 连续阅读正文、导航、菜单 |
| title | 18／24 | 列表主项、区块标题 |
| heading | 24／32 | 页面或弹窗主标题 |

`listTitleSize/LineHeight` 与 `listMetaSize/LineHeight` 是列表语义 token，默认18/24与14/20。默认列表高64，主行顶距8、次行底距8、行间4。更矮的列表须显式改为单行或自行安排次行，不能让文字溢出背景。列数据通常14/20右对齐；表头和数据共享同一边界。长内容选择自然折行或明确截断，重要身份须有完整查看路径。

上下文可通过 `theme.fontSizeDelta`、`theme.lineHeightDelta` 分别增加字号和显式行高，默认均为 0。所有组件 API 接收基准值；用 `C.SetFont(region, 基准字号)` 替代直接设置字号，再设置基准行高。偏移只作用于该上下文，不缩放控件、图标或其他上下文；使用方需按实际文字高度调整留白。

`Text` 默认自动高度；用 `SetLineHeight` 设置固定行盒前，先完成字体和字号设置，更换字体或字号后重设。`singleLine=true` 固定高度并垂直居中，多行文本则保留自然增高。

## 3. 几何与表面

以4为间距主步进：4、8、12、16、20、24、32。正文面板通常内距24；紧凑条目左右12、上下至少8；组间距16或24。Panel 半径默认24，Modal 28，Menu 12，Tooltip 16。半径不得超过内缩后区域短边的一半。

| 区域 | 默认几何 |
| --- | --- |
| Button | 高40、圆角20；Primary、Tonal、Text、Compact 由 variant 定义外观 |
| Choice | 高44、圆角4；左内距14，右侧保留箭头及空间 |
| Field | 高44、圆角4；Search 圆角24；聚焦使用单像素品牌内线 |
| Switch | 轨道44×26，关闭滑块16、开启20；控件高40 |
| Checkbox | 命中区32、方框18、圆角5 |
| Segmented | 容器高36；选项高30、内缩3、间距4、圆角8 |
| Navigation | 高48；默认圆角24，紧凑场景可改圆角8；选中标记3×18 |
| Slider | 外框高40、命中区24；轨道4、滑块8×12 |
| List 滚动槽 | 6px滑块与12px间距；无滚动条时 gutter 可为0 |
| Modal | 默认480×300；标题左上24，内容左右／底24、顶部80 |
| Notice | 最小高40；文字左距12，关闭区24×24、右距8 |

普通 Panel 使用连续圆角填充；Shadow 只用于窗口、浮层、Modal 等需要层级的表面，不给每一行或透明卡片添加投影。Hover、pressed 和选中底与控件边界、圆角保持一致。原生白色图像纹理使用同一顶点着色流程，避免圆角和中心接缝颜色不一致。

## 4. 控件状态

### Button 与选择

| Variant／组件 | 常态与反馈 |
| --- | --- |
| `ghost`（默认） | 透明常态；hover／pressed 显示所属背景内的白色状态层 |
| `primary` | 品牌实心；hover／pressed 使用对应品牌状态色，白色前景 |
| `tonal` | `secondaryContainer` 常态，使用派生的浅色 hover／pressed |
| `compact` | 圆角8、高30、14／20标签；以短标签选项为主 |
| `text` | 表面始终透明；muted 常态、品牌色 hover／pressed，active/selected 也保持品牌色 |
| `Choice` | 浅面用 select 背景及黑色状态层；深面使用 `surfaceLow` 与白色状态层。展开时显示聚焦内线，菜单选中单独显示 |
| `IconButton` | 按钮状态仍由 Button variant 控制；Glyph 或 Texture 图标不改变命中区，图标维持自身颜色和 alpha，不随按钮 active 状态灰化 |
| `Segmented` | 单一范围内少数互斥选项；完整 tonal 选中底在固定按钮下方连续移动，hover 不代替选择 |
| `Navigation` | 胶囊底和左侧固定选中标记；hover 不移动选中项 |

禁用按钮整体 alpha .38 并停止提交动作。点击不以位移表达；按下后离开或隐藏时清除按压。图标按钮命中区建议32或更大，图形大小按动作语义决定。普通背景或文字只在它们确实可拖动时加入 `Draggable` 命中区域；输入和子按钮保留各自输入。

### Form controls

- `Check` 是 Switch 开关，点击切换值并运行180ms位置过渡；hover/pressed只在轨道上反馈，不给标签整块底色。禁用时不可点击。
- `Checkbox` 是方形复选框，选中显示 CheckMark，hover 改变局部方框底色。命中区、方框、圆角可按 options 调整。
- `Slider` 使用红色已选轨、灰色余轨和原生拖动。默认 native slider 在值变化时调用 `onChange`。`commitOnRelease` 模式拖动时调用 `onPreview`，松开时提交一次 `onChange`；取消／隐藏时恢复拖动前的值。
- `Field` 只提供外壳。普通 `Edit` 默认不自动聚焦；焦点只由真实输入状态驱动。多行 Edit 保留原生文字、滚动和光标行为。`NativeInput` 用于必须保留原输入对象身份的场景。
- `Number` 只限制为数字输入，默认占位符为空；占位文案、留空含义与数值范围由消费插件确定。
- `Notice` 用于就地反馈，文字14/20、左对齐并折行；调用方预留提示布局空间，不覆盖末行或动作按钮。

输入错误、申请状态或成功反馈必须来自实际业务结果；库不推断业务状态，也不自动显示错误或成功。

## 5. 列表、图像与弹层

### List

List 使用可见行池加两行余量。默认双行64高：主项18/24，次级14/20；滚动条为荔枝红6px thumb + 12px gutter。选中填充为 `secondaryContainer`，hover／pressed 为轻量状态层，交替行 alpha 3/255。可通过 `SetStyle` 关闭任意背景/标记，同时保留文字状态和行回调。部分可见行会裁切命中区；换绑后旧按压不得提交到新项目。

可调整大小的页面应先设置列表宽度，再更新视口；自定义行通过 `SetRowInitializer` 统一创建，新增行与原行保持相同样式和交互。列表按实际可见需求增加行池，缩小后复用已有对象；页面负责重新定位自定义列，表头与数据继续共享边界。接口与扩容条件见 [API](API.md#lists-columns-and-numeric-controls)。

菜单和导航列表使用16/22，不继承大号内容标题。`C.Columns` 默认14/20右对齐。数据排序、补位和计数由消费插件组合。

`C.TableHeader` 统一管理可调整列宽的多列表头。常态不画分隔标记，鼠标进入表头后显示居中的 1 × 10px `dim` 短标记，不透明度 22%；10px 命中区覆盖边界两侧。分隔线自身悬停时宽度增至 2px、不透明度升至 70%，按住拖动时使用不透明 `accent`。拖动相邻列此增彼减，总宽不变；右键分隔线恢复当前表格的默认列宽，保留排序；列宽最小值兼顾调用方内容与当前字号下的完整标题。数字列点击切换升序／降序，当前排序列名用 `text` 提亮，不创建排序箭头，排序不改变标题可用宽度。单元格左右内距 6px，列名与行共用边界；标题、动作及复杂图标可由消费方另设内部留白。

### 图像

`Icon` 使用完整UV，显示消费插件明确提供的图片。`GameIcon` 使用圆角22%遮罩；`SetGameTexture` 和 `SetGameAtlas` 在真实子区域内裁边6%。`Glyph` 使用库内通用素材，并可按选择状态变灰：未选中alpha72%，hover90%，选中保持原色和alpha100%。普通动作图标不应误用选择状态。数据图像的解析、占位和语义由消费插件提供。

### Menu、Tooltip、Modal

| 控件 | 样式与操作 |
| --- | --- |
| Menu | `surfaceHigh` 底、圆角12、柔和阴影；项目高40、文字16/22，菜单内距4。最多显示10行，更多时可滚动；没有溢出时不保留隐藏滚动槽。Choice 菜单宽度优先匹配触发器，只有长内容才扩宽；可从指针右下弹出并按屏幕边缘调整。 |
| Tooltip | 默认宽300、`surfaceHigh` 底、圆角16、阴影；12/16文字，左右16，首行上距16，行距4、末尾12；跟随 owner，离开时清理。持续阅读的说明使用正文大小。 |
| Modal | 默认480×300、`surfaceHigh`、圆角28；标题24/32，关闭按钮40；48%黑色遮罩只覆盖构造时传入的 `parent`。关闭按钮和遮罩调用同一关闭动作。 |
| Notice | `primaryContainer` 底，圆角12；文字14/20；关闭动作局部布局。 |

Tooltip 应表达短暂的次要信息。需要稳定互动、名单或按钮的内容由消费插件组合独立面板，并提供明确的进入和离开路径；库不提供业务富提示。

## 6. 动效

`Selection` 让单一背景在160ms内移动并匹配目标尺寸，首次选择约140ms淡入；Segmented 默认使用，导航 List 可通过 `selectionMotion=true` 启用。背景位于容器底面之上，文字和命中区保持原位。菜单完成布局后从终点上方8单位处滑入并淡入，160ms。快速反向从当前姿态继续，同目标刷新不重播；隐藏列表直接应用最终选择状态。

状态动画应反馈而不延迟操作。Hover、pressed 和 Tooltip 淡入通常约100–120ms；选择标记约100ms；Switch 位置180ms；List滚动140ms。页面局部进入可采用约170–180ms、轻微位移；窗口 Presence 默认为420ms，从终点下方64进入，透明度前100ms渐入。刷新 Spin 默认每圈900ms。品牌图形、轨迹、枢轴和播放规则由消费插件持有，可通过通用 Motion 任务驱动。

隐藏、关闭、任务结束或减少动态效果时，应停止相应动画并稳定到终态。`Waiting` 从启用时捕获的尺寸、alpha 和首个锚点计算波形；停用或停止任务会恢复这组几何与透明度。`Busy` 保存启用前的 alpha，停止后还原。窗口 Presence 只改位置和 alpha，不负责调用 Frame 的 `Show`／`Hide`；由消费插件在正确时点控制可见性。窗口退出动画期间可保留完整视觉，但输入应立即停止；动画完成后由消费插件调用 `ctx:Hide()` 清理上下文任务、菜单、焦点和原生控件租借。所有动效只表达UI变化，不代表搜索、申请或网络任务已经完成。

自定义任务通过 `Start(key, job, onStop?)` 登记结束清理；自然完成、停止、替换及 StopAll 都恰好清理一次。StopAll 先移除本批旧任务并完成内置视觉终态，再执行清理，允许回调启动新任务；某个清理报错时，其余清理仍会完成。具体合同见 [Motion API](API.md#motion)。

## 7. 组件选型

优先使用现有组件和 variant，再用 `SetStyle` 或局部 token 覆盖适配布局。典型组合：SearchField = Search Field + 真实输入 + 搜索 Glyph + 必要的模式/清空按钮；图标动作 = IconButton + 真实 Glyph/Texture；设置行 = 标签、说明和独立控件；交互浮层 = Surface + Button/List，并由应用管理其业务生命周期。

避免用 hover 假装持久选择、用父级透明度淡化文字、把内容标题字号带入菜单、关闭整行状态以掩盖背景与文字错位、将借用原生输入替换成普通输入，或将未发生的动作展示为成功。自定义控件仍应保持明确命中区、状态颜色和文字可读性。


## 8. 启动主题与实时交互

Theme、recipe、elements、utilities 在 CreateContext 时解析为本会话的固定规则。库默认、产品默认、启动覆盖依次合并；颜色数组与规则按不可变引用使用。产品负责保存导入结果，并在 /reload 后构造新上下文。晚建页面、菜单与复用行继续使用同一个启动快照。

共享库取消通用热外观写入、任意实例补丁、历史图层恢复和全对象查询目录。普通文字只保留字号与行高引用；启动颜色与宽度直接应用，不保留另一份默认外观声明，也不分配完整样式管理表。相同规则组合复用编译结果；实例只保存目标引用、当前状态，以及离开状态或业务重绑所需的受影响属性值。不会保留历次 Theme 或全部属性的快照。

窗口拖动、列宽拖动、整体缩放、字号调整和 hover／pressed／selected／checked／focus／disabled 保持实时。SetFont 改变上下文的字体路径和比例，不改启动 Theme；活动状态中的字号和行高也从未缩放引用重新计算。状态退出恢复当前业务基准，不能恢复成过时的旧字号。正常业务更新使用原生与有限组件 setter，产品在真实布局终点显式应用已固定的元素规则。

文字使用 caption／label／body／title／heading 五套通用规范；组件专用 token 与产品启动默认仍可独立配置。字面 numeric 字号保留数值语义，不改写为近似角色。所有字体 API 统一应用上下文偏移和比例，不重复缩放。字体/行高须为正、尺寸/半径非负、alpha 为 0..1；偏移允许负值，默认虚拟行步长须为正。

Segmented 保留动态宽高、内缩、间距和现有选中动画。图片装饰由消费插件通过 Texture、Box、原生颜色/层次 setter 与显式遮罩组合；共享库不提供成员、职责、队伍或申请业务接口。

## 9. 原生组合与属性所有权

Box 描述既有对象的宽高、min/max、padding、align 与 content fit，不增建 Frame，不改变材质裁切、字体或产品装饰。显示框、命中区、字号各自独立，contain/cover 只调整已有 content 的尺寸和居中锚点；裁切由容器负责。

默认 Row/Column 处理 gap、四边 padding、align、justify、grow/shrink 与隐藏项。省略宽高时保留当前实测值；content 测自然内容，fill 分配预算。布局持有子对象锚点，状态不得竞争默认 LEFT。重复布局复用当前条目的记录与放置函数；完成重排后释放已移除条目的 Lua 记录和描述引用。未变的尺寸和锚点不写原生属性。字号变更重排已登记布局；业务文字、可见性或容器变化由产品调用 Layout。

显式增强模式在同一原生对象上支持约束再分配、控件换行和容器条件。跟踪布局随实际依赖变化更新；宽、高与锚点可以分别交给产品管理。文字变高列表只在完整高度索引提交后统一更新范围和行位置，保留可见首项及项内偏移，避免中间批次造成滚动跳动。

固定 recipe 用 base、variants、states、slots 表达。元素以模板、ID、模板实例、ID 实例的顺序合并，再按 selected、checked、hover、pressed、focus、disabled 叠加状态；disabled 清除临时 hover/pressed。父槽与子根指向同一原生对象时，子根的显式属性优先，父槽的无关属性继续生效。状态来源可以与目标分离，不覆盖 tooltip 或业务脚本。

仅真正受配置控制的字段保存当前业务值与最近应用值，用于状态退出、key 变更与租约归还。纹理、atlas 与 UV 作为一组恢复，避免图标数据重绑残留旧素材。原生租约持有完整必要的接入前快照；失去所有权后旧控制器不得回写新宿主。这里保留的是正常生命周期合同，不是通用历史撤销机制。

## 10. 固定元素与列表几何

元素引用既有槽，不扫描原生树、不为缺失槽增建装饰。合法实例 key 的表达能力保持不变，数字与字符串 key 不合并。库取消公开活对象 GetElement/GetElementInfo/ListElements；只为 @id 跨元素锚点保留所需内部索引。$root、$parent、$slot 与延迟登记的 @id#slot 继续可用。早期测量后才创建的槽，在正常构造完成的重复 Element 登记时接入。

模板、实例、variant、class 和状态的 root.height/minHeight/maxHeight 参与同一测量与绘制。无覆盖时保留固定步长；有覆盖时用数字前缀偏移统一总高、滚动、命中裁切和选择定位。离屏实例仅参与数字计算，不生成 Frame；零高折叠，短行只扩展当前视口及备用池。SetRowHeight 可一次更新步长、绘制高度和视口，SetRowHeightResolver 保留正常业务自适应高度。

文字测量每 label 保留当前文字一条、候选最多16条，字体或显式失效重用记录，不积累动态姓名历史。纯 base 文字不安装交互源；实际配置 hover/pressed/focus 时才绑定对应事件，正常重绑复用已有监听。

公共 C.Panel 直接提供七片原生材质。隐藏的按钮、列表与焦点表面保留完整 Panel 对象，首次显示或读取 regions 时才创建七片材质；此前设置的颜色、透明度、半径、层次与尺寸成为首帧外观。后续隐藏与显示始终复用原材质。父对象的尺寸分发支持不同上下文的 Panel 共用同一父对象。

共享离线测试覆盖固定规则、状态往返、实例重绑、锚点、字体缩放、原生归还与列表几何。它不能证明游戏内默认渲染一致或自然内存峰值；消费插件必须按其性能文档在游戏中验收。
