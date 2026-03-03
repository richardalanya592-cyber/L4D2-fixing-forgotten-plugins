#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "2.0.0"
#define PLUGIN_NAME "Weapon Speed Controller"

// ConVars
ConVar g_cvEnabled;
ConVar g_cvMeleeSwingRate;
ConVar g_cvFireRateMultiplier;
ConVar g_cvAdminOnly;
ConVar g_cvWeaponList;
ConVar g_cvDebug;

// Variables
bool g_bLateLoad;
bool g_bEnabled;
float g_fMeleeSwingRate;
float g_fFireRateMultiplier;
bool g_bAdminOnly;
char g_sWeaponList[256];
bool g_bDebug;

// Weapon configuration
ArrayList g_aWeaponConfigs;
StringMap g_smWeaponOverrides;

enum struct WeaponConfig
{
    char name[64];
    float meleeRate;
    float fireRate;
    bool override;
}

public Plugin myinfo = 
{
    name = "[L4D2] Weapon Speed Controller",
    author = "Harry Potter + Improvements",
    description = "Adjustable melee swing rate and weapon fire rate",
    version = PLUGIN_VERSION,
    url = "https://github.com/your-repo"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_bLateLoad = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    // Create convars
    g_cvEnabled = CreateConVar("l4d2_wsc_enabled", "1", "Enable/disable the plugin");
    g_cvMeleeSwingRate = CreateConVar("l4d2_wsc_melee_rate", "1.5", "Melee swing rate multiplier (0.5 = slower, 2.0 = faster)");
    g_cvFireRateMultiplier = CreateConVar("l4d2_wsc_fire_rate", "1.2", "Fire rate multiplier for all weapons (0.5 = slower, 2.0 = faster)");
    g_cvAdminOnly = CreateConVar("l4d2_wsc_admin_only", "0", "Restrict weapon speed modifications to admins only");
    g_cvWeaponList = CreateConVar("l4d2_wsc_weapon_list", "all", "Weapons to affect (all, melee_only, firearm_only, or comma-separated list: weapon_smg,weapon_rifle)");
    g_cvDebug = CreateConVar("l4d2_wsc_debug", "0", "Enable debug messages");
    
    // Hook changes
    g_cvEnabled.AddChangeHook(OnConVarChanged);
    g_cvMeleeSwingRate.AddChangeHook(OnConVarChanged);
    g_cvFireRateMultiplier.AddChangeHook(OnConVarChanged);
    g_cvAdminOnly.AddChangeHook(OnConVarChanged);
    g_cvWeaponList.AddChangeHook(OnConVarChanged);
    g_cvDebug.AddChangeHook(OnConVarChanged);
    
    // Auto-exec config
    AutoExecConfig(true, "l4d2_weapon_speed_controller");
    
    // Initialize arrays
    g_aWeaponConfigs = new ArrayList(sizeof(WeaponConfig));
    g_smWeaponOverrides = new StringMap();
    
    // Load default weapon configs
    LoadDefaultWeaponConfigs();
    
    // Late load
    if (g_bLateLoad)
    {
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i))
            {
                OnClientPutInServer(i);
            }
        }
    }
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    UpdateConVars();
}

void UpdateConVars()
{
    g_bEnabled = g_cvEnabled.BoolValue;
    g_fMeleeSwingRate = g_cvMeleeSwingRate.FloatValue;
    g_fFireRateMultiplier = g_cvFireRateMultiplier.FloatValue;
    g_bAdminOnly = g_cvAdminOnly.BoolValue;
    g_cvWeaponList.GetString(g_sWeaponList, sizeof(g_sWeaponList));
    g_bDebug = g_cvDebug.BoolValue;
    
    if (g_bDebug)
    {
        PrintToServer("[WSC] Settings updated: Enabled=%d, MeleeRate=%.2f, FireRate=%.2f, AdminOnly=%d",
            g_bEnabled, g_fMeleeSwingRate, g_fFireRateMultiplier, g_bAdminOnly);
    }
}

