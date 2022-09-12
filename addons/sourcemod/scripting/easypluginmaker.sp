#include <sourcemod>
#include <cstrike>
#include <clientprefs>
#include <sdktools>
#include <multicolors>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.2.1"
#define MAXMENUS 16
#define MAXCOMMANDS 32
#define MAXSUBMENUS 32

KeyValues gKV;

StringMap mCommandsList;
StringMap mAliasesList;

ArrayList g_hCmdAlreadyRegs;

ConVar epm_welcomemenu;

Cookie gCookie;

int iPreviousMenuIndex[MAXPLAYERS + 1];

enum struct MenuStructure
{
	char Identifier[64];
	char Title[64];
	bool CloseButton;
	int TimeToClose;
	ArrayList Items;
}
MenuStructure MenuStruct[MAXMENUS];

enum struct ItemStructure
{
	char Title[64];
	char Value[128];
	bool HasSubmenu;
	bool DisableItem;
	MenuStructure Submenu;
}

enum struct WelcomeMenuStructure
{
	char Title[64];
	bool CloseButton;
	int TimeToClose;
	ArrayList Items;
}
WelcomeMenuStructure WelcomeStruct;

public Plugin myinfo = 
{
	name = "Easy 'Plugin Maker'", 
	author = "Nathy", 
	description = "Create your commands, menus, aliases, welcome panel and more with this plugin.", 
	version = PLUGIN_VERSION, 
	url = "https://steamcommunity.com/id/nathyzinhaa"
};

public void OnPluginStart()
{
	AddCommandListener(SayHook, "say");
	AddCommandListener(SayHook, "say_team");
	epm_welcomemenu = CreateConVar("sm_welcome_menu_enable", "1", "enable/disable welcome menu (1 = Enable | 0 = Disable)");
	RegAdminCmd("sm_epm_reload", Command_reload_epm_config, ADMFLAG_ROOT, "Reload EasyPluginMaker Config");
	
	gCookie = new Cookie("welcomepanel", "if player already see panel, then it will save. Its useful to not display every map change", CookieAccess_Protected);
	
	AutoExecConfig(true, "EasyPluginMaker");
	RegisterCFG();
}

