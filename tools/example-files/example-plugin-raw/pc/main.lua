--setup() - Sets the plugin up for running. Receives it's configuration and returns whether is good to go or an error ocurred
function setup(config)
	return 0
end

--query() - Queries information from the host; only returns info if state changed after last call
function query()
	return "example"
end

--change() - Changes behaviour on host according to the instructions of controller
function change(action)
	
end
