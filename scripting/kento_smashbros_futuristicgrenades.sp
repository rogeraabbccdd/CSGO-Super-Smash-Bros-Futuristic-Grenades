#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Rachnus, Kento"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <emitsoundany>
#include <clientprefs>
#include <kento_smashbros>

#pragma newdecls required
#define BLACKHOLE_VOLUME 5.0
#define FORCEFIELD_VOLUME 5.0
#define EXPLOSION_VOLUME 5.0
#define IMPLOSION_VOLUME 5.0

enum DecoyMode
{
	DecoyMode_Normal = 0,
	DecoyMode_Blackhole,
	DecoyMode_Forcefield,
	DecoyMode_ForceExplosion,
	DecoyMode_ForceImplosion,
	DecoyMode_Max
}

enum ForceFieldMode
{
	ForcefieldMode_Normal = 0,
	ForcefieldMode_Self,
	ForcefieldMode_Max
}

enum ForceExplosionMode
{
	ForceExplosionMode_Ground = 0,
	ForceExplosionMode_World,
	ForceExplosionMode_Max
}

enum ForceImplosionMode
{
	ForceImplosionMode_Ground = 0,
	ForceImplosionMode_World,
	ForceImplosionMode_Max
}

EngineVersion g_Game;

DecoyMode g_eMode[MAXPLAYERS + 1] =  { DecoyMode_Normal, ... };
ForceFieldMode g_eForcefieldMode[MAXPLAYERS + 1] =  { ForcefieldMode_Normal, ... };
ForceExplosionMode g_eForceExplosionMode[MAXPLAYERS + 1] =  { ForceExplosionMode_Ground, ... };
ForceImplosionMode g_eForceImplosionMode[MAXPLAYERS + 1] =  { ForceImplosionMode_Ground, ... };
bool g_bSwitchGrenade[MAXPLAYERS + 1] =  { false, ... };
bool g_bSwitchMode[MAXPLAYERS + 1] =  { false, ... };
int g_PVMid[MAXPLAYERS + 1]; // Predicted ViewModel ID's
int g_iViewModelIndex;
int g_iPathLaserModelIndex;
ArrayList g_hBlackholes;
ArrayList g_hForcefields;
float g_BlackholeVolume[MAXPLAYERS * 2] =  { BLACKHOLE_VOLUME, ... };
float g_ForcefieldVolume[MAXPLAYERS * 2] =  { FORCEFIELD_VOLUME, ... };

//UserMsg g_SayText2;

//GLOBAL
ConVar g_FriendlyFire;
ConVar g_WModelScale;
//BLACKHOLE
ConVar g_BlackholeParticleEffect;
ConVar g_BlackholeMinimumDistance;
ConVar g_BlackholeBounceVelocity;
ConVar g_BlackholeshakePlayer;
ConVar g_BlackholeshakeIntensity;
ConVar g_BlackholeFrequency;
ConVar g_BlackholeForce;
ConVar g_BlackholeDuration;
ConVar g_Blackholesetting;
ConVar g_BlackholeDamage;
ConVar g_BlackholeProps;
ConVar g_BlackholeWeapons;
ConVar g_BlackholeGrenades;
ConVar g_BlackholeFlashbangs;
ConVar g_hBlackholesmokes;
ConVar g_BlackholeIndicator;
//FORCEFIELD
ConVar g_ForcefieldParticleEffect;
ConVar g_ForcefieldMinimumDistance;
ConVar g_ForcefieldBounceVelocity;
ConVar g_ForcefieldForce;
ConVar g_ForcefieldDuration;
ConVar g_ForcefieldProps;
ConVar g_ForcefieldGrenades;
ConVar g_ForcefieldFlashbangs;
ConVar g_hForcefieldsmokes;
ConVar g_ForcefieldIndicator;
ConVar g_ForcefieldMode;
//FORCE EXPLOSION
ConVar g_ExplosionParticleEffect;
ConVar g_ExplosionMinimumDistance;
ConVar g_ExplosionForce;
ConVar g_ExplosionProps;
ConVar g_ExplosionWeapons;
ConVar g_ExplosionGrenades;
ConVar g_ExplosionFlashbangs;
ConVar g_ExplosionSmokes;
ConVar g_ExplosionBounce;
ConVar g_ExplosionBounceVelocity;
ConVar g_ExplosionMode;
//FORCE IMPLOSION
ConVar g_ImplosionParticleEffect;
ConVar g_ImplosionMinimumDistance;
ConVar g_ImplosionProps;
ConVar g_ImplosionWeapons;
ConVar g_ImplosionGrenades;
ConVar g_ImplosionFlashbangs;
ConVar g_ImplosionSmokes;
ConVar g_ImplosionBounce;
ConVar g_ImplosionBounceVelocity;
ConVar g_ImplosionMode;

bool bLibraryExists;

public Plugin myinfo = 
{
	name = "[CS:GO] Super Smash Bros Item - Futuristic Grenades",
	author = PLUGIN_AUTHOR,
	description = "Super Smash Bros Item - Futuristic Grenades",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/kentomatoryoshika/"
};