void LoadDefaultWeaponConfigs()
{
    // Melee weapons
    AddWeaponConfig("fireaxe", 1.5, 1.0, true);
    AddWeaponConfig("baseball_bat", 1.5, 1.0, true);
    AddWeaponConfig("cricket_bat", 1.5, 1.0, true);
    AddWeaponConfig("crowbar", 1.5, 1.0, true);
    AddWeaponConfig("electric_guitar", 1.5, 1.0, true);
    AddWeaponConfig("frying_pan", 1.5, 1.0, true);
    AddWeaponConfig("golfclub", 1.5, 1.0, true);
    AddWeaponConfig("katana", 1.5, 1.0, true);
    AddWeaponConfig("knife", 1.5, 1.0, true);
    AddWeaponConfig("machete", 1.5, 1.0, true);
    AddWeaponConfig("tonfa", 1.5, 1.0, true);
    AddWeaponConfig("shovel", 1.5, 1.0, true);
    AddWeaponConfig("pitchfork", 1.5, 1.0, true);
    
    // Firearms
    AddWeaponConfig("weapon_smg", 1.0, 1.2, false);
    AddWeaponConfig("weapon_smg_silenced", 1.0, 1.2, false);
    AddWeaponConfig("weapon_rifle", 1.0, 1.2, false);
    AddWeaponConfig("weapon_rifle_ak47", 1.0, 1.1, false);
    AddWeaponConfig("weapon_rifle_desert", 1.0, 1.1, false);
    AddWeaponConfig("weapon_rifle_m60", 1.0, 1.0, false);
    AddWeaponConfig("weapon_autoshotgun", 1.0, 1.0, false);
    AddWeaponConfig("weapon_shotgun_chrome", 1.0, 1.0, false);
    AddWeaponConfig("weapon_pumpshotgun", 1.0, 1.0, false);
    AddWeaponConfig("weapon_shotgun_spas", 1.0, 1.1, false);
    AddWeaponConfig("weapon_hunting_rifle", 1.0, 1.0, false);
    AddWeaponConfig("weapon_sniper_scout", 1.0, 1.0, false);
    AddWeaponConfig("weapon_sniper_military", 1.0, 1.0, false);
    AddWeaponConfig("weapon_sniper_awp", 1.0, 1.0, false);
    AddWeaponConfig("weapon_pistol", 1.0, 1.3, false);
    AddWeaponConfig("weapon_pistol_magnum", 1.0, 1.0, false);
    AddWeaponConfig("weapon_mp5navy", 1.0, 1.2, false);
    AddWeaponConfig("weapon_grenade_launcher", 1.0, 1.0, false);
}

void AddWeaponConfig(const char[] name, float meleeRate, float fireRate, bool override)
{
    WeaponConfig config;
    strcopy(config.name, sizeof(config.name), name);
    config.meleeRate = meleeRate;
    config.fireRate = fireRate;
    config.override = override;
    
    g_aWeaponConfigs.PushArray(config);
    g_smWeaponOverrides.SetValue(name, g_aWeaponConfigs.Length - 1);
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
}

public void OnWeaponEquipPost(int client, int weapon)
{
    if (!g_bEnabled || !IsValidEntity(weapon))
        return;
    
    if (g_bAdminOnly && !CheckCommandAccess(client, "wsc_admin", ADMFLAG_GENERIC))
        return;
    
    char weaponClass[64];
    GetEntityClassname(weapon, weaponClass, sizeof(weaponClass));
    
    // Remove "weapon_" prefix for melee weapons
    ReplaceString(weaponClass, sizeof(weaponClass), "weapon_", "");
    
    if (ShouldModifyWeapon(weaponClass))
    {
        RequestFrame(Frame_ApplyWeaponMods, EntIndexToEntRef(weapon));
    }
}

void Frame_ApplyWeaponMods(int weaponRef)
{
    int weapon = EntRefToEntIndex(weaponRef);
    if (weapon == INVALID_ENT_REFERENCE)
        return;
    
    ApplyWeaponModifications(weapon);
}

void ApplyWeaponModifications(int weapon)
{
    char weaponClass[64];
    GetEntityClassname(weapon, weaponClass, sizeof(weaponClass));
    
    // Store original class for melee weapons
    char originalClass[64];
    strcopy(originalClass, sizeof(originalClass), weaponClass);
    ReplaceString(weaponClass, sizeof(weaponClass), "weapon_", "");
    
    int configIndex = -1;
    g_smWeaponOverrides.GetValue(weaponClass, configIndex);
    
    float meleeRate = g_fMeleeSwingRate;
    float fireRate = g_fFireRateMultiplier;
    
    // Check for weapon-specific overrides
    if (configIndex != -1)
    {
        WeaponConfig config;
        g_aWeaponConfigs.GetArray(configIndex, config);
        
        if (config.override)
        {
            meleeRate = config.meleeRate;
        }
        
        // Special handling for melee weapons
        if (StrContains(originalClass, "melee") != -1)
        {
            ApplyMeleeModifications(weapon, meleeRate);
        }
    }
    
    // Apply fire rate modifications to all weapons
    ApplyFireRateModifications(weapon, fireRate);
    
    if (g_bDebug)
    {
        PrintToServer("[WSC] Applied mods to weapon %s (melee: %.2f, fire: %.2f)", 
            weaponClass, meleeRate, fireRate);
    }
}

