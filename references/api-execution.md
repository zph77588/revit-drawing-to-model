# Revit API 执行与恢复

先执行 version-compatibility.md 的版本选择。下文旧 csc 命令仅为 Revit 2020 的已编译示例，不能直接用于现代 .NET 版本。目标 API、运行时、模板和插件年份必须一致。

## 环境与编译

先运行 scripts/inspect-revit.ps1，可传 -RevitDirectory 指定路径。历史安装目录为 D:\Program Files\Autodesk\Revit 2020，仅作候选。确认 Revit.exe，不能把 RevitAccelerator 当作主程序。

编译引用同版本安装目录的 RevitAPI.dll 和 RevitAPIUI.dll。系统编译器候选为 C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe，使用 PowerShell 调用运算符和参数数组传参，禁止拼接执行用户文字。

```powershell
$compiler = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
& $compiler /nologo /target:library "/out:$taskRoot\Bridge.dll" "/reference:$revitDir\RevitAPI.dll" "/reference:$revitDir\RevitAPIUI.dll" "$taskRoot\IdlingBridge.cs"
if ($LASTEXITCODE -ne 0) { throw 'Compile failed' }
```

$taskRoot 和 $revitDir 必须为已核实的绝对路径。Worker 同样编译为库。Revit 内部长度为英尺：毫米除以 304.8；2020 使用对应 UnitType/DisplayUnitType 接口，不能直接复制新版 ForgeTypeId 代码。

## 临时插件

文档修改必须在 Revit 主线程及 Transaction 内执行。外部进程只负责编译、准备文件及发请求。

1. 创建独立任务目录，复制 assets/IdlingBridge.cs，将 __TASK_ROOT__ 替换成任务绝对路径；C# verbatim 字符串中的双引号加倍。不同任务不共用目录。
2. 编写公开类 RevitTaskWorker，公开静态方法签名为 void Build(UIApplication app)；按需提供 Resume、Verify、Export。同名方法的事务、状态持久化和幂等由 Worker 实现，桥接器不是建模引擎。
3. 编译后在 %APPDATA%\Autodesk\Revit\Addins\<目标年份> 写唯一任务名 .addin。Assembly 为 Bridge.dll 绝对路径，FullClassName 为 RevitTaskBridge，AddInId 用新 GUID。XML 用序列化转义路径。记录准确清理路径。
4. 新 addin 不会自动加载进既有进程。先用已有通道；必须重启时检查未保存工作，不能强杀。会丢失工作时说明阻碍并等待用户处理。只处理自己生成插件的加载提示，不永久信任不相关插件。
5. Worker 与目标文档准备完毕后才发请求：同目录写临时命令文件，原子改名为 request.txt。只留一个待执行请求。允许 Build/Resume/Verify/Export，不能执行任意反射方法。
6. 读取 bridge.log 的 START/SUCCESS/ERROR 及 Worker 阶段日志。桥接 SUCCESS 只代表方法返回，仍需核验模型。热加载采用字节加载，更新 Worker 前等待当前命令结束。失败后先检查事务/文档状态，禁止自动盲重试 Build。
7. 完成或中止后清理本任务请求与 addin；当前进程仍可能加载桥接器，所以不能留待执行文件。保留源码及成果。

## 故障恢复

- OpenAndActivateDocument 后同一 Idling 内设 ActiveView 可能临时禁用。用 RequestViewChange，下次空闲再缩放。
- 对话框会阻塞 Idling。检查实际界面，不重复发请求；截图点击要考虑物理分辨率及缩放。
- 图纸事务失败时保留已提交模型，从相应阶段 Resume。重建上下文不能依赖已经被重命名的类型前缀。
- 插件调试使用授权的新工程或副本。保存检查点后再做视图、明细表和复杂连接。
