## This class will only serve as a quick access to all kinds
## of enums. You can access them by just using E.EnumNameHere
class_name E extends Object

enum PlayerInteractionMode {
	FirstPerson,
	Vehicle,
	CursorInteraction,
	PanelInteraction,
	InMenus,
	ChartInteraction,
	Incapacitated,
	WorkbenchInteraction
}

enum PlayerActionType {
	None,
	PrimaryAction,
	PrimaryInHandAction,
	SecondaryAction,
	SecondaryInHandAction
}

enum PlayerAnimationStates {
	None,
	NormalMovement,
	Sitting,
	StandingAtTable
}

enum ObjectiveState {
	PENDING,
	SUCCESS,
	FAILURE
}

enum ObjectivePriority {
	CRITICAL,
	OPTIONAL
}

enum CommunicationLineBits {
	None = 0,
	Authority = 1 << 0,
	# x = 1 << 1,
	# y = 1 << 2
}

enum RepairStatus {
	None = 0,
	Good = 1,
	Worn = 2,
	Damaged = 3,
	Broken = 4
}

enum RepairType {
	None,
	ElectricRepair,
	PlumbingRepair,
	MachinistRepair
}

enum MaterialType {
	INVALID,
	METAL,
	PLASTIC,
	ELECTRIC,
	ADHESIVE
}

enum AdditionalInfoType {
	NONE,
	REPAIR_STATUS,
	MATERIAL_STORAGE
}

enum CraftedItemType {
	NONE,
	MACHINIST_REPAIR_KIT,
	ELECTRIC_REPAIR_KIT,
	PLUMBING_KIT
}

enum DamageType {
	ELECTRIC,
	PHYSICAL
}
