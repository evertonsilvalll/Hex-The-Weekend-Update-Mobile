import flixel.FlxG;
import flixel.FlxGame;
import flixel.input.keyboard.FlxKey;
import flixel.input.keyboard.FlxKeyboard;
import flixel.system.frontEnds.SoundFrontEnd;
import openfl.Lib;
import openfl.display.Stage;
import openfl.events.KeyboardEvent;

/** Uses Flixel's real native correction table and the game's real Controls bindings. */
class MobileKeyboardEventTest
{
	static function main():Void
	{
		// Only the event surface is headless; the keyboard constructor and input state are real.
		@:privateAccess Lib.current.stage = Type.createEmptyInstance(Stage);
		@:privateAccess FlxG.sound = Type.createEmptyInstance(SoundFrontEnd);
		@:privateAccess FlxG.game = Type.createEmptyInstance(FlxGame);
		@:privateAccess FlxG.game.ticks = 1;
		var keyboard = new FlxKeyboard();
		@:privateAccess FlxG.keys = keyboard;
		@:privateAccess FlxG.save.data = {};
		var controls = new Controls("touch-regression");
		var oldEvent = new KeyboardEvent(KeyboardEvent.KEY_DOWN, true, false, 0, FlxKey.A);
		@:privateAccess keyboard.onKeyDown(oldEvent);
		check(oldEvent.keyCode == FlxKey.A && !controls.LEFT && keyboard.pressed.END, "Old raw A event must reproduce head-hit/held-note mismatch");
		@:privateAccess keyboard.reset();
		for (bindings in [["A", "S", "W", "D"], ["D", "F", "J", "K"], ["Q", "E", "R", "T"]])
		{
			FlxG.save.data.leftBind = bindings[0];
			FlxG.save.data.downBind = bindings[1];
			FlxG.save.data.upBind = bindings[2];
			FlxG.save.data.rightBind = bindings[3];
			controls.loadKeyBinds();
			for (lane in 0...4)
			{
				var code = FlxKey.fromString(bindings[lane]);
				var down = MobileKeyboardEvent.create(code, true);
				check(down.keyCode == code, "Raw note handler key changed");
				@:privateAccess keyboard.onKeyDown(down);
				for (frame in 0...120)
				{
					@:privateAccess FlxG.game.ticks++;
					var held = [controls.LEFT, controls.DOWN, controls.UP, controls.RIGHT];
					for (other in 0...4)
						check(held[other] == (other == lane), 'Hold mismatch ${bindings[lane]} at frame $frame');
					@:privateAccess keyboard.update();
				}
				var up = MobileKeyboardEvent.create(code, false);
				check(up.keyCode == code, "Raw release key changed");
				@:privateAccess keyboard.onKeyUp(up);
				@:privateAccess FlxG.game.ticks++;
				check(!controls.LEFT && !controls.DOWN && !controls.UP && !controls.RIGHT, "Stuck hold after release");
				@:privateAccess keyboard.update();
			}
		}
		// Menu, dialogue and pause keys must retain their native identities too.
		for (code in [13, 27, 32, 37, 38, 39, 40, 48, 57, 80])
		{
			var event = MobileKeyboardEvent.create(code, true);
			@:privateAccess var resolved = keyboard.resolveKeyCode(event);
			check(resolved == code && event.keyCode == code, 'Changed special/digit key $code');
		}
		controls.destroy();
		keyboard.destroy();
		Sys.println("PASS: real native old-event failure reproduced; WASD/DFJK/custom holds survive 120 updates and release; menu/digit/pause identities preserved");
	}

	static function check(value:Bool, message:String):Void
	{
		if (!value)
			throw message;
	}
}
