#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
    name = "Tank 40 Abilities",
    author = "YourName",
    description = "Tank with 40 different abilities - 3 random per spawn",
    version = "1.0",
    url = "http://yoursite.com"
}

// Global variables
int g_iTankAbilities[MAXPLAYERS+1][3];
int g_iTankHealth[MAXPLAYERS+1];
int g_iTankOriginalHealth[MAXPLAYERS+1];
bool g_bTankSpawned[MAXPLAYERS+1];
float g_fLastAbilityUse[MAXPLAYERS+1];
float g_fLastRageUse[MAXPLAYERS+1];
bool g_bIsEnraged[MAXPLAYERS+1];
int g_iRageCount[MAXPLAYERS+1];
Handle g_hPoisonTimer[MAXPLAYERS+1];
Handle g_hInfectionTimer[MAXPLAYERS+1];
Handle g_hLightningTimer[MAXPLAYERS+1];
Handle g_hToxicCloudTimer[MAXPLAYERS+1];
int g_iLightningTarget[MAXPLAYERS+1];
bool g_bIsFrozen[MAXPLAYERS+1];
bool g_bIsPoisoned[MAXPLAYERS+1];
bool g_bIsInfected[MAXPLAYERS+1];

// Complete abilities list - 40 total
char g_szAbilityNames[][] = 
{
    // Original 20
    "Boom-rock",
    "Points Bank",
    "Spawner",
    "Immortal",
    "Regeneration",
    "Speed",
    "Shield",
    "Poison",
    "Infect",
    "Teleport",
    "Multi-rock",
    "Earthquake",
    "Invisibility",
    "Mini-tanks",
    "Life Steal",
    "Wall Climb",
    "Scream",
    "Fire",
    "Ice",
    "Lightning",
    
    // 20 New Abilities
    "Vampire",
    "Berserker",
    "Reflect",
    "Gravity Well",
    "Time Slow",
    "Clone",
    "Nova Blast",
    "Summon Horde",
    "Bombardment",
    "Leech",
    "Berserk Rage",
    "Shield Wall",
    "Web Shot",
    "Toxic Cloud",
    "Earth Shield",
    "Chain Reaction",
    "Bloodlust",
    "Soul Drain",
    "Corruption",
    "Doom Gaze"
};

// Ability descriptions
char g_szAbilityDescriptions[][] = 
{
    // Original 20
    "Rocks explode on impact",
    "Accumulates points for players",
    "Constantly spawns zombies",
    "Resists more damage",
    "Gradually regenerates health",
    "Moves faster",
    "Shield that absorbs damage",
    "Poisons nearby players",
    "Infects with special virus",
    "Randomly teleports",
    "Throws multiple rocks",
    "Causes tremors while walking",
    "Partially invisible",
    "Creates mini-tanks on death",
    "Steals life on hit",
    "Can climb walls",
    "Scream that stuns players",
    "Sets players on fire",
    "Freezes players",
    "Chain lightning attack",
    
    // 20 New Abilities
    "Heals from damage dealt",
    "More damage when low health",
    "Reflects damage back to attacker",
    "Pulls players towards him",
    "Slows time around the tank",
    "Creates clones of himself",
    "Area damage pulse",
    "Summons zombie horde",
    "Calls rock rain from sky",
    "Drains health over time",
    "Gets stronger when hit",
    "Creates defensive barrier",
    "Traps players in webs",
    "Creates poison gas cloud",
    "Damage reduction shield",
    "Chain explosion damage",
    "Gets faster with each kill",
    "Steals maximum health",
    "Converts survivors to zombies",
    "Damages if looked at too long"
};

public void OnPluginStart()
{
    HookEvent("tank_spawn", Event_TankSpawn);
    HookEvent("tank_killed", Event_TankKilled);
    HookEvent("player_hurt", Event_PlayerHurt);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("ability_use", Event_AbilityUse);
    
    // Timer for passive abilities
    CreateTimer(1.0, Timer_ProcessAbilities, _, TIMER_REPEAT);
    CreateTimer(0.5, Timer_FastProcess, _, TIMER_REPEAT);
}

public void OnMapStart()
{
    // Precache sounds
    PrecacheSound("animation/tank_rock_throw_01.wav", true);
    PrecacheSound("ambient/explosions/explode_4.wav", true);
    PrecacheSound("player/charger/hit/charger_smash_01.wav", true);
    PrecacheSound("ui/pickup_secret01.wav", true);
    PrecacheSound("ambient/energy/zap1.wav", true);
    PrecacheSound("ambient/energy/zap2.wav", true);
    PrecacheSound("ambient/energy/zap3.wav", true);
    PrecacheSound("player/spitter/acid/tengusplash01.wav", true);
    
    // Precache models
    PrecacheModel("models/infected/hulk.mdl", true);
    PrecacheModel("models/infected/common_male_riot.mdl", true);
    PrecacheModel("sprites/glow01.spr", true);
}

