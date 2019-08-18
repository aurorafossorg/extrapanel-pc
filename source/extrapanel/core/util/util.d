module extrapanel.core.util.util;

import riverd.lua.statfun;
import riverd.lua.types;

import std.string;
import std.json;
import std.stdio;
import std.conv;

import extrapanel.core.util.logger;

public static immutable int MARGIN_DEFAULT = 10;	// UI default

public static void stackDump (lua_State *L) {
	int i;
	int top = lua_gettop(L);
	for (i = 1; i <= top; i++) {  /* repeat for each level */
		int t = lua_type(L, i);
		switch (t) {
	
		case LUA_TSTRING:  /* strings */
			writeln("String: ", lua_tostring(L, i).fromStringz);
			break;
	
		case LUA_TBOOLEAN:  /* booleans */
			writeln("Boolean: ", lua_toboolean(L, i) ? "true" : "false");
			break;
	
		case LUA_TNUMBER:  /* numbers */
			writeln("Number: ", lua_tonumber(L, i));
			break;
	
		default:  /* other values */
			writeln("Other type: ", lua_typename(L, t).fromStringz, "\t", lua_touserdata(L, i));
			break;
	
		}
	}
}

// This turn an JSON array into a nice comma-separated list
public static string formatArray(JSONValue[] arr) {
	string formatedStr;
	foreach(str; arr) {
		formatedStr ~= to!string(str) ~ ", ";
	}

	return chomp(formatedStr, ", ");
}