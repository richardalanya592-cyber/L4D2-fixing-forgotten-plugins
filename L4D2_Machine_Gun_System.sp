// Machine Gun System Enhanced - ULTIMATE EDITION - CORREGIDO
// Original by Ernecio
// Enhanced Version with 13 machine gun types
// Compatible with Left 4 Dead 1 & 2

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

// =====[ CONSTANTS ]=====
#define PLUGIN_VERSION "3.0.2 Ultimate Fixed"
#define MAX_MACHINE_GUNS 64
#define MAX_TYPES 13
#define SOUND_PICKUP "items/ammopickup.wav"
#define SOUND_DROP "items/weapondrop.wav"
#define SOUND_OVERHEAT "weapons/flame_thrower_loop.wav"
#define SOUND_FREEZE_WARNING "ambient/levels/labs/teleport_warning.wav"
#define SOUND_VORTEX "ambient/levels/labs/electric_explosion4.wav"
#define SOUND_PHASE "weapons/physcannon/energy_sing_explosion2.wav"
#define SOUND_VENOM "npc/infected/action/antici_moan_04.wav"
#define SOUND_GRAVITY "weapons/physcannon/physcannon_drop.wav"
#define SOUND_CHAOS "ambient/levels/labs/teleport_mechanism.wav"
#define MODEL_GATLING "models/w_models/weapons/w_minigun.mdl"
#define MODEL_50CAL "models/w_models/weapons/50cal.mdl"
#define MODEL_PLASMA_BALL "models/spitball_small.mdl"

// Movement types
#define MOVETYPE_NONE 0
#define MOVETYPE_WALK 2 
#define MOVETYPE_STEP 4
#define MOVETYPE_FLY 5
#define MOVETYPE_VPHYSICS 6
#define MOVETYPE_FOLLOW 7

// =====[ ENUMS ]=====
enum MachineType
{
    Type_Simple = 0,
    Type_Flame,
    Type_Laser,
    Type_Tesla,
    Type_Freeze,
    Type_Nauseating,
    Type_Plasma,
    Type_Shadow,
    Type_Vortex,
    Type_Phase,
    Type_Venom,
    Type_Gravity,
    Type_Chaos
}

enum MachineModel
{
    Model_Gatling = 1,
    Model_50Cal
}

// =====[ PLUGIN INFO ]=====
public Plugin myinfo =
{
    name = "[L4D2] Machine Gun System Ultimate",
    author = "Ernecio + Enhanced Ultimate Edition",
    description = "Advanced machine gun system with 13 unique types",
    version = PLUGIN_VERSION,
    url = "https://github.com/yourrepo"
};

// =====[ GLOBAL VARIABLES ]=====
// Machine gun data arrays
int g_iMachineRef[MAX_MACHINE_GUNS];
MachineType g_iMachineType[MAX_MACHINE_GUNS];
MachineModel g_iMachineModel[MAX_MACHINE_GUNS];
int g_iMachineOwner[MAX_MACHINE_GUNS];
int g_iMachineAmmo[MAX_MACHINE_GUNS];
float g_fMachineHeat[MAX_MACHINE_GUNS];
float g_fMachineNextShot[MAX_MACHINE_GUNS];
float g_fMachineNextSpecial[MAX_MACHINE_GUNS];
float g_fMachineNextBile[MAX_MACHINE_GUNS];
float g_fMachineNextFreeze[MAX_MACHINE_GUNS];
float g_fMachineNextVortex[MAX_MACHINE_GUNS];
float g_fMachineNextPhase[MAX_MACHINE_GUNS];
float g_fMachineNextVenom[MAX_MACHINE_GUNS];
float g_fMachineNextGravity[MAX_MACHINE_GUNS];
int g_iMachineChaosEffect[MAX_MACHINE_GUNS];
bool g_bMachineActive[MAX_MACHINE_GUNS];
bool g_bMachineOverheated[MAX_MACHINE_GUNS];
ArrayList g_aVenomTargets[MAX_MACHINE_GUNS];

// Client data
int g_iCurrentMachine[MAXPLAYERS+1];
bool g_bHasMachine[MAXPLAYERS+1];
float g_fLastPickupAttempt[MAXPLAYERS+1];
float g_fClientGravity[MAXPLAYERS+1];
bool g_bClientVenomed[MAXPLAYERS+1];
float g_fClientVenomTime[MAXPLAYERS+1];

// Convars
ConVar g_cvAmmoCount;
ConVar g_cvOverheatTime;
ConVar g_cvDamageSimple;
ConVar g_cvDamageFlame;
ConVar g_cvDamageLaser;
ConVar g_cvDamageTesla;
ConVar g_cvDamageFreeze;
ConVar g_cvDamageNauseating;
ConVar g_cvDamagePlasma;
ConVar g_cvDamageShadow;
ConVar g_cvDamageVortex;
ConVar g_cvDamagePhase;
ConVar g_cvDamageVenom;
ConVar g_cvDamageGravity;
ConVar g_cvDamageChaos;
ConVar g_cvCarrySpeed;
ConVar g_cvPersist;
ConVar g_cvDropOnIncap;
ConVar g_cvLimitSimple;
ConVar g_cvLimitFlame;
ConVar g_cvLimitLaser;
ConVar g_cvLimitTesla;
ConVar g_cvLimitFreeze;
ConVar g_cvLimitNauseating;
ConVar g_cvLimitPlasma;
ConVar g_cvLimitShadow;
ConVar g_cvLimitVortex;
ConVar g_cvLimitPhase;
ConVar g_cvLimitVenom;
ConVar g_cvLimitGravity;
ConVar g_cvLimitChaos;
ConVar g_cvRange;
ConVar g_cvFireRate;
ConVar g_cvChaosRandom;
ConVar g_cvVortexStrength;
ConVar g_cvVenomSpread;

// Forwards
Handle g_hOnMachineCreated;
Handle g_hOnMachineDestroyed;
Handle g_hOnMachinePickedUp;
Handle g_hOnMachineDropped;

