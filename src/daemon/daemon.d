module extrapanel.daemon;

import util.config;

import core.stdc.stdlib;
import core.sys.posix.unistd;
import core.sys.posix.signal;
import core.sys.linux.errno;
import core.thread;
import core.time;

import std.path;
import std.file;
import std.stdio;
import std.math;
import std.experimental.logger;
import std.process;
import std.conv;

extern (C) nothrow
{
	// These are for control of termination
	// druntime rt.critical_
	void _d_critical_term();
	// druntime rt.monitor_
	void _d_monitor_staticdtor();

	void gc_term();

	alias int pid_t;

	// daemon functions
	pid_t fork();
	int umask(int);
	int setsid();
	int close(int fd);

	// Signal trapping in Linux
	alias void function(int) sighandler_t;
	sighandler_t signal(int signum, sighandler_t handler);
	char* strerror(int errnum) pure;
}

extern (C) nothrow void signalHandler(int signal) {
	//logger.info("Signal: ", signal);
	shouldExit = true;
}

FileLogger logger;
bool shouldExit = false;

string getConfigFilePath() {
	return expandTilde(buildPath("~", ".config", "extrapanel/"));
}

string getLockFilePath() {
	return getConfigFilePath ~ "daemon.lock";
}

bool lockFileExists() {
	return exists(getLockFilePath);
}

void makeLockFile() {
	writeln(getConfigFilePath);
	File lockF = File(getLockFilePath, "w");
	lockF.close();
}

void deleteLockFile() {
	remove(getLockFilePath);
}

int getMsecsDelay() {
	return cast(int) round(Configuration.getOption!(float)(Options.CommDelay) * 1000);
}

pid_t daemonize() {
	// Process and Session ID's
	pid_t pid, sid;

	// Fork of of parent
	pid = fork();

	if(pid < 0) {
		logger.critical("Daemon process failed: fork failed");
		deleteLockFile();
		logger.file.close();

		exit(EXIT_FAILURE);
	}

	// Forking successfull, leaving parent
	if(pid > 0) {
		logger.info("Daemon detached with pid ", pid);
		info("Daemon detached with pid ", pid);
		exit(EXIT_SUCCESS);
	}

	// Change umask mode
	umask(0);

	// Creates a new SID for the child process
	sid = setsid();
	if(sid < 0) {
		deleteLockFile();
		logger.file.close();

		exit(EXIT_FAILURE);
	}

	// Closes file descriptors
	close(STDIN_FILENO);
	close(STDOUT_FILENO);
	close(STDERR_FILENO);

	// Daemon process finished; we return it' pid now
	return pid;
}

int main(string[] args) {
	Configuration.appArgs ~= args;

	logger = new FileLogger(getConfigFilePath ~ "daemonLog.log");
	
	if(lockFileExists && !Configuration.hasArg("--overwrite")) {
		critical("Lock file already exists! If you're sure no daemon is running, delete " ~ getLockFilePath ~ " manually");
		return -1;
	}

	makeLockFile();
	Configuration.load();

	auto pid = daemonize();

	// Connect signals to signalHandler
	signal(SIGINT, &signalHandler);
	signal(SIGABRT, &signalHandler);
	signal(SIGQUIT, &signalHandler);
	signal(SIGTERM, &signalHandler);

	while(!shouldExit) {
		//logger.trace(Configuration.getOption!(string)(Options.DeviceUUID));
		Thread.sleep(getMsecsDelay.dur!"msecs");
	}

	logger.info("Daemon is quitting...");
	logger.file.close();
	deleteLockFile();

	return 0;
}