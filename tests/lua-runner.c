/* Minimal host runner for the pinned LuaJIT runtime, without a system Lua CLI. */
#include <stdio.h>
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

int main(int argc, char **argv)
{
    if (argc != 2) return 2;
    lua_State *state = luaL_newstate();
    if (!state) return 2;
    luaL_openlibs(state);
    int result = luaL_dofile(state, argv[1]);
    if (result) fprintf(stderr, "%s\n", lua_tostring(state, -1));
    lua_close(state);
    return result;
}
