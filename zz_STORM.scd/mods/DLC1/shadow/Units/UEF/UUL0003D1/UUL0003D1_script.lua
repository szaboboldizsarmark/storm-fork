-----------------------------------------------------------------------------
--  File     : /units/uef/UUL0003D1/UUL0003D1_script.lua
--  Author(s): Gordon Duclos
--  Summary  : SC2 UEF Engineer: UUL0003D1
--  Copyright © 2009 Gas Powered Games, Inc.  All rights reserved.
-----------------------------------------------------------------------------
local ConstructionUnit = import('/lua/sim/ConstructionUnit.lua').ConstructionUnit
local DefaultProjectileWeapon = import('/lua/sim/DefaultWeapons.lua').DefaultProjectileWeapon
local TurretWeapon = import('/lua/sim/weapon.lua').TurretWeapon

UUL0003D1 = Class(ConstructionUnit) {

  	-- AmbientEffects01 = {
	-- 	'/effects/emitters/units/uef/uul0003d1/ambient/uef_uul0003d1_01_spinlight_emit.bp',
	-- 	'/effects/emitters/units/uef/uul0003d1/ambient/uef_uul0003d1_02_glowlight_emit.bp',
	-- },

    Weapons = {
        MainGun1 = Class(DefaultProjectileWeapon) { },
        MainGun2 = Class(DefaultProjectileWeapon) { },
    },

	OnCreate = function(self, createArgs)
		ConstructionUnit.OnCreate(self, createArgs)
		self:SetProductionActive(false)
		self.AmbientEffectsBag = {}
	end,

    OnStopBeingBuilt = function(self,builder,layer)
        ConstructionUnit.OnStopBeingBuilt(self,builder,layer)
        self.CustomUnpackSpinners = {
            -- CreateRotator(unit, bone, axis, [goal], [speed], [accel], [goalspeed])
            Spinner1 = CreateRotator(self, 'UUL0003D1_MidLever', 'x', 0, 300, 300),
            Spinner2 = CreateRotator(self, 'UUL0003D1_Lever01', '-x', 0, 300, 300),
            Spinner3 = CreateRotator(self, 'T01_Barrel01', 'x', 0, 300, 300),
        }
		self:CreateAmbientEffect()
    end,

    -- By default, just destroy us when we are killed.
    OnKilled = function(self, instigator, type, overkillRatio)
        local layer = self:GetCurrentLayer()
        self:DestroyIdleEffects()
        if(layer == 'Water' or layer == 'Seabed' or layer == 'Sub')then
            self.SinkThread = self:ForkThread(self.SinkingThread)
			self:PlayUnitAmbientSound('Sinking')
        end
        ConstructionUnit.OnKilled(self, instigator, type, overkillRatio)
    end,

    -- CreateAmbientEffect = function(self)
       -- -- Ambient effects
        -- for k, v in self.AmbientEffects01 do
		--	table.insert( self.AmbientEffectsBag, CreateAttachedEmitter( self, 'Turret01', self:GetArmy(), v ) )
		-- end
    -- end,
    
	OnAddToStorage = function(self, unit)
		self:DestroyAmbientEffect{}
		ConstructionUnit.OnAddToStorage(self, unit)
	end,
	
	DestroyAmbientEffect = function(self)
		if self.AmbientEffectsBag then
			for k, v in self.AmbientEffectsBag do
				v:Destroy()
			end
			self.AmbientEffectsBag = {}	
		end
	end,
	
	OnRemoveFromStorage = function(self, unit)
		self:CreateAmbientEffect()
		ConstructionUnit.OnRemoveFromStorage(self, unit)
	end,
	
    SinkingThread = function(self)
        local i = 8 -- initializing the above surface counter
        local sx, sy, sz = self:GetUnitSizes()
        local vol = sx * sy * sz
        local army = self:GetArmy()

		if self:PrecacheDebris() then
			WaitTicks(1)
		end

		-- Destroy any ambient damage effects on unit
        self:DestroyAllDamageEffects()

		-- Play destruction effects
		local bp = self:GetBlueprint()
		local ExplosionEffect = bp.Death.ExplosionEffect

		if ExplosionEffect then
			local faction = bp.General.FactionName
			local layer = self:GetCurrentLayer()
			local emitters = EffectTemplates.Units[faction][layer].General[ExplosionEffect]
			if emitters then
				CreateBoneEffects( self, -2, self:GetArmy(), emitters )
			end
		end

		if bp.Death.DebrisPieces then
			self:DebrisPieces( self )
		end

		if bp.Death.ExplosionTendrils then
			self:ExplosionTendrils( self )
		end

		if bp.Death.Light then
			local myPos = self:GetPosition()
			myPos[2] = myPos[2] + 7
			CreateLight( myPos[1], myPos[2], myPos[3], 0, -1, 0, 10, 4, 0.1, 0.1, 0.5 )
		end

		-- Create destruction debris fragments.
		self:CreateUnitDestructionDebris()

        while i >= 0 do
            if i > 0 then
                local rx, ry, rz = self:GetRandomOffset(1)
                local rs = Random(vol/2, vol*2) / (vol*2)
                CreateAttachedEmitter(self,-1,army,'/effects/emitters/units/general/event/death/destruction_water_sinking_ripples_01_emit.bp'):OffsetEmitter(rx, 0, rz):ScaleEmitter(rs)

                local rx, ry, rz = self:GetRandomOffset(1)
                CreateAttachedEmitter(self,self.LeftFrontWakeBone,army, '/effects/emitters/units/general/event/death/destruction_water_sinking_wash_01_emit.bp'):OffsetEmitter(rx, 0, rz):ScaleEmitter(rs)

                local rx, ry, rz = self:GetRandomOffset(1)
                CreateAttachedEmitter(self,self.RightFrontWakeBone,army, '/effects/emitters/units/general/event/death/destruction_water_sinking_wash_01_emit.bp'):OffsetEmitter(rx, 0, rz):ScaleEmitter(rs)
            end

            local rx, ry, rz = self:GetRandomOffset(1)
            local rs = Random(vol/2, vol*2) / (vol*2)
            CreateAttachedEmitter(self,-1,army,'/effects/emitters/units/general/event/death/destruction_underwater_sinking_wash_01_emit.bp'):OffsetEmitter(rx, 0, rz):ScaleEmitter(rs)

            i = i - 1
            WaitSeconds(1)
        end
    end,

    OnImpact = function(self, with, other)
		if not self:IsDead() then
			return
		end

        -- This is a bit of safety to keep us from calling the death thread twice in case we bounce twice quickly
        if not self.DeathBounce then
			self:StopUnitAmbientSound('Sinking')
            self:ForkThread(self.DeathThread, self.OverKillRatio )
            self.DeathBounce = 1
        end
    end,

    HandleBuildArm = function(self, enable)
        if enable then
            self.CustomUnpackSpinners.Spinner1:SetGoal(30)
            self.CustomUnpackSpinners.Spinner2:SetGoal(120)
            self.CustomUnpackSpinners.Spinner3:SetGoal(90)
        else
            self.CustomUnpackSpinners.Spinner1:SetGoal(0)
            self.CustomUnpackSpinners.Spinner2:SetGoal(0)
            self.CustomUnpackSpinners.Spinner3:SetGoal(0)
        end
        WaitSeconds(0.5)
    end,

    CreateMovementEffects = function( self, EffectsBag, TypeSuffix, TerrainType )
        local layer = self:GetCurrentLayer()
        local bpTable = self:GetBlueprint().Display.MovementEffects

        if bpTable[layer] then
            bpTable = bpTable[layer]
            local effectTypeGroups = bpTable.Effects

			if layer != 'Water' then
				if bpTable.Treads.ScrollTreads then
					self:AddThreadUVRScroller(1, 1, 1.0, bpTable.Treads.ScrollMultiplier or 0.2)
					self:AddThreadUVRScroller(2, 1, -1.0, bpTable.Treads.ScrollMultiplier or 0.2)
				end
			end

            if (not effectTypeGroups or (effectTypeGroups and (table.getn(effectTypeGroups) == 0))) then
                if not self.Footfalls and bpTable.Footfall then
                    LOG('*WARNING: No movement effect groups defined for unit ',repr(self:GetUnitId()),', Effect groups with bone lists must be defined to play movement effects. Add these to the Display.MovementEffects', layer, '.Effects table in unit blueprint. ' )
                end
                return false
            end

            if bpTable.CameraShake then
                self.CamShakeT1 = self:ForkThread(self.MovementCameraShakeThread, bpTable.CameraShake )
            end

            self:CreateTerrainTypeEffects( effectTypeGroups, 'FXMovement', layer, TypeSuffix, EffectsBag, TerrainType )
        end
    end,
}
TypeClass = UUL0003D1