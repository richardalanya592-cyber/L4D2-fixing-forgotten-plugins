/**
 * vim: set ts=4 :
 * =============================================================================
 * L4D Witch Damage Announce
 * Displays how much damage done to witch on witch death + display health remaining when witch kills or incaps the survivor.
 * Original private plugin by Harry Potter (https://steamcommunity.com/id/harrypotterl4d2/)
 * Public release by SirPlease (https://github.com/SirPlease/L4D2-Competitive-Rework)
 * 
 * @version 1.2.1
 */

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <left4dhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.2.1"
#define MAX_ENTITIES 2048

public Plugin myinfo = 
{
	name = "L4D Witch Damage Announce",
	author = "Harry Potter, SirPlease",
	description = "Displays Witch damage on death and remaining health on kill/incap",
	version = PLUGIN_VERSION,
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

// ConVars
ConVar g_hCvarAnnounceType;
ConVar g_hCvarPrintIncap;
ConVar g_hCvarCombineLow;
ConVar g_hCvarCombineMin;
ConVar g_hCvarMaxLines;
ConVar g_hCvarCombineName;

// Global variables
int g_iWitchHealth[MAX_ENTITIES];
int g_iWitchDamage[MAX_ENTITIES][MAXPLAYERS+1];
bool g_bWitchActive[MAX_ENTITIES];
bool g_bLateLoad;
ArrayList g_aWitches;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead2 && test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	// Create convars
	g_hCvarAnnounceType = CreateConVar("l4d_witch_announce_type", "1", "How to announce damage? 0=Chat only, 1=Hint box, 2=Center text", FCVAR_NOTIFY);
	g_hCvarPrintIncap = CreateConVar("l4d_witch_print_incap", "1", "Print Witch health when she incaps a survivor? 0=Off, 1=On", FCVAR_NOTIFY);
	g_hCvarCombineLow = CreateConVar("l4d_witch_combine_low", "0", "Combine percentages lower than minimum? 0=Off, 1=On", FCVAR_NOTIFY);
	g_hCvarCombineMin = CreateConVar("l4d_witch_combine_min", "5", "Minimum percentage to show individually (if combining)", FCVAR_NOTIFY);
	g_hCvarMaxLines = CreateConVar("l4d_witch_max_lines", "0", "Maximum lines to print (0=unlimited, 5=show top 5 + combined)", FCVAR_NOTIFY);
	g_hCvarCombineName = CreateConVar("l4d_witch_combine_name", "The Other Survivors", "Name for combined group", FCVAR_NOTIFY);
	
	CreateConVar("l4d_witch_damage_version", PLUGIN_VERSION, "Witch Damage Announce Version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	AutoExecConfig(true, "l4d_witch_damage_announce");
	
	// Hook events
	HookEvent("witch_spawn", Event_WitchSpawn);
	HookEvent("witch_killed", Event_WitchKilled);
	HookEvent("witch_harasser_set", Event_WitchHarasserSet);
	HookEvent("player_incapacitated", Event_PlayerIncapacitated);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_start", Event_RoundStart);
	
	// Initialize array
	g_aWitches = new ArrayList();
	
	if(g_bLateLoad)
	{
		// Find existing witches
		int entity = -1;
		while((entity = FindEntityByClassname(entity, "witch")) != -1)
		{
			OnWitchCreated(entity);
		}
	}
}

public void OnMapStart()
{
	CreateTimer(0.1, Timer_CheckWitches, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "witch"))
	{
		OnWitchCreated(entity);
	}
}

void OnWitchCreated(int entity)
{
	SDKHook(entity, SDKHook_SpawnPost, OnWitchSpawned);
	SDKHook(entity, SDKHook_OnTakeDamage, OnWitchTakeDamage);
	SDKHook(entity, SDKHook_OnTakeDamagePost, OnWitchTakeDamagePost);
}

public void OnWitchSpawned(int entity)
{
	g_iWitchHealth[entity] = L4D_GetEntityHealth(entity);
	g_bWitchActive[entity] = true;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		g_iWitchDamage[entity][i] = 0;
	}
	
	if(g_aWitches.FindValue(entity) == -1)
	{
		g_aWitches.Push(entity);
	}
}

public Action OnWitchTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if(!g_bWitchActive[victim] || attacker <= 0 || attacker > MaxClients)
		return Plugin_Continue;
	
	if(!IsClientInGame(attacker) || GetClientTeam(attacker) != 2)
		return Plugin_Continue;
	
	return Plugin_Continue;
}

