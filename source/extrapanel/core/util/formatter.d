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