public void OnPluginStart()
{
	bLibraryExists = LibraryExists("kento_smashbros");

	g_Game = GetEngineVersion();
	if(g_Game != Engine_CSGO)
	{
		SetFailState("This plugin is for CSGO only.");	
	}	
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("decoy_started", Event_DecoyStarted, EventHookMode_Pre);

	//GENERAL CONVARS
	g_FriendlyFire =				CreateConVar("fg_friendlyfire", "1", "Enable/Disable friendly fire", FCVAR_NOTIFY);
	g_WModelScale =				CreateConVar("fg_model_scale", "2.0", "World model scale", FCVAR_NOTIFY, true, 0.0);

	//BLACKHOLE CONVARS
	g_BlackholeParticleEffect =		CreateConVar("fg_blackhole_particle_effect", "blackhole", "Name of the particle effect you want to use for blackholes", FCVAR_NOTIFY);
	g_BlackholeMinimumDistance = 	CreateConVar("fg_blackhole_minimum_distance", "250", "Minimum distance to push player towards black hole", FCVAR_NOTIFY);
	g_BlackholeBounceVelocity = 	CreateConVar("fg_blackhole_bounce_velocity", "300", "Up/Down velocity to push the grenade on bounce", FCVAR_NOTIFY);
	g_BlackholeshakePlayer = 		CreateConVar("fg_blackhole_shake_player", "1", "Shake the player once entering minimum distance", FCVAR_NOTIFY);
	g_BlackholeshakeIntensity =		CreateConVar("fg_blackhole_shake_intensity", "5.0", "Intensity of the shake", FCVAR_NOTIFY);
	g_BlackholeFrequency =			CreateConVar("fg_blackhole_shake_frequency", "0.7", "Frequency of the shake", FCVAR_NOTIFY);
	g_BlackholeForce = 				CreateConVar("fg_blackhole_force", "350", "Force to fly at the black hole", FCVAR_NOTIFY); 
	g_BlackholeDuration = 			CreateConVar("fg_blackhole_duration", "10", "Duration in seconds the blackhole lasts", FCVAR_NOTIFY);
	g_Blackholesetting = 			CreateConVar("fg_blackhole_setting", "1", "0 = Do nothing on entering blackhole origin, 1 = Do damage on entering the blackhole origin", FCVAR_NOTIFY);
	g_BlackholeDamage = 			CreateConVar("fg_blackhole_damage", "0.5", "Damage to do once entering blackhole origin", FCVAR_NOTIFY);
	g_BlackholeProps = 				CreateConVar("fg_blackhole_props", "1", "Push props towards black hole (Client side props will not work)", FCVAR_NOTIFY);
	g_BlackholeWeapons = 			CreateConVar("fg_blackhole_weapons", "1", "Push dropped weapons towards black hole", FCVAR_NOTIFY);
	g_BlackholeGrenades = 			CreateConVar("fg_blackhole_hegrenades", "1", "Push active hand grenades towards black hole", FCVAR_NOTIFY);
	g_BlackholeFlashbangs =			CreateConVar("fg_blackhole_flashbangs", "1", "Push active flashbangs towards black hole", FCVAR_NOTIFY);
	g_hBlackholesmokes = 			CreateConVar("fg_blackhole_smokes", "1", "Push active smoke grenades towards black hole", FCVAR_NOTIFY);
	g_BlackholeIndicator = 			CreateConVar("fg_blackhole_indicator", "0", "Indicate minimum distance to push player towards black hole", FCVAR_NOTIFY);
	
	//FORCEFIELD CONVARS
	g_ForcefieldParticleEffect =	CreateConVar("fg_forcefield_particle_effect", "forcefield", "Name of the particle effect you want to use for forcefields", FCVAR_NOTIFY);
	g_ForcefieldMinimumDistance = 	CreateConVar("fg_forcefield_minimum_distance", "300", "Minimum distance to push player away from forcefield", FCVAR_NOTIFY);
	g_ForcefieldBounceVelocity = 	CreateConVar("fg_forcefield_bounce_velocity", "300", "Up/Down velocity to push the grenade on bounce", FCVAR_NOTIFY);
	g_ForcefieldForce = 			CreateConVar("fg_forcefield_force", "350", "Force to push away from forcefield", FCVAR_NOTIFY); 
	g_ForcefieldDuration = 			CreateConVar("fg_forcefield_duration", "10", "Duration in seconds the forcefield lasts", FCVAR_NOTIFY);
	g_ForcefieldProps = 			CreateConVar("fg_forcefield_props", "1", "Push props away from forcefield", FCVAR_NOTIFY);
	g_ForcefieldGrenades = 			CreateConVar("fg_forcefield_hegrenades", "1", "Push active hand grenades away from forcefield", FCVAR_NOTIFY);
	g_ForcefieldFlashbangs =		CreateConVar("fg_forcefield_flashbangs", "1", "Push active flashbangs away from forcefield", FCVAR_NOTIFY);
	g_hForcefieldsmokes = 			CreateConVar("fg_forcefield_smokes", "1", "Push active smoke grenades away from forcefield", FCVAR_NOTIFY);
	g_ForcefieldIndicator = 		CreateConVar("fg_forcefield_indicator", "1", "Indicate minimum distance to push player away from force field", FCVAR_NOTIFY);
	g_ForcefieldMode = CreateConVar("fg_forcefield_mode", "1", "0 = Push all except owner, 1 = Push all", FCVAR_NOTIFY);
	
	//FORCE EXPLOSION CONVARS
	g_ExplosionParticleEffect =		CreateConVar("fg_explosion_particle_effect", "explosion", "Name of the particle effect you want to use for force explosions", FCVAR_NOTIFY);
	g_ExplosionMinimumDistance =	CreateConVar("fg_explosion_minimum_distance", "300", "Minimum distance to push player away from force explosions", FCVAR_NOTIFY);
	g_ExplosionForce =				CreateConVar("fg_explosion_force", "800", "Force to push away from force explosions", FCVAR_NOTIFY); 
	g_ExplosionProps =				CreateConVar("fg_explosion_props", "1", "Push props away from force explosions", FCVAR_NOTIFY);
	g_ExplosionWeapons =			CreateConVar("fg_explosion_weapons", "1", "Push dropped weapons away from force explosions", FCVAR_NOTIFY);
	g_ExplosionGrenades =			CreateConVar("fg_explosion_hegrenades", "1", "Push active hand grenades away from force explosions", FCVAR_NOTIFY);
	g_ExplosionFlashbangs =			CreateConVar("fg_explosion_flashbangs", "1", "Push active flashbangs away from force explosions", FCVAR_NOTIFY);
	g_ExplosionSmokes =				CreateConVar("fg_explosion_smokes", "1", "Push active smoke grenades away from force explosions", FCVAR_NOTIFY);
	g_ExplosionBounce =				CreateConVar("fg_explosion_bounce", "0", "Bounce the grenade before activating", FCVAR_NOTIFY);
	g_ExplosionBounceVelocity =		CreateConVar("fg_explosion_bounce_velocity", "300", "Up/Down velocity to push the grenade on bounce (If fg_explosion_bounce enabled)", FCVAR_NOTIFY);
	g_ExplosionMode = CreateConVar("fg_explosion_mode", "1", "0 = Ground, 1 = World", FCVAR_NOTIFY);

	//FORCE IMPLOSION CONVARS
	g_ImplosionParticleEffect =		CreateConVar("fg_implosion_particle_effect", "implosion", "Name of the particle effect you want to use for force implosions", FCVAR_NOTIFY);
	g_ImplosionMinimumDistance = 	CreateConVar("fg_implosion_minimum_distance", "500", "Minimum distance to push player towards force implosions", FCVAR_NOTIFY);
	g_ImplosionProps =				CreateConVar("fg_implosion_props", "1", "Push props towards force implosions", FCVAR_NOTIFY);
	g_ImplosionWeapons =			CreateConVar("fg_implosion_weapons", "1", "Push dropped weapons towards force implosions", FCVAR_NOTIFY);
	g_ImplosionGrenades =			CreateConVar("fg_implosion_hegrenades", "1", "Push active hand grenades towards force implosions", FCVAR_NOTIFY);
	g_ImplosionFlashbangs =			CreateConVar("fg_implosion_flashbangs", "1", "Push active flashbangs towards force implosions", FCVAR_NOTIFY);
	g_ImplosionSmokes =				CreateConVar("fg_implosion_smokes", "1", "Push active smoke grenades towards force implosions", FCVAR_NOTIFY);
	g_ImplosionBounce =				CreateConVar("fg_implosion_bounce", "0", "Bounce the grenade before activating", FCVAR_NOTIFY);
	g_ImplosionBounceVelocity =		CreateConVar("fg_implosion_bounce_velocity", "300", "Up/Down velocity to push the grenade on bounce (If fg_implosion_bounce enabled)", FCVAR_NOTIFY);
	g_ImplosionMode = CreateConVar("fg_implosion_mode", "1", "0 = Ground, 1 = World", FCVAR_NOTIFY);

	for (int i = 1; i <= MaxClients;i++)
	{
		if(IsClientInGame(i))
		{
			if(!IsFakeClient(i))
			{
				SDKHook(i, SDKHook_WeaponSwitchPost, OnClientWeaponSwitchPost);
				g_PVMid[i] = Weapon_GetViewModelIndex(i, -1);
			}
		}
	}

	g_hBlackholes = new ArrayList();
	g_hForcefields = new ArrayList();
	AutoExecConfig(true, "futuristicgrenades");
}

public void OnLibraryAdded(const char [] name)
{
  if (StrEqual(name, "kento_smashbros"))
  {
    bLibraryExists = true;
  }
}

public void OnAllPluginsLoaded()
{
  bLibraryExists = LibraryExists("kento_smashbros");
}

public void OnLibraryRemoved(const char [] name)
{
  if (StrEqual(name, "kento_smashbros"))
  {
    bLibraryExists = false;
  }
}

public void ShakeScreen(int client, float intensity, float duration, float frequency)
{
		Handle pb;
		if((pb = StartMessageOne("Shake", client)) != null)
		{
				PbSetFloat(pb, "local_amplitude", intensity);
				PbSetFloat(pb, "duration", duration);
				PbSetFloat(pb, "frequency", frequency);
				EndMessage();
		}
}

public void OnGameFrame()
{
	UpdateBlackHoles();
	UpdateForceFields();
}

void UpdateBlackHoles()
{
	for (int index = 0; index < g_hBlackholes.Length; index++)
	{
		int iBlackhole = EntRefToEntIndex(g_hBlackholes.Get(index));
		if(IsValidEntity(iBlackhole))
		{
			for (int client = 1; client <= MaxClients; client++)
			{
				if(IsClientInGame(client) && IsPlayerAlive(client))
				{
					if(!g_FriendlyFire.BoolValue)
					{
						int owner = GetEntPropEnt(iBlackhole, Prop_Data, "m_hOwnerEntity");
						if(owner < 1 || owner > MaxClients)
						{
							g_hBlackholes.Erase(index);
							AcceptEntityInput(iBlackhole, "Kill");
							break;
						}
						
						if(!IsClientInGame(owner))
						{
							g_hBlackholes.Erase(index);
							AcceptEntityInput(iBlackhole, "Kill");
							break;
						}
							
						int ownerteam = GetClientTeam(owner);
						if((ownerteam != GetClientTeam(client)) || client == owner)
							PushPlayersToBlackHole(client, owner, iBlackhole);
					}
					else
					{
						int owner = GetEntPropEnt(iBlackhole, Prop_Data, "m_hOwnerEntity");

						if(owner < 1 || owner > MaxClients || !IsClientInGame(owner))
						{
							owner = -1;
						}

						PushPlayersToBlackHole(client, owner, iBlackhole);
					}
				}
			}
		
			if(g_BlackholeProps.BoolValue)
				PushToBlackHole(iBlackhole, "prop_physics*");
				
			if(g_BlackholeWeapons.BoolValue)
				PushToBlackHole(iBlackhole, "weapon_*");
			
			if(g_BlackholeGrenades.BoolValue)
				PushToBlackHole(iBlackhole, "hegrenade_projectile");
	
			if(g_BlackholeFlashbangs.BoolValue)
				PushToBlackHole(iBlackhole, "flashbang_projectile");
		
			if(g_hBlackholesmokes.BoolValue)
				PushToBlackHole(iBlackhole, "smokegrenade_projectile");	
		}
		else
			g_hBlackholes.Erase(index);		
	}
}

