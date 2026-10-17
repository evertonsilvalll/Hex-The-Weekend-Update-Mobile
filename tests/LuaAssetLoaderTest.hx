import llua.Lua;
import llua.LuaL;

class LuaAssetLoaderTest
{
	static function main()
	{
		var state = LuaL.newstate();
		LuaL.openlibs(state);
		Lua.init_callbacks(state);
		LuaAssetLoader.install(state, function(path:String):String
		{
			return switch (path)
			{
				case "assets/main.lua": "return dofile('assets/backend.lua')";
				case "assets/backend.lua": "calls = (calls or 0) + 1; return 42, 'backend'";
				case "assets/broken.lua": "this is not valid Lua";
				default: null;
			}
		});
		var result = LuaL.dostring(state,
			"for i=1,1000 do local a,b=dofile('assets/main.lua'); assert(a==42 and b=='backend') end; " +
			"assert(calls==1000); assert(not pcall(dofile, 'assets/broken.lua')); " + "assert(not pcall(dofile, 'missing.lua'))");
		if (result != 0)
			throw Lua.tostring(state, -1);
		if (Lua.gettop(state) != 0)
			throw "Lua stack leaked";
		Lua.close(state);
		Sys.println("PASS: packaged Lua callbacks, nested dofile, multiple returns, errors and stack balance");
	}
}
