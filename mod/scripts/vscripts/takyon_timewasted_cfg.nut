global function TW_CfgInit
global array<TW_PlayerData> tw_cfg_players = []

void function TW_CfgInit(){
tw_cfg_players.clear()
AddPlayer("Takyon_Scure", "1006880507304", 910)
}

void function AddPlayer(string name, string uid, float minutesPlayed){
TW_PlayerData tmp;
tmp.name = name;
tmp.uid = uid;
tmp.minutesPlayed = minutesPlayed;
tw_cfg_players.append(tmp);
}