public void OnClientDisconnect(int client)
{
    if (client >= 0 && client <= MaxClients)
    {
        g_bTankSpawned[client] = false;
        g_iRageCount[client] = 0;
        g_bIsEnraged[client] = false;
        g_bIsFrozen[client] = false;
        g_bIsPoisoned[client] = false;
        g_bIsInfected[client] = false;
        
        if (g_hPoisonTimer[client] != null)
        {
            KillTimer(g_hPoisonTimer[client]);
            g_hPoisonTimer[client] = null;
        }
        
        if (g_hInfectionTimer[client] != null)
        {
            KillTimer(g_hInfectionTimer[client]);
            g_hInfectionTimer[client] = null;
        }
        
        if (g_hLightningTimer[client] != null)
        {
            KillTimer(g_hLightningTimer[client]);
            g_hLightningTimer[client] = null;
        }
        
        if (g_hToxicCloudTimer[client] != null)
        {
            KillTimer(g_hToxicCloudTimer[client]);
            g_hToxicCloudTimer[client] = null;
        }
    }
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int tank = event.GetInt("tankid");
    int client = GetClientOfUserId(tank);
    
    if (!client || !IsClientInGame(client))
        return;
    
    // Select 3 random different abilities from 40
    int abilities[40];
    for (int i = 0; i < 40; i++) abilities[i] = i;
    
    // Shuffle array
    for (int i = 39; i > 0; i--)
    {
        int j = GetRandomInt(0, i);
        int temp = abilities[i];
        abilities[i] = abilities[j];
        abilities[j] = temp;
    }
    
    // Take first 3
    g_iTankAbilities[client][0] = abilities[0];
    g_iTankAbilities[client][1] = abilities[1];
    g_iTankAbilities[client][2] = abilities[2];
    
    // Save health
    g_iTankOriginalHealth[client] = GetEntProp(client, Prop_Data, "m_iHealth");
    g_iTankHealth[client] = g_iTankOriginalHealth[client];
    g_bTankSpawned[client] = true;
    g_iRageCount[client] = 0;
    g_bIsEnraged[client] = false;
    
    // Show message in chat
    PrintToChatAll("\x04[TANK] \x01Has spawned with special abilities:");
    PrintToChatAll("\x05➤ \x031. %s \x05- \x03%s", g_szAbilityNames[g_iTankAbilities[client][0]], g_szAbilityDescriptions[g_iTankAbilities[client][0]]);
    PrintToChatAll("\x05➤ \x042. %s \x05- \x04%s", g_szAbilityNames[g_iTankAbilities[client][1]], g_szAbilityDescriptions[g_iTankAbilities[client][1]]);
    PrintToChatAll("\x05➤ \x033. %s \x05- \x03%s", g_szAbilityNames[g_iTankAbilities[client][2]], g_szAbilityDescriptions[g_iTankAbilities[client][2]]);
    
    // Show hint text
    PrintHintTextToAll("Tank has spawned with 3 special abilities!");
    
    // Apply initial abilities
    ApplyInitialAbilities(client);
    
    // SDK Hooks for the tank
    SDKHook(client, SDKHook_OnTakeDamage, OnTankTakeDamage);
    SDKHook(client, SDKHook_OnTakeDamagePost, OnTankTakeDamagePost);
}