// =====[ INITIALIZATION ]=====
public void OnPluginStart()
{
    // Initialize forwards FIRST
    g_hOnMachineCreated = CreateGlobalForward("OnMachineCreated", ET_Event, Param_Cell, Param_Cell, Param_Cell);
    g_hOnMachineDestroyed = CreateGlobalForward("OnMachineDestroyed", ET_Event, Param_Cell, Param_Cell);
    g_hOnMachinePickedUp = CreateGlobalForward("OnMachinePickedUp", ET_Event, Param_Cell, Param_Cell);
    g_hOnMachineDropped = CreateGlobalForward("OnMachineDropped", ET_Event, Param_Cell, Param_Cell);
    
    // Commands
    RegConsoleCmd("sm_machine", Command_CreateMachine, "Create a machine gun - Usage: sm_machine <model> <type>");
    RegConsoleCmd("sm_machinemenu", Command_MachineMenu, "Open machine gun menu");
    RegConsoleCmd("sm_removemachine", Command_RemoveMachine, "Remove machine gun under crosshair");
    RegAdminCmd("sm_resetmachine", Command_ResetMachine, ADMFLAG_ROOT, "Reset all machine guns");
    RegConsoleCmd("sm_machinetypes", Command_ListTypes, "List all available machine gun types");
    
    // Convars
    CreateConVar("l4d_machine_version", PLUGIN_VERSION, "Machine Gun System Version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
    
    g_cvAmmoCount = CreateConVar("l4d_machine_ammo_count", "150", "Default ammo count for machine guns", 0, true, 1.0, true, 500.0);
    g_cvOverheatTime = CreateConVar("l4d_machine_overheat_time", "5.0", "Time in seconds before overheating", 0, true, 1.0, true, 20.0);
    
    // Damage convars
    g_cvDamageSimple = CreateConVar("l4d_machine_damage_simple", "25.0", "Damage for simple machine gun");
    g_cvDamageFlame = CreateConVar("l4d_machine_damage_flame", "15.0", "Damage per tick for flame machine gun");
    g_cvDamageLaser = CreateConVar("l4d_machine_damage_laser", "30.0", "Damage for laser machine gun");
    g_cvDamageTesla = CreateConVar("l4d_machine_damage_tesla", "40.0", "Damage for tesla machine gun");
    g_cvDamageFreeze = CreateConVar("l4d_machine_damage_freeze", "10.0", "Damage for freeze machine gun");
    g_cvDamageNauseating = CreateConVar("l4d_machine_damage_nauseating", "20.0", "Damage for nauseating machine gun");
    g_cvDamagePlasma = CreateConVar("l4d_machine_damage_plasma", "50.0", "Damage for plasma machine gun");
    g_cvDamageShadow = CreateConVar("l4d_machine_damage_shadow", "35.0", "Damage for shadow machine gun");
    g_cvDamageVortex = CreateConVar("l4d_machine_damage_vortex", "30.0", "Damage for vortex machine gun");
    g_cvDamagePhase = CreateConVar("l4d_machine_damage_phase", "45.0", "Damage for phase machine gun");
    g_cvDamageVenom = CreateConVar("l4d_machine_damage_venom", "20.0", "Damage per tick for venom machine gun");
    g_cvDamageGravity = CreateConVar("l4d_machine_damage_gravity", "25.0", "Damage for gravity machine gun");
    g_cvDamageChaos = CreateConVar("l4d_machine_damage_chaos", "40.0", "Base damage for chaos machine gun");
    
    // Gameplay convars
    g_cvCarrySpeed = CreateConVar("l4d_machine_carry_speed", "0.5", "Speed multiplier when carrying machine gun", 0, true, 0.1, true, 1.0);
    g_cvPersist = CreateConVar("l4d_machine_persist", "0", "Persist machine guns between maps", 0, true, 0.0, true, 1.0);
    g_cvDropOnIncap = CreateConVar("l4d_machine_drop_on_incap", "1", "Drop machine gun when incapacitated", 0, true, 0.0, true, 1.0);
    g_cvRange = CreateConVar("l4d_machine_range", "800.0", "Detection range for auto machine guns");
    g_cvFireRate = CreateConVar("l4d_machine_firerate", "0.2", "Base fire rate in seconds");
    
    // New special convars
    g_cvChaosRandom = CreateConVar("l4d_machine_chaos_random", "1", "Enable random effects for chaos gun", 0, true, 0.0, true, 1.0);
    g_cvVortexStrength = CreateConVar("l4d_machine_vortex_strength", "5.0", "Pull strength for vortex gun");
    g_cvVenomSpread = CreateConVar("l4d_machine_venom_spread", "1", "Enable venom spread between enemies", 0, true, 0.0, true, 1.0);
    
    // Limit convars for all types
    g_cvLimitSimple = CreateConVar("l4d_machine_limit_simple", "5", "Maximum simple machine guns", 0, true, 0.0, true, 32.0);
    g_cvLimitFlame = CreateConVar("l4d_machine_limit_flame", "3", "Maximum flame machine guns", 0, true, 0.0, true, 32.0);
    g_cvLimitLaser = CreateConVar("l4d_machine_limit_laser", "3", "Maximum laser machine guns", 0, true, 0.0, true, 32.0);
    g_cvLimitTesla = CreateConVar("l4d_machine_limit_tesla", "2", "Maximum tesla machine guns", 0, true, 0.0, true, 32.0);
    g_cvLimitFreeze = CreateConVar("l4d_machine_limit_freeze", "2", "Maximum freeze machine guns", 0, true, 0.0, true, 32.0);
    g_cvLimitNauseating = CreateConVar("l4d_machine_limit_nauseating", "2", "Maximum nauseating machine guns", 0, true, 0.0, true, 32.0);
    g_cvLimitPlasma = CreateConVar("l4d_machine_limit_plasma", "2", "Maximum plasma machine guns", 0, true, 0.0, true, 32.0);
    g_cvLimitShadow = CreateConVar("l4d_machine_limit_shadow", "2", "Maximum shadow machine guns", 0, true, 0.0, true, 32.0);
    g_cvLimitVortex = CreateConVar("l4d_machine_limit_vortex", "2", "Maximum vortex machine guns", 0, true, 0.0, true, 32.0);
    g_cvLimitPhase = CreateConVar("l4d_machine_limit_phase", "2", "Maximum phase machine guns", 0, true, 0.0, true, 32.0);
    g_cvLimitVenom = CreateConVar("l4d_machine_limit_venom", "2", "Maximum venom machine guns", 0, true, 0.0, true, 32.0);
    g_cvLimitGravity = CreateConVar("l4d_machine_limit_gravity", "2", "Maximum gravity machine guns", 0, true, 0.0, true, 32.0);
    g_cvLimitChaos = CreateConVar("l4d_machine_limit_chaos", "1", "Maximum chaos machine guns", 0, true, 0.0, true, 32.0);
    
    // Auto-exec config
    AutoExecConfig(true, "l4d_machinegun_ultimate");
    
    // Events
    HookEvent("player_incapacitated", Event_PlayerIncapacitated);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("round_start", Event_RoundStart);
    HookEvent("map_transition", Event_MapTransition);
    
    // Initialize arrays
    for (int i = 0; i < MAX_MACHINE_GUNS; i++)
    {
        g_iMachineRef[i] = INVALID_ENT_REFERENCE;
        g_iMachineType[i] = Type_Simple;
        g_iMachineModel[i] = Model_Gatling;
        g_iMachineOwner[i] = -1;
        g_iMachineAmmo[i] = 0;
        g_fMachineHeat[i] = 0.0;
        g_fMachineNextShot[i] = 0.0;
        g_fMachineNextSpecial[i] = 0.0;
        g_bMachineActive[i] = true;
        g_bMachineOverheated[i] = false;
        g_aVenomTargets[i] = new ArrayList();
    }
    
    for (int i = 1; i <= MaxClients; i++)
    {
        g_iCurrentMachine[i] = -1;
        g_bHasMachine[i] = false;
        g_fClientGravity[i] = 1.0;
        g_bClientVenomed[i] = false;
        g_fClientVenomTime[i] = 0.0;
    }
}

public void OnMapStart()
{
    // Precache models
    PrecacheModel(MODEL_GATLING, true);
    PrecacheModel(MODEL_50CAL, true);
    PrecacheModel(MODEL_PLASMA_BALL, true);
    PrecacheModel("sprites/laserbeam.vmt", true);
    PrecacheModel("sprites/blueglow1.vmt", true);
    PrecacheModel("sprites/redglow1.vmt", true);
    PrecacheModel("sprites/purpleglow1.vmt", true);
    
    // Precache sounds
    PrecacheSound(SOUND_PICKUP, true);
    PrecacheSound(SOUND_DROP, true);
    PrecacheSound(SOUND_OVERHEAT, true);
    PrecacheSound(SOUND_FREEZE_WARNING, true);
    PrecacheSound(SOUND_VORTEX, true);
    PrecacheSound(SOUND_PHASE, true);
    PrecacheSound(SOUND_VENOM, true);
    PrecacheSound(SOUND_GRAVITY, true);
    PrecacheSound(SOUND_CHAOS, true);
    
    // Reset non-persistent machines
    if (!g_cvPersist.BoolValue)
    {
        RemoveAllMachines();
    }
    
    // Create timer for machine gun AI
    CreateTimer(0.1, Timer_MachineAI, _, TIMER_REPEAT);
    CreateTimer(1.0, Timer_VenomDamage, _, TIMER_REPEAT);
}

// =====[ COMMAND FUNCTIONS ]=====
public Action Command_RemoveMachine(int client, int args)
{
    if (client == 0) return Plugin_Handled;
    
    int target = GetClientAimTarget(client, false);
    if (target > 0 && IsValidEntity(target))
    {
        char classname[64];
        GetEntityClassname(target, classname, sizeof(classname));
        
        // Check if it's a machine gun (prop_dynamic)
        if (StrContains(classname, "prop_dynamic", false) != -1)
        {
            // Check if it's one of our machine guns
            int slot = FindMachineSlotByEntity(target);
            if (slot != -1)
            {
                DestroyMachineGun(slot, target);
                PrintToChat(client, "\x04[MachineGun]\x01 Machine gun removed!");
            }
            else
            {
                PrintToChat(client, "\x04[MachineGun]\x03 That is not a machine gun from this system!");
            }
        }
        else
        {
            PrintToChat(client, "\x04[MachineGun]\x03 Target is not a machine gun!");
        }
    }
    else
    {
        PrintToChat(client, "\x04[MachineGun]\x03 No valid target!");
    }
    
    return Plugin_Handled;
}

public Action Command_ResetMachine(int client, int args)
{
    RemoveAllMachines();
    PrintToChatAll("\x04[MachineGun]\x01 All machine guns have been reset by admin!");
    return Plugin_Handled;
}

public Action Command_ListTypes(int client, int args)
{
    if (client == 0) return Plugin_Handled;
    
    PrintToChat(client, "\x04[MachineGun] \x01Available Types:");
    PrintToChat(client, "\x05simple \x01- Basic machine gun");
    PrintToChat(client, "\x05flame \x01- Fire damage, AOE effect");
    PrintToChat(client, "\x05laser \x01- Precision laser beams");
    PrintToChat(client, "\x05tesla \x01- Electric arcs between enemies");
    PrintToChat(client, "\x05freeze \x01- Freeze enemies in place");
    PrintToChat(client, "\x05nauseating \x01- Bile effect");
    PrintToChat(client, "\x05plasma \x01- Explosive plasma balls");
    PrintToChat(client, "\x05shadow \x01- Darkness damage, blinds enemies");
    PrintToChat(client, "\x05vortex \x01- Creates sucking whirlpools");
    PrintToChat(client, "\x05phase \x01- Shots through walls");
    PrintToChat(client, "\x05venom \x01- Poison that spreads");
    PrintToChat(client, "\x05gravity \x01- Manipulates enemy gravity");
    PrintToChat(client, "\x05chaos \x01- Random unpredictable effects");
    
    return Plugin_Handled;
}

public Action Command_CreateMachine(int client, int args)
{
    if (client == 0)
    {
        ReplyToCommand(client, "[SM] Command cannot be used from server console.");
        return Plugin_Handled;
    }
    
    MachineModel model = Model_Gatling;
    MachineType type = Type_Simple;
    
    if (args >= 1)
    {
        char arg[16];
        GetCmdArg(1, arg, sizeof(arg));
        model = view_as<MachineModel>(StringToInt(arg));
        if (model != Model_Gatling && model != Model_50Cal)
        {
            model = Model_Gatling;
        }
    }
    
    if (args >= 2)
    {
        char arg[32];
        GetCmdArg(2, arg, sizeof(arg));
        
        if (strcmp(arg, "flame", false) == 0)
            type = Type_Flame;
        else if (strcmp(arg, "laser", false) == 0)
            type = Type_Laser;
        else if (strcmp(arg, "tesla", false) == 0)
            type = Type_Tesla;
        else if (strcmp(arg, "freeze", false) == 0)
            type = Type_Freeze;
        else if (strcmp(arg, "nauseating", false) == 0)
            type = Type_Nauseating;
        else if (strcmp(arg, "plasma", false) == 0)
            type = Type_Plasma;
        else if (strcmp(arg, "shadow", false) == 0)
            type = Type_Shadow;
        else if (strcmp(arg, "vortex", false) == 0)
            type = Type_Vortex;
        else if (strcmp(arg, "phase", false) == 0)
            type = Type_Phase;
        else if (strcmp(arg, "venom", false) == 0)
            type = Type_Venom;
        else if (strcmp(arg, "gravity", false) == 0)
            type = Type_Gravity;
        else if (strcmp(arg, "chaos", false) == 0)
            type = Type_Chaos;
    }
    
    // Check limits
    if (!CheckMachineLimit(type))
    {
        PrintToChat(client, "\x04[MachineGun]\x03 Limit reached for this type! (Max: %d)", GetMachineLimit(type));
        return Plugin_Handled;
    }
    
    CreateMachineGun(client, model, type);
    return Plugin_Handled;
}

public Action Command_MachineMenu(int client, int args)
{
    if (client == 0) return Plugin_Handled;
    
    Menu menu = new Menu(MenuHandler_Machine);
    menu.SetTitle("Machine Gun System Ultimate (13 Types)");
    
    AddMenuItemWithCount(menu, "1_gatling", "Simple Machine Gun (Gatling)", Type_Simple, Model_Gatling);
    AddMenuItemWithCount(menu, "1_50cal", "Simple Machine Gun (50 Cal)", Type_Simple, Model_50Cal);
    AddMenuItemWithCount(menu, "2_gatling", "Flame Machine Gun", Type_Flame, Model_Gatling);
    AddMenuItemWithCount(menu, "3_gatling", "Laser Machine Gun", Type_Laser, Model_Gatling);
    AddMenuItemWithCount(menu, "4_gatling", "Tesla Machine Gun", Type_Tesla, Model_Gatling);
    AddMenuItemWithCount(menu, "5_gatling", "Freeze Machine Gun", Type_Freeze, Model_Gatling);
    AddMenuItemWithCount(menu, "6_gatling", "Nauseating Machine Gun", Type_Nauseating, Model_Gatling);
    AddMenuItemWithCount(menu, "7_gatling", "Plasma Machine Gun", Type_Plasma, Model_Gatling);
    AddMenuItemWithCount(menu, "8_gatling", "Shadow Machine Gun", Type_Shadow, Model_Gatling);
    AddMenuItemWithCount(menu, "9_gatling", "Vortex Machine Gun", Type_Vortex, Model_Gatling);
    AddMenuItemWithCount(menu, "10_gatling", "Phase Machine Gun", Type_Phase, Model_Gatling);
    AddMenuItemWithCount(menu, "11_gatling", "Venom Machine Gun", Type_Venom, Model_Gatling);
    AddMenuItemWithCount(menu, "12_gatling", "Gravity Machine Gun", Type_Gravity, Model_Gatling);
    AddMenuItemWithCount(menu, "13_gatling", "Chaos Machine Gun", Type_Chaos, Model_Gatling);
    
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
    
    return Plugin_Handled;
}

void AddMenuItemWithCount(Menu menu, const char[] info, const char[] display, MachineType type, MachineModel model)
{
    char buffer[128];
    int current = GetMachineCount(type);
    int limit = GetMachineLimit(type);
    
    if (limit > 0)
        Format(buffer, sizeof(buffer), "%s [%d/%d]", display, current, limit);
    else
        Format(buffer, sizeof(buffer), "%s [%d/∞]", display, current);
    
    menu.AddItem(info, buffer);
}

public int MenuHandler_Machine(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        
        // CORREGIDO: Uso correcto de ExplodeString
        char parts[2][16];
        ExplodeString(info, "_", parts, sizeof(parts), sizeof(parts[]));
        
        int typeNum = StringToInt(parts[0]);
        MachineModel model = (strcmp(parts[1], "50cal", false) == 0) ? Model_50Cal : Model_Gatling;
        
        MachineType type;
        switch (typeNum)
        {
            case 1: type = Type_Simple;
            case 2: type = Type_Flame;
            case 3: type = Type_Laser;
            case 4: type = Type_Tesla;
            case 5: type = Type_Freeze;
            case 6: type = Type_Nauseating;
            case 7: type = Type_Plasma;
            case 8: type = Type_Shadow;
            case 9: type = Type_Vortex;
            case 10: type = Type_Phase;
            case 11: type = Type_Venom;
            case 12: type = Type_Gravity;
            case 13: type = Type_Chaos;
            default: type = Type_Simple;
        }
        
        if (CheckMachineLimit(type))
        {
            CreateMachineGun(param1, model, type);
        }
        else
        {
            PrintToChat(param1, "\x04[MachineGun]\x03 Limit reached for this type!");
            Command_MachineMenu(param1, 0);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    
    return 0;
}

// =====[ MACHINE GUN CREATION ]=====
void CreateMachineGun(int client, MachineModel model, MachineType type)
{
    float pos[3], ang[3];
    GetClientAbsOrigin(client, pos);
    GetClientEyeAngles(client, ang);
    
    // Adjust position in front of player
    pos[0] += 50.0 * Cosine(DegToRad(ang[1]));
    pos[1] += 50.0 * Sine(DegToRad(ang[1]));
    pos[2] += 10.0;
    
    int entity = CreateEntityByName("prop_dynamic_override");
    
    if (entity == -1)
    {
        PrintToChat(client, "\x04[MachineGun]\x03 Failed to create machine gun!");
        return;
    }
    
    // Set model based on type
    char modelPath[128];
    if (model == Model_Gatling)
        strcopy(modelPath, sizeof(modelPath), MODEL_GATLING);
    else
        strcopy(modelPath, sizeof(modelPath), MODEL_50CAL);
    
    DispatchKeyValue(entity, "model", modelPath);
    DispatchKeyValue(entity, "solid", "6");
    DispatchKeyValue(entity, "spawnflags", "0");
    
    TeleportEntity(entity, pos, ang, NULL_VECTOR);
    DispatchSpawn(entity);
    
    // Find free slot
    int slot = -1;
    for (int i = 0; i < MAX_MACHINE_GUNS; i++)
    {
        if (g_iMachineRef[i] == INVALID_ENT_REFERENCE)
        {
            slot = i;
            break;
        }
    }
    
    if (slot == -1)
    {
        AcceptEntityInput(entity, "Kill");
        PrintToChat(client, "\x04[MachineGun]\x03 Maximum machine guns reached!");
        return;
    }
    
    // Store data
    g_iMachineRef[slot] = EntIndexToEntRef(entity);
    g_iMachineType[slot] = type;
    g_iMachineModel[slot] = model;
    g_iMachineOwner[slot] = -1;
    g_iMachineAmmo[slot] = g_cvAmmoCount.IntValue;
    g_fMachineHeat[slot] = 0.0;
    g_fMachineNextShot[slot] = 0.0;
    g_fMachineNextSpecial[slot] = 0.0;
    g_fMachineNextVortex[slot] = 0.0;
    g_fMachineNextPhase[slot] = 0.0;
    g_fMachineNextVenom[slot] = 0.0;
    g_fMachineNextGravity[slot] = 0.0;
    g_iMachineChaosEffect[slot] = 0;
    g_bMachineActive[slot] = true;
    g_bMachineOverheated[slot] = false;
    
    if (g_aVenomTargets[slot] == null)
        g_aVenomTargets[slot] = new ArrayList();
    else
        g_aVenomTargets[slot].Clear();
    
    // Set up interaction
    SetEntProp(entity, Prop_Data, "m_iEFlags", 0);
    SetEntProp(entity, Prop_Data, "m_takedamage", 2);
    
    SDKHook(entity, SDKHook_Use, OnUseMachineGun);
    SDKHook(entity, SDKHook_Touch, OnTouchMachineGun);
    SDKHook(entity, SDKHook_OnTakeDamage, OnMachineGunDamaged);
    
    // Create name based on type
    char typeName[32];
    GetTypeName(type, typeName, sizeof(typeName));
    DispatchKeyValue(entity, "targetname", typeName);
    
    PrintToChat(client, "\x04[MachineGun]\x01 Created \x05%s\x01 machine gun!", typeName);
    
    // Call forward
    Call_StartForward(g_hOnMachineCreated);
    Call_PushCell(client);
    Call_PushCell(entity);
    Call_PushCell(type);
    Call_Finish();
}

// =====[ MACHINE GUN INTERACTION ]=====
public Action OnUseMachineGun(int entity, int activator, int caller, UseType type, float value)
{
    if (activator < 1 || activator > MaxClients || !IsClientInGame(activator))
        return Plugin_Continue;
    
    int slot = FindMachineSlotByEntity(entity);
    if (slot == -1) return Plugin_Continue;
    
    // Check if machine gun is active
    if (!g_bMachineActive[slot])
        return Plugin_Continue;
    
    // Check if already has a machine gun
    if (g_bHasMachine[activator])
    {
        PrintToChat(activator, "\x04[MachineGun]\x03 You already have a machine gun!");
        return Plugin_Handled;
    }
    
    // Check if enough ammo
    if (g_iMachineAmmo[slot] <= 0)
    {
        PrintToChat(activator, "\x04[MachineGun]\x03 This machine gun has no ammo!");
        return Plugin_Handled;
    }
    
    // Pick up the machine gun
    PickupMachineGun(activator, slot, entity);
    
    return Plugin_Handled;
}

public Action OnTouchMachineGun(int entity, int other)
{
    // Auto-pickup logic can be added here
    return Plugin_Continue;
}

public Action OnMachineGunDamaged(int entity, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    int slot = FindMachineSlotByEntity(entity);
    if (slot == -1) return Plugin_Continue;
    
    // Reduce ammo when damaged
    g_iMachineAmmo[slot] -= RoundFloat(damage);
    if (g_iMachineAmmo[slot] < 0)
        g_iMachineAmmo[slot] = 0;
    
    // Destroy if out of ammo
    if (g_iMachineAmmo[slot] <= 0)
    {
        DestroyMachineGun(slot, entity);
    }
    
    return Plugin_Continue;
}

void PickupMachineGun(int client, int slot, int entity)
{
    // Remove physics properties - using constant value instead of MOVETYPE_FOLLOW
    SetEntProp(entity, Prop_Data, "m_MoveType", 7); // MOVETYPE_FOLLOW = 7
    
    // Attach to client
    SetVariantString("!activator");
    AcceptEntityInput(entity, "SetParent", client);
    
    // Set attachment position
    SetVariantString("primary");
    AcceptEntityInput(entity, "SetParentAttachment");
    
    // Update data
    g_iMachineOwner[slot] = client;
    g_iCurrentMachine[client] = slot;
    g_bHasMachine[client] = true;
    
    // Play sound
    EmitSoundToAll(SOUND_PICKUP, client);
    
    // Apply speed penalty
    SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_cvCarrySpeed.FloatValue);
    
    PrintToChat(client, "\x04[MachineGun]\x01 Machine gun equipped! Use +use to fire, +reload to drop.");
    
    // Call forward
    Call_StartForward(g_hOnMachinePickedUp);
    Call_PushCell(client);
    Call_PushCell(entity);
    Call_Finish();
}

void DropMachineGun(int client)
{
    int slot = g_iCurrentMachine[client];
    if (slot == -1) return;
    
    int entity = EntRefToEntIndex(g_iMachineRef[slot]);
    if (entity == INVALID_ENT_REFERENCE) return;
    
    // Detach from client
    SetVariantString("");
    AcceptEntityInput(entity, "SetParent");
    
    // Get client position for drop
    float pos[3];
    GetClientAbsOrigin(client, pos);
    pos[2] += 20.0;
    TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
    
    // Reset movement type - using constant value
    SetEntProp(entity, Prop_Data, "m_MoveType", 6); // MOVETYPE_VPHYSICS = 6
    
    // Update data
    g_iMachineOwner[slot] = -1;
    g_iCurrentMachine[client] = -1;
    g_bHasMachine[client] = false;
    
    // Reset speed
    SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
    
    // Play sound
    EmitSoundToAll(SOUND_DROP, entity);
    
    PrintToChat(client, "\x04[MachineGun]\x01 Machine gun dropped!");
    
    // Call forward
    Call_StartForward(g_hOnMachineDropped);
    Call_PushCell(client);
    Call_PushCell(entity);
    Call_Finish();
}

// =====[ FIRING MECHANICS ]=====
void FireMachineGun(int client, int slot, int entity)
{
    if (g_iMachineAmmo[slot] <= 0)
    {
        PrintToChat(client, "\x04[MachineGun]\x03 Out of ammo!");
        DropMachineGun(client);
        return;
    }
    
    if (g_bMachineOverheated[slot])
    {
        PrintToChat(client, "\x04[MachineGun]\x03 Weapon overheated! Waiting to cool down...");
        return;
    }
    
    float currentTime = GetGameTime();
    if (currentTime < g_fMachineNextShot[slot])
        return;
    
    // Increase heat
    g_fMachineHeat[slot] += 0.2;
    if (g_fMachineHeat[slot] >= g_cvOverheatTime.FloatValue)
    {
        g_bMachineOverheated[slot] = true;
        CreateTimer(3.0, Timer_CoolDown, slot);
    }
    
    // Reduce ammo
    g_iMachineAmmo[slot]--;
    
    // Get aim direction
    float pos[3], ang[3];
    GetClientEyePosition(client, pos);
    GetClientEyeAngles(client, ang);
    
    // Calculate end position
    float endPos[3];
    endPos[0] = pos[0] + 5000.0 * Cosine(DegToRad(ang[1])) * Cosine(DegToRad(ang[0]));
    endPos[1] = pos[1] + 5000.0 * Sine(DegToRad(ang[1])) * Cosine(DegToRad(ang[0]));
    endPos[2] = pos[2] + 5000.0 * Sine(DegToRad(ang[0]));
    
    // Fire based on type
    switch (g_iMachineType[slot])
    {
        case Type_Simple:
            FireSimple(entity, pos, ang, endPos, slot);
        case Type_Flame:
            FireFlame(entity, pos, ang, endPos, slot);
        case Type_Laser:
            FireLaser(entity, pos, ang, endPos, slot);
        case Type_Tesla:
            FireTesla(entity, pos, ang, endPos, slot);
        case Type_Freeze:
            FireFreeze(entity, pos, ang, endPos, slot);
        case Type_Nauseating:
            FireNauseating(entity, pos, ang, endPos, slot);
        case Type_Plasma:
            FirePlasma(entity, pos, ang, endPos, slot);
        case Type_Shadow:
            FireShadow(entity, pos, ang, endPos, slot);
        case Type_Vortex:
            FireVortex(entity, pos, ang, endPos, slot);
        case Type_Phase:
            FirePhase(entity, pos, ang, endPos, slot);
        case Type_Venom:
            FireVenom(entity, pos, ang, endPos, slot);
        case Type_Gravity:
            FireGravity(entity, pos, ang, endPos, slot);
        case Type_Chaos:
            FireChaos(entity, pos, ang, endPos, slot);
    }
    
    g_fMachineNextShot[slot] = currentTime + g_cvFireRate.FloatValue;
}

// Individual firing functions for each type
void FireSimple(int entity, float pos[3], float ang[3], float endPos[3], int slot)
{
    // Basic bullet trace
    Handle trace = TR_TraceRayFilterEx(pos, endPos, MASK_SHOT, RayType_EndPoint, TraceFilter, entity);
    
    if (TR_DidHit(trace))
    {
        int target = TR_GetEntityIndex(trace);
        if (target > 0 && target <= MaxClients)
        {
            DealDamage(target, g_cvDamageSimple.FloatValue, entity);
            
            // Bullet impact effect
            float hitPos[3];
            TR_GetEndPosition(hitPos, trace);
            
            // Efecto de impacto simple
            TE_SetupExplosion(hitPos, PrecacheModel("sprites/blueglow1.vmt"), 5.0, 1, 0, 10, 20);
            TE_SendToAll();
        }
    }
    
    delete trace;
}

void FireFlame(int entity, float pos[3], float ang[3], float endPos[3], int slot)
{
    // Flame thrower effect
    TE_SetupBeamPoints(pos, endPos, PrecacheModel("sprites/laserbeam.vmt"), 0, 0, 0, 0.1, 10.0, 10.0, 1, 0.0, {255, 100, 0, 255}, 0);
    TE_SendToAll();
    
    // AOE damage
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3)
        {
            float targetPos[3];
            GetClientEyePosition(i, targetPos);
            
            if (GetVectorDistance(pos, targetPos) < 200.0)
            {
                DealDamage(i, g_cvDamageFlame.FloatValue, entity);
                IgniteEntity(i, 3.0);
            }
        }
    }
}

