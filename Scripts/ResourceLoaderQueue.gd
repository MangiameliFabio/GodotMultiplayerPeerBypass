extends Node

# this script can be used to load resources asynchronously
# via the native ResourceLoader functionality. it offers
# convenience functions to handle all the resources in the
# queue as one big loading process.

var _queue : Array[String] = []

## do not use this signal! rather use the waitForLoadingFinished()
## function
signal internal_LoadingFinishedSignal

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func queueResource(resourcePath:String):
	if _queue.has(resourcePath):
		return
	var res = ResourceLoader.load_threaded_request(resourcePath, "", false)
	if res != OK:
		printerr("Could not load resource %s. Errorcode: %d" % [resourcePath, res])
		return

	_queue.append(resourcePath)

## the waitForLoadingFinished function should be used with
## an await. like this: 'await ResourceLoaderQueue.waitForLoadingFinished()'
func waitForLoadingFinished():
	if _queue.is_empty():
		return
	await internal_LoadingFinishedSignal


func isLoading() -> bool:
	return not _queue.is_empty()


func getCachedResource(resourcePath:String):
	var loadState := ResourceLoader.load_threaded_get_status(resourcePath)
	if loadState == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		# resource was probably not loaded via load_threaded!
		# last resort is to just use load() and hope that the
		# resource is cached!
		if not ResourceLoader.has_cached(resourcePath):
			print("Tried to get resource %s, but it wasn't cached!"%resourcePath)
		return ResourceLoader.load(resourcePath)
	elif loadState == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		# resource is still in process of being loaded!
		print("Tried to get resource %s, but it is still loading!"%resourcePath)
	# using the load_threaded_get function actually reduces the
	# refcount of the resource and makes it possible for the
	# resource to be freed after usage!
	return ResourceLoader.load_threaded_get(resourcePath)


func _process(_delta):
	if _queue.is_empty():
		return

	for i in range(_queue.size(), 0, -1):
		var loadState := ResourceLoader.load_threaded_get_status(_queue[i-1])
		if loadState != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if loadState != ResourceLoader.THREAD_LOAD_LOADED:
				printerr("Error while loading resource %s: %d" % [_queue[i-1], loadState])
			_queue.remove_at(i-1)


	if _queue.is_empty():
		internal_LoadingFinishedSignal.emit()
