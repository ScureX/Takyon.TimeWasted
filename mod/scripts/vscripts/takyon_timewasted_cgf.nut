global function TW_CfgInit
global array<TW_PlayerData> tw_cfg_players = []

void function TW_CfgInit(){
tw_cfg_players.clear()
}

void function AddPlayer(string name, string uid, float minutesPlayed){
RM_PlayerData tmp;
tmp.name = name;
tmp.uid = uid;
tmp.minutesPlayed = minutesPlayed;
}