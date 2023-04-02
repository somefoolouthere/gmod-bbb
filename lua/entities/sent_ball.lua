AddCSLuaFile()

DEFINE_BASECLASS( "base_anim" )

ENT.PrintName = "Bouncy Ball"
ENT.Author =	"Garry Newman"
ENT.Information = "An edible bouncy ball"
ENT.Category =	"Fun + Games"

ENT.Editable =	true
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

ENT.MinSize = 1 -- Less restricted size limits
ENT.MaxSize = 512

function ENT:SetupDataTables()

	self:NetworkVar( "Float",	0, "BallSize",		{ KeyName = "ballsize",			Edit = { type = "Float",	min = self.MinSize, max = self.MaxSize,	order = 1, title = "Size"								} } )
	self:NetworkVar( "Vector",	0, "BallColor",		{ KeyName = "ballcolor",		Edit = { type = "VectorColor",										order = 2, title = "Color"								} } )
	self:NetworkVar( "Float",	1, "Bounciness",	{ Keyname = "bounciness",		Edit = { type = "Float",	min = 0,			max = 2,			order = 3, title = "Bounciness"							} } ) -- New options
	self:NetworkVar( "String",	0, "BounceSound",	{ Keyname = "bouncesound",		Edit = { type = "Generic",											order = 4, title = "Bounce Sound",	waitforenter = true	} } )
	self:NetworkVar( "Int",		0, "HealAmount",	{ Keyname = "healamount",		Edit = { type = "Int",		min = 0,			max = 100,			order = 5, title = "Heal Amount"						} } )
	self:NetworkVar( "Bool",	0, "AllowOverheal",	{ Keyname = "allowoverheal",	Edit = { type = "Boolean",											order = 6, title = "Allow Overhealing"					} } )

	if ( SERVER ) then
	self:NetworkVarNotify( "BallSize", self.OnBallSizeChanged )
	end

end

-- This is the spawn function. It's called when a client calls the entity to be spawned.
-- If you want to make your SENT spawnable you need one of these functions to properly create the entity
--
-- ply is the name of the player that is spawning it
-- tr is the trace from the player's eyes
--
function ENT:SpawnFunction( ply, tr, ClassName )

	if ( !tr.Hit ) then return end

	local size = math.random( 16, 48 )
	local SpawnPos = tr.HitPos + tr.HitNormal * size

	-- Make sure the spawn position is not out of bounds
	local oobTr = util.TraceLine( {
		start = tr.HitPos,
		endpos = SpawnPos,
		mask = MASK_SOLID_BRUSHONLY
	} )

	if ( oobTr.Hit ) then
		SpawnPos = oobTr.HitPos + oobTr.HitNormal * ( tr.HitPos:Distance( oobTr.HitPos ) / 2 )
	end

	local ent = ents.Create( ClassName )
	ent:SetPos( SpawnPos )
	ent:SetBallSize( size )
	ent:SetBounciness( 0.9 )
	ent:SetBounceSound( "garrysmod/ball_bounce.wav" )
	ent:SetHealAmount( 5 )
	ent:SetAllowOverheal( true )
	ent:Spawn()
	ent:Activate()

	return ent

end

function ENT:Initialize()

	-- We do NOT want to execute anything below in this FUNCTION on CLIENT
	if ( CLIENT ) then return end

	-- Helicopter bomb was a crappy choice for a model
	self:SetModel( "models/XQM/Rails/gumball_1.mdl" )

	-- We will put this here just in case, even though it should be called from OnBallSizeChanged in any case
	self:RebuildPhysics()

	-- Select a random color for the ball
	self:SetBallColor( table.Random( {
		Vector( 1, 0.3, 0.3 ), -- Default Red
		Vector( 0.3, 1, 0.3 ), -- Default Green
		Vector( 1, 1, 0.3 ), -- Default Yellow
		Vector( 0.2, 0.3, 1 ), -- Default Blue
		Vector( 0.5, 0.5, 0.5 ), -- The Gray One
		Vector( 0.1, 0.1, 0.1 ), -- Black
		Vector( 1, 1, 1 ), -- White
		Vector( 1, 0.3, 1 ), -- Magenta
		Vector( 0.3, 1, 1 ), -- Cyan
		Vector( 0.3, 0.3, 1 ), -- Blue
		Vector( 1, 0.4, 0.3 ), -- Orange
		Vector( 0.4, 0.3, 1 ), -- Purple
		Vector( 0.3, 0.6, 1 ), -- Turquoise
		Vector( 0.3, 0.5, 1 ), -- Turquoise 2
		Vector( 0.5, 0.3, 1 ), -- Purple 2
		Vector( 1, 0.3, 0.5 ), -- Magenta 2
		Vector( 0.3, 1, 0.5 ), -- Mint
		Vector( 0.5, 1, 0.3 ), -- Lime Green
	} ) )

