import flixel.FlxG;
import flixel.util.FlxSave;

class MobileControlSettingsTest
{
	static function main():Void
	{
		var save = new RecordingMobileSave();
		@:privateAccess FlxG.save = save;
		check(MobileControlSettings.useHitbox() && MobileControlSettings.hitboxesVisible(), "Fresh defaults");
		MobileControlSettings.toggleMode();
		MobileControlSettings.toggleVisibility();
		check(!MobileControlSettings.useHitbox() && !MobileControlSettings.hitboxesVisible(), "Toggles did not update reads");
		check(save.flushes == 2, "Each toggle must flush the save");
		// Simulate reopening the settings screen over the saved fields.
		var saved:Dynamic = {mobileHitbox: save.data.mobileHitbox, mobileHitboxVisible: save.data.mobileHitboxVisible};
		@:privateAccess save.data = saved;
		check(!MobileControlSettings.useHitbox() && !MobileControlSettings.hitboxesVisible(), "Saved false values lost to defaults");
		MobileControlSettings.toggleMode();
		MobileControlSettings.toggleVisibility();
		check(MobileControlSettings.useHitbox() && MobileControlSettings.hitboxesVisible() && save.flushes == 4, "Toggle back");
		Sys.println("PASS: settings defaults, immediate updates, save flushes and saved false values");
	}

	static function check(value:Bool, message:String):Void
	{
		if (!value)
			throw message;
	}
}

private class RecordingMobileSave extends FlxSave
{
	public var flushes:Int = 0;

	public function new()
	{
		super();
		data = {};
	}

	public override function flush(MinFileSize:Int = 0, ?OnComplete:Bool->Void):Bool
	{
		flushes++;
		return true;
	}
}
