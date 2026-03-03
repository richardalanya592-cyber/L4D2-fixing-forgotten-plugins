#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

public Plugin myinfo = 
{
	name = "L4D2 Final Rescue Arrive Time",
	author = "Harry Potter Style Plugin",
	description = "Forces rescue vehicle to arrive in 10 minutes on all finale maps with center countdown",
	version = "2.0",
	url = "https://github.com/yourusername"
}

ConVar g_hCvarMinuteTime;
int g_iRescueMinutes = 10;
int g_iSecondsLeft;
int g_iTotalSeconds;
Handle g_hTimerAnnounce;
bool g_bFinaleActive;
bool g_bTenSecondAlertDone;

public void OnPluginStart()
{
	// Create convar for flexibility
	g_hCvarMinuteTime = CreateConVar("l4d2_rescue_minutes", "10", "Minutes until rescue arrives on finale", FCVAR_NOTIFY, true, 1.0, true, 60.0);
	g_iRescueMinutes = GetConVarInt(g_hCvarMinuteTime);
	HookConVarChange(g_hCvarMinuteTime, OnMinutesChanged);
	
	// Hook events
	HookEvent("finale_start", Event_FinaleStart);
	HookEvent("finale_radio_start", Event_FinaleStart);
	HookEvent("finale_bridge_start", Event_FinaleStart);
	HookEvent("finale_gate_unlocked", Event_FinaleStart);
	HookEvent("finale_rush", Event_FinaleStart);
	HookEvent("rescue_start", Event_RescueStart);
	HookEvent("finale_win", Event_FinaleWin);
	HookEvent("round_end", Event_RoundEnd);
	
	// Late load support
	if (IsFinaleMap())
	{
		CreateTimer(1.0, Timer_CheckFinaleStart, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void OnMinutesChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iRescueMinutes = GetConVarInt(convar);
}

public void OnMapStart()
{
	g_bFinaleActive = false;
	g_iTotalSeconds = g_iRescueMinutes * 60;
	g_iSecondsLeft = g_iTotalSeconds;
	g_bTenSecondAlertDone = false;
	
	// Precache sound for 10 second alert
	PrecacheSound("buttons/blip1.wav", true);
	PrecacheSound("ui/alert_countdown.wav", true);
	PrecacheSound("ui/beep07.wav", true);
}

public void Event_FinaleStart(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bFinaleActive)
		return;
		
	g_bFinaleActive = true;
	g_iTotalSeconds = g_iRescueMinutes * 60;
	g_iSecondsLeft = g_iTotalSeconds;
	g_bTenSecondAlertDone = false;
	
	// Kill old timer if exists
	if (g_hTimerAnnounce != null)
	{
		KillTimer(g_hTimerAnnounce);
		g_hTimerAnnounce = null;
	}
	
	// Start announcement timer
	g_hTimerAnnounce = CreateTimer(1.0, Timer_AnnounceRescue, _, TIMER_REPEAT);
	
	PrintToChatAll("\x04[Rescue Arrive] \x01Rescue will arrive in \x03%d minutes\x01! Hold out!", g_iRescueMinutes);
	PrintCenterTextAll("RESCUE IN: %d:%02d", g_iRescueMinutes, 0);
	PrintHintTextToAll("Rescue arrives in %d minutes!", g_iRescueMinutes);
}

public void Event_RescueStart(Event event, const char[] name, bool dontBroadcast)
{
	// Set rescue timer to exactly X minutes
	L4D2_SetRescueVehicleTimer(g_iRescueMinutes * 60);
	
	PrintToChatAll("\x04[Rescue Arrive] \x01Rescue timer set to \x03%d minutes\x01.", g_iRescueMinutes);
}

public void Event_FinaleWin(Event event, const char[] name, bool dontBroadcast)
{
	PrintToChatAll("\x04[Rescue Arrive] \x05Rescue vehicle arrived! Let's GO!!!");
	PrintCenterTextAll("RESCUE ARRIVED! LET'S GO!");
	
	if (g_hTimerAnnounce != null)
	{
		KillTimer(g_hTimerAnnounce);
		g_hTimerAnnounce = null;
	}
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_bFinaleActive = false;
	g_bTenSecondAlertDone = false;
	
	if (g_hTimerAnnounce != null)
	{
		KillTimer(g_hTimerAnnounce);
		g_hTimerAnnounce = null;
	}
}

public Action Timer_CheckFinaleStart(Handle timer)
{
	if (!g_bFinaleActive && IsFinaleActive())
	{
		g_bFinaleActive = true;
		g_iTotalSeconds = g_iRescueMinutes * 60;
		g_iSecondsLeft = g_iTotalSeconds;
		g_bTenSecondAlertDone = false;
		
		if (g_hTimerAnnounce == null)
		{
			g_hTimerAnnounce = CreateTimer(1.0, Timer_AnnounceRescue, _, TIMER_REPEAT);
		}
		
		PrintToChatAll("\x04[Rescue Arrive] \x01Rescue will arrive in \x03%d minutes\x01! Hold out!", g_iRescueMinutes);
		PrintCenterTextAll("RESCUE IN: %d:%02d", g_iRescueMinutes, 0);
	}
	
	return Plugin_Stop;
}

public Action Timer_AnnounceRescue(Handle timer)
{
	if (!g_bFinaleActive || !IsFinaleActive())
	{
		g_bFinaleActive = false;
		g_hTimerAnnounce = null;
		return Plugin_Stop;
	}
	
	// Get actual time left from rescue vehicle
	float timeLeft = L4D2_GetRescueTimeLeft();
	
	if (timeLeft <= 0.0)
	{
		// Try to get from our counter
		if (g_iSecondsLeft <= 0)
		{
			// Rescue arrived!
			PrintToChatAll("\x04[Rescue Arrive] \x05Rescue vehicle arrived! Let's GO!!!");
			PrintCenterTextAll("RESCUE ARRIVED! LET'S GO!");
			g_hTimerAnnounce = null;
			return Plugin_Stop;
		}
		
		timeLeft = float(g_iSecondsLeft);
	}
	else
	{
		// Sync our counter with game time
		g_iSecondsLeft = RoundToFloor(timeLeft);
	}
	
	int minutes = RoundToFloor(timeLeft / 60);
	int seconds = RoundToFloor(timeLeft) % 60;
	
	// ALWAYS show center countdown from start to finish
	PrintCenterTextAll("RESCUE IN: %d:%02d", minutes, seconds);
	
	// Announce every minute
	static int lastAnnouncedMinute = -1;
	
	if (minutes != lastAnnouncedMinute && minutes > 0)
	{
		if (minutes == 1)
			PrintToChatAll("\x04[Rescue Arrive] \x01Rescue arrives in \x03%d minute\x01.", minutes);
		else if (minutes <= 5 || minutes % 5 == 0)
			PrintToChatAll("\x04[Rescue Arrive] \x01Rescue arrives in \x03%d minutes\x01.", minutes);
		
		lastAnnouncedMinute = minutes;
	}
	
	// Special 10 second alert with sound
	if (minutes == 0 && seconds == 10 && !g_bTenSecondAlertDone)
	{
		g_bTenSecondAlertDone = true;
		PrintToChatAll("\x04[Rescue Arrive] \x05TEN SECONDS REMAINING! GET READY!");
		PrintHintTextToAll("⚡⚡ 10 SECONDS! ⚡⚡");
		
		// Play alert sound for all players
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsPlayerAlive(i))
			{
				EmitSoundToClient(i, "ui/alert_countdown.wav");
				EmitSoundToClient(i, "buttons/blip1.wav");
			}
		}
	}
	
	// Countdown last 5 seconds with beeps
	if (minutes == 0 && seconds <= 5 && seconds > 0)
	{
		char sound[64];
		if (seconds == 5)
			sound = "ui/beep07.wav";
		else if (seconds == 4)
			sound = "ui/beep07.wav";
		else if (seconds == 3)
			sound = "ui/beep07.wav";
		else if (seconds == 2)
			sound = "ui/beep07.wav";
		else if (seconds == 1)
			sound = "ui/beep07.wav";
			
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsPlayerAlive(i))
			{
				EmitSoundToClient(i, sound);
			}
		}
		
		// Show big center number for last 5 seconds
		char centerMsg[32];
		Format(centerMsg, sizeof(centerMsg), "%d", seconds);
		PrintCenterTextAll(centerMsg);
	}
	
	// Final message when rescue arrives
	if (minutes == 0 && seconds == 0)
	{
		PrintToChatAll("\x04[Rescue Arrive] \x05Rescue vehicle arrived! Let's GO!!!");
		PrintCenterTextAll("RESCUE ARRIVED! LET'S GO!");
		
		// Play arrival sound
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				EmitSoundToClient(i, "ui/alert_countdown.wav");
			}
		}
	}
	
	g_iSecondsLeft--;
	
	return Plugin_Continue;
}

