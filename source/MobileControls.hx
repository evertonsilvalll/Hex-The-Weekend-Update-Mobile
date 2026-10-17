package;

#if android
import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxSubState;
import flixel.input.keyboard.FlxKey;
import openfl.display.Sprite;
import openfl.display.Stage;
import openfl.events.Event;
import openfl.events.TouchEvent;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.ui.Multitouch;
import openfl.ui.MultitouchInputMode;

/** Psych-style controls aligned with the game's letterboxed 16:9 viewport. */
class MobileControls extends Sprite
{
	var hostStage:Stage;
	var pads:Array<Sprite> = [];
	var colors:Array<Int> = [
		0xC24B99,
		0x00FFFF,
		0x12FA05,
		0xF9393F,
		0xF9393F,
		0x12FA05,
		0xFFFFFF,
		0xFFFFFF,
		0xFFFFFF
	];
	var model:MobileTouchModel;
	var lastState:FlxState;
	var lastSubState:FlxSubState;
	var lastGameplay:Bool = false;
	var lastCutscene:Bool = false;
	var lastMode:Bool = true;
	var lastVisibility:Bool = true;
	var paintedState:Int = -1;

	public function new(hostStage:Stage)
	{
		super();
		this.hostStage = hostStage;
		mouseEnabled = false;
		mouseChildren = false;
		Multitouch.inputMode = MultitouchInputMode.TOUCH_POINT;
		model = new MobileTouchModel(resolveCode, sendKey, onAction);
		for (i in 0...9)
		{
			var pad = new Sprite();
			pad.mouseEnabled = false;
			pad.mouseChildren = false;
			var text = new TextField();
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
		FlxG.signals.postUpdate.add(refreshContext);
		resize();
	}

	function resolveCode(pad:Int):Int
	{
		if (pad < 4 && model.gameplay)
		{
			var binds:Array<String> = [
				FlxG.save.data.leftBind,
				FlxG.save.data.downBind,
				FlxG.save.data.upBind,
				FlxG.save.data.rightBind
			];
			if (binds[pad] != null)
				return FlxKey.fromString(binds[pad]);
		}
		if (pad == 6 && FlxG.save.data.pauseBind != null)
			return FlxKey.fromString(FlxG.save.data.pauseBind);
		return [37, 40, 38, 39, 27, 13, 13, 32][pad];
	}

	function sendKey(code:Int, down:Bool):Void
	{
		// Feed both Flixel polling and PlayState's raw note handlers.
		hostStage.dispatchEvent(MobileKeyboardEvent.create(code, down));
	}

	function onAction(pad:Int):Void
	{
		MobileControlSettings.toggleVisibility();
		lastVisibility = MobileControlSettings.hitboxesVisible();
		redraw();
	}

	function refreshContext():Void
	{
		var state = FlxG.state;
		var subState = state == null ? null : state.subState;
		while (subState != null && subState.subState != null)
			subState = subState.subState;
		var play:PlayState = Std.isOfType(state, PlayState) ? cast state : null;
		var cutscene = Std.isOfType(state, BruhADiagWindow) || Std.isOfType(state, StoryScene);
		var gameplay = false;
		if (play != null && subState == null)
		{
			@:privateAccess cutscene = play.inCutscene || !play.startedCountdown;
			gameplay = !cutscene && !play.paused;
		}
		var mode = MobileControlSettings.useHitbox();
		var visibility = MobileControlSettings.hitboxesVisible();
		var relayout = state != lastState || subState != lastSubState || gameplay != lastGameplay || cutscene != lastCutscene || mode != lastMode;
		if (relayout)
		{
			lastState = state;
			lastSubState = subState;
			lastGameplay = gameplay;
			lastCutscene = cutscene;
			lastMode = mode;
			model.layout(gameplay, mode, cutscene);
		}
		if (relayout || visibility != lastVisibility)
		{
			lastVisibility = visibility;
			redraw();
		}
	}

	function resize(?event:Event):Void
	{
		releaseAll();
		var viewport = MobileTouchModel.viewport(hostStage.stageWidth, hostStage.stageHeight);
		x = viewport.x;
		y = viewport.y;
		scaleX = viewport.width / 1280;
		scaleY = viewport.height / 720;
		refreshContext();
		// Also initialize the menu before the first Flixel state is created.
		if (model.bounds.length == 0)
			model.layout(false, lastMode);
		redraw();
	}

	function redraw():Void
	{
		if (model.bounds.length == 0)
			return;
		var visualState = (lastGameplay ? 1 : 0) | (lastMode ? 2 : 0) | (lastVisibility ? 4 : 0) | (lastCutscene ? 8 : 0);
		for (i in 0...pads.length)
			if (model.isHeld(i))
				visualState |= 1 << (i + 4);
		// Finger movement inside the same lane must not rebuild vector shapes/text.
		if (visualState == paintedState)
			return;
		paintedState = visualState;
		for (i in 0...pads.length)
		{
			var pad = pads[i];
			var rect = model.bounds[i];
			var lane = model.gameplay && model.hitbox && i < 4;
			pad.visible = rect != null && (!lane || lastVisibility);
			if (rect == null)
				continue;
			pad.x = rect.x;
			pad.y = rect.y;
			var active = model.isHeld(i);
			var g = pad.graphics;
			g.clear();
			g.lineStyle(lane ? 2 : 4, colors[i], active ? 1 : 0.65);
			g.beginFill(lane ? colors[i] : 0x111827, lane ? (active ? 0.22 : 0.035) : (active ? 0.85 : 0.5));
			if (lane)
				g.drawRect(0, 0, rect.width, rect.height);
			else
				g.drawRoundRect(0, 0, rect.width, rect.height, i < 6 ? 24 : 12, i < 6 ? 24 : 12);
			g.endFill();
			var text:TextField = cast pad.getChildAt(0);
			text.text = "";
			if (i < 4)
			{
				var angle = [Math.PI, Math.PI / 2, -Math.PI / 2, 0.0][i];
				var centerY = lane ? rect.height - 70 : rect.height / 2;
				var size = lane ? 40.0 : 36.0;
				var points = [
					[-0.85, -0.4],
					[0.0, -0.4],
					[0.0, -0.85],
					[0.9, 0.0],
					[0.0, 0.85],
					[0.0, 0.4],
					[-0.85, 0.4]
				];
				g.lineStyle(2, 0xFFFFFF, active ? 1 : 0.7);
				g.beginFill(colors[i], active ? 1 : 0.7);
				for (p in 0...points.length)
				{
					var px = rect.width / 2 + size * (points[p][0] * Math.cos(angle) - points[p][1] * Math.sin(angle));
					var py = centerY + size * (points[p][0] * Math.sin(angle) + points[p][1] * Math.cos(angle));
					if (p == 0)
						g.moveTo(px, py);
					else
						g.lineTo(px, py);
				}
				g.endFill();
			}
			else
			{
				text.defaultTextFormat = new TextFormat("_sans", i < 6 ? 56 : 22, colors[i], true, null, null, null, null, "center");
				text.text = i == 4 ? "B" : i == 5 ? "A" : i == 6 ? "PAUSA" : i == 7 ? "PULAR" : lastVisibility ? "OCULTAR" : "MOSTRAR";
				text.width = rect.width;
				text.height = rect.height;
				text.y = (rect.height - text.textHeight) / 2 - 2;
			}
		}
	}

	function onBegin(event:TouchEvent):Void
	{
		model.begin(event.touchPointID, (event.stageX - x) / scaleX, (event.stageY - y) / scaleY);
		redraw();
	}

	function onMove(event:TouchEvent):Void
	{
		model.move(event.touchPointID, (event.stageX - x) / scaleX, (event.stageY - y) / scaleY);
		redraw();
	}

	function onEnd(event:TouchEvent):Void
	{
		model.end(event.touchPointID);
		redraw();
	}

	function releaseAll():Void
	{
		model.releaseAll();
		redraw();
	}

	function onDeactivate(event:Event):Void
	{
		releaseAll();
	}
}
#end
