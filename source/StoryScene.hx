import flixel.FlxG;
import flixel.FlxSprite;

class StoryScene extends MusicBeatState
{
	public var handler:MP4Handler;

	public var path:String = "";

	var leaving:Bool = false;

	function finishScene():Void
	{
		if (leaving)
			return;
		leaving = true;
		switchState(new BruhADiagWindow(PlayState.SONG.songId));
	}

	public function new(bruh)
	{
		path = bruh;
		super();
	}

	public override function load()
	{
		handler = new MP4Handler();
	}

	public override function update(elapsed)
	{
		if (FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE)
		{
			handler.kill();
			finishScene();
		}
		super.update(elapsed);
	}

	public override function create()
	{
		handler.finishCallback = finishScene;
		handler.playMP4(Paths.video(path));
		super.create();
	}
}
