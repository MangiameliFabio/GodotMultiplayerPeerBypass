extends RefCounted

class_name MultiStateMachine

class StateAction:
	var SetStates : PackedByteArray
	var UnSetStates : PackedByteArray
	var AnySetStates : PackedByteArray
	var CurrentlyActive : bool = false
	var Owner : Object

	var ActivatedCallable : Callable
	var DeactivatedCallable : Callable

	func ShouldBeActive(activeStates:PackedByteArray) -> bool:
		# if any of the SetStates is NOT set -> should not be active
		for setState in SetStates:
			if not activeStates[setState]:
				return false
		# or if any of the UnSetStates IS set -> should not be active
		for unsetState in UnSetStates:
			if activeStates[unsetState]:
				return false
		# or if there ary AnySetStates and none of them are set -> should not be active
		if not AnySetStates.is_empty():
			for anyState in AnySetStates:
				if activeStates[anyState]:
					return true
			# none were set!
			return false
		# no canceling condition was true -> should be active
		return true

var _currentStates : PackedByteArray
var _stateActions : Array[StateAction]

func Initialize(numberOfStates:int):
	_currentStates.resize(numberOfStates)

func IsValidState(state:int, callingFunctionName:String) -> bool:
	if state < 0 or state >= _currentStates.size():
		printerr("MultiStateMachine is set up to haldle %s number of states, %s was called with %s"%[_currentStates.size(), callingFunctionName, state])
		return false
	return true

func AddStatesAction(owner:Object, setStates:PackedByteArray, unsetStates:PackedByteArray, anyStates:PackedByteArray, activatedCallable:Callable, deactivatedCallable:Callable, triggerCallableRightAway:bool) -> StateAction:
	for state in setStates:
		if not IsValidState(state, "AddStatesAction"):
			return null
	for state in unsetStates:
		if not IsValidState(state, "AddStatesAction"):
			return null
	for state in anyStates:
		if not IsValidState(state, "AddStatesAction"):
			return null
	var stateAction : StateAction = StateAction.new()
	stateAction.Owner = owner
	stateAction.SetStates = setStates
	stateAction.UnSetStates = unsetStates
	stateAction.AnySetStates = anyStates
	stateAction.ActivatedCallable = activatedCallable
	stateAction.DeactivatedCallable = deactivatedCallable
	stateAction.CurrentlyActive = stateAction.ShouldBeActive(_currentStates)
	_stateActions.append(stateAction)
	if triggerCallableRightAway:
		if stateAction.CurrentlyActive:
			stateAction.ActivatedCallable.call()
		else:
			stateAction.DeactivatedCallable.call()
	return stateAction

func RemoveAllStatesActionsWithOwner(owner:Object):
	for i in range(_stateActions.size() - 1, -1, -1):
		if _stateActions[i].Owner == owner:
			if _stateActions.size() > 1:
				_stateActions[i] = _stateActions.pop_back()
			else:
				_stateActions.clear()

func SetState(state:int):
	if not IsValidState(state, "SetState"):
		return
	if _currentStates[state]:
		# already set
		return
	_currentStates[state] = 1
	UpdateAllStateActions()

func UnSetState(state:int):
	if not IsValidState(state, "UnSetState"):
		return
	if not _currentStates[state]:
		# already not set
		return
	_currentStates[state] = 0
	UpdateAllStateActions()

func SetUnsetStates(setStates:Array[int], unsetStates:Array[int]):
	var needsUpdate : bool = false
	for setState in setStates:
		if IsValidState(setState, "SetUnsetStates") and not _currentStates[setState]:
			_currentStates[setState] = 1
			needsUpdate = true
	for unsetState in unsetStates:
		if IsValidState(unsetState, "SetUnsetStates") and _currentStates[unsetState]:
			_currentStates[unsetState] = 0
			needsUpdate = true
	if needsUpdate:
		UpdateAllStateActions()

func ResetStates(setStates:Array[int]):
	_currentStates.fill(0)
	for setState in setStates:
		if IsValidState(setState, "ResetStates"):
			_currentStates[setState] = 1
	UpdateAllStateActions()

func IsStateSet(state:int) -> bool:
	if not IsValidState(state, "IsStateSet"):
		return false
	return bool(_currentStates[state])

func IsAnyStateSet(states:Array[int]) -> bool:
	for state in states:
		if IsValidState(state, "IsAnyStateSet") and _currentStates[state]:
			return true
	return false

func UpdateAllStateActions():
	for stateAction in _stateActions:
		var shouldBeActive : bool = stateAction.ShouldBeActive(_currentStates)
		if stateAction.CurrentlyActive and not shouldBeActive:
			stateAction.CurrentlyActive = false
			if stateAction.DeactivatedCallable.is_valid():
				stateAction.DeactivatedCallable.call()
		elif not stateAction.CurrentlyActive and shouldBeActive:
			stateAction.CurrentlyActive = true
			if stateAction.ActivatedCallable.is_valid():
				stateAction.ActivatedCallable.call()
