/** Run: bash scripts/test-mobile-controls.sh */
class MobileTouchModelTest
{
	static var checks = 0;
	static var events:Array<String>;
	static var actions:Int;
	static var model:MobileTouchModel;

	static function check(value:Bool, message:String):Void
	{
		checks++;
		if (!value)
			throw message;
	}

	static function reset(?resolver:Int->Int):Void
	{
		events = [];
		actions = 0;
		model = new MobileTouchModel(resolver == null ? function(p) return [37, 40, 38, 39, 27, 13, 13, 32][p] : resolver,
			function(code, down) events.push((down ? "+" : "-") + code), function(_) actions++);
	}

	static function main():Void
	{
		reset();
		for (gameplay in [false, true])
			for (hitbox in [false, true])
			{
				model.layout(gameplay, hitbox, true);
				for (i in 0...model.bounds.length)
				{
					var r = model.bounds[i];
					if (r == null)
						continue;
					check(r.x >= 0 && r.y >= 0 && r.x + r.width <= 1280 && r.y + r.height <= 720, "Control outside canvas");
					check(model.padAt(r.x + r.width / 2, r.y + r.height / 2) == i, "Overlapping control");
				}
			}
		model.layout(false, true);
		check(model.padAt(1200, 500) == 5 && model.padAt(1050, 640) == 4, "A/B menu buttons");
		model.begin(1, 1200, 500);
		model.move(1, 1201, 501);
		check(events.join(",") == "+13", "Small movement released confirm");
		model.end(1);
		check(events.join(",") == "+13,-13", "Confirm did not release");
		reset();
		model.layout(true, true);
		for (i in 0...4)
		{
			check(model.padAt(i * 320, 88) == i, "Lane starts");
			check(model.padAt(i * 320 + 319.99, 719.99) == i, "Lane ends");
		}
		check(model.padAt(-1, 200) == -1 && model.padAt(1280, 200) == -1, "Outside viewport accepts note");
		check(model.padAt(100, 87) == -1, "Toolbar triggers note");
		model.begin(1, 100, 200);
		model.begin(1, 400, 200);
		model.begin(2, 100, 300);
		check(events.join(",") == "+37", "Duplicate key down for same lane");
		model.end(1);
		check(events.join(",") == "+37" && model.isHeld(0), "Second finger lost its hold");
		model.move(2, 400, 200);
		check(events.join(",") == "+37,-37,+40", "Lane slide order");
		model.move(2, -10, 200);
		check(events[events.length - 1] == "-40", "Leaving lane keeps held note");
		model.move(2, 800, 200);
		check(events[events.length - 1] == "+38", "Re-entering lane failed");
		model.end(2);
		check(events[events.length - 1] == "-38", "Lift did not release note");
		model.begin(10, 1000, 30);
		model.move(10, 1001, 30);
		check(actions == 1, "Visibility action repeats while moving");
		model.end(10);
		// Visibility only changes drawing: these same bounds remain active afterwards.
		model.begin(11, 100, 200);
		check(model.isHeld(0), "Invisible hitbox stopped accepting input");
		model.begin(12, 1000, 200);
		model.move(12, 1000, 30);
		check(actions == 1, "Sliding note finger toggled visibility");
		model.begin(13, 1200, 30);
		model.move(11, 1200, 30);
		model.end(11);
		check(model.isHeld(6), "Sliding finger released another finger's pause");
		model.releaseAll();
		for (i in 0...9)
			check(!model.isHeld(i), "Release-all left held control");
		var previous = events.length;
		model.move(13, 100, 200);
		model.end(13);
		check(events.length == previous, "Stale touch survived release-all");
		model.begin(20, 100, 200);
		model.layout(false, false);
		check(events[events.length - 1] == "-37", "Switching to pause/menu keeps note held");
		reset(function(_) return 65);
		model.layout(true, true);
		model.begin(1, 100, 200);
		model.begin(2, 400, 200);
		model.end(1);
		check(events.join(",") == "+65", "Shared binding released too early");
		model.end(2);
		check(events.join(",") == "+65,-65", "Shared binding not released");
		var binding = 65;
		reset(function(_) return binding);
		model.layout(true, true);
		model.begin(1, 100, 200);
		binding = 66;
		model.end(1);
		check(events.join(",") == "+65,-65", "Binding change released wrong key");
		for (size in [[1280, 720], [1600, 720], [1024, 768], [2340, 1080], [720, 1600]])
		{
			var v = MobileTouchModel.viewport(size[0], size[1]);
			check(v.width <= size[0] && v.height <= size[1], "Viewport cropped");
			check(Math.abs(v.width / v.height - 16 / 9) < 0.005, "Viewport is not 16:9");
			check(Math.abs(v.x * 2 + v.width - size[0]) <= 1 && Math.abs(v.y * 2 + v.height - size[1]) <= 1, "Viewport not centered");
		}
		Sys.println("PASS: " + checks + " checks for layouts, multitouch, holds, slides, actions, bindings and 16:9 viewports");
	}
}