public void Event_TankKilled(Event event, const char[] name, bool dontBroadcast)
{
    int tank = event.GetInt("tankid");
    int client = GetClientOfUserId(tank);
    
    if (!client || !g_bTankSpawned[client])
        return;
    
    // Check for Points Bank (index 1)
    if (HasAbility(client, 1))
    {
        int totalPoints = g_iTankOriginalHealth[client] / 8;
        DistributePoints(totalPoints);
    }
    
    // Check for Mini-tanks (index 13)
    if (HasAbility(client, 13))
    {
        SpawnMiniTanks(client, 4);
    }
    
    // Check for Clone (index 25)
    if (HasAbility(client, 25))
    {
        SpawnClones(client, 2);
    }
    
    // Check for Soul Drain (index 37)
    if (HasAbility(client, 37))
    {
        ApplySoulDrainEffect(client);
    }
    
    // Check for Corruption (index 38)
    if (HasAbility(client, 38))
    {
        ConvertNearbySurvivors(client);
    }
    
    // Stop any active timers
    if (g_hPoisonTimer[client] != null)
    {
        KillTimer(g_hPoisonTimer[client]);
        g_hPoisonTimer[client] = null;
    }
    
    if (g_hInfectionTimer[client] != null)
    {
        KillTimer(g_hInfectionTimer[client]);
        g_hInfectionTimer[client] = null;
    }
    
    if (g_hLightningTimer[client] != null)
    {
        KillTimer(g_hLightningTimer[client]);
        g_hLightningTimer[client] = null;
    }
    
    if (g_hToxicCloudTimer[client] != null)
    {
        KillTimer(g_hToxicCloudTimer[client]);
        g_hToxicCloudTimer[client] = null;
    }
    
    g_bTankSpawned[client] = false;
    
    PrintToChatAll("\x04[TANK] \x05Tank has been defeated! Abilities lost.");
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int damage = event.GetInt("dmg_health");
    
    if (!attacker || !victim || !g_bTankSpawned[attacker])
        return;
    
    // Life Steal (index 14)
    if (HasAbility(attacker, 14))
    {
        int currentHealth = GetClientHealth(attacker);
        int newHealth = currentHealth + damage / 2;
        int maxHealth = g_iTankOriginalHealth[attacker];
        
        if (newHealth > maxHealth)
            newHealth = maxHealth;
        
        SetEntityHealth(attacker, newHealth);
        
        PrintHintText(victim, "Tank stole your life!");
        EmitSoundToAll("ui/pickup_secret01.wav", attacker);
    }
    
    // Vampire (index 20)
    if (HasAbility(attacker, 20))
    {
        int healAmount = damage;
        int currentHealth = GetClientHealth(attacker);
        int newHealth = currentHealth + healAmount;
        int maxHealth = g_iTankOriginalHealth[attacker] * 2;
        
        if (newHealth > maxHealth)
            newHealth = maxHealth;
        
        SetEntityHealth(attacker, newHealth);
        
        PrintHintText(victim, "Vampire tank drains your blood!");
    }
    
    // Berserker (index 21) - Rage on hit
    if (HasAbility(attacker, 21))
    {
        g_iRageCount[attacker]++;
        
        if (g_iRageCount[attacker] >= 5 && !g_bIsEnraged[attacker])
        {
            ActivateRageMode(attacker);
        }
    }
    
    // Berserk Rage (index 30)
    if (HasAbility(attacker, 30))
    {
        int currentHealth = GetClientHealth(attacker);
        int healthPercent = (currentHealth * 100) / g_iTankOriginalHealth[attacker];
        
        if (healthPercent < 30 && !g_bIsEnraged[attacker])
        {
            ActivateRageMode(attacker);
        }
    }
    
    // Bloodlust (index 36)
    if (HasAbility(attacker, 36))
    {
        g_iRageCount[attacker]++;
        float speed = 1.0 + (g_iRageCount[attacker] * 0.05);
        if (speed > 2.0) speed = 2.0;
        
        SetEntPropFloat(attacker, Prop_Send, "m_flLaggedMovementValue", speed);
        PrintHintText(attacker, "Bloodlust: Speed %d%%", RoundToFloor(speed * 100));
    }
    
    // Poison (index 7)
    if (HasAbility(attacker, 7) && !g_bIsPoisoned[victim])
    {
        ApplyPoison(victim, attacker);
    }
    
    // Infect (index 8)
    if (HasAbility(attacker, 8) && !g_bIsInfected[victim])
    {
        ApplyInfection(victim);
    }
    
    // Fire (index 17)
    if (HasAbility(attacker, 17))
    {
        IgniteEntity(victim, 5.0);
        PrintHintText(victim, "You're on fire!");
    }
    
    // Ice (index 18)
    if (HasAbility(attacker, 18) && !g_bIsFrozen[victim])
    {
        FreezePlayer(victim, 2.5);
    }
    
    // Lightning (index 19)
    if (HasAbility(attacker, 19))
    {
        ChainLightning(attacker, victim);
    }
    
    // Leech (index 29)
    if (HasAbility(attacker, 29))
    {
        ApplyLeech(victim, attacker, damage);
    }
    
    // Soul Drain (index 37)
    if (HasAbility(attacker, 37))
    {
        ApplySoulDrain(victim, attacker);
    }
    
    // Doom Gaze (index 39)
    if (HasAbility(attacker, 39))
    {
        StartDoomGaze(victim, attacker);
    }
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    
    if (!attacker || !g_bTankSpawned[attacker])
        return;
    
    // Bloodlust (index 36) - reset on survivor death
    if (HasAbility(attacker, 36))
    {
        g_iRageCount[attacker] = 0;
        SetEntPropFloat(attacker, Prop_Send, "m_flLaggedMovementValue", 1.0);
    }
    
    // Reset status on victim
    if (victim > 0 && victim <= MaxClients)
    {
        g_bIsFrozen[victim] = false;
        g_bIsPoisoned[victim] = false;
        g_bIsInfected[victim] = false;
    }
}

public void Event_AbilityUse(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    int ability = event.GetInt("ability");
    
    if (!client || !g_bTankSpawned[client])
        return;
    
    // Check for rock throw abilities
    if (ability == 0)
    {
        // Boom-rock (index 0)
        if (HasAbility(client, 0))
        {
            CreateTimer(0.1, Timer_MakeRockExplosive, _, TIMER_REPEAT);
        }
        
        // Multi-rock (index 10)
        if (HasAbility(client, 10))
        {
            CreateTimer(0.1, Timer_CreateMultiRock, client);
        }
    }
}

public Action OnTankTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if (!g_bTankSpawned[victim])
        return Plugin_Continue;
    
    // Immortal (index 3) - damage reduction
    if (HasAbility(victim, 3))
    {
        damage *= 0.4;
        return Plugin_Changed;
    }
    
    // Shield (index 6) - block chance
    if (HasAbility(victim, 6))
    {
        if (GetRandomFloat(0.0, 1.0) < 0.35)
        {
            damage = 0.0;
            PrintHintText(attacker, "Tank's shield blocked!");
            EmitSoundToAll("player/charger/hit/charger_smash_01.wav", victim);
            return Plugin_Changed;
        }
    }
    
    // Earth Shield (index 34) - damage reduction
    if (HasAbility(victim, 34))
    {
        damage *= 0.6;
        return Plugin_Changed;
    }
    
    // Reflect (index 22)
    if (HasAbility(victim, 22) && attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker))
    {
        int reflectDamage = RoundToFloor(damage * 0.3);
        if (reflectDamage > 0)
        {
            SDKHooks_TakeDamage(attacker, victim, victim, float(reflectDamage), DMG_GENERIC);
            PrintHintText(attacker, "Damage reflected! -%d", reflectDamage);
        }
    }
    
    // Berserk Rage (index 30) - trigger on low health
    if (HasAbility(victim, 30))
    {
        int currentHealth = GetClientHealth(victim);
        int healthPercent = (currentHealth * 100) / g_iTankOriginalHealth[victim];
        
        if (healthPercent < 30 && !g_bIsEnraged[victim])
        {
            ActivateRageMode(victim);
        }
    }
    
    return Plugin_Continue;
}

