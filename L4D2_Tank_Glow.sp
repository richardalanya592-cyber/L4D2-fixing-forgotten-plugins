/**
 * v1.0.0 - L4D2 Tank Glow
 * An improved SourceMod plugin that applies a glow effect to Tanks in Left 4 Dead 2,
 * visible to all players.
 *
 * Based on the glow functionality from "Mutant Tanks" and the private plugin
 * "l4d2_tank_glow" by author "Harry Potter".
 */

#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0.0"

// --- Default Configuration ---
#define DEFAULT_GLOW_COLOR "255 0 0" // Red
#define DEFAULT_GLOW_ENABLED 1       // Enabled
#define DEFAULT_GLOW_DISTANCE 1500   // Glow distance (in units)

// --- Global Variables ---
ConVar g_cvGlowEnabled = null;
ConVar g_cvGlowColor = null;
ConVar g_cvGlowDistance = null;

int g_iGlowColor[4] = {255, 0, 0, 255}; // Red (RGBA)
bool g_bLateLoad = false;

public Plugin myinfo =
{
    name = "[L4D2] Tank Glow (Improved)",
    author = "Your Name / Based on Harry Potter",
    description = "Applies a visible glow effect to Tanks for all players.",
    version = PLUGIN_VERSION,
    url = "https://github.com/"
};

/**
 * Called when the plugin is loaded.
 */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_bLateLoad = late;
    return APLRes_Success;
}

/**
 * Called when the plugin starts.
 */
public void OnPluginStart()
{
    // Create ConVars
    CreateConVar("l4d2_tank_glow_version", PLUGIN_VERSION, "Version of the [L4D2] Tank Glow plugin.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

    g_cvGlowEnabled = CreateConVar("l4d2_tank_glow_enabled", "1", "Enable glow effect on Tanks? (1 = Yes, 0 = No)", FCVAR_NONE, true, 0.0, true, 1.0);
    g_cvGlowColor = CreateConVar("l4d2_tank_glow_color", DEFAULT_GLOW_COLOR, "Glow color in RGB format (e.g. '255 0 0' for red).", FCVAR_NONE);
    g_cvGlowDistance = CreateConVar("l4d2_tank_glow_distance", "1500", "Maximum distance the glow is visible (in units).", FCVAR_NONE, true, 100.0, true, 5000.0);

    // Hook ConVar changes
    g_cvGlowColor.AddChangeHook(OnConVarChanged);
    g_cvGlowDistance.AddChangeHook(OnConVarChanged);

    // Execute change hook once to set initial color
    OnConVarChanged(g_cvGlowColor, "", "");

    // Hook events
    HookEvent("tank_spawn", Event_TankSpawn);
    HookEvent("player_team", Event_PlayerTeam);
    
    // Auto-execute for late load
    if (g_bLateLoad)
    {
        RequestFrame(OnNextFrame);
    }
}

public void OnNextFrame()
{
    ApplyGlowToAllTanks();
}

/**
 * Called when plugin is ready.
 */
public void OnConfigsExecuted()
{
    ApplyGlowToAllTanks();
}

/**
 * Handles ConVar changes.
 */
public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cvGlowColor)
    {
        char sColor[16];
        g_cvGlowColor.GetString(sColor, sizeof(sColor));
        
        if (strlen(sColor) == 0)
        {
            strcopy(sColor, sizeof(sColor), DEFAULT_GLOW_COLOR);
        }

        char sColors[3][4];
        int numColors = ExplodeString(sColor, " ", sColors, 3, 4);

        if (numColors == 3)
        {
            g_iGlowColor[0] = StringToInt(sColors[0]);
            g_iGlowColor[1] = StringToInt(sColors[1]);
            g_iGlowColor[2] = StringToInt(sColors[2]);
            g_iGlowColor[3] = 255;
        }
        else
        {
            LogError("Invalid color format in l4d2_tank_glow_color. Using default red.");
            g_iGlowColor[0] = 255;
            g_iGlowColor[1] = 0;
            g_iGlowColor[2] = 0;
            g_iGlowColor[3] = 255;
        }

        ApplyGlowToAllTanks();
    }
}

/**
 * Called when a Tank spawns.
 */
public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvGlowEnabled.BoolValue)
        return;
        
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client && IsClientInGame(client))
    {
        ApplyGlowToTank(client);
    }
}

/**
 * Called when a player changes team.
 */
public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvGlowEnabled.BoolValue)
        return;
        
    int userid = event.GetInt("userid");
    int client = GetClientOfUserId(userid);
    int team = event.GetInt("team");

    // If player switched to infected team
    if (team == 3 && client && IsClientInGame(client))
    {
        // Check if it's a Tank
        if (IsTank(client))
        {
            ApplyGlowToTank(client);
        }
    }
}

/**
 * Checks if a client is a Tank.
 */
bool IsTank(int client)
{
    if (client < 1 || client > MaxClients)
        return false;
        
    if (!IsClientInGame(client))
        return false;
        
    if (GetClientTeam(client) != 3)
        return false;
    
    return (GetEntProp(client, Prop_Send, "m_zombieClass") == 8);
}

/**
 * Applies glow effect to a specific Tank client.
 */
void ApplyGlowToTank(int client)
{
    if (!IsValidEntity(client))
        return;
        
    if (!IsTank(client))
        return;

    // Set glow properties
    SetEntProp(client, Prop_Send, "m_glowColorOverride", GetColorInt(g_iGlowColor));
    SetEntProp(client, Prop_Send, "m_iGlowType", 3);
    SetEntProp(client, Prop_Send, "m_nGlowRange", g_cvGlowDistance.IntValue);
    SetEntProp(client, Prop_Send, "m_bFlashing", 0);
}

/**
 * Iterates through all clients and applies glow to Tanks.
 */
void ApplyGlowToAllTanks()
{
    if (!g_cvGlowEnabled.BoolValue)
        return;
        
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsTank(i))
        {
            ApplyGlowToTank(i);
        }
    }
}

/**
 * Converts RGBA color array to integer for SourceMod.
 */
int GetColorInt(int color[4])
{
    return color[0] | (color[1] << 8) | (color[2] << 16) | (color[3] << 24);
}