end

function ENT:RebuildPhysics( value )

	local size = math.Clamp( value or self:GetBallSize(), self.MinSize, self.MaxSize ) / 2.1
	self:PhysicsInitSphere( size, "metal_bouncy" )
	self:SetCollisionBounds( Vector( -size, -size, -size ), Vector( size, size, size ) )

	self:PhysWake()

end

if ( SERVER ) then
function ENT:OnBallSizeChanged( varname, oldvalue, newvalue )

	-- Do not rebuild if the size wasn't changed
	if ( oldvalue == newvalue ) then return end

	self:RebuildPhysics( newvalue )

end
end

-- local BounceSound = Sound( "garrysmod/ball_bounce.wav" )

function ENT:PhysicsCollide( data, physobj )

	-- Play sound on bounce
	if ( data.Speed > 20 && data.DeltaTime > 0.1 ) then -- More bouncing sounds
		local pitch = 255 / ( ( math.Clamp( self:GetBallSize(), self.MinSize, self.MaxSize ) + 16 ) / 24 ) -- New better sound pitch calculation
		sound.Play( self:GetBounceSound(), self:GetPos(), 75, math.random( pitch - ( 0.07 * pitch ), pitch + ( 0.07 * pitch ) ), math.Clamp( ( data.Speed / 150 ) / ( pitch / 32 ), 0, 1 ) ) -- Pitch variation and volume adjusts to ball size
end

	-- Bounce like a crazy bitch
	local LastSpeed = math.max( data.OurOldVelocity:Length(), data.Speed )
	local NewVelocity = physobj:GetVelocity()
	NewVelocity:Normalize()

	LastSpeed = math.max( NewVelocity:Length(), LastSpeed )

	local TargetVelocity = NewVelocity * LastSpeed * self:GetBounciness()

	physobj:SetVelocity( TargetVelocity )

end

function ENT:OnTakeDamage( dmginfo )

	-- React physically when shot/getting blown
	self:TakePhysicsDamage( dmginfo )

end

function ENT:Use( activator, caller )

	if ( activator:IsPlayer() ) then
		-- Give the collecting player some free health
		local health = activator:Health()
		if ( !self:GetAllowOverheal() ) then
			if ( health < 100 ) then -- Prevent overheal the proper way
				self:Remove()
				activator:SetHealth( math.Clamp( health + self:GetHealAmount(), -math.huge, activator:GetMaxHealth() ) )
				activator:SendLua( "achievements.EatBall()" )
			end
		else
			self:Remove()
			activator:SetHealth( health + self:GetHealAmount() )
			activator:SendLua( "achievements.EatBall()" )
		end
	else
		self:Remove()
	end
end

if ( SERVER ) then return end -- We do NOT want to execute anything below in this FILE on SERVER

local matBall = Material( "sprites/sent_ball" )

function ENT:Draw()

	render.SetMaterial( matBall )

	local pos = self:GetPos()
	local lcolor = render.ComputeLighting( pos, Vector( 0, 0, 1 ) )
	local c = self:GetBallColor()

	lcolor.x = c.r * ( math.Clamp( lcolor.x, 0, 1 ) + 0.5 ) * 255
	lcolor.y = c.g * ( math.Clamp( lcolor.y, 0, 1 ) + 0.5 ) * 255
	lcolor.z = c.b * ( math.Clamp( lcolor.z, 0, 1 ) + 0.5 ) * 255

	local size = math.Clamp( self:GetBallSize(), self.MinSize, self.MaxSize )
	render.DrawSprite( pos, size, size, Color( lcolor.x, lcolor.y, lcolor.z, 255 ) )

end