void UpdateForceFields()
{
	for (int index = 0; index < g_hForcefields.Length; index++)
	{
		int iForcefield = EntRefToEntIndex(g_hForcefields.Get(index));
		if(IsValidEntity(iForcefield))
		{
			for (int client = 1; client <= MaxClients; client++)
			{
				if(IsClientInGame(client) && IsPlayerAlive(client))
				{
					if(!g_FriendlyFire.BoolValue)
					{
						int owner = GetEntPropEnt(iForcefield, Prop_Data, "m_hOwnerEntity");
						
						if(owner < 1 || owner > MaxClients)
						{
							g_hForcefields.Erase(index);
							AcceptEntityInput(iForcefield, "Kill");
							break;
						}
						
						if(!IsClientInGame(owner))
						{
							g_hForcefields.Erase(index);
							AcceptEntityInput(iForcefield, "Kill");
							break;
						}
						
						int ownerteam = GetClientTeam(owner);
						
						if(ownerteam != GetClientTeam(client) || (client == owner && g_eForcefieldMode[owner] == ForcefieldMode_Self))
							PushPlayersAwayFromForceField(client, iForcefield);
					}
					else
					{
						int owner = GetEntPropEnt(iForcefield, Prop_Data, "m_hOwnerEntity");
						if(client == owner)
						{
							if(g_eForcefieldMode[owner] == ForcefieldMode_Self)
								PushPlayersAwayFromForceField(client, iForcefield);
						}
						else
							PushPlayersAwayFromForceField(client, iForcefield);
					}
				}
			}				
		
			if(g_ForcefieldProps.BoolValue)
				PushAwayFromForceField(iForcefield, "prop_physics*");
			
			if(g_ForcefieldGrenades.BoolValue)
				PushAwayFromForceField(iForcefield, "hegrenade_projectile");
	
			if(g_ForcefieldFlashbangs.BoolValue)
				PushAwayFromForceField(iForcefield, "flashbang_projectile");
		
			if(g_hForcefieldsmokes.BoolValue)
				PushAwayFromForceField(iForcefield, "smokegrenade_projectile");	
		}
		else
			g_hForcefields.Erase(index);
	}
}

void PushPlayersAwayFromForceField(int client, int iForcefield)
{
	if(IsValidEntity(iForcefield))
	{
		float clientPos[3], forcefieldPos[3];
		GetClientAbsOrigin(client, clientPos);
		GetEntPropVector(iForcefield, Prop_Send, "m_vecOrigin", forcefieldPos);
		
		float distance = GetVectorDistance(clientPos, forcefieldPos);

		if(distance < g_ForcefieldMinimumDistance.FloatValue)
		{
			SetEntPropEnt(client, Prop_Data, "m_hGroundEntity", -1);
			
			float direction[3];
			SubtractVectors(forcefieldPos, clientPos, direction);
			
			float gravityForce = FindConVar("sv_gravity").FloatValue * (((g_ForcefieldForce.FloatValue * g_ForcefieldMinimumDistance.FloatValue / 50) * 20.0) / GetVectorLength(direction,true));
			gravityForce = gravityForce / 20.0;
			
			NormalizeVector(direction, direction);
			ScaleVector(direction, gravityForce);
			
			float playerVel[3];
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", playerVel);

			ScaleVector(direction, distance / 300);
			SubtractVectors(playerVel, direction, direction);
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, direction);
		}
	}
}

void PushPlayersToBlackHole(int client, int owner, int iBlackhole)
{
	if(!bLibraryExists) return;
	
	if(IsValidEntity(iBlackhole))
	{
		float clientPos[3], blackholePos[3];
		GetClientAbsOrigin(client, clientPos);
		GetEntPropVector(iBlackhole, Prop_Send, "m_vecOrigin", blackholePos);
		
		float distance = GetVectorDistance(clientPos, blackholePos);

		if(distance < 20.0)
		{
			if(g_BlackholeshakePlayer.BoolValue)
				ShakeScreen(client, g_BlackholeshakeIntensity.FloatValue, 0.1, g_BlackholeFrequency.FloatValue);
						
			if(g_Blackholesetting.IntValue == 1)
			{
				bool dodmg = false;
				if (owner == -1 || !IsClientInGame(owner))
				{
					owner = iBlackhole;
					dodmg = true;
				}
				else {
					bool ff = SB_IsFriendlyFire();
					if(ff || (!ff && GetClientTeam(owner) != GetClientTeam(client))) {
						dodmg = true;
					}
				}
				if(dodmg) {
					float dmg = SB_GetClientDamage(client) + g_BlackholeDamage.FloatValue;
					SB_SetClientDamage(client, dmg);
				}
			}
		}
		if(distance < g_BlackholeMinimumDistance.FloatValue)
		{
			if(g_BlackholeshakePlayer.BoolValue)
				ShakeScreen(client, g_BlackholeshakeIntensity.FloatValue, 0.1, g_BlackholeFrequency.FloatValue);
				
			SetEntPropEnt(client, Prop_Data, "m_hGroundEntity", -1);

			float direction[3];
			SubtractVectors(blackholePos, clientPos, direction);
			
			float gravityForce = FindConVar("sv_gravity").FloatValue * (((g_BlackholeForce.FloatValue * g_BlackholeMinimumDistance.FloatValue / 50) * 20.0) / GetVectorLength(direction,true));
			gravityForce = gravityForce / 20.0;
			
			NormalizeVector(direction, direction);
			ScaleVector(direction, gravityForce);
			
			float playerVel[3];
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", playerVel);
			NegateVector(direction);
			ScaleVector(direction, distance / 300);
			SubtractVectors(playerVel, direction, direction);
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, direction);
		}
	}
}

void PushToBlackHole(int iBlackhole, const char[] classname)
{
	int iEnt = MaxClients + 1;
	while((iEnt = FindEntityByClassname(iEnt, classname)) != -1)
	{
		float propPos[3], blackholePos[3];
		GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", propPos);
		GetEntPropVector(iBlackhole, Prop_Send, "m_vecOrigin", blackholePos);
		
		float distance = GetVectorDistance(propPos, blackholePos);
		if(distance > 20.0 && distance < g_BlackholeMinimumDistance.FloatValue)
		{
			float direction[3];
			SubtractVectors(blackholePos, propPos, direction);
			
			float gravityForce = FindConVar("sv_gravity").FloatValue * (((g_BlackholeForce.FloatValue * g_BlackholeMinimumDistance.FloatValue / 50) * 20.0) / GetVectorLength(direction,true));
			gravityForce = gravityForce / 20.0;
			
			NormalizeVector(direction, direction);
			ScaleVector(direction, gravityForce);
			
			float entityVel[3];
			GetEntPropVector(iEnt, Prop_Data, "m_vecVelocity", entityVel);
			NegateVector(direction);
			ScaleVector(direction, distance / 300);
			SubtractVectors(entityVel, direction, direction);
			TeleportEntity(iEnt, NULL_VECTOR, NULL_VECTOR, direction);
		}
	}
}

