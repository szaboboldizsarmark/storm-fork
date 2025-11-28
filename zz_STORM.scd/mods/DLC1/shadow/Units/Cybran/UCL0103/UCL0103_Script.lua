-----------------------------------------------------------------------------
--  File     :  /units/cybran/ucl0103/ucl0103_script.lua
--  Author(s):  Aaron Lundquist, Gordon Duclos
--  Summary  :  SC2 Cybran Assault Bot: UCL0103
--  Copyright © 2009 Gas Powered Games, Inc.  All rights reserved.
-----------------------------------------------------------------------------
local MobileUnit = import('/lua/sim/MobileUnit.lua').MobileUnit
local DefaultProjectileWeapon = import('/lua/sim/DefaultWeapons.lua').DefaultProjectileWeapon
local TurretWeapon = import('/lua/sim/weapon.lua').TurretWeapon

UCL0103 = Class(MobileUnit)
{
	DestructionExplosionWaitDelayMin = 0.6,
	DestructionExplosionWaitDelayMax = 0.8,
	
    Weapons = {
        Laser01 = Class(TurretWeapon) {},
        Laser02 = Class(DefaultProjectileWeapon) {},
        Laser03 = Class(DefaultProjectileWeapon) {},
    },
	
    OnResearchedTechnologyAdded = function( self, upgradeName, level, modifierGroup )
        MobileUnit.OnResearchedTechnologyAdded( self, upgradeName, level, modifierGroup )
        if upgradeName == "CLB_MOVESPEED" then
            self:ForkThread(self.SpeedCheck)
        end
    end,

    SpeedCheck = function(self)
        while not self:IsDead() do
            WaitSeconds( 5 )
            self:SetNavMaxSpeedMultiplier(self:GetSpeedMult())
        end
    end,
}
TypeClass = UCL0103