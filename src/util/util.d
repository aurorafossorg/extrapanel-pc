module extrapanel.util;

import gtk.Menu;
import gtk.MenuItem;
import gtk.SeparatorMenuItem;
import gtk.Image;
import gtk.ImageMenuItem;
import gtk.CheckMenuItem;

import std.stdio;

public static immutable int MARGIN_DEFAULT = 10;	// UI default

public static immutable enum Args : string {
	RECONFIGURE = "--reconfigure"	// Force the app to regenereate the configuration file
}