void FireLaser(int entity, float pos[3], float ang[3], float endPos[3], int slot)
{
    // Laser beam effect
    TE_SetupBeamPoints(pos, endPos, PrecacheModel("sprites/laserbeam.vmt"), 0, 0, 0, 0.1, 5.0, 5.0, 1, 0.0, {255, 0, 0, 255}, 0);
    TE_SendToAll();
    
    Handle trace = TR_TraceRayFilterEx(pos, endPos, MASK_SHOT, RayType_EndPoint, TraceFilter, entity);
    
    if (TR_DidHit(trace))
    {
        int target = TR_GetEntityIndex(trace);
        if (target > 0 && target <= MaxClients)
        {
            DealDamage(target, g_cvDamageLaser.FloatValue, entity);
        }
    }
    
    delete trace;
}

void FireTesla(int entity, float pos[3], float ang[3], float endPos[3], int slot)
{
    // Find primary target
    int primaryTarget = FindTargetInRange(pos, g_cvRange.FloatValue);
    if (primaryTarget > 0)
    {
        float targetPos[3];
        GetClientEyePosition(primaryTarget, targetPos);
        
        // Primary arc
        TE_SetupBeamPoints(pos, targetPos, PrecacheModel("sprites/laserbeam.vmt"), 0, 0, 0, 0.2, 15.0, 15.0, 5, 0.0, {255, 255, 0, 255}, 0);
        TE_SendToAll();
        
        DealDamage(primaryTarget, g_cvDamageTesla.FloatValue, entity);
        
        // Chain to nearby enemies
        for (int i = 1; i <= MaxClients; i++)
        {
            if (i != primaryTarget && IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3)
            {
                float chainPos[3];
                GetClientEyePosition(i, chainPos);
                
                if (GetVectorDistance(targetPos, chainPos) < 200.0)
                {
                    TE_SetupBeamPoints(targetPos, chainPos, PrecacheModel("sprites/laserbeam.vmt"), 0, 0, 0, 0.1, 10.0, 10.0, 3, 0.0, {200, 200, 0, 255}, 0);
                    TE_SendToAll();
                    
                    DealDamage(i, g_cvDamageTesla.FloatValue * 0.5, entity);
                }
            }
        }
    }
}

