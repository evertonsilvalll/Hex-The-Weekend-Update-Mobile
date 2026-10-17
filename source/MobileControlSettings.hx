package;

import flixel.FlxG;

class MobileControlSettings
{
	public static function useHitbox():Bool
	{
		if (FlxG.save.data.mobileHitbox == null)
			FlxG.save.data.mobileHitbox = true;
		return FlxG.save.data.mobileHitbox;
	}

	public static function hitboxesVisible():Bool
	{
		if (FlxG.save.data.mobileHitboxVisible == null)
			FlxG.save.data.mobileHitboxVisible = true;
		return FlxG.save.data.mobileHitboxVisible;
	}

	public static function toggleMode():Void
	{
		FlxG.save.data.mobileHitbox = !useHitbox();
		FlxG.save.flush();
	}

	public static function toggleVisibility():Void
	{
		FlxG.save.data.mobileHitboxVisible = !hitboxesVisible();
		FlxG.save.flush();
	}
}
