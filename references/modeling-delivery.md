# 结构建模与交付

以下中文路径和 API 名称源于 2020 案例。其他年份须先按 version-compatibility.md 选择对应 API，模板与族库以目标机器为准。

## 模型

先按平面整理轴距、梁墙端点、板边界、洞口，再用立面校核标高。“十层”及“11F”可能分别描述十层加地下室和屋面标高，按标高序列判断。未定位构件沿轴对称等规则只在题面适用时使用。

结构模板优于空白公制项目，后者可能没有 WallFoundationType。中文内容候选根 C:\ProgramData\Autodesk\RVT 2020；先查 Templates、Family Templates 和 Libraries。历史结构模板在 Templates\China\Structural Analysis-DefaultCHSCHS.rte。

- 柱梁常用 b/h；矩形基础常用“长度”“宽度”“基础厚度”。实际读取参数及单位/只读状态，设置后复核。LoadFamily 返回 false 也可能是族已存在，先查询。
- 柱墙按楼层分段，明确底顶约束及偏移。基础放置后检查实际 BoundingBox 顶底，不按插入点推断。
- 墙板由有效系统类型复制，读取 CompoundStructure 后 SetLayers 并设置 StructuralMaterialIndex。直接 CreateSimpleCompoundStructure 曾出现 EndCap 不兼容。
- 条基承重与挡土类型宽度参数不同，要验证实际总宽及趾踵，不能只看类型名称。
- 检查实例 STRUCTURAL_MATERIAL_PARAM、类型材质、墙板层及 GetMaterialIds(false)，名称含 C30 不证明实际几何材料正确。
- 类型标记用简短 KZ/KL/L/Q/LB/DJ/TJ；完整截面材料放类型参数或注释，实例 Mark 唯一以防重复警告。

## 连接和工程量

包围盒重叠或实体接触不代表有相交体积。只连接实际相交实体。对“连接但不相交”定位图元后取消无效连接，梁端自动连接可能需 StructuralFramingUtils.DisallowJoinAtEnd 后再清理。不得吞掉所有警告或删有效构件追求零警告。

连接优先级会改变分项体积。最终修复后 Regenerate，重新统计原生类别、类型、实际材料、数量和 HOST_VOLUME_COMPUTED 等体积字段。单位立方米，建议精度 0.001，设置分组及总计。ELEM_TYPE 是 ElementId，不能用字符串 BeginsWith；可用隐藏 ALL_MODEL_TYPE_MARK 字符串字段按 DJ/TJ 筛选。CSV 用 UTF-8 BOM，明细表同时可导出文本。

## 视图与出图

- 轴网竖向范围覆盖全部层，按视图调整二维范围和气泡。基础平面切面在基础顶以下可能看不到柱墙，按实际目标调整视图范围。
- 尺寸优先引用真实轴网/标高/构件；辅助详图线尺寸不能称全部关联。
- ViewSection.CreateSection 生成的仍是剖面类别，即使表达立面。需要真正立面时用对应 API。创建后用视图实际 Origin/RightDirection 定位，不假定和输入 Transform 一致。
- 检查标高线二维范围、气泡及注释裁剪。标签宜显示短类型标记；修改标签边框前先确认具体曲线，不能删除任意族全部曲线。EditFamily 在项目事务外执行。
- 三维可用 ShadingWithEdges，隐藏分析类别和无关参照，按模型范围设视角。
- A0 图纸按比例和可读性决定页数。标题按实际视口框定位；参数写值要匹配整数/浮点类型。检查轴号、标签、明细表重叠。
- 从 Revit 用 ImageExportOptions 导出单视图及每张完整图纸，逐张查看。文件存在、代码编译和某一视图截图不能替代全面核验。

交付前检查本次时间/运行标识、关键几何、材质、分项和总体积、警告、平立面和所有图纸。附成果路径及未完成事项。