void FireFreeze(int entity, float pos[3], float ang[3], float endPos[3], int slot)
{
    // Freeze ray effect
    TE_SetupBeamPoints(pos, endPos, PrecacheModel("sprites/laserbeam.vmt"), 0, 0, 0, 0.1, 8.0, 8.0, 1, 0.0, {0, 255, 255, 255}, 0);
    TE_SendToAll();
    
    Handle trace = TR_TraceRayFilterEx(pos, endPos, MASK_SHOT, RayType_EndPoint, TraceFilter, entity);
    
    if (TR_DidHit(trace))
    {
        int target = TR_GetEntityIndex(trace);
        if (target > 0 && target <= MaxClients)
        {
            DealDamage(target, g_cvDamageFreeze.FloatValue, entity);
            
            // Freeze effect (slow movement)
            SetEntPropFloat(target, Prop_Data, "m_flLaggedMovementValue", 0.3);
            CreateTimer(2.0, Timer_RemoveFreeze, target);
            
            // Visual freeze effect
            float targetPos[3];
            GetClientEyePosition(target, targetPos);
            TE_SetupBeamRingPoint(pos, 50.0, 100.0, PrecacheModel("sprites/laserbeam.vmt"), 0, 0, 0, 2.0, 10.0, 1.0, {0, 255, 255, 50}, 10, 0);
            TE_SendToAll();
        }
    }
    
    delete trace;
}

