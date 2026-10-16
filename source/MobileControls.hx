package;

#if android
import flixel.FlxG;
import flixel.FlxSubState;
import flixel.input.keyboard.FlxKey;
import openfl.display.Sprite;
import openfl.display.Stage;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.events.TouchEvent;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.ui.Multitouch;
import openfl.ui.MultitouchInputMode;

/** Screen-space controls shared by menus, gameplay and substates on Android. */
class MobileControls extends Sprite
{
	var hostStage:Stage;
	var pads:Array<Sprite> = [];
	var keyCodes:Array<Int> = [37, 40, 38, 39, 27, 13, 13, 32];
	var labels:Array<String> = ["LEFT", "DOWN", "UP", "RIGHT", "BACK", "OK", "PAUSE", "SKIP"];
	var touches:Map<Int, Int> = new Map();
	var held:Map<Int, Int> = new Map();
	var pressedCodes:Map<Int, Int> = new Map();
	var keyHolds:Map<Int, Int> = new Map();
	var lastSubState:FlxSubState;

	public function new(hostStage:Stage)
	{
		super();
		this.hostStage = hostStage;
		Multitouch.inputMode = MultitouchInputMode.TOUCH_POINT;
		for (label in labels)
		{
			var pad = new Sprite();
			pad.mouseChildren = false;
			var text = new TextField();
			text.defaultTextFormat = new TextFormat("_sans", 18, 0xFFFFFF, true, null, null, null, null, "center");
			text.text = label;
			text.selectable = false;
			text.mouseEnabled = false;
			pad.addChild(text);
			pads.push(pad);
			addChild(pad);
		}
		hostStage.addEventListener(TouchEvent.TOUCH_BEGIN, onBegin);
		hostStage.addEventListener(TouchEvent.TOUCH_MOVE, onMove);
		hostStage.addEventListener(TouchEvent.TOUCH_END, onEnd);
		hostStage.addEventListener(Event.DEACTIVATE, onDeactivate);
		hostStage.addEventListener(Event.RESIZE, resize);
		FlxG.signals.preStateSwitch.add(releaseAll);
		FlxG.signals.postUpdate.add(checkSubState);
		resize();
	}

	function resize(?event:Event):Void
	{
		releaseAll();
		var width = hostStage.stageWidth;
		var height = hostStage.stageHeight;
		var gap = Math.max(6, height * 0.015);
		var padWidth = (width - gap * 5) / 4;
		var padHeight = height * 0.20;
		for (i in 0...pads.length)
		{
			var pad = pads[i];
			var top = i >= 4;
			var buttonWidth = top ? width * 0.13 : padWidth;
			var buttonHeight = top ? height * 0.10 : padHeight;
			pad.x = top ? width - (8 - i) * (buttonWidth + gap) : gap + i * (padWidth + gap);
			pad.y = top ? gap : height - padHeight - gap;
			pad.graphics.clear();
			pad.graphics.lineStyle(2, 0xFFFFFF, 0.65);
			pad.graphics.beginFill(0x16243B, 0.55);
			pad.graphics.drawRoundRect(0, 0, buttonWidth, buttonHeight, 12, 12);
			pad.graphics.endFill();
			var text:TextField = cast pad.getChildAt(0);
			text.defaultTextFormat = new TextFormat("_sans", Std.int(Math.max(12, height * 0.035)), 0xFFFFFF, true, null, null, null, null, "center");
			text.text = labels[i];
			text.width = buttonWidth;
			text.height = buttonHeight;
			text.y = (buttonHeight - text.textHeight) / 2 - 2;
		}
	}

	function padAt(event:TouchEvent):Int
	{
		for (i in 0...pads.length)
			if (pads[i].hitTestPoint(event.stageX, event.stageY))
				return i;
		return -1;
	}

	function onBegin(event:TouchEvent):Void
	{
		var pad = padAt(event);
		if (pad == -1 || touches.exists(event.touchPointID))
			return;
		touches.set(event.touchPointID, pad);
		press(pad);
	}

	function onMove(event:TouchEvent):Void
	{
		if (!touches.exists(event.touchPointID))
			return;
		var previous = touches.get(event.touchPointID);
		var next = padAt(event);
		if (previous == next)
			return;
		release(previous);
		touches.set(event.touchPointID, next);
		press(next);
	}

	function onEnd(event:TouchEvent):Void
	{
		if (!touches.exists(event.touchPointID))
			return;
		release(touches.get(event.touchPointID));
		touches.remove(event.touchPointID);
	}

	function press(pad:Int):Void
	{
		if (pad < 0)
			return;
		var count = held.exists(pad) ? held.get(pad) : 0;
		held.set(pad, count + 1);
		if (count != 0)
			return;
		var code = keyCodes[pad];
		if (pad == 6 && FlxG.save.data.pauseBind != null)
			code = FlxKey.fromString(FlxG.save.data.pauseBind);
		pressedCodes.set(pad, code);
		pads[pad].alpha = 0.65;
		var keyCount = keyHolds.exists(code) ? keyHolds.get(code) : 0;
		keyHolds.set(code, keyCount + 1);
		// Both Flixel polling and PlayState's raw note handlers receive the event.
		if (keyCount == 0)
			hostStage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN, true, false, 0, code));
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
		pads[pad].alpha = 1;
		var keyCount = keyHolds.get(code) - 1;
		if (keyCount > 0)
			keyHolds.set(code, keyCount);
		else
		{
			keyHolds.remove(code);
			hostStage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_UP, true, false, 0, code));
		}
	}

	function releaseAll():Void
	{
		var active = [for (pad in held.keys()) pad];
		for (pad in active)
		{
			held.set(pad, 1);
			release(pad);
		}
		touches = new Map();
	}

	function onDeactivate(event:Event):Void
	{
		releaseAll();
	}

	function checkSubState():Void
	{
		var subState = FlxG.state == null ? null : FlxG.state.subState;
		if (subState != lastSubState)
		{
			releaseAll();
			lastSubState = subState;
		}
	}
}
#end