float L4D2_GetRescueTimeLeft()
{
	int timer = FindEntityByClassname(-1, "func_rescuevehicle");
	if (timer == -1)
		return 0.0;
	
	float duration = GetEntPropFloat(timer, Prop_Send, "m_duration");
	float elapsed = GetEntPropFloat(timer, Prop_Send, "m_timer");
	
	return duration - elapsed;
}

void L4D2_SetRescueVehicleTimer(int seconds)
{
	int timer = FindEntityByClassname(-1, "func_rescuevehicle");
	if (timer == -1)
		return;
	
	SetEntPropFloat(timer, Prop_Send, "m_duration", float(seconds));
	SetEntPropFloat(timer, Prop_Send, "m_timer", 0.0);
	
	// Also try to find and set any rescue vehicle relay
	int relay = FindEntityByClassname(-1, "logic_relay");
	while (relay != -1)
	{
		char name[64];
		GetEntPropString(relay, Prop_Data, "m_iName", name, sizeof(name));
		
		if (StrContains(name, "rescue") != -1 || StrContains(name, "finale") != -1)
		{
			AcceptEntityInput(relay, "Disable");
		}
		
		relay = FindEntityByClassname(relay, "logic_relay");
	}
}

bool IsFinaleActive()
{
	// Check for finale entities
	if (FindEntityByClassname(-1, "trigger_finale") != -1)
		return true;
	
	if (FindEntityByClassname(-1, "info_changelevel") != -1)
	{
		// Check if it's a finale changelevel
		char target[64];
		GetEntPropString(FindEntityByClassname(-1, "info_changelevel"), Prop_Data, "m_mapName", target, sizeof(target));
		
		if (strlen(target) > 0)
			return true;
	}
	
	// Check for rescue vehicle
	if (FindEntityByClassname(-1, "func_rescuevehicle") != -1)
	{
		float time = L4D2_GetRescueTimeLeft();
		if (time > 0.0)
			return true;
	}
	
	return false;
}

bool IsFinaleMap()
{
	char map[64];
	GetCurrentMap(map, sizeof(map));
	
	// Common finale maps in L4D2
	if (StrEqual(map, "c1m4_atrium") ||
		StrEqual(map, "c2m5_concert") ||
		StrEqual(map, "c3m4_plantation") ||
		StrEqual(map, "c4m5_milltown_escape") ||
		StrEqual(map, "c5m5_bridge") ||
		StrEqual(map, "c6m3_port") ||
		StrEqual(map, "c7m3_port") ||
		StrEqual(map, "c8m5_rooftop") ||
		StrEqual(map, "c9m2_lots") ||
		StrEqual(map, "c10m5_houseboat") ||
		StrEqual(map, "c11m5_runway") ||
		StrEqual(map, "c12m5_cornfield") ||
		StrEqual(map, "c13m4_cutthroatcreek"))
	{
		return true;
	}
	
	return false;
}