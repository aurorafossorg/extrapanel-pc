module extrapanel.core.util.formatter;

import pango.PgAttribute;

public static string bold(string text) {
	return "<b>" ~ text ~ "</b>";
}

public static string italic(string text) {
	return "<i>" ~ text ~ "</i>";
}

public static string monospaced(string text) {
	return "<tt>" ~ text ~ "</tt>";
}

public static string url(string text) {
	return "<a href=\"" ~ text ~ "\">" ~ text ~ "</a>";
}

public static string consoleGreen(string text) {
	return "\033[0;32m" ~ text ~ "\033[0m";
}

public static string consoleYellow(string text) {
	return "\033[1;33m" ~ text ~ "\033[0m";
}

public static string consoleRed(string text) {
	return "\033[0;31m" ~ text ~ "\033[0m";
}

public static PgAttribute uiBold() {
	return PgAttribute.weightNew(PangoWeight.BOLD);
}

public static PgAttribute uiItalic() {
	return PgAttribute.styleNew(PangoStyle.ITALIC);
}

public static PgAttribute uiRed() {
	return PgAttribute.foregroundNew(0xcccc, 0x0000, 0x0000);
}

public static PgAttribute uiGreen() {
	return PgAttribute.foregroundNew(0x4e4e, 0x9a9a, 0x0606);
}

public static PgAttribute uiGrey() {
	return PgAttribute.foregroundNew(0xaaaa, 0xaaaa, 0xaaaa);
}