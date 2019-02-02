module extrapanel.util;

import gtk.Menu;
import gtk.MenuItem;
import gtk.SeparatorMenuItem;
import gtk.Image;
import gtk.ImageMenuItem;
import gtk.CheckMenuItem;
import gtk.c.functions;

import std.stdio;

public static Menu createTrayMenu() {
	Menu menu = new Menu();

	MenuItem item = new MenuItem("Open config panel");
	SeparatorMenuItem sep = new SeparatorMenuItem();
	menu.append(item);
	menu.append(sep);

	item = new MenuItem("Enable");
	menu.append(item);

	item = new MenuItem("Exit");
	menu.append(item);
	menu.showAll();
	return menu;
}