void PushAwayFromForceField(int iForcefield, const char[] classname)
{
	int iEnt = MaxClients + 1;
	while((iEnt = FindEntityByClassname(iEnt, classname)) != -1)
	{
		int entityowner = GetEntPropEnt(iEnt, Prop_Data, "m_hOwnerEntity");
		int forcefieldowner = GetEntPropEnt(iForcefield, Prop_Data, "m_hOwnerEntity");
		
		if(entityowner > 0 && entityowner <= MaxClients)
		{
			if(entityowner == forcefieldowner)		
			{
				if(g_eForcefieldMode[forcefieldowner] == ForcefieldMode_Self)
				{
					float propPos[3], forcefieldPos[3];
					GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", propPos);
					GetEntPropVector(iForcefield, Prop_Send, "m_vecOrigin", forcefieldPos);
					
					float distance = GetVectorDistance(propPos, forcefieldPos);
					if(distance < g_ForcefieldMinimumDistance.FloatValue)
					{
						float direction[3];
						SubtractVectors(forcefieldPos, propPos, direction);
						
						float gravityForce = FindConVar("sv_gravity").FloatValue * (((g_ForcefieldForce.FloatValue * g_ForcefieldMinimumDistance.FloatValue / 50) * 20.0) / GetVectorLength(direction,true));
						gravityForce = gravityForce / 20.0;
						
						NormalizeVector(direction, direction);
						ScaleVector(direction, gravityForce);
						
						float entityVel[3];
						GetEntPropVector(iEnt, Prop_Data, "m_vecVelocity", entityVel);
			
						ScaleVector(direction, distance / 300);
						SubtractVectors(entityVel, direction, direction);
						TeleportEntity(iEnt, NULL_VECTOR, NULL_VECTOR, direction);
					}
				}
			}
			else
			{
				float propPos[3], forcefieldPos[3];
				GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", propPos);
				GetEntPropVector(iForcefield, Prop_Send, "m_vecOrigin", forcefieldPos);
				
				float distance = GetVectorDistance(propPos, forcefieldPos);
				if(distance < g_ForcefieldMinimumDistance.FloatValue)
				{
					float direction[3];
					SubtractVectors(forcefieldPos, propPos, direction);
					
					float gravityForce = FindConVar("sv_gravity").FloatValue * (((g_ForcefieldForce.FloatValue * g_ForcefieldMinimumDistance.FloatValue / 50) * 20.0) / GetVectorLength(direction,true));
					gravityForce = gravityForce / 20.0;
					
					NormalizeVector(direction, direction);
					ScaleVector(direction, gravityForce);
					
					float entityVel[3];
					GetEntPropVector(iEnt, Prop_Data, "m_vecVelocity", entityVel);
		
					ScaleVector(direction, distance / 300);
					SubtractVectors(entityVel, direction, direction);
					TeleportEntity(iEnt, NULL_VECTOR, NULL_VECTOR, direction);
				}
			}
		}
		else
		{
			float propPos[3], forcefieldPos[3];
			GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", propPos);
			GetEntPropVector(iForcefield, Prop_Send, "m_vecOrigin", forcefieldPos);
			
			float distance = GetVectorDistance(propPos, forcefieldPos);
			if(distance < g_ForcefieldMinimumDistance.FloatValue)
			{
				float direction[3];
				SubtractVectors(forcefieldPos, propPos, direction);
				
				float gravityForce = FindConVar("sv_gravity").FloatValue * (((g_ForcefieldForce.FloatValue * g_ForcefieldMinimumDistance.FloatValue / 50) * 20.0) / GetVectorLength(direction,true));
				gravityForce = gravityForce / 20.0;
				
				NormalizeVector(direction, direction);
				ScaleVector(direction, gravityForce);
				
				float entityVel[3];
				GetEntPropVector(iEnt, Prop_Data, "m_vecVelocity", entityVel);
		
				ScaleVector(direction, distance / 300);
				SubtractVectors(entityVel, direction, direction);
				TeleportEntity(iEnt, NULL_VECTOR, NULL_VECTOR, direction);
			}
		}
	}
}

void PushAwayFromExplosion(int entity, const char[] classname)
{
	
	int iEnt = MaxClients + 1;
	while((iEnt = FindEntityByClassname(iEnt, classname)) != -1)
	{
		float propPos[3], entityPos[3];
		GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", propPos);
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entityPos);
		entityPos[2] -= 30.0;
		float distance = GetVectorDistance(propPos, entityPos);
		if(distance < g_ExplosionMinimumDistance.FloatValue)
		{
			float direction[3];
			SubtractVectors(propPos, entityPos, direction);
			NormalizeVector(direction, direction);
			if (distance <= 20.0)
				distance = 20.0;
			ScaleVector(direction, g_ExplosionForce.FloatValue);

			float propVel[3];
			GetEntPropVector(iEnt, Prop_Data, "m_vecVelocity", propVel);
			AddVectors(propVel, direction, direction);

			TeleportEntity(iEnt, NULL_VECTOR, NULL_VECTOR, direction);
		}
	}
}

void PushToImplosion(int entity, const char[] classname)
{
	int iEnt = MaxClients + 1;
	while((iEnt = FindEntityByClassname(iEnt, classname)) != -1)
	{
		float propPos[3], entityPos[3];
		GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", propPos);
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entityPos);
		
		float distance = GetVectorDistance(propPos, entityPos);
		if(distance < g_ImplosionMinimumDistance.FloatValue)
		{
			float direction[3];
			SubtractVectors(entityPos, propPos, direction);
			
			direction[2] +=  (200.0 + (distance * 0.4));
			TeleportEntity(iEnt, NULL_VECTOR, NULL_VECTOR, direction);
		}
	}
}

/*
public Action Command_Test(int client, int args)
{
	int x = GetPlayerWeaponSlot(client, CS_SLOT_GRENADE);
	PrintToChat(client, "WEAPONSSLOT: %d", x);
}
*/

public void OnEntityCreated(int entity, const char[] classname)
{		
	if(StrEqual(classname, "decoy_projectile", false))
	{
		SDKHook(entity, SDKHook_SpawnPost, DecoySpawned);
	}	
}

public Action DecoySpawned(int entity)
{
	int owner = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");

	if(owner > 0 && owner <= MaxClients)
	{
		if(g_eMode[owner] == DecoyMode_Normal)
		{
			SetEntPropString(entity, Prop_Data, "m_iName", "normal");
			return Plugin_Continue;
		}
			
		if(g_eMode[owner] == DecoyMode_Blackhole)
			SetEntPropString(entity, Prop_Data, "m_iName", "blackhole");
		else if(g_eMode[owner] == DecoyMode_Forcefield)
			SetEntPropString(entity, Prop_Data, "m_iName", "forcefield");
		else if(g_eMode[owner] == DecoyMode_ForceExplosion)
			SetEntPropString(entity, Prop_Data, "m_iName", "explosion");
		else if(g_eMode[owner] == DecoyMode_ForceImplosion)
			SetEntPropString(entity, Prop_Data, "m_iName", "implosion");
				
		SetEntityModel(entity, "models/weapons/futuristicgrenades/w_eq_decoy2.mdl");
	
		SDKHook(entity, SDKHook_TouchPost, DecoyTouchPost);
	}

	return Plugin_Continue;
}