void FireNauseating(int entity, float pos[3], float ang[3], float endPos[3], int slot)
{
    float currentTime = GetGameTime();
    
    // Check if can fire bile
    if (currentTime >= g_fMachineNextSpecial[slot])
    {
        Handle trace = TR_TraceRayFilterEx(pos, endPos, MASK_SHOT, RayType_EndPoint, TraceFilter, entity);
        
        if (TR_DidHit(trace))
        {
            int target = TR_GetEntityIndex(trace);
            if (target > 0 && target <= MaxClients && GetClientTeam(target) == 2)
            {
                // Create bile effect
                int bile = CreateEntityByName("env_entity_dissolver");
                if (bile != -1)
                {
                    DispatchKeyValue(bile, "target", "!activator");
                    DispatchKeyValue(bile, "magnitude", "1");
                    DispatchKeyValue(bile, "dissolvetype", "0");
                    AcceptEntityInput(bile, "Dissolve", target);
                    
                    // Bile visual effect
                    float targetPos[3];
                    GetClientEyePosition(target, targetPos);
                    TE_SetupExplosion(targetPos, PrecacheModel("sprites/blueglow1.vmt"), 10.0, 1, 0, 50, 100);
                    TE_SendToAll();
                }
                
                DealDamage(target, g_cvDamageNauseating.FloatValue, entity);
            }
        }
        
        delete trace;
        g_fMachineNextSpecial[slot] = currentTime + 5.0; // Bile every 5 seconds
    }
}

void FirePlasma(int entity, float pos[3], float ang[3], float endPos[3], int slot)
{
    // Create plasma projectile
    int plasma = CreateEntityByName("env_rockettrail");
    if (plasma != -1)
    {
        DispatchKeyValue(plasma, "model", MODEL_PLASMA_BALL);
        DispatchSpawn(plasma);
        
        TeleportEntity(plasma, pos, ang, NULL_VECTOR);
        
        // Set velocity
        float velocity[3];
        velocity[0] = 1000.0 * Cosine(DegToRad(ang[1])) * Cosine(DegToRad(ang[0]));
        velocity[1] = 1000.0 * Sine(DegToRad(ang[1])) * Cosine(DegToRad(ang[0]));
        velocity[2] = 1000.0 * Sine(DegToRad(ang[0]));
        
        TeleportEntity(plasma, NULL_VECTOR, NULL_VECTOR, velocity);
        
        // Color based on type
        int color[4] = {255, 0, 255, 255}; // Purple for plasma
        
        // Effect
        TE_SetupBeamFollow(plasma, PrecacheModel("sprites/laserbeam.vmt"), 0, 0.5, 10.0, 10.0, 1, color);
        TE_SendToAll();
        
        CreateTimer(0.1, Timer_CheckPlasmaHit, EntIndexToEntRef(plasma), TIMER_REPEAT);
    }
}

void FireShadow(int entity, float pos[3], float ang[3], float endPos[3], int slot)
{
    // Shadow/darkness effect
    TE_SetupBeamPoints(pos, endPos, PrecacheModel("sprites/laserbeam.vmt"), 0, 0, 0, 0.2, 20.0, 20.0, 5, 0.0, {75, 0, 130, 255}, 0);
    TE_SendToAll();
    
    Handle trace = TR_TraceRayFilterEx(pos, endPos, MASK_SHOT, RayType_EndPoint, TraceFilter, entity);
    
    if (TR_DidHit(trace))
    {
        int target = TR_GetEntityIndex(trace);
        if (target > 0 && target <= MaxClients)
        {
            DealDamage(target, g_cvDamageShadow.FloatValue, entity);
            
            // Blind effect (reduce FOV)
            SetEntProp(target, Prop_Send, "m_iFOV", 30);
            CreateTimer(2.0, Timer_RemoveBlind, target);
            
            // Dark pulse
            float targetPos[3];
            GetClientEyePosition(target, targetPos);
            TE_SetupExplosion(targetPos, PrecacheModel("sprites/purpleglow1.vmt"), 5.0, 1, 0, 50, 100);
            TE_SendToAll();
        }
    }
    
    delete trace;
}

void FireVortex(int entity, float pos[3], float ang[3], float endPos[3], int slot)
{
    float currentTime = GetGameTime();
    
    // Check cooldown for vortex
    if (currentTime >= g_fMachineNextVortex[slot])
    {
        // Create vortex at impact point
        Handle trace = TR_TraceRayFilterEx(pos, endPos, MASK_SHOT, RayType_EndPoint, TraceFilter, entity);
        
        if (TR_DidHit(trace))
        {
            float hitPos[3];
            TR_GetEndPosition(hitPos, trace);
            
            // Vortex effect
            TE_SetupBeamRingPoint(hitPos, 50.0, 300.0, PrecacheModel("sprites/laserbeam.vmt"), 0, 0, 0, 2.0, 20.0, 1.0, {100, 0, 255, 255}, 10, 0);
            TE_SendToAll();
            
            EmitSoundToAll(SOUND_VORTEX, entity);
            
            // Pull enemies
            float strength = g_cvVortexStrength.FloatValue;
            for (int i = 1; i <= MaxClients; i++)
            {
                if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3)
                {
                    float targetPos[3];
                    GetClientEyePosition(i, targetPos);
                    
                    float distance = GetVectorDistance(hitPos, targetPos);
                    if (distance < 300.0)
                    {
                        // Pull towards vortex center
                        float pullDir[3];
                        SubtractVectors(hitPos, targetPos, pullDir);
                        NormalizeVector(pullDir, pullDir);
                        
                        ScaleVector(pullDir, strength * (1.0 - distance/300.0));
                        
                        TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, pullDir);
                        DealDamage(i, g_cvDamageVortex.FloatValue, entity);
                    }
                }
            }
            
            int hitTarget = TR_GetEntityIndex(trace);
            if (hitTarget > 0 && hitTarget <= MaxClients)
            {
                DealDamage(hitTarget, g_cvDamageVortex.FloatValue * 2.0, entity);
            }
        }
        
        delete trace;
        g_fMachineNextVortex[slot] = currentTime + 3.0; // Cooldown
    }
}

void FirePhase(int entity, float pos[3], float ang[3], float endPos[3], int slot)
{
    float currentTime = GetGameTime();
    
    if (currentTime >= g_fMachineNextPhase[slot])
    {
        // Phase shot - goes through walls
        TE_SetupBeamPoints(pos, endPos, PrecacheModel("sprites/laserbeam.vmt"), 0, 0, 0, 0.3, 15.0, 15.0, 10, 0.0, {255, 255, 255, 255}, 0);
        TE_SendToAll();
        
        EmitSoundToAll(SOUND_PHASE, entity);
        
        // Damage all enemies in line
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3)
            {
                float targetPos[3];
                GetClientEyePosition(i, targetPos);
                
                // Check if target is roughly in line
                float dirToTarget[3];
                SubtractVectors(targetPos, pos, dirToTarget);
                NormalizeVector(dirToTarget, dirToTarget);
                
                float dir[3];
                GetAngleVectors(ang, dir, NULL_VECTOR, NULL_VECTOR);
                
                float dot = GetVectorDotProduct(dir, dirToTarget);
                if (dot > 0.8) // Within ~36 degrees
                {
                    float distance = GetVectorDistance(pos, targetPos);
                    if (distance < 2000.0)
                    {
                        DealDamage(i, g_cvDamagePhase.FloatValue, entity);
                        
                        // Phase impact effect
                        TE_SetupExplosion(targetPos, PrecacheModel("sprites/blueglow1.vmt"), 10.0, 1, 0, 50, 100);
                        TE_SendToAll();
                    }
                }
            }
        }
        
        g_fMachineNextPhase[slot] = currentTime + 2.0;
    }
}

void FireVenom(int entity, float pos[3], float ang[3], float endPos[3], int slot)
{
    Handle trace = TR_TraceRayFilterEx(pos, endPos, MASK_SHOT, RayType_EndPoint, TraceFilter, entity);
    
    if (TR_DidHit(trace))
    {
        int target = TR_GetEntityIndex(trace);
        if (target > 0 && target <= MaxClients)
        {
            // Apply venom
            g_bClientVenomed[target] = true;
            g_fClientVenomTime[target] = GetGameTime() + 5.0;
            
            // Add to venom targets list
            if (g_aVenomTargets[slot] == null)
                g_aVenomTargets[slot] = new ArrayList();
            
            if (g_aVenomTargets[slot].FindValue(target) == -1)
                g_aVenomTargets[slot].Push(target);
            
            // Venom effect
            float targetPos[3];
            GetClientEyePosition(target, targetPos);
            TE_SetupExplosion(targetPos, PrecacheModel("sprites/purpleglow1.vmt"), 5.0, 1, 0, 50, 100);
            TE_SendToAll();
            
            EmitSoundToAll(SOUND_VENOM, target);
            
            DealDamage(target, g_cvDamageVenom.FloatValue, entity);
        }
    }
    
    delete trace;
}

