package;

#if android
import haxe.CallStack;
import lime.graphics.opengl.GL;
import lime.system.JNI;
import openfl.Lib;
import openfl.events.UncaughtErrorEvent;

@:buildXml("<target id='haxe' if='HXCPP_ARM64'><flag value='-Wl,-z,max-page-size=16384'/><flag value='-Wl,-z,common-page-size=16384'/></target>")
#end
class AndroidStartup
{
	#if android
	static var markMethod:Dynamic;
	static var errorMethod:Dynamic;
	static var graphicsMethod:Dynamic;
	#end

	public static function initialize():Void
	{
		#if android
		try
		{
			markMethod = JNI.createStaticMethod("com/hexmod/weekend/StartupDiagnostics", "mark", "(Ljava/lang/String;)V", false, true);
			errorMethod = JNI.createStaticMethod("com/hexmod/weekend/StartupDiagnostics", "recordError", "(Ljava/lang/String;)V", false, true);
			graphicsMethod = JNI.createStaticMethod("com/hexmod/weekend/StartupDiagnostics", "recordGraphics", "(Ljava/lang/String;)V", false, true);
			Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, function(event:UncaughtErrorEvent)
			{
				// Preserve OpenFL's normal error handling after saving the evidence.
				try
				{
					if (errorMethod != null)
						errorMethod(Std.string(event.error) + CallStack.toString(CallStack.exceptionStack()));
				}
				catch (_:Dynamic)
				{
				}
			});
			mark("Haxe: Main.main");
			if (graphicsMethod != null)
				graphicsMethod("GPU: " + GL.getString(GL.RENDERER) + "\nOpenGL: " + GL.getString(GL.VERSION) + "\nTextura máxima: "
					+ GL.getParameter(GL.MAX_TEXTURE_SIZE));
		}
		catch (_:Dynamic)
		{
		}
		#end
	}

	public static function mark(stage:String):Void
	{
		#if android
		try
		{
			if (markMethod != null)
				markMethod(stage);
		}
		catch (_:Dynamic)
		{
		}
		#end
	}
}