public Action DecoyTouchPost(int entity, int other)
{
	if(other == 0)
	{
		if(!IsValidEntity(entity))
			return;
			
		char name[16];
		GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name));
		int owner = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
		
		if(owner < 1 || owner > MaxClients)
			AcceptEntityInput(entity, "Kill");
		
		if(!IsClientInGame(owner))
			AcceptEntityInput(entity, "Kill");
			
		if(StrEqual(name, "explosion", false))
		{
			if(g_eForceExplosionMode[owner] == ForceExplosionMode_Ground)
			{
				float vecPos[3], startPoint[3], endPoint[3], slopeAngle[3];
				GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vecPos);
				endPoint = vecPos;
				startPoint = vecPos;
				endPoint[2] = vecPos[2] - 5.0;
				
				Handle traceZ = TR_TraceRayFilterEx(startPoint, endPoint, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilterNotSelf, entity);
				TR_GetPlaneNormal(traceZ, slopeAngle);
				
				endPoint = vecPos;
				startPoint = vecPos;
				startPoint[1] = vecPos[1] + 1.0;
				endPoint[1] = vecPos[1] - 1.0;
				
				Handle traceX = TR_TraceRayFilterEx(startPoint, endPoint, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilterNotSelf, entity);
				
				endPoint = vecPos;
				startPoint = vecPos;
				startPoint[0] = vecPos[0] + 1.0;
				endPoint[0] = vecPos[0] - 1.0;
				
				Handle traceY = TR_TraceRayFilterEx(startPoint, endPoint, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilterNotSelf, entity);
				
				if((TR_DidHit(traceZ) && !TR_DidHit(traceX) && !TR_DidHit(traceY)) || slopeAngle[2] > 0.5)
					RequestFrame(FrameCallback, entity);
					
				CloseHandle(traceZ);
				CloseHandle(traceX);
				CloseHandle(traceY);
				
			}
			else
				RequestFrame(FrameCallback, entity);
		}
		else if(StrEqual(name, "implosion", false))
		{
			if(g_eForceImplosionMode[owner] == ForceImplosionMode_Ground)
			{
				float vecPos[3], startPoint[3], endPoint[3], slopeAngle[3];
				GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vecPos);
				endPoint = vecPos;
				startPoint = vecPos;
				endPoint[2] = vecPos[2] - 5.0;
				
				Handle traceZ = TR_TraceRayFilterEx(startPoint, endPoint, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilterNotSelf, entity);
				TR_GetPlaneNormal(traceZ, slopeAngle);
				
				endPoint = vecPos;
				startPoint = vecPos;
				startPoint[1] = vecPos[1] + 1.0;
				endPoint[1] = vecPos[1] - 1.0;
				
				Handle traceX = TR_TraceRayFilterEx(startPoint, endPoint, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilterNotSelf, entity);
				
				endPoint = vecPos;
				startPoint = vecPos;
				startPoint[0] = vecPos[0] + 1.0;
				endPoint[0] = vecPos[0] - 1.0;
				
				Handle traceY = TR_TraceRayFilterEx(startPoint, endPoint, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilterNotSelf, entity);

				if((TR_DidHit(traceZ) && !TR_DidHit(traceX) && !TR_DidHit(traceY)) || slopeAngle[2] > 0.5)
					RequestFrame(FrameCallback, entity);
				
				CloseHandle(traceZ);
				CloseHandle(traceX);
				CloseHandle(traceY);
			}
			else
				RequestFrame(FrameCallback, entity);
		}
		else
		{
			float vecPos[3], startPoint[3], endPoint[3], slopeAngle[3];
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vecPos);
			endPoint = vecPos;
			startPoint = vecPos;
			endPoint[2] = vecPos[2] - 5.0;
			
			Handle traceZ = TR_TraceRayFilterEx(startPoint, endPoint, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilterNotSelf, entity);
			TR_GetPlaneNormal(traceZ, slopeAngle);
			
			endPoint = vecPos;
			startPoint = vecPos;
			startPoint[1] = vecPos[1] + 1.0;
			endPoint[1] = vecPos[1] - 1.0;
			
			Handle traceX = TR_TraceRayFilterEx(startPoint, endPoint, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilterNotSelf, entity);
			
			endPoint = vecPos;
			startPoint = vecPos;
			startPoint[0] = vecPos[0] + 1.0;
			endPoint[0] = vecPos[0] - 1.0;
			
			Handle traceY = TR_TraceRayFilterEx(startPoint, endPoint, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilterNotSelf, entity);

			if((TR_DidHit(traceZ) && !TR_DidHit(traceX) && !TR_DidHit(traceY)) || slopeAngle[2] > 0.5)
				RequestFrame(FrameCallback, entity);
				
			CloseHandle(traceZ);
			CloseHandle(traceX);
			CloseHandle(traceY);
		}	
	}
}

public void FrameCallback(any entity)
{
	if(!IsValidEntity(entity))
		return;
	
	SDKUnhook(entity, SDKHook_TouchPost, DecoyTouchPost);
	
	char entityName[16];
	GetEntPropString(entity, Prop_Data, "m_iName", entityName, sizeof(entityName));
	int ref = EntIndexToEntRef(entity);
	float vel[3] =  { 0.0, 0.0, 300.0 };
	
	if(StrEqual(entityName, "blackhole", false))
	{
		vel[2] = g_BlackholeBounceVelocity.FloatValue;
		TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, vel);
		CreateTimer(0.5, Timer_Decoy, ref);
	}
	else if(StrEqual(entityName, "forcefield", false))
	{
		vel[2] = g_ForcefieldBounceVelocity.FloatValue;
		TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, vel);
		CreateTimer(0.5, Timer_Decoy, ref);
	}
	else if(StrEqual(entityName, "explosion", false))
	{
		vel[2] = g_ExplosionBounceVelocity.FloatValue;
		
		if(g_ExplosionBounce.BoolValue)
		{
			TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, vel);
			CreateTimer(0.5, Timer_Decoy, ref);
		}
		else
			SpawnEffect(entity);
	}
	else if(StrEqual(entityName, "implosion", false))
	{
		vel[2] = g_ImplosionBounceVelocity.FloatValue;
		
		if(g_ImplosionBounce.BoolValue)
		{
			TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, vel);
			CreateTimer(0.5, Timer_Decoy, ref);
		}
		else
			SpawnEffect(entity);
	}
}

public Action Timer_Decoy(Handle timer, any ref)
{
	int ent = EntRefToEntIndex(ref);
	SpawnEffect(ent);
}

void SpawnEffect(int entity)
{
	if(!IsValidEntity(entity))
		return;
		
	char entityName[16];
	char particleEffect[PLATFORM_MAX_PATH];
	GetEntPropString(entity, Prop_Data, "m_iName", entityName, sizeof(entityName));
	
	if(StrEqual(entityName, "explosion", false))
	{
		SpawnExplosion(entity);
		return;
	}
	else if(StrEqual(entityName, "implosion", false))
	{
		SpawnImplosion(entity);
		return;
	}
	
	float interval = 10.0;
	float nadeOrigin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", nadeOrigin);
	int volumeIndex;
	
	int owner = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
	if(owner < 1 || owner > MaxClients)
		return;
	
	if(!IsClientInGame(owner))
		return;
		
	int particle = CreateEntityByName("info_particle_system");
	SetEntPropEnt(particle, Prop_Data, "m_hOwnerEntity", owner);
	SetEntPropString(particle, Prop_Data, "m_iName", entityName);
	AcceptEntityInput(entity, "Kill");
	int ref = EntIndexToEntRef(particle);
	if(StrEqual(entityName, "blackhole", false))
	{
		g_BlackholeParticleEffect.GetString(particleEffect, sizeof(particleEffect));
		DispatchKeyValue(particle , "effect_name", particleEffect);

		g_hBlackholes.Push(ref);
		volumeIndex = g_hBlackholes.FindValue(ref);
		EmitAmbientSoundAny("misc/futuristicgrenades/blackhole.mp3", nadeOrigin, particle,_,_, BLACKHOLE_VOLUME);
		interval = g_BlackholeDuration.FloatValue;
		
		if(g_BlackholeIndicator.BoolValue)
		{
			int color[4] =  { 0, 0, 255, 255 };
			TE_SetupBeamRingPoint(nadeOrigin, (g_BlackholeMinimumDistance.FloatValue + 80.0)*1.4, (g_BlackholeMinimumDistance.FloatValue + 81.0)*1.4, g_iPathLaserModelIndex, g_iPathLaserModelIndex, 0, 15, g_BlackholeDuration.FloatValue, 10.0, 10.0, color, 1, 0);
			TE_SendToAll();
		}
	}
	else if(StrEqual(entityName, "forcefield", false))
	{
		g_ForcefieldParticleEffect.GetString(particleEffect, sizeof(particleEffect));
		DispatchKeyValue(particle , "effect_name", particleEffect);
		
		g_hForcefields.Push(ref);
		volumeIndex = g_hForcefields.FindValue(ref);
		EmitAmbientSoundAny("ambient/energy/force_field_loop1.wav", nadeOrigin, particle,_,_, FORCEFIELD_VOLUME);
		interval = g_ForcefieldDuration.FloatValue;
		
		if(g_ForcefieldIndicator.BoolValue)
		{
			int color[4] =  { 0, 0, 255, 255 };
			TE_SetupBeamRingPoint(nadeOrigin, (g_ForcefieldMinimumDistance.FloatValue + 80.0)*1.4, (g_ForcefieldMinimumDistance.FloatValue + 81.0)*1.4, g_iPathLaserModelIndex, g_iPathLaserModelIndex, 0, 15, g_ForcefieldDuration.FloatValue, 10.0, 10.0, color, 1, 0);
			TE_SendToAll();
		}
	}

	DispatchKeyValue(particle , "start_active", "0");
	DispatchSpawn(particle);
	TeleportEntity(particle, nadeOrigin, NULL_VECTOR,NULL_VECTOR);
	ActivateEntity(particle);
	AcceptEntityInput(particle, "Start");

	DataPack pack;
	CreateDataTimer(interval, Timer_Duration, pack);
	pack.WriteCell(ref);
	pack.WriteCell(nadeOrigin[0]);
	pack.WriteCell(nadeOrigin[1]);
	pack.WriteCell(nadeOrigin[2]);
	pack.WriteCell(volumeIndex);
}

