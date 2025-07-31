## Simple utility to pass a Signal around.
class_name SignalHolder extends RefCounted

signal HeldSignal
var SignalTriggered : bool = false

var DebugName : String = "NoName"

func TriggerSignal():
	SignalTriggered = true
	HeldSignal.emit()

func AwaitSignal():
	if not SignalTriggered:
		await HeldSignal

static func CombineSignalHolders(signal_holders:Array[SignalHolder]) -> SignalHolder:
	var combined : SignalHolder = SignalHolder.new()
	AwaitAllAndTriggerSingle(signal_holders, combined)
	return combined

static func AwaitAllAndTriggerSingle(signal_holders:Array[SignalHolder], trigger:SignalHolder):
	for sh in signal_holders:
		await sh.AwaitSignal()
	trigger.TriggerSignal()