public void RegisterCFG()
{
	mCommandsList = new StringMap();
	mAliasesList = new StringMap();
	g_hCmdAlreadyRegs = new ArrayList(ByteCountToCells(32));
	
	
	gKV = new KeyValues("EasyPluginMaker");
	char sPath[1024];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/easypluginmaker.cfg");
	
	if(!gKV.ImportFromFile(sPath))
	{
		delete gKV;
		PrintToServer("%s NOT FOUND", sPath);
	}
	
	if(gKV.JumpToKey("chat"))
	{
		if (!gKV.GotoFirstSubKey())
		{
			PrintToServer("ERROR IN MENU FIRST KEY");
			delete gKV;
			return;
		}
			
		do
		{
			char buffer[32];
			if(gKV.GetSectionName(buffer, sizeof(buffer)))
			{
				char sValue[2048];
				gKV.GetString("print", sValue, sizeof(sValue));
				mCommandsList.SetString(buffer, sValue);
			}
		}
		while(gKV.GotoNextKey());
		
		gKV.Rewind();
	}
	
	if(gKV.JumpToKey("menu"))
	{
		if (!gKV.GotoFirstSubKey())
		{
			PrintToServer("ERROR IN MENU FIRST KEY");
			delete gKV;
			return;
		}
		
		int count;
		char buffer[32];
		do {
			if(gKV.GetSectionName(buffer, sizeof(buffer)))
			{
				count++;
				
				strcopy(MenuStruct[count].Identifier, sizeof(MenuStruct[].Identifier), buffer);
				gKV.GetString("title", MenuStruct[count].Title, sizeof(MenuStruct[].Title));
				MenuStruct[count].CloseButton = view_as<bool>(gKV.GetNum("closebutton"));
				MenuStruct[count].TimeToClose = gKV.GetNum("timetoclose");
				MenuStruct[count].Items = new ArrayList(sizeof(ItemStructure));
				
				if(gKV.JumpToKey("items"))
				{
					if (!gKV.GotoFirstSubKey())
					{
						PrintToServer("ERROR ITEM FIRST KEY");
						delete gKV;
						return;
					}
					
					do {
						ItemStructure Item;
						
						if(gKV.GetSectionName(buffer, sizeof(buffer)))
						{
							char sValue[128];
							gKV.GetString("value", sValue, sizeof(sValue));
							strcopy(Item.Title, sizeof(Item.Title), buffer);
							strcopy(Item.Value, sizeof(Item.Value), sValue);
							
							if(gKV.JumpToKey("disabled"))
							{
								Item.DisableItem = true;
								
								gKV.GoBack();
							}
							
							if(gKV.JumpToKey("submenu"))
							{
								Item.HasSubmenu = true;
								gKV.GetString("title", Item.Submenu.Title, 64);
								Item.Submenu.CloseButton = view_as<bool>(gKV.GetNum("closebutton"));
								Item.Submenu.TimeToClose = gKV.GetNum("timetoclose");
								Item.Submenu.Items = new ArrayList(sizeof(ItemStructure));
								
								if(gKV.JumpToKey("items"))
								{
									gKV.GotoFirstSubKey();
									
									do {
										ItemStructure SubItem;
										
										if(gKV.GetSectionName(buffer, sizeof(buffer)))
										{
											gKV.GetString("value", sValue, sizeof(sValue));
											strcopy(SubItem.Title, sizeof(SubItem.Title), buffer);
											strcopy(SubItem.Value, sizeof(SubItem.Value), sValue);
											
											if(gKV.JumpToKey("disabled"))
											{
												SubItem.DisableItem = true;
								
												gKV.GoBack();
											}
											
											Item.Submenu.Items.PushArray(SubItem);
										}
									}
									while (gKV.GotoNextKey());
									
									gKV.GoBack();
									gKV.GoBack();
								}
								
								gKV.GoBack();
							}
							
							MenuStruct[count].Items.PushArray(Item);
						}
					}
					while (gKV.GotoNextKey());

					gKV.GoBack();
				}
			}	
			gKV.GoBack();			
		}	
		while (gKV.GotoNextKey());
		
		gKV.Rewind();
	}
	
	if(gKV.JumpToKey("alias"))
	{
		if(!gKV.GotoFirstSubKey(false))
		{
			PrintToServer("ERROR IN ALIAS FIRST KEY");
			delete gKV;
			return;
		}
		
		char sKey[32], sBuffer[256];
		do
		{
			gKV.GetSectionName(sKey, sizeof sKey);
			gKV.GetString(NULL_STRING, sBuffer, sizeof(sBuffer));
			int i = 0;
			do 
			{
				i = FindCharInString(sBuffer, ';', true);
				if (i > -1)
				{
					sBuffer[i] = 0;
				}

				i++;
				mAliasesList.SetString(sBuffer[i], sKey);
				if(PushRegCommand(sBuffer[i])) 
					RegConsoleCmd(sBuffer[i], CommandCB);
			} 
			while (i != 0);
		}
		while(gKV.GotoNextKey(false));
		
		gKV.Rewind();
	}
	
	if(gKV.JumpToKey("welcome"))
	{
		gKV.GetString("title", WelcomeStruct.Title, sizeof(WelcomeStruct.Title));
		WelcomeStruct.CloseButton = view_as<bool>(gKV.GetNum("closebutton"));
		WelcomeStruct.TimeToClose = gKV.GetNum("timetoclose");
		
		if(gKV.JumpToKey("items"))
		{
			WelcomeStruct.Items = new ArrayList(ByteCountToCells(256));
			
			gKV.GotoFirstSubKey(false);
			
			do
			{
				char sValue[256];
				gKV.GetString(NULL_STRING, sValue, sizeof(sValue));
				WelcomeStruct.Items.PushString(sValue);
			}
			while(gKV.GotoNextKey(false));
			
			gKV.GoBack();
		}
		
		gKV.Rewind();
	}
	
	gKV.Rewind();
	delete gKV;
}

public Action SayHook(int client, char[] Cmd, int args)
{
	char arg[256];
	GetCmdArgString(arg, sizeof(arg));
	StripQuotes(arg);
	TrimString(arg);
	
	char sCommandValue[2048];
	if(mCommandsList.GetString(arg, sCommandValue, sizeof(sCommandValue)))
	{
		DataPack pack;
		CreateDataTimer(0.1, Timer_MessageDelay, pack);
		pack.WriteCell(client);
		pack.WriteString(sCommandValue);
	}

	ArgEqualMenu(client, arg);
	
	return Plugin_Continue;
}


