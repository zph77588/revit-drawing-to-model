using System;
using System.IO;
using System.Reflection;
using Autodesk.Revit.UI;
using Autodesk.Revit.UI.Events;

public class RevitTaskBridge : IExternalApplication
{
    // Replace in a task-local copy before compiling.
    private const string Root = @"__TASK_ROOT__";
    private bool busy;
    public Result OnStartup(UIControlledApplication app)
    { app.Idling += Tick; return Result.Succeeded; }
    public Result OnShutdown(UIControlledApplication app)
    { app.Idling -= Tick; return Result.Succeeded; }
    private void Log(string message)
    {
        File.AppendAllText(Path.Combine(Root, "bridge.log"),
            DateTime.Now.ToString("o") + " " + message + Environment.NewLine);
    }
    private void Tick(object sender, IdlingEventArgs args)
    {
        if (busy || !Path.IsPathRooted(Root) || !Directory.Exists(Root)) return;
        string request = Path.Combine(Root, "request.txt");
        if (!File.Exists(request)) return;
        busy = true;
        try
        {
            string command = File.ReadAllText(request).Trim();
            File.Delete(request); // Consume first; never automatically retry failures.
            if (command != "Build" && command != "Resume" &&
                command != "Verify" && command != "Export")
                throw new InvalidOperationException("Unsupported request: " + command);
            UIApplication app = sender as UIApplication;
            if (app == null) throw new InvalidOperationException("No UIApplication context");
            Log("START " + command);
            Assembly worker = Assembly.Load(File.ReadAllBytes(Path.Combine(Root, "Worker.dll")));
            Type type = worker.GetType("RevitTaskWorker", true);
            MethodInfo method = type.GetMethod(command, BindingFlags.Public | BindingFlags.Static,
                null, new Type[] { typeof(UIApplication) }, null);
            if (method == null || method.ReturnType != typeof(void))
                throw new MissingMethodException("Expected public static void " + command + "(UIApplication)");
            method.Invoke(null, new object[] { app });
            Log("SUCCESS " + command);
        }
        catch (Exception ex)
        { try { Log("ERROR " + ex.ToString()); } catch { } }
        finally { busy = false; }
    }
}
