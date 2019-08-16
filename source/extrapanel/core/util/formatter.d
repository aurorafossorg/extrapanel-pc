module extrapanel.core.util.formatter;

public static string bold(string text) {
	return "<b>" ~ text ~ "</b>";
}

public static string italic(string text) {
	return "<i>" ~ text ~ "</i>";
}

public static string monospaced(string text) {
	return "<tt>" ~ text ~ "</tt>";
}

public static string consoleGreen(string text) {
	return "\033[0;32m" ~ text ~ "\033[1;37m";
}

public static string consoleYellow(string text) {
	return "\033[1;33m" ~ text ~ "\033[1;37m";
}

public static string consoleRed(string text) {
	return "\033[0;31m" ~ text ~ "\033[1;37m";
}