module extrapanel.core.util.exception;

/**
 * Exception to represent a missing file.
 */
public class FileNotFoundException : Exception {
	/**
	 * Constructor of the exception.
	 *
	 * Params:
	 *  msg = the file path that caused the exception.
	 */
	this(string msg) {
		super("File \"" ~ msg ~ "\" doesn't exist.", file, line);
	}
}

/**
 * Exception to represent an error during a script's execution.
 */
public class ScriptMethodExecutionException : Exception {
	/**
	 * Constructor of the exception.
	 *
	 * Params:
	 *  script = the script file that caused the error.
	 *		method = the method that failed.
	 */
	this(string script, string method) {
		super("Script \"" ~ script ~ "\" failed on executing " ~ method ~ "().", file, line);
	}
}

/**
 * Exception to represent an error during a script's loading.
 */
public class ScriptLoadingException : Exception {
	/**
	 * Constructor of the exception.
	 *
	 * Params:
	 *  script = the script file that caused the error.
	 */
	this(string script) {
		super("Script\"" ~ script ~ "\" failed on loading.", file, line);
	}
}
