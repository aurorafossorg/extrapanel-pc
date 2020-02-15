module extrapanel.core.util.util;

// Extra Panel
import extrapanel.core.util.logger;

// RiverD
import riverd.lua.statfun;
import riverd.lua.types;

// STD
import std.algorithm.iteration;
import std.array;
import std.conv;
import std.json;
import std.string;
import std.traits;

/// Default margin for UI layouts.
public static immutable int MARGIN_DEFAULT = 10;

/**
 * Performs a stack dump on a Lua script to the logger.
 *
 * Params:
 *		L = the lua_State* to dump.
 */
public static void stackDump (lua_State *L) {
	int i;
	immutable int top = lua_gettop(L);
	for (i = 1; i <= top; i++) {  // repeat for each level
		int t = lua_type(L, i);
		switch (t) {

		case LUA_TSTRING:  // strings
			log("String: ", lua_tostring(L, i).fromStringz);
			break;

		case LUA_TBOOLEAN:  // booleans
			log("Boolean: ", lua_toboolean(L, i) ? "true" : "false");
			break;

		case LUA_TNUMBER:  // numbers
			log("Number: ", lua_tonumber(L, i));
			break;

		default:  // other values
			log("Other type: ", lua_typename(L, t).fromStringz, "\t", lua_touserdata(L, i));
			break;

		}
	}
}

/**
 * Turns an JSON array into a nice comma-separated list.
 *
 * Params:
 *		arr: a JSONValue[] array containing only strings of data.
 *
 * Returns: a formatted string containing the info on the array.
 */
public static string arrayToString(T)(T[] arr) {
	return to!string(arr.map!(e => to!string(e).replace("\"", ""))
		.joiner(", ")
		.array);
}

public static T[] stringToArray(T)(string data) {
	return data.splitter(", ")
		.map!(to!(T))
		.array;
}

@("Util: Format a JSON array")
unittest {
	JSONValue arr = JSONValue(["Rei Ayanami", "Asuka Sohryu", "Shinji Ikari", "Tōji Suzuhara"]);
	float[] floatArr = [3.14f, 0.8f];

	assert(arrayToString(arr.array) == "Rei Ayanami, Asuka Sohryu, Shinji Ikari, Tōji Suzuhara");
	assert(arrayToString(floatArr) == "3.14, 0.8");
}