void SpawnExplosion(int entity)
{
	int owner = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
	if(owner < 1 || owner > MaxClients)
		return;
	if(!IsClientInGame(owner))
		return;
	
	char particleEffect[PLATFORM_MAX_PATH];
	float nadeOrigin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", nadeOrigin);
	
	AcceptEntityInput(entity, "Kill");
	
	int particle = CreateEntityByName("info_particle_system");
	g_ExplosionParticleEffect.GetString(particleEffect, sizeof(particleEffect));
	DispatchKeyValue(particle , "effect_name", particleEffect);
	
	DispatchKeyValue(particle , "start_active", "0");
	DispatchSpawn(particle);
	TeleportEntity(particle, nadeOrigin, NULL_VECTOR,NULL_VECTOR);
	ActivateEntity(particle);
	AcceptEntityInput(particle, "Start");
	EmitAmbientSoundAny("misc/futuristicgrenades/explosion.mp3", nadeOrigin, particle,_,_, EXPLOSION_VOLUME);
	for (int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && IsPlayerAlive(client))
		{	
			if(!g_FriendlyFire.BoolValue)
			{
				int ownerteam = GetClientTeam(owner);
				if((ownerteam != GetClientTeam(client)) || client == owner)
				{
					float clientPos[3], explosionPos[3];
					GetClientAbsOrigin(client, clientPos);
					GetEntPropVector(particle, Prop_Send, "m_vecOrigin", explosionPos);
					clientPos[2] += 30.0;
					float distance = GetVectorDistance(clientPos, explosionPos);
		
					if(distance < g_ExplosionMinimumDistance.FloatValue)
					{
						SetEntPropEnt(client, Prop_Data, "m_hGroundEntity", -1);
						float direction[3];
						SubtractVectors(clientPos, explosionPos, direction);
						NormalizeVector(direction, direction);
						if (distance <= 20.0)
							distance = 20.0;
						ScaleVector(direction, g_ExplosionForce.FloatValue);
		
						float playerVel[3];
						GetEntPropVector(client, Prop_Data, "m_vecVelocity", playerVel);
						AddVectors(playerVel, direction, direction);
			
						TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, direction);
					}
				}
			}
			else
			{
				float clientPos[3], explosionPos[3];
				GetClientAbsOrigin(client, clientPos);
				GetEntPropVector(particle, Prop_Send, "m_vecOrigin", explosionPos);
				if(GetEntPropEnt(client, Prop_Data, "m_hGroundEntity") != -1)
					explosionPos[2] -= 30.0;
					
				float distance = GetVectorDistance(clientPos, explosionPos);
	
				if(distance < g_ExplosionMinimumDistance.FloatValue)
				{
					SetEntPropEnt(client, Prop_Data, "m_hGroundEntity", -1);
					float direction[3];
					SubtractVectors(clientPos, explosionPos, direction);
					NormalizeVector(direction, direction);
					if (distance <= 20.0)
						distance = 20.0;
					ScaleVector(direction, g_ExplosionForce.FloatValue);
	
					float playerVel[3];
					GetEntPropVector(client, Prop_Data, "m_vecVelocity", playerVel);
					AddVectors(playerVel, direction, direction);
		
					TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, direction);
				}
			}
		}
	}
	
	if(g_ExplosionProps.BoolValue)
		PushAwayFromExplosion(particle, "prop_physics*");
			
	if(g_ExplosionWeapons.BoolValue)
		PushAwayFromExplosion(particle, "weapon_*");
		
	if(g_ExplosionGrenades.BoolValue)
		PushAwayFromExplosion(particle, "hegrenade_projectile");

	if(g_ExplosionFlashbangs.BoolValue)
		PushAwayFromExplosion(particle, "flashbang_projectile");
	
	if(g_ExplosionSmokes.BoolValue)
		PushAwayFromExplosion(particle, "smokegrenade_projectile");
}

void SpawnImplosion(int entity)
{
	int owner = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
	if(owner < 1 || owner > MaxClients)
		return;
	if(!IsClientInGame(owner))
		return;
	char particleEffect[PLATFORM_MAX_PATH];
	float nadeOrigin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", nadeOrigin);
	AcceptEntityInput(entity, "Kill");
	
	int particle = CreateEntityByName("info_particle_system");
	g_ImplosionParticleEffect.GetString(particleEffect, sizeof(particleEffect));
	DispatchKeyValue(particle , "effect_name", particleEffect);

	DispatchKeyValue(particle , "start_active", "0");
	
	DispatchSpawn(particle);
	TeleportEntity(particle, nadeOrigin, NULL_VECTOR,NULL_VECTOR);
	ActivateEntity(particle);
	AcceptEntityInput(particle, "Start");
	EmitAmbientSoundAny("misc/futuristicgrenades/implosion.mp3", nadeOrigin, particle,_,_, IMPLOSION_VOLUME);
	for (int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && IsPlayerAlive(client))
		{
			if(!g_FriendlyFire.BoolValue)
			{
				int ownerteam = GetClientTeam(owner);
				if((ownerteam != GetClientTeam(client)) || client == owner)
				{
					float clientPos[3], implosionPos[3];
					GetClientAbsOrigin(client, clientPos);
					GetEntPropVector(particle, Prop_Send, "m_vecOrigin", implosionPos);
					
					float distance = GetVectorDistance(clientPos, implosionPos);
		
					if(distance < g_ImplosionMinimumDistance.FloatValue)
					{
						SetEntPropEnt(client, Prop_Data, "m_hGroundEntity", -1);
						float direction[3];
						SubtractVectors(implosionPos, clientPos, direction);
		
						direction[2] +=  (200.0 + (distance * 0.6));
						TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, direction);
					}
				}
			}
			else
			{
				float clientPos[3], implosionPos[3];
				GetClientAbsOrigin(client, clientPos);
				GetEntPropVector(particle, Prop_Send, "m_vecOrigin", implosionPos);
				
				float distance = GetVectorDistance(clientPos, implosionPos);
	
				if(distance < g_ImplosionMinimumDistance.FloatValue)
				{
					SetEntPropEnt(client, Prop_Data, "m_hGroundEntity", -1);
					float direction[3];
					SubtractVectors(implosionPos, clientPos, direction);
	
					direction[2] +=  (200.0 + (distance * 0.6));
					TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, direction);
				}
			}
		}
	}
	
	if(g_ImplosionProps.BoolValue)
		PushToImplosion(particle, "prop_physics*");
			
	if(g_ImplosionWeapons.BoolValue)
		PushToImplosion(particle, "weapon_*");
		
	if(g_ImplosionGrenades.BoolValue)
		PushToImplosion(particle, "hegrenade_projectile");

	if(g_ImplosionFlashbangs.BoolValue)
		PushToImplosion(particle, "flashbang_projectile");
	
	if(g_ImplosionSmokes.BoolValue)
		PushToImplosion(particle, "smokegrenade_projectile");
}

public Action Timer_Duration(Handle timer, DataPack pack)
{
	pack.Reset();
	float nadeOrigin[3];
	int ref = pack.ReadCell();
	nadeOrigin[0] = pack.ReadCell();
	nadeOrigin[1] = pack.ReadCell();
	nadeOrigin[2] = pack.ReadCell();
	int volumeIndex = pack.ReadCell();
	int particle = EntRefToEntIndex(ref);
	if(!IsValidEntity(particle))
	{
		int blackholeIndex = g_hBlackholes.FindValue(ref);
		if(blackholeIndex != -1)
			g_hBlackholes.Erase(blackholeIndex);
		
		
		int forcefieldIndex = g_hForcefields.FindValue(ref);
		if(forcefieldIndex != -1)
			g_hForcefields.Erase(forcefieldIndex);
			
		return Plugin_Handled;
	}
	
	char particleName[16];
	GetEntPropString(particle, Prop_Data, "m_iName", particleName, sizeof(particleName));
	
	if(StrEqual(particleName, "blackhole", false))
	{
		int index = g_hBlackholes.FindValue(ref);
		if(index != -1)
			g_hBlackholes.Erase(index);
	}
	else if(StrEqual(particleName, "forcefield", false))
	{
		int index = g_hForcefields.FindValue(ref);
		if(index != -1)
			g_hForcefields.Erase(index);
	}
	
	AcceptEntityInput(particle, "Stop");
	
	DataPack packFade;
	CreateDataTimer(0.2, Timer_Fade, packFade, TIMER_REPEAT);
	packFade.WriteCell(ref);
	packFade.WriteCell(nadeOrigin[0]);
	packFade.WriteCell(nadeOrigin[1]);
	packFade.WriteCell(nadeOrigin[2]);
	packFade.WriteCell(volumeIndex);
	
	return Plugin_Handled;
}

