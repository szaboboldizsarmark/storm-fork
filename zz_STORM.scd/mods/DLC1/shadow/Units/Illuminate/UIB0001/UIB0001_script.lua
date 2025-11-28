-----------------------------------------------------------------------------
--  File     : /units/illuminate/uib0001/uib0001_script.lua
--  Author(s): Gordon Duclos, Aaron Lundquist
--  Summary  : SC2 Illuminate Land Factory: UIB0001
--  Copyright © 2009 Gas Powered Games, Inc.  All rights reserved.
-----------------------------------------------------------------------------
local FactoryUnit = import('/lua/sim/FactoryUnit.lua').FactoryUnit
local SeaUnit = import('/lua/sim/SeaUnit.lua').SeaUnit
local AIUtils = import('/lua/ai/aiutilities.lua')

UIB0001 = Class(FactoryUnit) {

	BuildEffectsEmitters = {
		-- '/effects/emitters/units/illuminate/uib0001/event/build/illuminate_build_01_glow_emit.bp',
		-- '/effects/emitters/units/illuminate/uib0001/event/build/illuminate_build_02_plasma_emit.bp',
		-- '/effects/emitters/units/illuminate/uib0001/event/build/illuminate_build_03_sparks_emit.bp',
		-- '/effects/emitters/units/illuminate/uib0001/event/build/illuminate_build_04_smoke_emit.bp',
	},

	OnStopBeingBuilt = function(self,builder,layer)
        FactoryUnit.OnStopBeingBuilt(self,builder,layer)
		self.EffectsBag = {}
    end,

    OnCreate = function(self, createArgs)
        FactoryUnit.OnCreate(self, createArgs)
		if (self:GetCurrentLayer() == "Water") then
			self:AddBuildRestriction(categories.LAND - categories.HOVER - categories.UPGRADEMODULE)
		end
        self:ForkThread(self.NaniteCloudThread)
    end,

	-- StartBuildFx = function(self, unitBeingBuilt)
    --     local army = self:GetArmy()
	--     
	-- 	for k, v in self.BuildEffectsEmitters do
	-- 		self.BuildEffectsBag:Add( CreateAttachedEmitter( self, 'Addon11', army, v ) )
	-- 		self.BuildEffectsBag:Add( CreateAttachedEmitter( self, 'Addon12', army, v ) )
	-- 	end
    -- end,
    
    NaniteCloudThread = function(self)
        while not self:IsDead() do
            if self.NaniteCloudActive then
                -- Get friendly units in the area (including self)
                local affectradius = 30
                local captureCategory = (categories.MOBILE * categories.LAND) - categories.COMMAND - categories.EXPERIMENTAL
                local units = AIUtils.GetOwnUnitsAroundPoint(self:GetAIBrain(), captureCategory, self:GetPosition(), affectradius)
                -- Give them a 5 second regen buff
                for _,unit in units do
                    if not unit:IsDead() then
                        ApplyBuff(unit, 'HealingNaniteCloudBuff')
                    end
                end

                -- Wait 1 second
            end
            WaitSeconds(1)
        end
    end,
    
    CreateExplosionDebris01 = function( self, army, bone )
		CreateEmittersAtBone( self, bone, army, EffectTemplates.Explosions.Land.IlluminateStructureDestroyEffectsSecondary01 )
    end,
    
    CreateExplosionDebris02 = function( self, army )
		CreateEmittersAtEntity( self, army, EffectTemplates.Explosions.Land.IlluminateStructureDestroyEffectsExtraLarge01 )
    end,

    CreateExplosionDebris03 = function( self, army, bone )
    	CreateEmittersAtBone( self, bone, army, EffectTemplates.Units.Illuminate.Experimental.UIX0111.Death01, false, 1, { 0, -2, 0 } )
    end,
    
    CreateExplosionDebris04 = function( self, army, bone )
		CreateEmittersAtBone( self, bone, army, EffectTemplates.Explosions.Land.UEFStructureDestroyEffectsFlash01, false, 1.4, { 0, 8, 0 } )
    end,

    -- By default, just destroy us when we are killed.
    OnKilled = function(self, instigator, type, overkillRatio)
        local layer = self:GetCurrentLayer()
        self:DestroyIdleEffects()
		
        if (not self:IsBeingBuilt() or (self:IsBeingBuilt() and self:GetFractionComplete() > 0.5)) and ( layer == 'Water' or layer == 'Seabed' or layer == 'Sub' ) then
			-- Remove any build scaffolding
			if self.BuildScaffoldUnit and not self.BuildScaffoldUnit:IsDead() then
				self.BuildScaffoldUnit:BuildUnitComplete()
			end
			
			-- Give us a move type so we can sink
			self:SetImmobile(false)
			self:OccupyGround(false)
			self:SetMotionType('RULEUMT_AmphibiousFloating')
			self:CreateNavigator()
			self:PlayUnitSound('Killed')
			self:PlayUnitAmbientSound('Sinking')
            self.SinkThread = self:ForkThread(self.SinkingThread)
            self.Callbacks.OnKilled:Call( self, instigator, type )
            if instigator and IsUnit(instigator) then
                instigator:OnKilledUnit(self)
            end
        else
            self.DeathBounce = 1
            FactoryUnit.OnKilled(self, instigator, type, overkillRatio)
        end
    end,
	
    SinkingThread = function(self)
		if self:PrecacheDebris() then
			WaitTicks(1)
		end

		-- Destroy any ambient damage effects on unit
        self:DestroyAllDamageEffects()

		-- Play destruction effects
		local bp = self:GetBlueprint()
		local ExplosionEffect = bp.Death.ExplosionEffect
		local ExplosionScale = bp.Death.ExplosionEffectScale or 1

		if ExplosionEffect then
			local layer = self:GetCurrentLayer()
			local emitters = EffectTemplates.Explosions[layer][ExplosionEffect]

			if emitters then
                for k, v in emitters do
                    CreateEmitterAtBone( self, -2, self:GetArmy(), v ):ScaleEmitter( ExplosionScale )
                end
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

        self:ForkThread(self.SinkingEffects)
    end,

    OnImpact = function(self, with, other)
		if not self:IsDead() then
			return
		end

        -- This is a bit of safety to keep us from calling the death thread twice in case we bounce twice quickly
        if not self.DeathBounce then
            self:ForkThread(self.DeathThread, self.OverKillRatio )
            self.DeathBounce = 1
        end
    end,

    DeathThread = function(self, overkillRatio, instigator)
        local army = self:GetArmy()
		local bp = self:GetBlueprint()
		local utilities = import('/lua/system/utilities.lua')
		local GetRandomFloat = utilities.GetRandomFloat

		self:PlayUnitSound('Destroyed')

        if self:GetCurrentLayer() == 'Water' then
			SeaUnit.DeathThread(self, overkillRatio)
        else
            FactoryUnit.DeathThread(self, overkillRatio)
        end
        self:ForkThread(self.SeaFloorImpactEffects)

        -- delay so dust impact effects can cover up the wreckage/prop swap
        WaitSeconds(1.0)

        local bp = self:GetBlueprint()
		self:StopUnitAmbientSound('Sinking')
		
        self:CreateExplosionDebris01( army, 'Addon04' )
        WaitSeconds(0.2)
        self:CreateExplosionDebris01( army, 'Addon02' )
        WaitSeconds(0.4)
        self:CreateExplosionDebris03( army, 'Addon09' )
        WaitSeconds(0.1)
        self:ExplosionTendrils( self )

        -- Create destruction debris fragments.
		self:CreateUnitDestructionDebris()

		WaitSeconds(0.1)

		self:CreateExplosionDebris02( army )
		self:CreateExplosionDebris04( army, -2 )

		WaitSeconds(0.2)

		if self.DeathAnimManip then
            WaitFor(self.DeathAnimManip)
        end

        --self:CreateWreckage(0.1)

		local scale = bp.Physics.SkirtSizeX + bp.Physics.SkirtSizeZ
		CreateDecal(self:GetPosition(),GetRandomFloat(0,2*math.pi),'/textures/Terrain/Decals/scorch_001_diffuse.dds', '', '', scale , scale, GetRandomFloat(200,350), GetRandomFloat(300,600), self:GetArmy(), 3 )

        --self:Destroy()
        
		-- Create unit wreckage
        self:CreateWreckage( overkillRatio )

        self:PlayUnitSound('Destroyed')
        self:Destroy()
    end,

    SeaFloorImpactEffects = function(self)
        local sx, sy, sz = self:GetUnitSizes()
        local vol = sx * sz  / 7
        CreateAttachedEmitter(self,-2,self:GetArmy(),'/effects/emitters/units/general/event/death/destruction_underwater_seafloordust_01_emit.bp'):ScaleEmitter(vol/12)
    end,

    SinkingEffects = function(self)
        local i = 8 -- initializing the above surface counter
        local sx, sy, sz = self:GetUnitSizes()
        local vol = sx * sz / 7
        local army = self:GetArmy()

        while i >= 0 do
            if i > 0 then
                local rx, ry, rz = self:GetRandomOffset(1)
                local rs = Random(vol/2, vol*2) / (vol*2)
                CreateAttachedEmitter(self,-1,army,'/effects/emitters/units/general/event/death/destruction_water_sinking_ripples_01_emit.bp'):OffsetEmitter(rx, 0, rz):ScaleEmitter(rs)

                local rx, ry, rz = self:GetRandomOffset(1)
                CreateAttachedEmitter(self,self.Addon01,army, '/effects/emitters/units/general/event/death/destruction_water_sinking_wash_01_emit.bp'):OffsetEmitter(rx, 0, rz):ScaleEmitter(rs)

                local rx, ry, rz = self:GetRandomOffset(1)
                CreateAttachedEmitter(self,self.Addon03,army, '/effects/emitters/units/general/event/death/destruction_water_sinking_wash_01_emit.bp'):OffsetEmitter(rx, 0, rz):ScaleEmitter(rs)
            end

            local rx, ry, rz = self:GetRandomOffset(1)
            local rs = Random(vol/2.5, vol*2.5) / (vol*2.5)
            CreateAttachedEmitter(self,-2,army,'/effects/emitters/units/general/event/death/destruction_underwater_sinking_wash_01_emit.bp'):OffsetEmitter(rx, 0, rz):ScaleEmitter(rs)
            CreateAttachedEmitter(self,-2,army,'/effects/emitters/units/general/event/death/destruction_water_sinking_bubbles_01_emit.bp'):OffsetEmitter(rx, 0, rz):ScaleEmitter(vol/8)

            i = i - 1
            WaitSeconds(1)
        end
    end,
}
TypeClass = UIB0001