void ArgEqualMenu(int client, char[] arg)
{
	for(int i = 0; i < MAXMENUS; i++)
	{
		if(StrEqual(MenuStruct[i].Identifier, arg))
		{
			ExecuteMenu(client, i);
			break;
		}
	}
}

bool PushRegCommand(char[] sCommand)
{
	if(g_hCmdAlreadyRegs.FindString(sCommand) == -1)
	{
		g_hCmdAlreadyRegs.PushString(sCommand);

		return true;
	}
	else return false;
}

Action CommandCB(int iClient, int iArgs)
{
	char sCommand[32], sBuf[32], sArgs[512];

	GetCmdArg(0, sCommand, sizeof(sCommand));
	for(int i = 1; i <= iArgs; i++)
	{
		GetCmdArg(i, sBuf, sizeof(sBuf));
		Format(sArgs, sizeof(sArgs), "%s %s", sArgs, sBuf);
	}

	if(mAliasesList.GetString(sCommand, sBuf, sizeof(sBuf)))
	{
		if(iClient == 0)
		{
			ServerCommand("%s %s", sBuf, sArgs);
		}
		else ClientCommand(iClient, "%s %s", sBuf, sArgs);
	}

	return Plugin_Handled;
}

public Action Timer_MessageDelay(Handle timer, DataPack pack)
{
    pack.Reset();
    int client = pack.ReadCell();
    char message[2048];
    pack.ReadString(message, sizeof(message));
    
    CheckVariables(client, message, sizeof(message));
    CPrintToChat(client, "\x01 %s", message);
    
    return Plugin_Handled;
}

