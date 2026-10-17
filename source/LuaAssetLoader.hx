import llua.Lua;
import llua.LuaL;
import llua.State;

/** Resolves packaged scripts while preserving Lua dofile return/error semantics. */
class LuaAssetLoader
{
	public static function install(state:State, readAsset:String->String):Void
	{
		Lua_helper.add_callback(state, "readModchartAsset", readAsset);
		var result = LuaL.dostring(state,
			"local diskDofile = dofile; function dofile(path) " + "local text = readModchartAsset(path); if text == nil then return diskDofile(path) end; " +
			"local chunk, err = loadstring(text, '@' .. path); if not chunk then error(err) end; return chunk() end");
		if (result != 0)
			throw Lua.tostring(state, -1);
	}
}