void ApplyMeleeModifications(int weapon, float rate)
{
    // Modify melee swing delay
    SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", 
        GetGameTime() + (0.5 / rate)); // Base melee swing time is 0.5s
    
    // Store custom value for persistence
    SetEntPropFloat(weapon, Prop_Data, "m_flAnimSpeed", rate);
}

void ApplyFireRateModifications(int weapon, float rate)
{
    // Modify fire rate for firearms
    float nextAttack = GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack");
    float nextSecondary = GetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack");
    
    float gameTime = GetGameTime();
    
    if (nextAttack > gameTime)
    {
        // Adjust existing cooldown
        float remaining = nextAttack - gameTime;
        SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", 
            gameTime + (remaining / rate));
    }
    
    if (nextSecondary > gameTime)
    {
        float remaining = nextSecondary - gameTime;
        SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", 
            gameTime + (remaining / rate));
    }
    
    // Store cycle time for automatic weapons
    float cycleTime = GetEntPropFloat(weapon, Prop_Send, "m_flCycleTime");
    if (cycleTime > 0.0)
    {
        SetEntPropFloat(weapon, Prop_Send, "m_flCycleTime", cycleTime / rate);
    }
}

bool ShouldModifyWeapon(const char[] weaponClass)
{
    if (StrEqual(g_sWeaponList, "all"))
        return true;
    
    if (StrEqual(g_sWeaponList, "melee_only"))
    {
        return (StrContains(weaponClass, "melee") != -1 || 
                StrContains(weaponClass, "fireaxe") != -1 ||
                StrContains(weaponClass, "bat") != -1);
    }
    
    if (StrEqual(g_sWeaponList, "firearm_only"))
    {
        return (StrContains(weaponClass, "weapon_") != -1 && 
                StrContains(weaponClass, "melee") == -1);
    }
    
    // Check custom list
    char weapons[256];
    strcopy(weapons, sizeof(weapons), g_sWeaponList);
    
    char parts[32][64];
    int count = ExplodeString(weapons, ",", parts, sizeof(parts), sizeof(parts[]));
    
    for (int i = 0; i < count; i++)
    {
        TrimString(parts[i]);
        if (StrContains(weaponClass, parts[i]) != -1)
            return true;
    }
    
    return false;
}

// Admin commands
public void OnPluginEnd()
{
    ResetAllWeapons();
}

void ResetAllWeapons()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsPlayerAlive(i))
        {
            int weapon = GetPlayerWeaponSlot(i, 0); // Primary
            if (weapon != -1)
                ResetWeapon(weapon);
            
            weapon = GetPlayerWeaponSlot(i, 1); // Secondary
            if (weapon != -1)
                ResetWeapon(weapon);
            
            weapon = GetPlayerWeaponSlot(i, 2); // Melee
            if (weapon != -1)
                ResetWeapon(weapon);
        }
    }
}

void ResetWeapon(int weapon)
{
    if (!IsValidEntity(weapon))
        return;
    
    // Reset to default values
    SetEntPropFloat(weapon, Prop_Data, "m_flAnimSpeed", 1.0);
    
    char weaponClass[64];
    GetEntityClassname(weapon, weaponClass, sizeof(weaponClass));
    
    if (g_bDebug)
    {
        PrintToServer("[WSC] Reset weapon: %s", weaponClass);
    }
}

// Additional features: Dynamic adjustment during gameplay
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    if (!g_bEnabled || !IsClientInGame(client) || !IsPlayerAlive(client))
        return Plugin_Continue;
    
    if (g_bAdminOnly && !CheckCommandAccess(client, "wsc_admin", ADMFLAG_GENERIC))
        return Plugin_Continue;
    
    // Check for melee attack
    if (buttons & IN_ATTACK2)
    {
        int meleeWeapon = GetPlayerWeaponSlot(client, 2);
        if (meleeWeapon != -1)
        {
            // Dynamic melee speed adjustment
            float animSpeed = GetEntPropFloat(meleeWeapon, Prop_Data, "m_flAnimSpeed");
            if (animSpeed != g_fMeleeSwingRate)
            {
                SetEntPropFloat(meleeWeapon, Prop_Data, "m_flAnimSpeed", g_fMeleeSwingRate);
            }
        }
    }
    
    return Plugin_Continue;
}