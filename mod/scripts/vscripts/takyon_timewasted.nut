global function TimeWastedInit

global struct TW_PlayerData{
	string name 
	string uid
	float minutesPlayed
}

const string startDate = "18th April 2022"
const string path = "../R2Northstar/mods/Takyon.TimeWasted/mod/scripts/vscripts/takyon_timewasted_cfg.nut" // where the config is stored
array<TW_PlayerData> tw_playerData = [] // data from current match

void function TimeWastedInit(){
	AddCallback_OnReceivedSayTextMessage(TW_ChatCallback)
	AddCallback_OnPlayerRespawned(TW_OnPlayerSpawned)

	thread TimeWastedLoop()
}

void function TimeWastedLoop(){
	for(;;){
		try{
			wait GetConVarInt("tw_loop_frequency")

			foreach(entity player in GetPlayerArray()){
				try{

				}
			}

			TW_SaveConfig()
		} catch(e){print("[TimeWasted] Couldnt complete loop: " + e)}
	}
}

void function TW_LeaderBoard(entity player){
	TW_CfgInit() // load config

	array<TW_PlayerData> TW_sortedConfig = tw_cfg_players // sort config in new array to not fuck with other shit
	tw_sortedConfig.sort(RankMeSort)
	Chat_ServerPrivateMessage(player, "\x1b[34m[TimeWasted] \x1b[38;2;0;220;30mTop Leaderboard \x1b[0m[" + tq_sortedConfig.len() + " Ranked since " + startDate "]", false)

	int loopAmount = GetConVarInt("tw_cfg_leaderboard_amount") > tw_sortedConfig.len() ? tw_sortedConfig.len() : GetConVarInt("tw_cfg_leaderboard_amount")

	for(int i = 0; i < loopAmount; i++){
		Chat_ServerPrivateMessage(player, format("[%i] %s wasted [\x1b[38;2;0;220;30m%.2f \x1b[0mHours on this Server!", i+1, tw_sortedConfig[i].name, tw_sortedConfig[i].minutesPlayed/60, false)
	}
}

void function TW_Rank(entity player){
	TW_CfgInit() // load config

	array<TW_PlayerData> tw_sortedConfig = tw_cfg_players // sort config in new array to not fuck with other shit
	tw_sortedConfig.sort(RankMeSort)

	for(int i = 0; i < tw_sortedConfig.len(); i++){
		if(tw_sortedConfig[i].uid == player.GetUID()){
			int deaths = tw_sortedConfig[i].deaths == 0 ? 1 : tw_sortedConfig[i].deaths // aboid division through 0
			string kd = format("%.2f", tw_sortedConfig[i].kills*1.0/deaths*1.0)
			Chat_ServerPrivateMessage(player, format("[%i/%i] %s wasted [\x1b[38;2;0;220;30m%.2f Hours on this Server!", i+1, tw_sortedConfig.len(), tw_sortedConfig[i].name, tw_sortedConfig[i].minutesPlayed, false)
			break
		}
	}
}

/*
 *	CHAT COMMANDS
 */

ClServer_MessageStruct function TW_ChatCallback(ClServer_MessageStruct message) {
    string msg = message.message.tolower()
    // find first char -> gotta be ! to recognize command
    if (format("%c", msg[0]) == "!") {
        // command
        msg = msg.slice(1) // remove !
        array<string> msgArr = split(msg, " ") // split at space, [0] = command
        string cmd
        
        try{
            cmd = msgArr[0] // save command
        }
        catch(e){
            return message
        }

        // command logic
		if(cmd == "topwasted"){
			TW_LeaderBoard(message.player)
		}
		else if(cmd == "rankwasted"){
			TW_Rank(message.player)
		}
    }
    return message
}

/*
 *	CONFIG
 */

const string TW_HEADER = "global function TW_CfgInit\n" +
						 "global array<TW_PlayerData> tw_cfg_players = []\n\n" +
						 "void function TW_CfgInit(){\n" +
						 "tw_cfg_players.clear()\n"

const string TW_FOOTER = "}\n\n" +
						 "void function AddPlayer(string name, string uid, float minutesPlayed){\n" +
						 "TW_PlayerData tmp;\ntmp.name = name;\ntmp.uid = uid;\ntmp.minutesPlayed = minutesPlayed;\ntw_cfg_players.append(tmp);\n" +
						 "}"

void function TW_SaveConfig(){
	TW_CfgInit()

	array<TW_PlayerData> offlinePlayersToSave = []

	foreach(TW_PlayerData pdcfg in tw_cfg_players){ // loop through each player in cfg
		bool found = false
		foreach(TW_PlayerData pd in tw_playerData){ // loop through each player in current match
			if(pdcfg.uid == pd.uid){ // player in live match is in cfg // REM 
				found = true
			}
		}

		if(!found){
			offlinePlayersToSave.append(pdcfg)
		}
	}
	
	// merge live and offline players
	array<TW_PlayerData> allPlayersToSave = []
	allPlayersToSave.extend(tw_playerData)
	allPlayersToSave.extend(offlinePlayersToSave)

	// write to buffer
	DevTextBufferClear()
	DevTextBufferWrite(TW_HEADER)

	foreach(TW_PlayerData pd in allPlayersToSave){
		DevTextBufferWrite(format("AddPlayer(\"%s\", \"%s\", %i)\n", pd.name, pd.uid, pd.minutesPlayed))	
	}
	
    DevTextBufferWrite(TW_FOOTER)

    DevP4Checkout(path)
	DevTextBufferDumpToFile(path)
	DevP4Add(path)
	print("[TimeWasted] Saving config at " + path)
}

/*
 *	CALLBACKS
 */

void function TW_OnPlayerSpawned(entity player){
	foreach(TW_PlayerData pd tw_playerData){ // check if in live data
		try{
			if(player.GetUID() == pd.uid){ // REM
				return
			}
		} catch(e){print("[TW] " + e)}
	}
	TW_CfgInit()
	foreach(TW_PlayerData pd in tw_cfg_players){
		if(player.GetUID() == pd.uid){ // if player in config, load player stats // REM
			TW_PlayerData tmp
			tmp.name = player.GetPlayerName() // maybe they changed their name? idk just gonna do it like this
			tmp.uid = pd.uid
			tmp.minutesPlayed = pd.minutesPlayed
			tw_playerData.append(tmp)
			return
		}
	}
	// player not yet in config
	TW_PlayerData tmp
	tmp.name = player.GetPlayerName()
	tmp.uid = player.GetUID() 
	tmp.minutesPlayed = 0
	tw_playerData.append(tmp)
}