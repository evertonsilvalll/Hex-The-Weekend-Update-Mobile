package;

#if android
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFramesCollection.FlxFrameCollectionType;
import openfl.utils.Assets;

/** Lossless multi-texture Sparrow atlas. Each frame keeps its own GPU texture. */
class AndroidAtlasFrames extends FlxAtlasFrames
{
	var retainedPages:Array<FlxGraphic> = [];

	public static function load(manifestPath:String, library:String):AndroidAtlasFrames
	{
		var manifest = Xml.parse(Assets.getText(manifestPath)).firstElement();
		var pages:Array<FlxAtlasFrames> = [];
		for (page in manifest.elementsNamed("Page"))
		{
			var key = page.get("key");
			pages.push(FlxAtlasFrames.fromSparrow(Paths.loadImage(key, library), Paths.file('images/$key.xml', library)));
		}
		var owner = pages[0].parent;
		for (existing in owner.getFramesCollections(FlxFrameCollectionType.ATLAS))
			if (Std.isOfType(existing, AndroidAtlasFrames))
				return cast existing;
		var result = new AndroidAtlasFrames(owner);
		for (page in pages)
		{
			if (page.parent != owner)
			{
				page.parent.useCount++;
				result.retainedPages.push(page.parent);
			}
		}
		for (entry in manifest.elementsNamed("Frame"))
		{
			var name = entry.get("name");
			for (page in pages)
			{
				var frame = page.getByName(name);
				if (frame != null)
				{
					// Collections own their frames; never share a destructible frame instance.
					result.pushFrame(frame.copyTo());
					break;
				}
			}
		}
		return result;
	}

	public function new(owner:FlxGraphic)
	{
		super(owner);
	}

	override public function destroy():Void
	{
		super.destroy();
		for (page in retainedPages)
			page.useCount--;
		retainedPages = [];
	}
}
#end
