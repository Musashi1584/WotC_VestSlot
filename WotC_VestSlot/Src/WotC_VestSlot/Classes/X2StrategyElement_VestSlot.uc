class X2StrategyElement_VestSlot extends CHItemSlotSet config (VestSlot);

var localized string strVestFirstLetter;

var config array<name> AbilityUnlocksVestSlot;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;
	Templates.AddItem(CreateVestSlotTemplate());
	return Templates;
}

static function X2DataTemplate CreateVestSlotTemplate()
{
	local CHItemSlot Template;

	`CREATE_X2TEMPLATE(class'CHItemSlot', Template, 'VestSlot');

	Template.InvSlot = eInvSlot_Vest;
	Template.SlotCatMask = Template.SLOT_ARMOR | Template.SLOT_ITEM;
	// Unused for now
	Template.IsUserEquipSlot = true;
	// Uses unique rule
	Template.IsEquippedSlot = true;
	// Does not bypass unique rule
	Template.BypassesUniqueRule = false;
	Template.IsMultiItemSlot = false;
	Template.IsSmallSlot = true;


	Template.CanAddItemToSlotFn = CanAddItemToVestSlot;
	Template.UnitHasSlotFn = HasVestSlot;
	Template.GetPriorityFn = VestGetPriority;
	Template.ShowItemInLockerListFn = ShowVestItemInLockerList;
	Template.ValidateLoadoutFn = VestValidateLoadout;
	Template.GetSlotUnequipBehaviorFn = VestGetUnequipBehavior;

	return Template;
}

static function bool CanAddItemToVestSlot(CHItemSlot Slot, XComGameState_Unit Unit, X2ItemTemplate Template, optional XComGameState CheckGameState, optional int Quantity = 1, optional XComGameState_Item ItemState)
{
	local string strDummy;
	`log(GetFuncName() @ "called");
	if (!Slot.UnitHasSlot(Unit, strDummy, CheckGameState) || Unit.GetItemInSlot(Slot.InvSlot, CheckGameState) != none)
	{
		return false;
	}
	return Template.ItemCat == 'defense';
}

static function bool HasVestSlot(CHItemSlot Slot, XComGameState_Unit UnitState, out string LockedReason, optional XComGameState CheckGameState)
{
	local name Ability;
	local X2EquipmentTemplate EquipmentTemplate;
	local array<XComGameState_Item> CurrentInventory;
	local XComGameState_Item InventoryItem;


	`log(GetFuncName() @ "called");

	if (default.AbilityUnlocksVestSlot.Length == 0)
	{
		return UnitState.IsSoldier() && !UnitState.IsRobotic();
	}

	foreach default.AbilityUnlocksVestSlot(Ability)
	{
		if (UnitState.HasSoldierAbility(Ability, true))
		{
			`LOG(GetFuncName() @ "unlocked by" @ Ability,, 'VestSlot');
			return true;
		}
	}

	CurrentInventory = UnitState.GetAllInventoryItems(CheckGameState);
	foreach CurrentInventory(InventoryItem)
	{
		EquipmentTemplate = X2EquipmentTemplate(InventoryItem.GetMyTemplate());
		if (EquipmentTemplate != none)
		{
			foreach EquipmentTemplate.Abilities(Ability)
			{
				if (default.AbilityUnlocksVestSlot.Find(Ability) != INDEX_NONE)
				{
					`LOG(GetFuncName() @ "unlocked by" @ Ability,, 'VestSlot');
					return true;
				}
			}
		}
	}

	return false;

	
}

static function int VestGetPriority(CHItemSlot Slot, XComGameState_Unit UnitState, optional XComGameState CheckGameState)
{
	`log(GetFuncName() @ "called");
	return 120; // Ammo Pocket is 110 
}

static function bool ShowVestItemInLockerList(CHItemSlot Slot, XComGameState_Unit Unit, XComGameState_Item ItemState, X2ItemTemplate ItemTemplate, XComGameState CheckGameState)
{
	return ItemTemplate.ItemCat == 'defense';
}

static function string GetVestDisplayLetter(CHItemSlot Slot)
{
	`log(GetFuncName() @ "called");
	return default.strVestFirstLetter;
}

static function VestValidateLoadout(CHItemSlot Slot, XComGameState_Unit Unit, XComGameState_HeadquartersXCom XComHQ, XComGameState NewGameState)
{
	local XComGameState_Item EquippedVest;
	local string strDummy;
	local bool HasSlot;
	EquippedVest = Unit.GetItemInSlot(Slot.InvSlot, NewGameState);
	HasSlot = Slot.UnitHasSlot(Unit, strDummy, NewGameState);
	`log(GetFuncName() @ "called");
	if(EquippedVest == none && HasSlot)
	{
		//EquippedSecondaryWeapon = GetBestSecondaryWeapon(NewGameState);
		//AddItemToInventory(EquippedSecondaryWeapon, eInvSlot_SecondaryWeapon, NewGameState);
	}
	else if(EquippedVest != none && !HasSlot)
	{
		EquippedVest = XComGameState_Item(NewGameState.ModifyStateObject(class'XComGameState_Item', EquippedVest.ObjectID));
		Unit.RemoveItemFromInventory(EquippedVest, NewGameState);
		XComHQ.PutItemInInventory(NewGameState, EquippedVest);
		EquippedVest = none;
	}

}

function ECHSlotUnequipBehavior VestGetUnequipBehavior(CHItemSlot Slot, ECHSlotUnequipBehavior DefaultBehavior, XComGameState_Unit Unit, XComGameState_Item ItemState, optional XComGameState CheckGameState)
{
	return eCHSUB_AllowEmpty;
}