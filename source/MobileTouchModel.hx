package;

/** Geometry and multitouch bookkeeping, independent of display visibility. */
class MobileTouchModel
{
	public var bounds:Array<TouchBounds> = [];
	public var gameplay(default, null):Bool = false;
	public var hitbox(default, null):Bool = true;

	var touches:Map<Int, Int> = new Map();
	var held:Map<Int, Int> = new Map();
	var pressedCodes:Map<Int, Int> = new Map();
	var keyHolds:Map<Int, Int> = new Map();
	var resolveCode:Int->Int;
	var sendKey:(Int, Bool) -> Void;
	var action:Int->Void;

	public function new(resolveCode:Int->Int, sendKey:(Int, Bool) -> Void, action:Int->Void)
	{
		this.resolveCode = resolveCode;
		this.sendKey = sendKey;
		this.action = action;
	}

	/** Coordinates use the game's fixed 1280x720 canvas. Null pads are inactive. */
	public function layout(gameplay:Bool, hitbox:Bool, cutscene:Bool = false):Void
	{
		releaseAll();
		this.gameplay = gameplay;
		this.hitbox = hitbox;
		bounds = [for (_ in 0...9) null];
		if (gameplay)
		{
			for (i in 0...4)
				bounds[i] = hitbox ? new TouchBounds(i * 320, 88, 320, 632) : new TouchBounds(160 + i * 248, 566, 216, 136);
			bounds[6] = new TouchBounds(1124, 12, 144, 64);
			if (hitbox)
				bounds[8] = new TouchBounds(968, 12, 144, 64);
		}
		else
		{
			// Psych-style directional cross, with confirm/back on the opposite side.
			bounds[0] = new TouchBounds(20, 474, 112, 112);
			bounds[1] = new TouchBounds(144, 598, 112, 112);
			bounds[2] = new TouchBounds(144, 350, 112, 112);
			bounds[3] = new TouchBounds(268, 474, 112, 112);
			bounds[4] = new TouchBounds(996, 584, 112, 112);
			bounds[5] = new TouchBounds(1144, 460, 112, 112);
			if (cutscene)
				bounds[7] = new TouchBounds(1124, 12, 144, 64);
		}
	}

	public function padAt(x:Float, y:Float):Int
	{
		for (i in 0...bounds.length)
			if (bounds[i] != null && bounds[i].contains(x, y))
				return i;
		return -1;
	}

	public function isHeld(pad:Int):Bool
	{
		return held.exists(pad);
	}

	public function begin(id:Int, x:Float, y:Float):Void
	{
		if (touches.exists(id))
			return;
		var pad = padAt(x, y);
		if (pad < 0)
			return;
		touches.set(id, pad);
		press(pad, true);
	}

	public function move(id:Int, x:Float, y:Float):Void
	{
		if (!touches.exists(id))
			return;
		var previous = touches.get(id);
		var next = padAt(x, y);
		if (next >= 4 && next != previous)
			next = -1;
		if (previous == next)
			return;
		release(previous);
		touches.set(id, next);
		// Sliding between notes works; sliding onto a toolbar action must not toggle it.
		press(next, false);
	}

	public function end(id:Int):Void
	{
		if (!touches.exists(id))
			return;
		release(touches.get(id));
		touches.remove(id);
	}

	function press(pad:Int, fresh:Bool):Void
	{
		if (pad < 0)
			return;
		if (pad == 8)
		{
			if (fresh)
				action(pad);
			return;
		}
		if (pad >= 4 && !fresh)
			return;
		var count = held.exists(pad) ? held.get(pad) : 0;
		held.set(pad, count + 1);
		if (count != 0)
			return;
		var code = resolveCode(pad);
		pressedCodes.set(pad, code);
		var keyCount = keyHolds.exists(code) ? keyHolds.get(code) : 0;
		keyHolds.set(code, keyCount + 1);
		if (keyCount == 0)
			sendKey(code, true);
	}

	function release(pad:Int):Void
	{
		if (pad < 0 || !held.exists(pad))
			return;
		var count = held.get(pad) - 1;
		if (count > 0)
		{
			held.set(pad, count);
			return;
		}
		held.remove(pad);
		var code = pressedCodes.get(pad);
		pressedCodes.remove(pad);
		var keyCount = keyHolds.get(code) - 1;
		if (keyCount > 0)
			keyHolds.set(code, keyCount);
		else
		{
			keyHolds.remove(code);
			sendKey(code, false);
		}
	}

	public function releaseAll():Void
	{
		var active = [for (pad in held.keys()) pad];
		for (pad in active)
		{
			held.set(pad, 1);
			release(pad);
		}
		touches = new Map();
	}

	/** Match Flixel's RatioScaleMode rounding, including centered black bars. */
	public static function viewport(width:Float, height:Float):TouchBounds
	{
		var w = width;
		var h = height;
		if (width / height < 16 / 9)
			h = Math.floor(w * 9 / 16);
		else
			w = Math.floor(h * 16 / 9);
		return new TouchBounds(Math.ceil((width - w) / 2), Math.ceil((height - h) / 2), w, h);
	}
}

class TouchBounds
{
	public var x:Float;
	public var y:Float;
	public var width:Float;
	public var height:Float;

	public function new(x:Float, y:Float, width:Float, height:Float)
	{
		this.x = x;
		this.y = y;
		this.width = width;
		this.height = height;
	}

	public function contains(px:Float, py:Float):Bool
	{
		return px >= x && py >= y && px < x + width && py < y + height;
	}
}
