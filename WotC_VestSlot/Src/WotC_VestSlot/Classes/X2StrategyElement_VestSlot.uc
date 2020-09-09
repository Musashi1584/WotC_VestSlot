class X2StrategyElement_VestSlot extends CHItemSlotSet config (VestSlot);

var localized string strVestFirstLetter;

var config array<name> AbilityUnlocksVestSlot;

var config bool bLog;
var config array<name> AllowedItemCategories;
var config bool bAllowEmpty;

var config array<name> AllowedSoldierClasses;
var config array<name> AllowedCharacterTemplates;

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

	if (!Slot.UnitHasSlot(Unit, strDummy, CheckGameState) || Unit.GetItemInSlot(Slot.InvSlot, CheckGameState) != none)
	{
		`LOG(Unit.GetFullName() @ "can NOT add item to Vest Slot:" @ Template.FriendlyName @ Template.DataName @ ", because unit does not have the Vest Slot:" @ !Slot.UnitHasSlot(Unit, strDummy, CheckGameState) @ "or" @ "the Vest Slot is already occupied:" @ Unit.GetItemInSlot(Slot.InvSlot, CheckGameState) != none, default.bLog, 'WotC_VestSlot');
		return false;
	}
	if (default.AllowedItemCategories.Find(Template.ItemCat) != INDEX_NONE)
	{
		`LOG(Unit.GetFullName() @ "can add item to Vest Slot:" @ Template.FriendlyName @ Template.DataName @ ", because it has a matching Item Category:" @ Template.ItemCat, default.bLog, 'WotC_VestSlot');
		return true;
	}
}

static function bool HasVestSlot(CHItemSlot Slot, XComGameState_Unit UnitState, out string LockedReason, optional XComGameState CheckGameState)
{
	local name Ability;
	local X2EquipmentTemplate EquipmentTemplate;
	local array<XComGameState_Item> CurrentInventory;
	local XComGameState_Item InventoryItem;
	
	// Added by Hotl3looded to check for GTS granted abilities
	local X2AbilityTemplateManager			AbilityTemplateManager;
	local XComGameState_HeadquartersXCom	XComHQ;
	local array<X2SoldierUnlockTemplate>	UnlockTemplates;
	local X2SoldierAbilityUnlockTemplate	AbilityUnlockTemplate;
	local X2AbilityTemplate					AbilityTemplate;
	local int								i;
	// End of addition by Hotl3looded

	//	Check for whitelisted soldier classes first.
	if (default.AllowedSoldierClasses.Find(UnitState.GetSoldierClassTemplateName()) != INDEX_NONE)
	{
		`LOG(UnitState.GetFullName() @ "has Vest Slot, because they have a matching Soldier Class:" @ UnitState.GetSoldierClassTemplateName(), default.bLog, 'WotC_VestSlot');
		return true;
	}
	//	Then check whitelisted character templates. Can come in handy if there are any robotic soldier classes.
	if (default.AllowedCharacterTemplates.Find(UnitState.GetMyTemplateName()) != INDEX_NONE)
	{	
		`LOG(UnitState.GetFullName() @ "has Vest Slot, because they have a matching Character Template Name:" @ UnitState.GetMyTemplateName(), default.bLog, 'WotC_VestSlot');
		return true;
	}
	//	If there is no soldier class match, check if there are any entries in the config array for abilities that unlock the Vest Slot.
	if (default.AbilityUnlocksVestSlot.Length != 0)
	{
		foreach default.AbilityUnlocksVestSlot(Ability)
		{
			if (UnitState.HasSoldierAbility(Ability, true))
			{
				`LOG(UnitState.GetFullName() @ "has Vest Slot, because they have a matching Ability:" @ Ability, default.bLog, 'WotC_VestSlot');
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
						`LOG(UnitState.GetFullName() @ "has Vest Slot, because they have a matching Ability:" @ Ability @ "on an equipped Item:" @ EquipmentTemplate.DataName @ "in slot:" @ InventoryItem.InventorySlot, default.bLog, 'WotC_VestSlot');
						return true;
					}
				}
			}
		}
		
		// Added by Hotl3looded to check for GTS granted abilities
		AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
		XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom', true));
		if (XComHQ != none)
		{
			UnlockTemplates = XComHQ.GetActivatedSoldierUnlockTemplates(); // gets all activated GTS Unlock templates
			for (i = 0; i < UnlockTemplates.Length; ++i)
			{
				AbilityUnlockTemplate = X2SoldierAbilityUnlockTemplate(UnlockTemplates[i]); // selects an activated GTS Unlock template
				if (AbilityUnlockTemplate != none && AbilityUnlockTemplate.UnlockAppliesToUnit(UnitState)) // checks if unit's soldier class is allowed to have the ability through the GTS Unlock template
				{
					AbilityTemplate = AbilityTemplateManager.FindAbilityTemplate(AbilityUnlockTemplate.AbilityName); // finds ability given by the selected GTS Unlock template
					if (AbilityTemplate != none)
					{
						if (default.AbilityUnlocksVestSlot.Find(AbilityTemplate.DataName) != INDEX_NONE) // checks if ability is supposed to unlock the Vest Slot
						{
								return true;
						}
					}
				}
			}
		}
		// End of addition by Hotl3looded

		//	If the config array has at least one ability, we do not add the slot to all soldiers.
		`LOG(UnitState.GetFullName() @ "does not have Vest Slot, because they do not have any abilities from the configured list.", default.bLog, 'WotC_VestSlot');
		return false;

	}	//	If there are no entries in the ability config array, allow the Slot for all non-robotic soldiers.
	else if(UnitState.IsSoldier() && !UnitState.IsRobotic())
	{
		`LOG(UnitState.GetFullName() @ "has Vest Slot, because they are a non-robotic soldier.", default.bLog, 'WotC_VestSlot');
		return true;
	}
	return false;	
}