void FireGravity(int entity, float pos[3], float ang[3], float endPos[3], int slot)
{
    float currentTime = GetGameTime();
    
    if (currentTime >= g_fMachineNextGravity[slot])
    {
        Handle trace = TR_TraceRayFilterEx(pos, endPos, MASK_SHOT, RayType_EndPoint, TraceFilter, entity);
        
        if (TR_DidHit(trace))
        {
            int target = TR_GetEntityIndex(trace);
            if (target > 0 && target <= MaxClients)
            {
                // Gravity effect
                EmitSoundToAll(SOUND_GRAVITY, target);
                
                // Reduce gravity (float up)
                g_fClientGravity[target] = 0.3;
                SetEntityGravity(target, 0.3);
                
                // Visual effect
                float targetPos[3];
                GetClientEyePosition(target, targetPos);
                TE_SetupBeamRingPoint(targetPos, 20.0, 100.0, PrecacheModel("sprites/laserbeam.vmt"), 0, 0, 0, 3.0, 10.0, 1.0, {255, 255, 0, 255}, 10, 0);
                TE_SendToAll();
                
                DealDamage(target, g_cvDamageGravity.FloatValue, entity);
                
                CreateTimer(3.0, Timer_ResetGravity, target);
            }
        }
        
        delete trace;
        g_fMachineNextGravity[slot] = currentTime + 4.0;
    }
}

void FireChaos(int entity, float pos[3], float ang[3], float endPos[3], int slot)
{
    if (!g_cvChaosRandom.BoolValue)
    {
        FireSimple(entity, pos, ang, endPos, slot);
        return;
    }
    
    // Random effect each time
    int effect = GetRandomInt(0, 7);
    g_iMachineChaosEffect[slot] = effect;
    
    EmitSoundToAll(SOUND_CHAOS, entity);
    
    switch (effect)
    {
        case 0: // Fireball
        {
            TE_SetupExplosion(endPos, PrecacheModel("sprites/redglow1.vmt"), 20.0, 1, 0, 100, 200);
            TE_SendToAll();
            
            for (int i = 1; i <= MaxClients; i++)
            {
                if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3)
                {
                    float targetPos[3];
                    GetClientEyePosition(i, targetPos);
                    
                    if (GetVectorDistance(endPos, targetPos) < 200.0)
                    {
                        DealDamage(i, g_cvDamageChaos.FloatValue * 1.5, entity);
                        IgniteEntity(i, 3.0);
                    }
                }
            }
        }
        case 1: // Lightning
        {
            int target = FindTargetInRange(pos, g_cvRange.FloatValue);
            if (target > 0)
            {
                float targetPos[3];
                GetClientEyePosition(target, targetPos);
                
                TE_SetupBeamPoints(pos, targetPos, PrecacheModel("sprites/laserbeam.vmt"), 0, 0, 0, 0.3, 30.0, 30.0, 10, 0.0, {255, 255, 0, 255}, 0);
                TE_SendToAll();
                
                DealDamage(target, g_cvDamageChaos.FloatValue * 2.0, entity);
            }
        }
        case 2: // Freeze burst
        {
            TE_SetupBeamRingPoint(pos, 50.0, 300.0, PrecacheModel("sprites/laserbeam.vmt"), 0, 0, 0, 2.0, 20.0, 1.0, {0, 255, 255, 255}, 10, 0);
            TE_SendToAll();
            
            for (int i = 1; i <= MaxClients; i++)
            {
                if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3)
                {
                    float targetPos[3];
                    GetClientEyePosition(i, targetPos);
                    
                    if (GetVectorDistance(pos, targetPos) < 300.0)
                    {
                        SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", 0.2);
                        CreateTimer(2.0, Timer_RemoveFreeze, i);
                    }
                }
            }
        }
        case 3: // Teleport
        {
            int target = FindTargetInRange(pos, g_cvRange.FloatValue);
            if (target > 0)
            {
                float targetPos[3];
                GetClientEyePosition(target, targetPos);
                
                // Teleport effect
                TE_SetupExplosion(targetPos, PrecacheModel("sprites/blueglow1.vmt"), 10.0, 1, 0, 50, 100);
                TE_SendToAll();
                
                // Random teleport
                float newPos[3];
                newPos[0] = targetPos[0] + GetRandomFloat(-300.0, 300.0);
                newPos[1] = targetPos[1] + GetRandomFloat(-300.0, 300.0);
                newPos[2] = targetPos[2];
                
                TeleportEntity(target, newPos, NULL_VECTOR, NULL_VECTOR);
            }
        }
        case 4: // Vortex
        {
            FireVortex(entity, pos, ang, endPos, slot);
        }
        case 5: // Bile
        {
            FireNauseating(entity, pos, ang, endPos, slot);
        }
        case 6: // Shadow
        {
            FireShadow(entity, pos, ang, endPos, slot);
        }
        case 7: // Plasma
        {
            FirePlasma(entity, pos, ang, endPos, slot);
        }
    }
}

// =====[ TIMER FUNCTIONS ]=====
public Action Timer_MachineAI(Handle timer)
{
    float range = g_cvRange.FloatValue;
    float fireRate = g_cvFireRate.FloatValue;
    float currentTime = GetGameTime();
    
    for (int i = 0; i < MAX_MACHINE_GUNS; i++)
    {
        int entity = EntRefToEntIndex(g_iMachineRef[i]);
        if (entity == INVALID_ENT_REFERENCE || !IsValidEntity(entity))
        {
            // Clean up invalid references
            if (g_iMachineRef[i] != INVALID_ENT_REFERENCE)
            {
                g_iMachineRef[i] = INVALID_ENT_REFERENCE;
                if (g_aVenomTargets[i] != null)
                {
                    delete g_aVenomTargets[i];
                    g_aVenomTargets[i] = null;
                }
            }
            continue;
        }
        
        // Handle overheating
        if (g_fMachineHeat[i] > 0.0)
        {
            g_fMachineHeat[i] -= 0.05;
            if (g_fMachineHeat[i] > g_cvOverheatTime.FloatValue * 0.8)
            {
                // Overheat warning effects
                EmitSoundToAll(SOUND_OVERHEAT, entity);
                
                // Visual warning
                float pos[3];
                GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
                TE_SetupExplosion(pos, PrecacheModel("sprites/redglow1.vmt"), 5.0, 1, 0, 50, 100);
                TE_SendToAll();
            }
        }
        
        // Auto-targeting for unmanned guns
        if (g_iMachineOwner[i] == -1 && g_bMachineActive[i] && g_iMachineAmmo[i] > 0)
        {
            float pos[3];
            GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
            
            int target = FindTargetInRange(pos, range);
            if (target > 0 && currentTime >= g_fMachineNextShot[i])
            {
                // Calculate direction to target
                float targetPos[3];
                GetClientEyePosition(target, targetPos);
                
                float dir[3];
                SubtractVectors(targetPos, pos, dir);
                NormalizeVector(dir, dir);
                
                float ang[3];
                GetVectorAngles(dir, ang);
                
                float endPos[3];
                endPos[0] = targetPos[0];
                endPos[1] = targetPos[1];
                endPos[2] = targetPos[2];
                
                // Fire at target based on type
                switch (g_iMachineType[i])
                {
                    case Type_Simple: FireSimple(entity, pos, ang, endPos, i);
                    case Type_Flame: FireFlame(entity, pos, ang, endPos, i);
                    case Type_Laser: FireLaser(entity, pos, ang, endPos, i);
                    case Type_Tesla: FireTesla(entity, pos, ang, endPos, i);
                    case Type_Freeze: FireFreeze(entity, pos, ang, endPos, i);
                    case Type_Nauseating: FireNauseating(entity, pos, ang, endPos, i);
                    case Type_Plasma: FirePlasma(entity, pos, ang, endPos, i);
                    case Type_Shadow: FireShadow(entity, pos, ang, endPos, i);
                    case Type_Vortex: FireVortex(entity, pos, ang, endPos, i);
                    case Type_Phase: FirePhase(entity, pos, ang, endPos, i);
                    case Type_Venom: FireVenom(entity, pos, ang, endPos, i);
                    case Type_Gravity: FireGravity(entity, pos, ang, endPos, i);
                    case Type_Chaos: FireChaos(entity, pos, ang, endPos, i);
                }
                
                g_fMachineNextShot[i] = currentTime + fireRate;
                g_iMachineAmmo[i]--;
                
                if (g_iMachineAmmo[i] <= 0)
                {
                    DestroyMachineGun(i, entity);
                }
            }
        }
    }
    
    return Plugin_Continue;
}

