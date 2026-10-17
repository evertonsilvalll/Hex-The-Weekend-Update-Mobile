import flixel.FlxG;
import flixel.input.keyboard.FlxKey;
import flixel.system.frontEnds.SoundFrontEnd;

/** Exercises the same binding constructor used before KadeEngineData.initSave. */
class StartupBindingsTest
{
	static function main()
	{
		@:privateAccess FlxG.sound = Type.createEmptyInstance(SoundFrontEnd);
		check({}, FlxKey.PLUS, FlxKey.MINUS);
		// Old saves may contain the unused array fields but lack the binding strings.
		check({volumeUpKeys: ["PLUS"], volumeDownKeys: ["MINUS"]}, FlxKey.PLUS, FlxKey.MINUS);
		check({volUpBind: "ONE", volDownBind: "TWO"}, FlxKey.ONE, FlxKey.TWO);
		check({volUpBind: "THREE"}, FlxKey.THREE, FlxKey.MINUS);
		Sys.println("PASS: fresh, legacy, custom and partially initialized startup bindings");
	}

	static function check(data:Dynamic, up:FlxKey, down:FlxKey)
	{
		@:privateAccess FlxG.save.data = data;
		var controls = new Controls("startup-test");
		if (FlxG.sound.volumeUpKeys[0] != up || FlxG.sound.volumeDownKeys[0] != down)
			throw "Startup changed or failed to initialize the volume bindings";
		if (FlxG.sound.muteKeys[0] != FlxKey.ZERO)
			throw "Startup failed to initialize the mute binding";
		controls.destroy();
	}
}