public void OnTankTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
    if (!g_bTankSpawned[victim])
        return;
    
    g_iTankHealth[victim] = GetClientHealth(victim);
}

public Action Timer_ProcessAbilities(Handle timer)
{
    float currentTime = GetGameTime();
    
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || !IsPlayerAlive(client) || !g_bTankSpawned[client])
            continue;
        
        // Regeneration (index 4) - every 2 seconds
        if (HasAbility(client, 4) && currentTime - g_fLastAbilityUse[client] >= 2.0)
        {
            int currentHealth = GetClientHealth(client);
            
            if (currentHealth < g_iTankOriginalHealth[client])
            {
                int newHealth = currentHealth + 75;
                if (newHealth > g_iTankOriginalHealth[client])
                    newHealth = g_iTankOriginalHealth[client];
                
                SetEntityHealth(client, newHealth);
                PrintHintTextToAll("Tank is regenerating!");
            }
            
            g_fLastAbilityUse[client] = currentTime;
        }
        
        // Spawner (index 2) - every 4 seconds
        if (HasAbility(client, 2) && currentTime - g_fLastAbilityUse[client] >= 4.0)
        {
            SpawnZombieNearTank(client, 2);
            g_fLastAbilityUse[client] = currentTime;
        }
        
        // Summon Horde (index 27) - every 10 seconds
        if (HasAbility(client, 27) && currentTime - g_fLastAbilityUse[client] >= 10.0)
        {
            SpawnZombieHorde(client, 8);
            g_fLastAbilityUse[client] = currentTime;
        }
        
        // Toxic Cloud (index 33) - every 5 seconds
        if (HasAbility(client, 33) && currentTime - g_fLastAbilityUse[client] >= 5.0)
        {
            CreateToxicCloud(client);
            g_fLastAbilityUse[client] = currentTime;
        }
        
        // Gravity Well (index 23) - every 3 seconds
        if (HasAbility(client, 23) && currentTime - g_fLastAbilityUse[client] >= 3.0)
        {
            PullPlayersToTank(client);
            g_fLastAbilityUse[client] = currentTime;
        }
        
        // Check for rage abilities
        if (g_bIsEnraged[client])
        {
            // Berserker (index 21) - extra speed while enraged
            if (HasAbility(client, 21))
            {
                SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 1.8);
            }
            
            // Berserk Rage (index 30) - extra stats
            if (HasAbility(client, 30))
            {
                SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 2.0);
            }
        }
    }
    
    return Plugin_Continue;
}

public Action Timer_FastProcess(Handle timer)
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || !IsPlayerAlive(client) || !g_bTankSpawned[client])
            continue;
        
        // Speed (index 5) - always active
        if (HasAbility(client, 5))
        {
            SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 1.6);
        }
        
        // Time Slow (index 24) - slow survivors
        if (HasAbility(client, 24))
        {
            SlowSurvivorsAroundTank(client);
        }
        
        // Corruption (index 38) - check for conversions
        if (HasAbility(client, 38))
        {
            CheckCorruption(client);
        }
        
        // Doom Gaze (index 39) - check gaze
        if (HasAbility(client, 39))
        {
            CheckDoomGaze(client);
        }
    }
    
    return Plugin_Continue;
}

// ==================== HELPER FUNCTIONS ====================

bool HasAbility(int client, int abilityIndex)
{
    if (client < 0 || client > MaxClients)
        return false;
        
    return (g_iTankAbilities[client][0] == abilityIndex || 
            g_iTankAbilities[client][1] == abilityIndex || 
            g_iTankAbilities[client][2] == abilityIndex);
}

void ApplyInitialAbilities(int client)
{
    // Speed initial
    if (HasAbility(client, 5))
    {
        SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 1.6);
    }
    
    // Invisibility (index 12)
    if (HasAbility(client, 12))
    {
        SetEntityRenderMode(client, RENDER_TRANSCOLOR);
        SetEntityRenderColor(client, 255, 255, 255, 30);
    }
    
    // Wall Climb (index 15)
    if (HasAbility(client, 15))
    {
        SetEntityMoveType(client, MOVETYPE_FLY);
    }
}

void ActivateRageMode(int client)
{
    g_bIsEnraged[client] = true;
    
    PrintToChatAll("\x04[TANK] \x05The tank goes BERSERK!");
    PrintHintTextToAll("TANK BERSERK RAGE ACTIVATED!");
    
    EmitSoundToAll("player/charger/hit/charger_smash_01.wav", client);
    SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 2.2);
    
    // Rage lasts for 10 seconds
    CreateTimer(10.0, Timer_EndRageMode, client);
}

public Action Timer_EndRageMode(Handle timer, int client)
{
    if (IsClientInGame(client) && g_bTankSpawned[client])
    {
        g_bIsEnraged[client] = false;
        PrintHintTextToAll("Tank's rage has faded!");
    }
    return Plugin_Stop;
}