static function int VestGetPriority(CHItemSlot Slot, XComGameState_Unit UnitState, optional XComGameState CheckGameState)
{
	return 120; // Ammo Pocket is 110 
}

static function bool ShowVestItemInLockerList(CHItemSlot Slot, XComGameState_Unit Unit, XComGameState_Item ItemState, X2ItemTemplate ItemTemplate, XComGameState CheckGameState)
{
	return default.AllowedItemCategories.Find(ItemTemplate.ItemCat) != INDEX_NONE;
}

static function string GetVestDisplayLetter(CHItemSlot Slot)
{
	return default.strVestFirstLetter;
}

static function VestValidateLoadout(CHItemSlot Slot, XComGameState_Unit Unit, XComGameState_HeadquartersXCom XComHQ, XComGameState NewGameState)
{
	local XComGameState_Item EquippedVest;
	local string strDummy;
	local bool HasSlot;
	EquippedVest = Unit.GetItemInSlot(Slot.InvSlot, NewGameState);
	HasSlot = Slot.UnitHasSlot(Unit, strDummy, NewGameState);

	`LOG(Unit.GetFullName() @ "validating Vest Slot. Unit has slot:" @ HasSlot @ EquippedVest == none ? ", slot is empty." : ", slot contains item:" @ EquippedVest.GetMyTemplateName(), default.bLog, 'WotC_VestSlot');

	if(EquippedVest == none && HasSlot && !default.bAllowEmpty)
	{
		EquippedVest = FindBestVest(Unit, XComHQ, NewGameState);
		if (EquippedVest != none)
		{
			`LOG("Empty slot is not allowed, equipping:" @ EquippedVest.GetMyTemplateName(), default.bLog, 'WotC_VestSlot');
			Unit.AddItemToInventory(EquippedVest, eInvSlot_Vest, NewGameState);
		}
		else `LOG("Empty slot is not allowed, but the mod was unable to find an infinite item to fill the slot.", default.bLog, 'WotC_VestSlot');
	}
	else if(EquippedVest != none && !HasSlot)
	{
		`LOG("WARNING Unit has an item equipped in the Vest Slot, but they do not have the Vest Slot. Unequipping the item and putting it into HQ Inventory.", default.bLog, 'WotC_VestSlot');
		EquippedVest = XComGameState_Item(NewGameState.ModifyStateObject(class'XComGameState_Item', EquippedVest.ObjectID));
		Unit.RemoveItemFromInventory(EquippedVest, NewGameState);
		XComHQ.PutItemInInventory(NewGameState, EquippedVest);
		EquippedVest = none;
	}
}

private static function XComGameState_Item FindBestVest(const XComGameState_Unit UnitState, XComGameState_HeadquartersXCom XComHQ, XComGameState NewGameState)
{
	local X2EquipmentTemplate				EquipmentTemplate;
	local XComGameStateHistory				History;
	local int								HighestTier;
	local XComGameState_Item				ItemState;
	local XComGameState_Item				BestItemState;
	local StateObjectReference				ItemRef;

	HighestTier = -999;
	History = `XCOMHISTORY;

	//	Cycle through all items in HQ Inventory
	foreach XComHQ.Inventory(ItemRef)
	{
		ItemState = XComGameState_Item(History.GetGameStateForObjectID(ItemRef.ObjectID));
		if (ItemState != none)
		{
			EquipmentTemplate = X2EquipmentTemplate(ItemState.GetMyTemplate());

			if (EquipmentTemplate != none &&	//	If this is an equippable item
				default.AllowedItemCategories.Find(EquipmentTemplate.ItemCat) != INDEX_NONE &&	//	That has a matching Item Category
				EquipmentTemplate.bInfiniteItem && EquipmentTemplate.Tier > HighestTier &&		//	And is of higher Tier than previously found items
				UnitState.CanAddItemToInventory(EquipmentTemplate, eInvSlot_Vest, NewGameState, ItemState.Quantity, ItemState))	//	And can be equipped on the soldier
			{
				//	Remember this item as the currently best replacement option.
				HighestTier = EquipmentTemplate.Tier;
				BestItemState = ItemState;
			}
		}
	}

	if (BestItemState != none)
	{
		//	This will set up the Item State for modification automatically, or create a new Item State in the NewGameState if the template is infinite.
		XComHQ.GetItemFromInventory(NewGameState, BestItemState.GetReference(), BestItemState);
		return BestItemState;
	}
	else
	{
		return none;
	}
}

function ECHSlotUnequipBehavior VestGetUnequipBehavior(CHItemSlot Slot, ECHSlotUnequipBehavior DefaultBehavior, XComGameState_Unit Unit, XComGameState_Item ItemState, optional XComGameState CheckGameState)
{	
	if (default.bAllowEmpty)
	{
		return eCHSUB_AllowEmpty;
	}
	else
	{
		return eCHSUB_AttemptReEquip;
	}
}