public Action Timer_Fade(Handle timer, DataPack pack)
{
	pack.Reset();
	float nadeOrigin[3];
	int ref = pack.ReadCell();
	nadeOrigin[0] = pack.ReadCell();
	nadeOrigin[1] = pack.ReadCell();
	nadeOrigin[2] = pack.ReadCell();
	int volumeIndex = pack.ReadCell();
	int particle = EntRefToEntIndex(ref);
	if(!IsValidEntity(particle))
		return Plugin_Stop;
	
	char particleName[16];
	GetEntPropString(particle, Prop_Data, "m_iName", particleName, sizeof(particleName));
	
	if(StrEqual(particleName, "blackhole", false))
	{
		g_BlackholeVolume[volumeIndex] -= 0.25;
		EmitAmbientSoundAny("misc/futuristicgrenades/blackhole.mp3", nadeOrigin, particle, _, SND_CHANGEVOL, g_BlackholeVolume[volumeIndex]);
		
		if(g_BlackholeVolume[volumeIndex] < 0.0)
		{
			AcceptEntityInput(particle, "Kill");
			StopSoundAny(particle, SNDCHAN_STATIC, "misc/futuristicgrenades/blackhole.mp3");
			g_BlackholeVolume[volumeIndex] = BLACKHOLE_VOLUME;
			return Plugin_Stop;
		}	
	}
	else if(StrEqual(particleName, "forcefield", false))
	{
		g_ForcefieldVolume[volumeIndex] -= 0.25;
		EmitAmbientSoundAny("ambient/energy/force_field_loop1.wav", nadeOrigin, particle, _, SND_CHANGEVOL, g_ForcefieldVolume[volumeIndex]);
		
		if(g_ForcefieldVolume[volumeIndex] < 0.0)
		{
			AcceptEntityInput(particle, "Kill");
			StopSoundAny(particle, SNDCHAN_STATIC, "ambient/energy/force_field_loop1.wav");
			g_ForcefieldVolume[volumeIndex] = FORCEFIELD_VOLUME;
			return Plugin_Stop;
		}	
	}
	else
	{
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}
	
public bool TraceFilterNotSelf(int entityhit, int mask, any entity)
{
	if(entity == 0 && entityhit != entity)
		return true;
	
	return false;
}

public Action Event_DecoyStarted(Event event, const char[] name, bool dontBroadcast)
{
	int entity = event.GetInt("entityid");
	char decoyName[16];
	GetEntPropString(entity, Prop_Data, "m_iName", decoyName, sizeof(decoyName));
	if(!StrEqual(decoyName, "normal", false))
		AcceptEntityInput(entity, "Kill");
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	int ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
	
	float clientPos[3], blackholePos[3];
	
	GetEntPropVector(ragdoll, Prop_Send, "m_vecOrigin", clientPos);
	for (int i = 0; i < g_hBlackholes.Length; i++)
	{
		GetEntPropVector(EntRefToEntIndex(g_hBlackholes.Get(i)), Prop_Send, "m_vecOrigin", blackholePos);
		if(GetVectorDistance(clientPos, blackholePos) < 50.0)
		{
			AcceptEntityInput(ragdoll, "Kill");
		}
	}
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_PVMid[client] = Weapon_GetViewModelIndex(client, -1);
	
	return Plugin_Continue;
}

int Weapon_GetViewModelIndex(int client, int sIndex)
{
		while ((sIndex = FindEntityByClassname2(sIndex, "predicted_viewmodel")) != -1)
		{
				int Owner = GetEntPropEnt(sIndex, Prop_Send, "m_hOwner");
				
				if (Owner != client)
						continue;
				
				return sIndex;
		}
		return -1;
}
// Get entity name
int FindEntityByClassname2(int startEnt, char[] classname)
{
		while (startEnt > -1 && !IsValidEntity(startEnt)) startEnt--;
		return FindEntityByClassname(startEnt, classname);
}  

stock void AddMaterialsFromFolder(char path[PLATFORM_MAX_PATH])
{
	DirectoryListing dir = OpenDirectory(path, true);
	if(dir != INVALID_HANDLE)
	{
		char buffer[PLATFORM_MAX_PATH];
		FileType type;
		
		while(dir.GetNext(buffer, PLATFORM_MAX_PATH, type))
		{
			if(type == FileType_File && ((StrContains(buffer, ".vmt", false) != -1) || (StrContains(buffer, ".vtf", false) != -1) && !(StrContains(buffer, ".ztmp", false) != -1)))
			{
				char fullPath[PLATFORM_MAX_PATH];
				
				Format(fullPath, sizeof(fullPath), "%s%s", path, buffer);
				AddFileToDownloadsTable(fullPath);
				
				if(!IsModelPrecached(fullPath))
					PrecacheModel(fullPath);
			}
		}
	}
}

public void OnClientWeaponSwitchPost(int client, int weaponid)
{
	SetEntPropEnt(weaponid, Prop_Data, "m_hOwnerEntity", client);
	char weapon[64];
	GetEntityClassname(weaponid, weapon,sizeof(weapon));
	
	if(StrEqual(weapon, "weapon_decoy", false))
	{
		SetEntProp(weaponid, Prop_Send, "m_nModelIndex", 0);
		SetEntProp(g_PVMid[client], Prop_Send, "m_nModelIndex", g_iViewModelIndex);

		switch(g_eMode[client]){
			case DecoyMode_Blackhole: {
				DispatchKeyValue(g_PVMid[client], "skin", "0");
			}
			case DecoyMode_Forcefield: {
				DispatchKeyValue(g_PVMid[client], "skin", "1");
			}
			case DecoyMode_ForceExplosion: {
				DispatchKeyValue(g_PVMid[client], "skin", "2");
			}
			case DecoyMode_ForceImplosion: {
				DispatchKeyValue(g_PVMid[client], "skin", "3");
			}
		}
	}
}

stock void PrecacheEffect(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;
	
	if (table == INVALID_STRING_TABLE)
	{
		table = FindStringTable("EffectDispatch");
	}
	
	bool save = LockStringTables(false);
	AddToStringTable(table, sEffectName);
	LockStringTables(save);
}

stock void PrecacheParticleEffect(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;
	
	if (table == INVALID_STRING_TABLE)
	{
		table = FindStringTable("ParticleEffectNames");
	}
	
	bool save = LockStringTables(false);
	AddToStringTable(table, sEffectName);
	LockStringTables(save);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponSwitchPost, OnClientWeaponSwitchPost); 
	SDKHook(client, SDKHook_WeaponEquip, OnPostWeaponEquip);
}

public void OnClientDisconnect(int client)
{
	g_eMode[client] = DecoyMode_Normal;
	g_eForcefieldMode[client] = ForcefieldMode_Normal;
	g_eForceExplosionMode[client] = ForceExplosionMode_Ground;
	g_eForceImplosionMode[client] = ForceImplosionMode_Ground;
	g_bSwitchGrenade[client] = false;
	g_bSwitchMode[client] = false;
	SDKUnhook(client, SDKHook_WeaponSwitchPost, OnClientWeaponSwitchPost); 
	SDKUnhook(client, SDKHook_WeaponEquip, OnPostWeaponEquip);
}