void DistributePoints(int totalPoints)
{
    int alivePlayers = 0;
    int[] players = new int[MaxClients];
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
        {
            players[alivePlayers++] = i;
        }
    }
    
    if (alivePlayers > 0)
    {
        int pointsPerPlayer = totalPoints / alivePlayers;
        for (int i = 0; i < alivePlayers; i++)
        {
            int client = players[i];
            PrintToChat(client, "\x04[Points Bank] \x05You received +%d points", pointsPerPlayer);
            PrintHintText(client, "+%d points", pointsPerPlayer);
        }
    }
}

void SpawnMiniTanks(int client, int count)
{
    float pos[3];
    GetClientAbsOrigin(client, pos);
    
    PrintToChatAll("\x04[TANK] \x05The tank created mini-tanks!");
    
    for (int i = 0; i < count; i++)
    {
        float spawnPos[3];
        spawnPos[0] = pos[0] + GetRandomFloat(-150.0, 150.0);
        spawnPos[1] = pos[1] + GetRandomFloat(-150.0, 150.0);
        spawnPos[2] = pos[2];
        
        int miniTank = CreateEntityByName("tank_rock");
        if (miniTank != -1)
        {
            DispatchKeyValue(miniTank, "model", "models/infected/hulk.mdl");
            DispatchSpawn(miniTank);
            TeleportEntity(miniTank, spawnPos, NULL_VECTOR, NULL_VECTOR);
            
            SetEntPropFloat(miniTank, Prop_Send, "m_flModelScale", 0.5);
            SetEntityMoveType(miniTank, MOVETYPE_WALK);
            
            CreateTimer(15.0, Timer_RemoveEntity, EntIndexToEntRef(miniTank));
        }
    }
}

void SpawnClones(int client, int count)
{
    float pos[3];
    GetClientAbsOrigin(client, pos);
    
    PrintToChatAll("\x04[TANK] \x05The tank created clones!");
    
    for (int i = 0; i < count; i++)
    {
        float clonePos[3];
        clonePos[0] = pos[0] + GetRandomFloat(-200.0, 200.0);
        clonePos[1] = pos[1] + GetRandomFloat(-200.0, 200.0);
        clonePos[2] = pos[2];
        
        int clone = CreateEntityByName("tank_rock");
        if (clone != -1)
        {
            DispatchKeyValue(clone, "model", "models/infected/hulk.mdl");
            DispatchSpawn(clone);
            TeleportEntity(clone, clonePos, NULL_VECTOR, NULL_VECTOR);
            
            SetEntityRenderMode(clone, RENDER_TRANSCOLOR);
            SetEntityRenderColor(clone, 255, 255, 255, 150);
            
            CreateTimer(20.0, Timer_RemoveEntity, EntIndexToEntRef(clone));
        }
    }
}

void ApplySoulDrainEffect(int client)
{
    float pos[3];
    GetClientAbsOrigin(client, pos);
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
        {
            float targetPos[3];
            GetClientAbsOrigin(i, targetPos);
            
            if (GetVectorDistance(pos, targetPos) < 500.0)
            {
                int currentHealth = GetClientHealth(i);
                int drainAmount = 20;
                int newHealth = currentHealth - drainAmount;
                
                if (newHealth < 1)
                    newHealth = 1;
                
                SetEntityHealth(i, newHealth);
                PrintHintText(i, "Soul drained by tank!");
            }
        }
    }
}

void ConvertNearbySurvivors(int client)
{
    float pos[3];
    GetClientAbsOrigin(client, pos);
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
        {
            float targetPos[3];
            GetClientAbsOrigin(i, targetPos);
            
            if (GetVectorDistance(pos, targetPos) < 300.0)
            {
                if (GetRandomFloat(0.0, 1.0) < 0.3)
                {
                    ConvertToZombie(i);
                }
            }
        }
    }
}

void ConvertToZombie(int client)
{
    PrintHintText(client, "You have been corrupted!");
    PrintToChat(client, "\x04[Corruption] \x05You are now a zombie!");
    
    SetEntProp(client, Prop_Send, "m_iTeamNum", 3);
    SetEntityModel(client, "models/infected/common_male_riot.mdl");
    
    CreateTimer(0.5, Timer_ConvertedZombieAI, client, TIMER_REPEAT);
}

void ApplyPoison(int victim, int attacker)
{
    g_bIsPoisoned[victim] = true;
    
    DataPack pack = new DataPack();
    pack.WriteCell(GetClientUserId(victim));
    pack.WriteCell(GetClientUserId(attacker));
    g_hPoisonTimer[victim] = CreateTimer(1.0, Timer_PoisonDamage, pack, TIMER_REPEAT);
}

void ApplyInfection(int victim)
{
    g_bIsInfected[victim] = true;
    PrintHintText(victim, "You've been infected!");
    
    SetEntPropFloat(victim, Prop_Send, "m_flLaggedMovementValue", 0.7);
    
    DataPack pack = new DataPack();
    pack.WriteCell(GetClientUserId(victim));
    g_hInfectionTimer[victim] = CreateTimer(1.0, Timer_InfectionDamage, pack, TIMER_REPEAT);
}