void ExecuteMenu(int client, int index)
{
	Menu menu = new Menu(Handle_Menu);
	menu.SetTitle(MenuStruct[index].Title);
	
	char sTmp[64];
	for(int i = 0; i < MenuStruct[index].Items.Length; i++)
	{
		ItemStructure Item;
		MenuStruct[index].Items.GetArray(i, Item);
		
		Format(sTmp, sizeof(sTmp), "%i|%i", index, i); // MENU INDEX | MENU ITEM INDEX
		
		CheckVariables(client, Item.Title, sizeof(Item.Title));
		menu.AddItem(sTmp, Item.Title, (Item.DisableItem)?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	}
	
	menu.ExitButton = MenuStruct[index].CloseButton;
	menu.Display(client, 30);
}

public int Handle_Menu(Menu menu, MenuAction action, int client, int param)
{
	if(action == MenuAction_Select)
	{
		char info[32], buffer[2][16];
		menu.GetItem(param, info, sizeof(info));
		ExplodeString(info, "|", buffer, 2, 16);
		
		int menuindex = StringToInt(buffer[0]);
		int itemindex = StringToInt(buffer[1]);
		
		ItemStructure Item;
		MenuStruct[menuindex].Items.GetArray(itemindex, Item);
		
		FakeClientCommand(client, "say /%s", Item.Value);
		
		if(Item.HasSubmenu)
		{
			iPreviousMenuIndex[client] = menuindex;
			ExecuteSubmenu(client, menuindex, itemindex);
		}
	}
	else if(action == MenuAction_End)
		delete menu;
		
	return 0;
}

void ExecuteSubmenu(int client, int menuindex, int itemindex)
{
    ItemStructure Item;
    MenuStruct[menuindex].Items.GetArray(itemindex, Item);
    
    Menu menu = new Menu(Handle_SubMenu);
    menu.SetTitle(Item.Submenu.Title);
    
    
    char sTmp[64];
    for(int i = 0; i < Item.Submenu.Items.Length; i++)
    {
        ItemStructure SubItem;
        Item.Submenu.Items.GetArray(i, SubItem);
        
        Format(sTmp, sizeof(sTmp), "%i|%i|%i", menuindex, itemindex, i); // MENU INDEX | MENU ITEM INDEX
        
        CheckVariables(client, SubItem.Title, sizeof(SubItem.Title));
        menu.AddItem(sTmp, SubItem.Title, (SubItem.DisableItem)?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
    }
    
    menu.ExitButton = Item.Submenu.CloseButton;
    menu.ExitBackButton = true;
    menu.Display(client, 30);
}

public int Handle_SubMenu(Menu menu, MenuAction action, int client, int param)
{
    if(action == MenuAction_Select)
    {
        char info[32], buffer[3][32];
        menu.GetItem(param, info, sizeof(info));
        
        if(StrEqual(info, "goback"))
        {
        	ExecuteMenu(client, iPreviousMenuIndex[client]);
        }
        else
        {
	        ExplodeString(info, "|", buffer, 3, 32);
	        
	        int menuindex = StringToInt(buffer[0]);
	        int itemindex = StringToInt(buffer[1]);
	        int subitemindex = StringToInt(buffer[2]);
	        
	        ItemStructure Item;
	        MenuStruct[menuindex].Items.GetArray(itemindex, Item);
	        
	        ItemStructure SubItem;
	        Item.Submenu.Items.GetArray(subitemindex, SubItem);
	        
	        FakeClientCommand(client, "say /%s", SubItem.Value);
		}
    }
   	else if(action == MenuAction_Cancel)
	{
		if(param == MenuCancel_ExitBack)
			ExecuteMenu(client, iPreviousMenuIndex[client]);
	}
	else if(action == MenuAction_End)
		delete menu;
        
    return 0;
}

public void OnClientCookiesCached(int client)
{
	char notwice[32];
	GetClientCookie(client, gCookie, notwice, 32);
	int value = StringToInt(notwice);
	
	if(value == 1 && epm_welcomemenu.BoolValue)
		return;
		
	CreateTimer(5.0, Timer_Welcome, client);
	return;
}

public Action Timer_Welcome(Handle timer, int client)
{
	MenuWelcome(client);
	SetClientCookie(client, gCookie, "1");
	
	return Plugin_Handled;
}

void MenuWelcome(int client)
{
	Panel panel = new Panel();
	CheckVariables(client, WelcomeStruct.Title, sizeof(WelcomeStruct.Title));
	panel.SetTitle(WelcomeStruct.Title);

	char text[256];
	for(int i = 0; i < WelcomeStruct.Items.Length; i++)
	{
		WelcomeStruct.Items.GetString(i, text, sizeof(text));
		CheckVariables(client, text, sizeof(text));
		panel.DrawText(text);
	}

	panel.Send(client, Handle_Menu, WelcomeStruct.TimeToClose);
}

public Action Command_reload_epm_config(int client, int args)
{
	RegisterCFG();
	ReplyToCommand(client, "[EasyPluginMaker] Configs reloaded successfully.");
	
	return Plugin_Handled;
}

void CheckVariables(int client, char[] buffer, int maxlen)
{
	char sTmp[512];

	if (StrContains(buffer, "{USERID}", false))
	{
		IntToString(GetClientUserId(client), sTmp, sizeof(sTmp));
		ReplaceString(buffer, maxlen, "{USERID}", sTmp);
	}
	
	if (StrContains(buffer, "{PLAYERNAME}", false)) 
	{
		Format(sTmp, sizeof(sTmp), "%N", client);
		ReplaceString(buffer, maxlen, "{PLAYERNAME}", sTmp);
	}
	
	if (StrContains(buffer, "{STEAM32}", false))
	{
		GetClientAuthId(client, AuthId_Steam2, sTmp, sizeof(sTmp));
		ReplaceString(buffer, maxlen, "{STEAM32}", sTmp);
	}
	
	if (StrContains(buffer, "{PING}", false)) 
	{
		Format(sTmp, sizeof(sTmp), "%d", GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iPing", _, client));
		ReplaceString(buffer, maxlen, "{PING}", sTmp);
	}
	
	if (StrContains(buffer, "{SECTION_TIME}", false)) 
	{
		Format(sTmp, sizeof(sTmp), "%s", FormatShortTime(RoundToFloor(GetClientTime(client))));
		ReplaceString(buffer, maxlen, "{SECTION_TIME}", sTmp);
	}
}

char FormatShortTime(int time) {
	char Time[12];
	int g_iHours = 0;
	int g_iMinutes = 0;
	int g_iSeconds = time;
	
	while (g_iSeconds > 3600) {
		g_iHours++;
		g_iSeconds -= 3600;
	}
	while (g_iSeconds > 60) {
		g_iMinutes++;
		g_iSeconds -= 60;
	}
	if (g_iHours >= 1)Format(Time, sizeof(Time), "%d:%d:%d", g_iHours, g_iMinutes, g_iSeconds);
	else if (g_iMinutes >= 1)Format(Time, sizeof(Time), "  %d:%d", g_iMinutes, g_iSeconds);
	else Format(Time, sizeof(Time), "   %d", g_iSeconds);
	return Time;
}