public void OnMapStart()
{
	g_hBlackholes.Clear();
	g_hForcefields.Clear();
	
	//VIEWMODEL
	AddFileToDownloadsTable("models/weapons/futuristicgrenades/v_eq_decoy2.dx90.vtx");
	AddFileToDownloadsTable("models/weapons/futuristicgrenades/v_eq_decoy2.mdl");
	AddFileToDownloadsTable("models/weapons/futuristicgrenades/v_eq_decoy2.vvd");
	
	//GRENADE MODEL
	AddFileToDownloadsTable("models/weapons/futuristicgrenades/w_eq_decoy2.dx90.vtx");
	AddFileToDownloadsTable("models/weapons/futuristicgrenades/w_eq_decoy2.mdl");
	AddFileToDownloadsTable("models/weapons/futuristicgrenades/w_eq_decoy2.phy");
	AddFileToDownloadsTable("models/weapons/futuristicgrenades/w_eq_decoy2.vvd");

	//MATERIALS
	AddMaterialsFromFolder("materials/models/weapons/v_models/futuristicgrenades/hydragrenade/");
	
	AddFileToDownloadsTable("materials/futuristicgrenades/effects/electric1.vmt");
	AddFileToDownloadsTable("materials/futuristicgrenades/effects/electric1.vtf");
		
	AddFileToDownloadsTable("materials/futuristicgrenades/effects/conc_warp.vmt");
	AddFileToDownloadsTable("materials/futuristicgrenades/effects/conc_normal.vtf");
	AddFileToDownloadsTable("materials/futuristicgrenades/effects/conc_tint.vtf");
	
	AddFileToDownloadsTable("materials/futuristicgrenades/effects/star_noz.vmt");
	AddFileToDownloadsTable("materials/futuristicgrenades/effects/yellowflare_noz.vmt");
	AddFileToDownloadsTable("materials/futuristicgrenades/effects/yellowflare.vtf");
	
	AddFileToDownloadsTable("materials/futuristicgrenades/particle/particle_decals/snow_crater_1.vmt");
	AddFileToDownloadsTable("materials/futuristicgrenades/particle/particle_decals/snow_crater_1.vtf");
	
	AddFileToDownloadsTable("materials/futuristicgrenades/particle/particle_flares/aircraft_white.vmt");
	AddFileToDownloadsTable("materials/futuristicgrenades/particle/particle_flares/aircraft_white.vtf");
	
	AddFileToDownloadsTable("materials/futuristicgrenades/particle/particle_flares/particle_flare_002.vtf");
	AddFileToDownloadsTable("materials/futuristicgrenades/particle/particle_flares/particle_flare_002_noz.vmt");
	
	AddFileToDownloadsTable("materials/futuristicgrenades/particle/particle_flares/particle_flare_004_nodepth.vmt");
	AddFileToDownloadsTable("materials/futuristicgrenades/particle/particle_flares/particle_flare_004.vtf");
	
	//PARTICLES
	AddFileToDownloadsTable("particles/futuristicgrenades/futuristicgrenades.pcf");
	
	//SOUND
	AddFileToDownloadsTable("sound/misc/futuristicgrenades/blackhole.mp3");
	AddFileToDownloadsTable("sound/misc/futuristicgrenades/explosion.mp3");
	AddFileToDownloadsTable("sound/misc/futuristicgrenades/implosion.mp3");
	
	//Precaching
	g_iViewModelIndex = PrecacheModel("models/weapons/futuristicgrenades/v_eq_decoy2.mdl",true);
	g_iPathLaserModelIndex = PrecacheModel("materials/sprites/laserbeam.vmt");
	
	PrecacheModel("models/weapons/futuristicgrenades/w_eq_decoy2.mdl",true);
	
	PrecacheGeneric("particles/futuristicgrenades/futuristicgrenades.pcf",true);
	
	PrecacheModel("materials/futuristicgrenades/effects/electric1.vmt");
	PrecacheModel("materials/futuristicgrenades/effects/electric1.vtf");
	
	PrecacheModel("materials/futuristicgrenades/effects/conc_warp.vmt");
	PrecacheModel("materials/futuristicgrenades/effects/conc_normal.vtf");
	PrecacheModel("materials/futuristicgrenades/effects/conc_tint.vtf");
	
	PrecacheModel("materials/futuristicgrenades/effects/star_noz.vmt");
	PrecacheModel("materials/futuristicgrenades/effects/yellowflare_noz.vmt");
	PrecacheModel("materials/futuristicgrenades/effects/yellowflare.vtf");
	
	PrecacheModel("materials/futuristicgrenades/particle/particle_decals/snow_crater_1.vmt");
	PrecacheModel("materials/futuristicgrenades/particle/particle_decals/snow_crater_1.vtf");
	
	PrecacheModel("materials/futuristicgrenades/particle/particle_flares/aircraft_white.vmt");
	PrecacheModel("materials/futuristicgrenades/particle/particle_flares/aircraft_white.vtf");
	
	PrecacheModel("materials/futuristicgrenades/particle/particle_flares/particle_flare_002.vtf");
	PrecacheModel("materials/futuristicgrenades/particle/particle_flares/particle_flare_002_noz.vmt");
	
	PrecacheModel("materials/futuristicgrenades/particle/particle_flares/particle_flare_004_nodepth.vmt");
	PrecacheModel("materials/futuristicgrenades/particle/particle_flares/particle_flare_004.vtf");
	
	PrecacheEffect("ParticleEffect");
	PrecacheParticleEffect("futuristicgrenades");
	PrecacheSoundAny("misc/futuristicgrenades/blackhole.mp3", true);
	PrecacheSoundAny("ambient/energy/force_field_loop1.wav", true);
	PrecacheSoundAny("misc/futuristicgrenades/explosion.mp3", true);
	PrecacheSoundAny("misc/futuristicgrenades/implosion.mp3", true);
	PrecacheSoundAny("buttons/button15.wav", true);
}

public Action SB_OnItemSpawn (const char[] name, float pos[3])
{
	if(!bLibraryExists) return;
	
	float newpos[3];
	newpos[0] = pos[0];
	newpos[1] = pos[1];
	newpos[2] = pos[2] + 10.0;

	float scale = g_WModelScale.FloatValue;

	int entity;
	if(StrEqual(name, "item_blackhole")) {
		entity = CreateEntityByName("weapon_decoy");
		SetEntityModel(entity, "models/weapons/futuristicgrenades/w_eq_decoy2.mdl");
		DispatchSpawn(entity);
		DispatchKeyValue(entity, "skin", "0");
		SetEntPropFloat(entity, Prop_Data, "m_flModelScale", scale);
		TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
	}
	else if(StrEqual(name, "item_forcefield")) {
		entity = CreateEntityByName("weapon_decoy");
		SetEntityModel(entity, "models/weapons/futuristicgrenades/w_eq_decoy2.mdl");
		DispatchSpawn(entity);
		DispatchKeyValue(entity, "skin", "1");
		SetEntPropFloat(entity, Prop_Data, "m_flModelScale", scale);
		TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
	}
	else if(StrEqual(name, "item_explosion")) {
		entity = CreateEntityByName("weapon_decoy");
		SetEntityModel(entity, "models/weapons/futuristicgrenades/w_eq_decoy2.mdl");
		DispatchSpawn(entity);
		DispatchKeyValue(entity, "skin", "2");
		SetEntPropFloat(entity, Prop_Data, "m_flModelScale", scale);
		TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
	}
	else if(StrEqual(name, "item_implosion")) {
		entity = CreateEntityByName("weapon_decoy");
		SetEntityModel(entity, "models/weapons/futuristicgrenades/w_eq_decoy2.mdl");
		DispatchSpawn(entity);
		DispatchKeyValue(entity, "skin", "3");
		SetEntPropFloat(entity, Prop_Data, "m_flModelScale", scale);
		TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
	}
}

public Action OnPostWeaponEquip(int client, int weapon)
{
	if(weapon < 1 || !IsValidEdict(weapon) || !IsValidEntity(weapon)) return;
	
	int owner = GetEntProp(weapon, Prop_Send, "m_hPrevOwner");
	if (owner > 0)	return;
		
	char classname[64];
	if(!GetEdictClassname(weapon, classname, sizeof(classname))) return;

	if(StrContains(classname, "decoy") == -1)	return;

	char modelname[128];
	GetEntPropString(weapon, Prop_Data, "m_ModelName", modelname, sizeof(modelname));
	
	if(StrContains(modelname, "futuristicgrenades") != -1)
	{
		int skin = GetEntProp(weapon, Prop_Send, "m_nSkin", skin); 

		// blackhole
		if(skin == 0)
		{
			g_eMode[client] = DecoyMode_Blackhole;
		}
		else if(skin == 1)
		{
			g_eMode[client] = DecoyMode_Forcefield;
			g_eForcefieldMode[client] = g_ForcefieldMode.IntValue == 0 ? ForcefieldMode_Normal : ForcefieldMode_Self;
		}
		else if(skin == 2)
		{
			g_eMode[client] = DecoyMode_ForceExplosion;
			g_eForceExplosionMode[client] = g_ExplosionMode.IntValue == 0 ? ForceExplosionMode_Ground : ForceExplosionMode_World;
		}
		else if(skin == 3)
		{
			g_eMode[client] = DecoyMode_ForceImplosion;
			g_eForceImplosionMode[client] = g_ImplosionMode.IntValue == 0 ? ForceImplosionMode_Ground : ForceImplosionMode_World;
		}
	}
}