public Action Timer_VenomDamage(Handle timer)
{
    float currentTime = GetGameTime();
    
    for (int i = 0; i < MAX_MACHINE_GUNS; i++)
    {
        if (g_iMachineType[i] == Type_Venom && g_aVenomTargets[i] != null)
        {
            // Process venom damage over time
            for (int j = g_aVenomTargets[i].Length - 1; j >= 0; j--)
            {
                int target = g_aVenomTargets[i].Get(j);
                
                if (!IsClientInGame(target) || !IsPlayerAlive(target) || currentTime > g_fClientVenomTime[target])
                {
                    g_bClientVenomed[target] = false;
                    g_aVenomTargets[i].Erase(j);
                    continue;
                }
                
                // Venom damage
                int entity = EntRefToEntIndex(g_iMachineRef[i]);
                if (entity != INVALID_ENT_REFERENCE)
                {
                    DealDamage(target, g_cvDamageVenom.FloatValue, entity);
                    
                    // Spread venom if enabled
                    if (g_cvVenomSpread.BoolValue)
                    {
                        float targetPos[3];
                        GetClientEyePosition(target, targetPos);
                        
                        for (int k = 1; k <= MaxClients; k++)
                        {
                            if (k != target && IsClientInGame(k) && IsPlayerAlive(k) && GetClientTeam(k) == 3)
                            {
                                float otherPos[3];
                                GetClientEyePosition(k, otherPos);
                                
                                if (GetVectorDistance(targetPos, otherPos) < 200.0 && !g_bClientVenomed[k])
                                {
                                    g_bClientVenomed[k] = true;
                                    g_fClientVenomTime[k] = currentTime + 5.0;
                                    g_aVenomTargets[i].Push(k);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    return Plugin_Continue;
}

public Action Timer_CoolDown(Handle timer, int slot)
{
    if (slot >= 0 && slot < MAX_MACHINE_GUNS)
    {
        g_bMachineOverheated[slot] = false;
        g_fMachineHeat[slot] = 0.0;
        
        int entity = EntRefToEntIndex(g_iMachineRef[slot]);
        if (entity != INVALID_ENT_REFERENCE)
        {
            EmitSoundToAll(SOUND_PICKUP, entity);
        }
    }
    
    return Plugin_Continue;
}

public Action Timer_RemoveFreeze(Handle timer, int client)
{
    if (IsClientInGame(client) && IsPlayerAlive(client))
    {
        SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
    }
    return Plugin_Continue;
}

public Action Timer_RemoveBlind(Handle timer, int client)
{
    if (IsClientInGame(client))
    {
        SetEntProp(client, Prop_Send, "m_iFOV", 90);
    }
    return Plugin_Continue;
}

public Action Timer_ResetGravity(Handle timer, int client)
{
    if (IsClientInGame(client))
    {
        SetEntityGravity(client, 1.0);
        g_fClientGravity[client] = 1.0;
    }
    return Plugin_Continue;
}

public Action Timer_CheckPlasmaHit(Handle timer, int ref)
{
    int entity = EntRefToEntIndex(ref);
    if (entity == INVALID_ENT_REFERENCE)
        return Plugin_Stop;
    
    float pos[3];
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
    
    // Check for hits
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3)
        {
            float targetPos[3];
            GetClientEyePosition(i, targetPos);
            
            if (GetVectorDistance(pos, targetPos) < 100.0)
            {
                // Hit!
                int slot = FindMachineSlotByEntity(entity);
                if (slot != -1)
                {
                    DealDamage(i, g_cvDamagePlasma.FloatValue, entity);
                    
                    // Explosion effect
                    TE_SetupExplosion(pos, PrecacheModel("sprites/redglow1.vmt"), 20.0, 1, 0, 100, 200);
                    TE_SendToAll();
                }
                
                AcceptEntityInput(entity, "Kill");
                return Plugin_Stop;
            }
        }
    }
    
    return Plugin_Continue;
}

// =====[ UTILITY FUNCTIONS ]=====
int FindMachineSlotByEntity(int entity)
{
    for (int i = 0; i < MAX_MACHINE_GUNS; i++)
    {
        if (g_iMachineRef[i] != INVALID_ENT_REFERENCE && EntRefToEntIndex(g_iMachineRef[i]) == entity)
        {
            return i;
        }
    }
    return -1;
}

void DestroyMachineGun(int slot, int entity)
{
    // Special destruction effects based on type
    float pos[3];
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
    
    switch (g_iMachineType[slot])
    {
        case Type_Flame:
        {
            // Fire explosion
            TE_SetupExplosion(pos, PrecacheModel("sprites/redglow1.vmt"), 30.0, 1, 0, 200, 300);
            TE_SendToAll();
            
            for (int i = 1; i <= MaxClients; i++)
            {
                if (IsClientInGame(i) && IsPlayerAlive(i))
                {
                    float targetPos[3];
                    GetClientEyePosition(i, targetPos);
                    
                    if (GetVectorDistance(pos, targetPos) < 300.0)
                    {
                        IgniteEntity(i, 5.0);
                    }
                }
            }
        }
        
        case Type_Tesla:
        {
            // Electrical explosion
            for (int i = 1; i <= MaxClients; i++)
            {
                if (IsClientInGame(i) && IsPlayerAlive(i))
                {
                    float targetPos[3];
                    GetClientEyePosition(i, targetPos);
                    
                    if (GetVectorDistance(pos, targetPos) < 400.0)
                    {
                        TE_SetupBeamPoints(pos, targetPos, PrecacheModel("sprites/laserbeam.vmt"), 0, 0, 0, 0.5, 30.0, 30.0, 10, 0.0, {255, 255, 0, 255}, 0);
                        TE_SendToAll();
                        
                        DealDamage(i, 50.0, entity);
                    }
                }
            }
        }
        
        case Type_Freeze:
        {
            // Ice explosion
            TE_SetupExplosion(pos, PrecacheModel("sprites/blueglow1.vmt"), 30.0, 1, 0, 200, 300);
            TE_SendToAll();
            
            for (int i = 1; i <= MaxClients; i++)
            {
                if (IsClientInGame(i) && IsPlayerAlive(i))
                {
                    float targetPos[3];
                    GetClientEyePosition(i, targetPos);
                    
                    if (GetVectorDistance(pos, targetPos) < 300.0)
                    {
                        SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", 0.1);
                        CreateTimer(3.0, Timer_RemoveFreeze, i);
                    }
                }
            }
        }
        
        case Type_Nauseating:
        {
            // Bile explosion
            for (int i = 1; i <= MaxClients; i++)
            {
                if (IsClientInGame(i) && IsPlayerAlive(i))
                {
                    float targetPos[3];
                    GetClientEyePosition(i, targetPos);
                    
                    if (GetVectorDistance(pos, targetPos) < 350.0)
                    {
                        int bile = CreateEntityByName("env_entity_dissolver");
                        if (bile != -1)
                        {
                            DispatchKeyValue(bile, "target", "!activator");
                            DispatchKeyValue(bile, "magnitude", "1");
                            DispatchKeyValue(bile, "dissolvetype", "0");
                            AcceptEntityInput(bile, "Dissolve", i);
                        }
                    }
                }
            }
        }
        
        case Type_Plasma:
        {
            // Plasma explosion
            TE_SetupExplosion(pos, PrecacheModel("sprites/purpleglow1.vmt"), 40.0, 1, 0, 250, 350);
            TE_SendToAll();
            
            for (int i = 1; i <= MaxClients; i++)
            {
                if (IsClientInGame(i) && IsPlayerAlive(i))
                {
                    float targetPos[3];
                    GetClientEyePosition(i, targetPos);
                    
                    if (GetVectorDistance(pos, targetPos) < 400.0)
                    {
                        DealDamage(i, 75.0, entity);
                    }
                }
            }
        }
        
        case Type_Vortex:
        {
            // Vortex implosion
            TE_SetupBeamRingPoint(pos, 100.0, 500.0, PrecacheModel("sprites/laserbeam.vmt"), 0, 0, 0, 3.0, 40.0, 1.0, {150, 0, 255, 255}, 10, 0);
            TE_SendToAll();
            
            for (int i = 1; i <= MaxClients; i++)
            {
                if (IsClientInGame(i) && IsPlayerAlive(i))
                {
                    float targetPos[3];
                    GetClientEyePosition(i, targetPos);
                    
                    float distance = GetVectorDistance(pos, targetPos);
                    if (distance < 500.0 && distance > 100.0)
                    {
                        // Pull towards center
                        float pullDir[3];
                        SubtractVectors(pos, targetPos, pullDir);
                        NormalizeVector(pullDir, pullDir);
                        
                        float strength = 10.0 * (1.0 - distance/500.0);
                        ScaleVector(pullDir, strength);
                        
                        TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, pullDir);
                        DealDamage(i, 60.0, entity);
                    }
                }
            }
        }
        
        case Type_Chaos:
        {
            // Chaos explosion - random effects
            for (int j = 0; j < 5; j++)
            {
                int randomEffect = GetRandomInt(0, 3);
                switch (randomEffect)
                {
                    case 0: // Fire
                    {
                        for (int i = 1; i <= MaxClients; i++)
                        {
                            if (IsClientInGame(i) && IsPlayerAlive(i))
                            {
                                float targetPos[3];
                                GetClientEyePosition(i, targetPos);
                                
                                if (GetVectorDistance(pos, targetPos) < 400.0)
                                {
                                    IgniteEntity(i, 3.0);
                                }
                            }
                        }
                    }
                    case 1: // Lightning
                    {
                        for (int i = 1; i <= MaxClients; i++)
                        {
                            if (IsClientInGame(i) && IsPlayerAlive(i))
                            {
                                float targetPos[3];
                                GetClientEyePosition(i, targetPos);
                                
                                if (GetVectorDistance(pos, targetPos) < 400.0)
                                {
                                    TE_SetupBeamPoints(pos, targetPos, PrecacheModel("sprites/laserbeam.vmt"), 0, 0, 0, 0.5, 30.0, 30.0, 10, 0.0, {255, 255, 0, 255}, 0);
                                    TE_SendToAll();
                                    DealDamage(i, 50.0, entity);
                                }
                            }
                        }
                    }
                    case 2: // Freeze
                    {
                        for (int i = 1; i <= MaxClients; i++)
                        {
                            if (IsClientInGame(i) && IsPlayerAlive(i))
                            {
                                float targetPos[3];
                                GetClientEyePosition(i, targetPos);
                                
                                if (GetVectorDistance(pos, targetPos) < 400.0)
                                {
                                    SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", 0.2);
                                    CreateTimer(2.0, Timer_RemoveFreeze, i);
                                }
                            }
                        }
                    }
                    case 3: // Explosion
                    {
                        TE_SetupExplosion(pos, PrecacheModel("sprites/redglow1.vmt"), 50.0, 1, 0, 300, 400);
                        TE_SendToAll();
                        
                        for (int i = 1; i <= MaxClients; i++)
                        {
                            if (IsClientInGame(i) && IsPlayerAlive(i))
                            {
                                float targetPos[3];
                                GetClientEyePosition(i, targetPos);
                                
                                if (GetVectorDistance(pos, targetPos) < 500.0)
                                {
                                    DealDamage(i, 100.0, entity);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Remove from owner if any
    if (g_iMachineOwner[slot] != -1)
    {
        int client = g_iMachineOwner[slot];
        g_iCurrentMachine[client] = -1;
        g_bHasMachine[client] = false;
        SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
    }
    
    // Call forward
    Call_StartForward(g_hOnMachineDestroyed);
    Call_PushCell(entity);
    Call_PushCell(g_iMachineType[slot]);
    Call_Finish();
    
    // Clean up data
    g_iMachineRef[slot] = INVALID_ENT_REFERENCE;
    g_bMachineActive[slot] = false;
    
    if (g_aVenomTargets[slot] != null)
    {
        delete g_aVenomTargets[slot];
        g_aVenomTargets[slot] = null;
    }
    
    AcceptEntityInput(entity, "Kill");
}

void RemoveAllMachines()
{
    for (int i = 0; i < MAX_MACHINE_GUNS; i++)
    {
        if (g_iMachineRef[i] != INVALID_ENT_REFERENCE)
        {
            int entity = EntRefToEntIndex(g_iMachineRef[i]);
            if (entity != INVALID_ENT_REFERENCE && IsValidEntity(entity))
            {
                DestroyMachineGun(i, entity);
            }
            else
            {
                g_iMachineRef[i] = INVALID_ENT_REFERENCE;
            }
        }
        
        if (g_aVenomTargets[i] != null)
        {
            delete g_aVenomTargets[i];
            g_aVenomTargets[i] = null;
        }
    }
    
    // Reset client data
    for (int i = 1; i <= MaxClients; i++)
    {
        g_iCurrentMachine[i] = -1;
        g_bHasMachine[i] = false;
        SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", 1.0);
    }
}

int FindTargetInRange(float pos[3], float range)
{
    ArrayList candidates = new ArrayList();
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3)
        {
            float targetPos[3];
            GetClientEyePosition(i, targetPos);
            
            float distance = GetVectorDistance(pos, targetPos);
            if (distance <= range)
            {
                candidates.Push(i);
            }
        }
    }
    
    if (candidates.Length > 0)
    {
        int randomIndex = GetRandomInt(0, candidates.Length - 1);
        int target = candidates.Get(randomIndex);
        delete candidates;
        return target;
    }
    
    delete candidates;
    return -1;
}

bool CheckMachineLimit(MachineType type)
{
    int current = GetMachineCount(type);
    int limit = GetMachineLimit(type);
    
    return (limit <= 0 || current < limit);
}

int GetMachineCount(MachineType type)
{
    int count = 0;
    for (int i = 0; i < MAX_MACHINE_GUNS; i++)
    {
        if (g_iMachineRef[i] != INVALID_ENT_REFERENCE && g_iMachineType[i] == type)
        {
            count++;
        }
    }
    return count;
}

int GetMachineLimit(MachineType type)
{
    switch (type)
    {
        case Type_Simple: return g_cvLimitSimple.IntValue;
        case Type_Flame: return g_cvLimitFlame.IntValue;
        case Type_Laser: return g_cvLimitLaser.IntValue;
        case Type_Tesla: return g_cvLimitTesla.IntValue;
        case Type_Freeze: return g_cvLimitFreeze.IntValue;
        case Type_Nauseating: return g_cvLimitNauseating.IntValue;
        case Type_Plasma: return g_cvLimitPlasma.IntValue;
        case Type_Shadow: return g_cvLimitShadow.IntValue;
        case Type_Vortex: return g_cvLimitVortex.IntValue;
        case Type_Phase: return g_cvLimitPhase.IntValue;
        case Type_Venom: return g_cvLimitVenom.IntValue;
        case Type_Gravity: return g_cvLimitGravity.IntValue;
        case Type_Chaos: return g_cvLimitChaos.IntValue;
        default: return 0;
    }
}

void GetTypeName(MachineType type, char[] buffer, int maxlen)
{
    switch (type)
    {
        case Type_Simple: strcopy(buffer, maxlen, "Simple");
        case Type_Flame: strcopy(buffer, maxlen, "Flame");
        case Type_Laser: strcopy(buffer, maxlen, "Laser");
        case Type_Tesla: strcopy(buffer, maxlen, "Tesla");
        case Type_Freeze: strcopy(buffer, maxlen, "Freeze");
        case Type_Nauseating: strcopy(buffer, maxlen, "Nauseating");
        case Type_Plasma: strcopy(buffer, maxlen, "Plasma");
        case Type_Shadow: strcopy(buffer, maxlen, "Shadow");
        case Type_Vortex: strcopy(buffer, maxlen, "Vortex");
        case Type_Phase: strcopy(buffer, maxlen, "Phase");
        case Type_Venom: strcopy(buffer, maxlen, "Venom");
        case Type_Gravity: strcopy(buffer, maxlen, "Gravity");
        case Type_Chaos: strcopy(buffer, maxlen, "Chaos");
        default: strcopy(buffer, maxlen, "Unknown");
    }
}

void DealDamage(int victim, float damage, int attacker = 0)
{
    if (victim < 1 || victim > MaxClients || !IsClientInGame(victim) || !IsPlayerAlive(victim))
        return;
    
    int health = GetClientHealth(victim);
    int newHealth = health - RoundFloat(damage);
    
    if (newHealth <= 0)
    {
        ForcePlayerSuicide(victim);
    }
    else
    {
        SetEntityHealth(victim, newHealth);
    }
}

public bool TraceFilter(int entity, int mask, int data)
{
    return entity != data;
}

// =====[ EVENTS ]=====
public void Event_PlayerIncapacitated(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvDropOnIncap.BoolValue) return;
    
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client && g_bHasMachine[client])
    {
        DropMachineGun(client);
    }
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client && g_bHasMachine[client])
    {
        DropMachineGun(client);
    }
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvPersist.BoolValue)
    {
        RemoveAllMachines();
    }
}

public void Event_MapTransition(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvPersist.BoolValue)
    {
        RemoveAllMachines();
    }
}

// =====[ CLIENT COMMANDS ]=====
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    if (!g_bHasMachine[client])
        return Plugin_Continue;
    
    // Fire with +use (E key)
    if (buttons & IN_USE)
    {
        int slot = g_iCurrentMachine[client];
        if (slot != -1)
        {
            int entity = EntRefToEntIndex(g_iMachineRef[slot]);
            if (entity != INVALID_ENT_REFERENCE)
            {
                FireMachineGun(client, slot, entity);
            }
        }
    }
    
    // Drop with +reload (R key)
    if (buttons & IN_RELOAD)
    {
        static float lastDrop[MAXPLAYERS+1];
        float currentTime = GetGameTime();
        
        if (currentTime - lastDrop[client] > 1.0) // Prevent multiple drops
        {
            DropMachineGun(client);
            lastDrop[client] = currentTime;
        }
    }
    
    return Plugin_Continue;
}

// =====[ FORWARDS ]=====
public void OnClientDisconnect(int client)
{
    if (g_bHasMachine[client])
    {
        DropMachineGun(client);
    }
    
    g_bClientVenomed[client] = false;
    g_fClientVenomTime[client] = 0.0;
    SetEntityGravity(client, 1.0);
}

// Natives for other plugins
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("MachineGun_Create", Native_CreateMachineGun);
    CreateNative("MachineGun_Remove", Native_RemoveMachineGun);
    CreateNative("MachineGun_GetType", Native_GetMachineType);
    CreateNative("MachineGun_GetAmmo", Native_GetMachineAmmo);
    CreateNative("MachineGun_SetAmmo", Native_SetMachineAmmo);
    
    RegPluginLibrary("l4d2_machinegun_ultimate");
    
    return APLRes_Success;
}

public int Native_CreateMachineGun(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    MachineModel model = GetNativeCell(2);
    MachineType type = GetNativeCell(3);
    
    CreateMachineGun(client, model, type);
    return 0;
}

public int Native_RemoveMachineGun(Handle plugin, int numParams)
{
    int entity = GetNativeCell(1);
    RemoveMachineGun(entity);
    return 0;
}

public int Native_GetMachineType(Handle plugin, int numParams)
{
    int entity = GetNativeCell(1);
    int slot = FindMachineSlotByEntity(entity);
    
    if (slot != -1)
        return view_as<int>(g_iMachineType[slot]);
    
    return -1;
}

public int Native_GetMachineAmmo(Handle plugin, int numParams)
{
    int entity = GetNativeCell(1);
    int slot = FindMachineSlotByEntity(entity);
    
    if (slot != -1)
        return g_iMachineAmmo[slot];
    
    return -1;
}

public int Native_SetMachineAmmo(Handle plugin, int numParams)
{
    int entity = GetNativeCell(1);
    int ammo = GetNativeCell(2);
    int slot = FindMachineSlotByEntity(entity);
    
    if (slot != -1)
    {
        g_iMachineAmmo[slot] = ammo;
        return 1;
    }
    
    return 0;
}

void RemoveMachineGun(int entity)
{
    int slot = FindMachineSlotByEntity(entity);
    if (slot != -1)
    {
        DestroyMachineGun(slot, entity);
    }
}