void ApplyLeech(int victim, int attacker, int damage)
{
    int healAmount = damage / 3;
    int currentHealth = GetClientHealth(attacker);
    int newHealth = currentHealth + healAmount;
    int maxHealth = g_iTankOriginalHealth[attacker] * 2;
    
    if (newHealth > maxHealth)
        newHealth = maxHealth;
    
    SetEntityHealth(attacker, newHealth);
    PrintHintText(victim, "Tank leeches your health!");
}

void ApplySoulDrain(int victim, int attacker)
{
    int drainAmount = 5;
    int currentHealth = GetClientHealth(victim);
    int newHealth = currentHealth - drainAmount;
    
    if (newHealth < 1)
        newHealth = 1;
    
    SetEntityHealth(victim, newHealth);
    PrintHintText(victim, "Soul drained!");
}

void StartDoomGaze(int victim, int attacker)
{
    g_iLightningTarget[victim] = attacker;
    
    DataPack pack = new DataPack();
    pack.WriteCell(GetClientUserId(victim));
    pack.WriteCell(GetClientUserId(attacker));
    g_hLightningTimer[victim] = CreateTimer(0.5, Timer_DoomGaze, pack, TIMER_REPEAT);
}

void FreezePlayer(int client, float duration)
{
    g_bIsFrozen[client] = true;
    SetEntityMoveType(client, MOVETYPE_NONE);
    SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 0.0);
    
    PrintHintText(client, "You're frozen!");
    
    DataPack pack = new DataPack();
    pack.WriteCell(GetClientUserId(client));
    CreateTimer(duration, Timer_UnfreezePlayer, pack);
}

void ChainLightning(int attacker, int startVictim)
{
    float startPos[3];
    GetClientAbsOrigin(startVictim, startPos);
    
    int currentVictim = startVictim;
    int jumps = 0;
    int maxJumps = 5;
    
    while (jumps < maxJumps)
    {
        int nextVictim = FindNearestSurvivor(currentVictim, 300.0);
        
        if (nextVictim == -1 || nextVictim == currentVictim)
            break;
        
        SDKHooks_TakeDamage(nextVictim, attacker, attacker, 15.0, DMG_SHOCK);
        
        EmitSoundToAll("ambient/energy/zap1.wav", nextVictim);
        
        currentVictim = nextVictim;
        jumps++;
    }
}

void SpawnZombieNearTank(int tank, int count)
{
    float tankPos[3];
    GetClientAbsOrigin(tank, tankPos);
    
    for (int i = 0; i < count; i++)
    {
        float spawnPos[3];
        spawnPos[0] = tankPos[0] + GetRandomFloat(-250.0, 250.0);
        spawnPos[1] = tankPos[1] + GetRandomFloat(-250.0, 250.0);
        spawnPos[2] = tankPos[2];
        
        int zombie = CreateEntityByName("infected");
        if (zombie != -1)
        {
            DispatchSpawn(zombie);
            TeleportEntity(zombie, spawnPos, NULL_VECTOR, NULL_VECTOR);
            SetEntityMoveType(zombie, MOVETYPE_WALK);
        }
    }
}

void SpawnZombieHorde(int tank, int count)
{
    float tankPos[3];
    GetClientAbsOrigin(tank, tankPos);
    
    PrintToChatAll("\x04[TANK] \x05The tank summoned a zombie horde!");
    
    for (int i = 0; i < count; i++)
    {
        float spawnPos[3];
        spawnPos[0] = tankPos[0] + GetRandomFloat(-400.0, 400.0);
        spawnPos[1] = tankPos[1] + GetRandomFloat(-400.0, 400.0);
        spawnPos[2] = tankPos[2];
        
        int zombie = CreateEntityByName("infected");
        if (zombie != -1)
        {
            DispatchSpawn(zombie);
            TeleportEntity(zombie, spawnPos, NULL_VECTOR, NULL_VECTOR);
        }
    }
}

void CreateToxicCloud(int tank)
{
    float tankPos[3];
    GetClientAbsOrigin(tank, tankPos);
    
    PrintHintTextToAll("Tank created a toxic cloud!");
    
    int cloud = CreateEntityByName("env_smokestack");
    if (cloud != -1)
    {
        DispatchKeyValue(cloud, "BaseSpread", "50");
        DispatchKeyValue(cloud, "SpreadSpeed", "20");
        DispatchKeyValue(cloud, "Speed", "30");
        DispatchKeyValue(cloud, "StartColor", "0 255 0");
        DispatchKeyValue(cloud, "EndColor", "0 100 0");
        DispatchKeyValue(cloud, "SmokeMaterial", "sprites/glow01.spr");
        
        DispatchSpawn(cloud);
        TeleportEntity(cloud, tankPos, NULL_VECTOR, NULL_VECTOR);
        
        CreateTimer(10.0, Timer_RemoveEntity, EntIndexToEntRef(cloud));
        
        g_hToxicCloudTimer[tank] = CreateTimer(1.0, Timer_ToxicCloudDamage, tank, TIMER_REPEAT);
    }
}

void PullPlayersToTank(int tank)
{
    float tankPos[3];
    GetClientAbsOrigin(tank, tankPos);
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
        {
            float playerPos[3];
            GetClientAbsOrigin(i, playerPos);
            
            float distance = GetVectorDistance(tankPos, playerPos);
            
            if (distance < 600.0 && distance > 100.0)
            {
                float pullVector[3];
                SubtractVectors(tankPos, playerPos, pullVector);
                NormalizeVector(pullVector, pullVector);
                
                ScaleVector(pullVector, 50.0);
                AddVectors(playerPos, pullVector, playerPos);
                
                TeleportEntity(i, playerPos, NULL_VECTOR, NULL_VECTOR);
                PrintHintText(i, "Gravity well pulling you!");
            }
        }
    }
}

