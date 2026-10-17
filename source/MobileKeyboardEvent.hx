package;

import openfl.events.KeyboardEvent;

/** Native Flixel treats charCode=0 plus letter keycodes as legacy function keys. */
class MobileKeyboardEvent
{
	public static function create(code:Int, down:Bool):KeyboardEvent
	{
		// Preserve printable letter/digit identity for polling, as well as raw note handlers.
		var character = code >= 48 && code <= 90 ? code : 0;
		return new KeyboardEvent(down ? KeyboardEvent.KEY_DOWN : KeyboardEvent.KEY_UP, true, false, character, code);
	}
}