public void OnWitchTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	if(!g_bWitchActive[victim] || attacker <= 0 || attacker > MaxClients)
		return;
	
	if(!IsClientInGame(attacker) || GetClientTeam(attacker) != 2)
		return;
	
	g_iWitchDamage[victim][attacker] += RoundToNearest(damage);
	
	// Update health
	g_iWitchHealth[victim] = L4D_GetEntityHealth(victim);
}

public void Event_WitchSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int witch = event.GetInt("witchid");
	if(witch > 0 && IsValidEntity(witch))
	{
		OnWitchSpawned(witch);
	}
}

public void Event_WitchHarasserSet(Event event, const char[] name, bool dontBroadcast)
{
	int witch = event.GetInt("witchid");
	int survivor = GetClientOfUserId(event.GetInt("userid"));
	
	if(witch > 0 && IsValidEntity(witch) && survivor > 0)
	{
		// Just track that someone is harassing
	}
}

public void Event_WitchKilled(Event event, const char[] name, bool dontBroadcast)
{
	int witch = event.GetInt("witchid");
	int killer = GetClientOfUserId(event.GetInt("userid"));
	
	if(!IsValidEntity(witch) || !g_bWitchActive[witch])
		return;
	
	if(killer > 0 && killer <= MaxClients && IsClientInGame(killer) && GetClientTeam(killer) == 2)
	{
		// Add final damage if needed
		int damage = event.GetInt("damageamount");
		g_iWitchDamage[witch][killer] += damage;
	}
	
	// Print damage report
	PrintDamageReport(witch, killer);
	
	// Clean up
	g_bWitchActive[witch] = false;
	int index = g_aWitches.FindValue(witch);
	if(index != -1)
	{
		g_aWitches.Erase(index);
	}
}