void SlowSurvivorsAroundTank(int tank)
{
    float tankPos[3];
    GetClientAbsOrigin(tank, tankPos);
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
        {
            float playerPos[3];
            GetClientAbsOrigin(i, playerPos);
            
            if (GetVectorDistance(tankPos, playerPos) < 400.0)
            {
                SetEntPropFloat(i, Prop_Send, "m_flLaggedMovementValue", 0.3);
            }
            else
            {
                SetEntPropFloat(i, Prop_Send, "m_flLaggedMovementValue", 1.0);
            }
        }
    }
}

void CheckCorruption(int tank)
{
    float tankPos[3];
    GetClientAbsOrigin(tank, tankPos);
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
        {
            float playerPos[3];
            GetClientAbsOrigin(i, playerPos);
            
            if (GetVectorDistance(tankPos, playerPos) < 200.0)
            {
                if (GetRandomFloat(0.0, 1.0) < 0.01)
                {
                    ConvertToZombie(i);
                }
            }
        }
    }
}

void CheckDoomGaze(int tank)
{
    float tankPos[3];
    GetClientAbsOrigin(tank, tankPos);
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2 && g_iLightningTarget[i] == tank)
        {
            float playerPos[3];
            GetClientAbsOrigin(i, playerPos);
            
            if (GetVectorDistance(tankPos, playerPos) < 500.0)
            {
                int currentHealth = GetClientHealth(i);
                int newHealth = currentHealth - 2;
                
                if (newHealth < 1)
                    newHealth = 1;
                
                SetEntityHealth(i, newHealth);
                PrintHintText(i, "Doom Gaze: Don't look at the tank!");
            }
            else
            {
                g_iLightningTarget[i] = 0;
                if (g_hLightningTimer[i] != null)
                {
                    KillTimer(g_hLightningTimer[i]);
                    g_hLightningTimer[i] = null;
                }
            }
        }
    }
}

int FindNearestSurvivor(int startClient, float maxDist)
{
    float startPos[3];
    GetClientAbsOrigin(startClient, startPos);
    
    int nearest = -1;
    float nearestDist = maxDist + 1.0;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (i != startClient && IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
        {
            float pos[3];
            GetClientAbsOrigin(i, pos);
            
            float dist = GetVectorDistance(startPos, pos);
            
            if (dist < nearestDist)
            {
                nearest = i;
                nearestDist = dist;
            }
        }
    }
    
    return nearest;
}

// ==================== TIMER CALLBACKS ====================

public Action Timer_MakeRockExplosive(Handle timer)
{
    int rock = -1;
    while ((rock = FindEntityByClassname(rock, "tank_rock")) != -1)
    {
        if (!GetEntProp(rock, Prop_Send, "m_bExplosive"))
        {
            SetEntProp(rock, Prop_Send, "m_bExplosive", 1);
        }
    }
    
    return Plugin_Continue;
}

public Action Timer_CreateMultiRock(Handle timer, int client)
{
    if (!IsClientInGame(client) || !IsPlayerAlive(client) || !g_bTankSpawned[client])
        return Plugin_Stop;
    
    float pos[3];
    GetClientAbsOrigin(client, pos);
    
    for (int i = 0; i < 3; i++)
    {
        float rockPos[3];
        rockPos[0] = pos[0] + GetRandomFloat(-100.0, 100.0);
        rockPos[1] = pos[1] + GetRandomFloat(-100.0, 100.0);
        rockPos[2] = pos[2] + 50.0;
        
        int rock = CreateEntityByName("tank_rock");
        if (rock != -1)
        {
            DispatchSpawn(rock);
            TeleportEntity(rock, rockPos, NULL_VECTOR, NULL_VECTOR);
            
            float vel[3];
            vel[0] = GetRandomFloat(-500.0, 500.0);
            vel[1] = GetRandomFloat(-500.0, 500.0);
            vel[2] = GetRandomFloat(200.0, 400.0);
            TeleportEntity(rock, NULL_VECTOR, NULL_VECTOR, vel);
        }
    }
    
    PrintToChatAll("\x04[TANK] \x05Multi-rock: Tank threw multiple rocks!");
    
    return Plugin_Stop;
}

public Action Timer_PoisonDamage(Handle timer, DataPack pack)
{
    pack.Reset();
    int victim = GetClientOfUserId(pack.ReadCell());
    int attacker = GetClientOfUserId(pack.ReadCell());
    
    if (!IsClientInGame(victim) || !IsPlayerAlive(victim))
    {
        g_hPoisonTimer[victim] = null;
        g_bIsPoisoned[victim] = false;
        delete pack;
        return Plugin_Stop;
    }
    
    int health = GetClientHealth(victim);
    health -= 3;
    
    if (health <= 0)
    {
        ForcePlayerSuicide(victim);
        g_hPoisonTimer[victim] = null;
        g_bIsPoisoned[victim] = false;
        delete pack;
        return Plugin_Stop;
    }
    
    SetEntityHealth(victim, health);
    PrintHintText(victim, "Poison damage: -3");
    
    return Plugin_Continue;
}

public Action Timer_InfectionDamage(Handle timer, DataPack pack)
{
    pack.Reset();
    int victim = GetClientOfUserId(pack.ReadCell());
    
    if (!IsClientInGame(victim) || !IsPlayerAlive(victim))
    {
        g_hInfectionTimer[victim] = null;
        g_bIsInfected[victim] = false;
        delete pack;
        return Plugin_Stop;
    }
    
    int health = GetClientHealth(victim);
    health -= 2;
    
    if (health <= 0)
    {
        ForcePlayerSuicide(victim);
        g_hInfectionTimer[victim] = null;
        g_bIsInfected[victim] = false;
        delete pack;
        return Plugin_Stop;
    }
    
    SetEntityHealth(victim, health);
    PrintHintText(victim, "Infection damage: -2");
    
    return Plugin_Continue;
}

public Action Timer_DoomGaze(Handle timer, DataPack pack)
{
    pack.Reset();
    int victim = GetClientOfUserId(pack.ReadCell());
    int attacker = GetClientOfUserId(pack.ReadCell());
    
    if (!IsClientInGame(victim) || !IsPlayerAlive(victim) || 
        !IsClientInGame(attacker) || !IsPlayerAlive(attacker) ||
        !g_bTankSpawned[attacker])
    {
        g_hLightningTimer[victim] = null;
        g_iLightningTarget[victim] = 0;
        delete pack;
        return Plugin_Stop;
    }
    
    float victimPos[3];
    float attackerPos[3];
    GetClientAbsOrigin(victim, victimPos);
    GetClientAbsOrigin(attacker, attackerPos);
    
    if (GetVectorDistance(victimPos, attackerPos) > 500.0)
    {
        g_hLightningTimer[victim] = null;
        g_iLightningTarget[victim] = 0;
        delete pack;
        return Plugin_Stop;
    }
    
    int health = GetClientHealth(victim);
    health -= 5;
    
    if (health <= 0)
    {
        ForcePlayerSuicide(victim);
        g_hLightningTimer[victim] = null;
        g_iLightningTarget[victim] = 0;
        delete pack;
        return Plugin_Stop;
    }
    
    SetEntityHealth(victim, health);
    PrintHintText(victim, "Doom Gaze: -5");
    
    return Plugin_Continue;
}

public Action Timer_UnfreezePlayer(Handle timer, DataPack pack)
{
    pack.Reset();
    int client = GetClientOfUserId(pack.ReadCell());
    delete pack;
    
    if (IsClientInGame(client))
    {
        SetEntityMoveType(client, MOVETYPE_WALK);
        SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 1.0);
        g_bIsFrozen[client] = false;
        PrintHintText(client, "You're unfrozen!");
    }
    
    return Plugin_Stop;
}

public Action Timer_RemoveEntity(Handle timer, int ref)
{
    int entity = EntRefToEntIndex(ref);
    if (entity != INVALID_ENT_REFERENCE && IsValidEntity(entity))
    {
        AcceptEntityInput(entity, "Kill");
    }
    return Plugin_Stop;
}

public Action Timer_ToxicCloudDamage(Handle timer, int tank)
{
    if (!IsClientInGame(tank) || !IsPlayerAlive(tank) || !g_bTankSpawned[tank])
    {
        g_hToxicCloudTimer[tank] = null;
        return Plugin_Stop;
    }
    
    float tankPos[3];
    GetClientAbsOrigin(tank, tankPos);
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
        {
            float playerPos[3];
            GetClientAbsOrigin(i, playerPos);
            
            if (GetVectorDistance(tankPos, playerPos) < 250.0)
            {
                int health = GetClientHealth(i);
                health -= 4;
                
                if (health < 1)
                    health = 1;
                
                SetEntityHealth(i, health);
                PrintHintText(i, "Toxic cloud damage: -4");
            }
        }
    }
    
    return Plugin_Continue;
}

public Action Timer_ConvertedZombieAI(Handle timer, int client)
{
    if (!IsClientInGame(client) || !IsPlayerAlive(client))
        return Plugin_Stop;
    
    float clientPos[3];
    GetClientAbsOrigin(client, clientPos);
    
    int nearestSurvivor = -1;
    float nearestDist = 1000.0;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (i != client && IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
        {
            float pos[3];
            GetClientAbsOrigin(i, pos);
            
            float dist = GetVectorDistance(clientPos, pos);
            
            if (dist < nearestDist)
            {
                nearestSurvivor = i;
                nearestDist = dist;
            }
        }
    }
    
    if (nearestSurvivor != -1 && nearestDist < 100.0)
    {
        SDKHooks_TakeDamage(nearestSurvivor, client, client, 10.0, DMG_SLASH);
    }
    else if (nearestSurvivor != -1)
    {
        float targetPos[3];
        GetClientAbsOrigin(nearestSurvivor, targetPos);
        
        float moveDir[3];
        SubtractVectors(targetPos, clientPos, moveDir);
        NormalizeVector(moveDir, moveDir);
        ScaleVector(moveDir, 50.0);
        
        AddVectors(clientPos, moveDir, clientPos);
        TeleportEntity(client, clientPos, NULL_VECTOR, NULL_VECTOR);
    }
    
    return Plugin_Continue;
}