public void Event_PlayerIncapacitated(Event event, const char[] name, bool dontBroadcast)
{
	if(!g_hCvarPrintIncap.BoolValue)
		return;
	
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if(victim <= 0 || !IsClientInGame(victim) || GetClientTeam(victim) != 2)
		return;
	
	// Check if incapacitated by witch
	char sWeapon[32];
	event.GetString("weapon", sWeapon, sizeof(sWeapon));
	
	if(StrContains(sWeapon, "witch", false) != -1)
	{
		PrintWitchHealthToSurvivor(victim);
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if(!g_hCvarPrintIncap.BoolValue)
		return;
	
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if(victim <= 0 || !IsClientInGame(victim) || GetClientTeam(victim) != 2)
		return;
	
	// Check if killed by witch
	char sWeapon[32];
	event.GetString("weapon", sWeapon, sizeof(sWeapon));
	
	if(StrEqual(sWeapon, "witch"))
	{
		PrintWitchHealthToSurvivor(victim);
	}
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	// Clean up all witch data
	for(int i = 0; i < g_aWitches.Length; i++)
	{
		int witch = g_aWitches.Get(i);
		g_bWitchActive[witch] = false;
	}
	
	g_aWitches.Clear();
}

public Action Timer_CheckWitches(Handle timer)
{
	// Check if any witches need cleanup
	for(int i = g_aWitches.Length - 1; i >= 0; i--)
	{
		int witch = g_aWitches.Get(i);
		if(!IsValidEntity(witch) || !IsValidEdict(witch))
		{
			g_aWitches.Erase(i);
			continue;
		}
		
		// Update health if active
		if(g_bWitchActive[witch])
		{
			g_iWitchHealth[witch] = L4D_GetEntityHealth(witch);
		}
	}
	
	return Plugin_Continue;
}

void PrintDamageReport(int witch, int killer)
{
	// Collect damage data
	int totalDamage = 0;
	int damageCount = 0;
	int damageArray[MAXPLAYERS+1][2]; // [client][damage]
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(g_iWitchDamage[witch][i] > 0)
		{
			damageArray[damageCount][0] = i;
			damageArray[damageCount][1] = g_iWitchDamage[witch][i];
			totalDamage += g_iWitchDamage[witch][i];
			damageCount++;
		}
	}
	
	if(damageCount == 0)
		return;
	
	// Sort by damage (highest first)
	SortCustom2D(damageArray, damageCount, SortDamageDesc);
	
	// Build output string
	char sOutput[512];
	char sTemp[128];
	int iCombineMin = g_hCvarCombineMin.IntValue;
	int iMaxLines = g_hCvarMaxLines.IntValue;
	bool bCombine = g_hCvarCombineLow.BoolValue;
	
	// Header
	Format(sOutput, sizeof(sOutput), "Witch has been killed");
	
	// Show damage
	int iLinesPrinted = 0;
	int iCombinedDamage = 0;
	int iCombinedPlayers = 0;
	char sCombineName[64];
	g_hCvarCombineName.GetString(sCombineName, sizeof(sCombineName));
	
	for(int i = 0; i < damageCount; i++)
	{
		int client = damageArray[i][0];
		int damage = damageArray[i][1];
		int percentage = RoundToNearest(float(damage) / float(totalDamage) * 100.0);
		
		// Check if we should combine this player
		if(bCombine && percentage < iCombineMin && iMaxLines > 0 && iLinesPrinted >= iMaxLines - 1)
		{
			iCombinedDamage += damage;
			iCombinedPlayers++;
			continue;
		}
		
		// Check line limit
		if(iMaxLines > 0 && iLinesPrinted >= iMaxLines)
		{
			iCombinedDamage += damage;
			iCombinedPlayers++;
			continue;
		}
		
		// Get player name
		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));
		
		Format(sTemp, sizeof(sTemp), "\n[%d] (%d%%) %s", damage, percentage, sName);
		StrCat(sOutput, sizeof(sOutput), sTemp);
		iLinesPrinted++;
	}
	
	// Add combined line if needed
	if(iCombinedPlayers > 0)
	{
		int combinedPercentage = RoundToNearest(float(iCombinedDamage) / float(totalDamage) * 100.0);
		Format(sTemp, sizeof(sTemp), "\n[%d] (%d%%) %s", iCombinedDamage, combinedPercentage, sCombineName);
		StrCat(sOutput, sizeof(sOutput), sTemp);
	}
	
	// Add killer/assist info
	Format(sTemp, sizeof(sTemp), "\n \nWitch got killed by %N (%d dmg).", killer, g_iWitchDamage[witch][killer]);
	StrCat(sOutput, sizeof(sOutput), sTemp);
	
	// Add assists
	bool bHasAssist = false;
	for(int i = 0; i < damageCount; i++)
	{
		int client = damageArray[i][0];
		if(client != killer)
		{
			if(!bHasAssist)
			{
				Format(sTemp, sizeof(sTemp), "\n|| Assist: %N (%d dmg)", client, g_iWitchDamage[witch][client]);
				StrCat(sOutput, sizeof(sOutput), sTemp);
				bHasAssist = true;
			}
			else
			{
				Format(sTemp, sizeof(sTemp), ", %N (%d dmg)", client, g_iWitchDamage[witch][client]);
				StrCat(sOutput, sizeof(sOutput), sTemp);
			}
		}
	}
	
	// Print to all
	int type = g_hCvarAnnounceType.IntValue;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			switch(type)
			{
				case 0: PrintToChat(i, sOutput);
				case 1: PrintHintText(i, sOutput);
				case 2: PrintCenterText(i, sOutput);
			}
		}
	}
}

void PrintWitchHealthToSurvivor(int victim)
{
	// Find the witch that did this
	int witch = FindWitchNearby(victim);
	if(witch == -1 || !g_bWitchActive[witch])
		return;
	
	int health = L4D_GetEntityHealth(witch);
	if(health < 0) health = 0;
	
	char sOutput[256];
	Format(sOutput, sizeof(sOutput), "Witch had %d health remaining.", health);
	
	// Print to victim
	int type = g_hCvarAnnounceType.IntValue;
	switch(type)
	{
		case 0: PrintToChat(victim, sOutput);
		case 1: PrintHintText(victim, sOutput);
		case 2: PrintCenterText(victim, sOutput);
	}
}

int FindWitchNearby(int client)
{
	float clientPos[3];
	GetClientAbsOrigin(client, clientPos);
	
	for(int i = 0; i < g_aWitches.Length; i++)
	{
		int witch = g_aWitches.Get(i);
		if(!IsValidEntity(witch) || !g_bWitchActive[witch])
			continue;
		
		float witchPos[3];
		GetEntPropVector(witch, Prop_Send, "m_vecOrigin", witchPos);
		
		if(GetVectorDistance(clientPos, witchPos) < 500.0)
		{
			return witch;
		}
	}
	
	return -1;
}

public int SortDamageDesc(int[] elem1, int[] elem2, int[][] array, Handle hndl)
{
	if(elem1[1] > elem2[1]) return -1;
	if(elem1[1] < elem2[1]) return 1;
	return 0;
}

stock int L4D_GetEntityHealth(int entity)
{
	return GetEntProp(entity, Prop_Send, "m_iHealth");
}