untyped
global function TimeWastedInit

global struct TW_PlayerData{
	string name 
	string uid
	var minutesPlayed = 0
}

void function TimeWastedInit(){
	AddCallback_OnReceivedSayTextMessage(TW_ChatCallback)

	FlagInit("TW_ReceivedGetPlayer")
	FlagInit("TW_SavedConfig")

	thread TimeWastedLoop()
}

void function TimeWastedLoop(){
	for(;;){
		try{
			wait GetConVarInt("tw_loop_frequency")

			foreach(entity player in GetPlayerArray()){
				if(!IsValid(player))
					continue

				TW_PlayerData data
				GetPlayer(player, data)

				FlagWait("TW_ReceivedGetPlayer")
				FlagClear("TW_ReceivedGetPlayer")

				try{
					if(player.GetUID() == data.uid)
						data.minutesPlayed += GetConVarInt("tw_loop_frequency")*1.0/60
					
					TW_SaveConfig(data, player)
				} catch(e){}
			}
		} catch(e){print("[TimeWasted] Couldnt complete loop: " + e)}
	}
}

void function TW_LeaderBoard(entity player){
	HttpRequest request;
	request.method = HttpRequestMethod.GET;
	request.url = "http://localhost:8080";
	request.headers["t_querytype"] <- ["timewasted_leaderboard"];

	entity player = player

	void functionref( HttpRequestResponse ) onSuccess = void function ( HttpRequestResponse response ) : ( player )
	{
		array<string> lines = split(response.body, "\n")

		int loopAmount = GetConVarInt("tw_cfg_leaderboard_amount")
		
		for(int i = 0; i < (loopAmount > lines.len() ? lines.len() : loopAmount); i++)
			Chat_ServerPrivateMessage(player, lines[i], false, false)
	}

	void functionref( HttpRequestFailure ) onFailure = void function ( HttpRequestFailure failure ) : ( player )
	{
		Chat_ServerPrivateMessage(player, TW_SERVER_ERROR, false, false)
	}

	NSHttpRequest( request, onSuccess, onFailure );
}

void function TW_Rank(entity player){
	HttpRequest request;
	request.method = HttpRequestMethod.GET;
	request.url = "http://localhost:8080";
	request.headers["t_querytype"] <- ["timewasted_queryplayer"];
	request.headers["t_uid"] <- [player.GetUID().tostring()];

	entity player = player

	void functionref( HttpRequestResponse ) onSuccess = void function ( HttpRequestResponse response ) : ( player )
	{
		Chat_ServerPrivateMessage(player, response.body, false, false)
	}

	void functionref( HttpRequestFailure ) onFailure = void function ( HttpRequestFailure failure ) : ( player )
	{
		Chat_ServerPrivateMessage(player, TW_SERVER_ERROR, false, false)
	}

	NSHttpRequest( request, onSuccess, onFailure );
}

void function TW_AllWastedTime(entity player){
	HttpRequest request;
	request.method = HttpRequestMethod.GET;
	request.url = "http://localhost:8080";
	request.headers["t_querytype"] <- ["timewasted_allwastedtime"];
	request.headers["t_uid"] <- [player.GetUID().tostring()];

	entity player = player

	void functionref( HttpRequestResponse ) onSuccess = void function ( HttpRequestResponse response ) : ( player )
	{
		Chat_ServerPrivateMessage(player, response.body, false, false)
	}

	void functionref( HttpRequestFailure ) onFailure = void function ( HttpRequestFailure failure ) : ( player )
	{
		Chat_ServerPrivateMessage(player, TW_SERVER_ERROR, false, false)
	}

	NSHttpRequest( request, onSuccess, onFailure );
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
		if(cmd == "topwasted" || cmd == "toptime"){
			TW_LeaderBoard(message.player)
		}
		else if(cmd == "rankwasted" || cmd == "ranktime"){
			TW_Rank(message.player)
		}
		else if(cmd == "wasted"){
			TW_AllWastedTime(message.player)
		}
    }
    return message
}

/*
 *	CONFIG
 */

void function TW_SaveConfig(TW_PlayerData player_data, entity player){
	print("[timewasted] [TW_SaveConfig]")
	try{
		// send post request to update
		HttpRequest request;
		request.method = HttpRequestMethod.POST;
		request.url = "http://localhost:8080";
		request.headers["t_uid"] <- [player.GetUID().tostring()];
		request.contentType = "application/json; charset=utf-8"
		request.body =  PlayerDataToJson(player, player_data)

		void functionref( HttpRequestResponse ) onSuccess = void function ( HttpRequestResponse response )
		{
			FlagSet("TW_SavedConfig")
		}

		void functionref( HttpRequestFailure ) onFailure = void function ( HttpRequestFailure failure ) : ( player )
		{
			FlagSet("TW_SavedConfig")
			if(!IsValid(player))
				return
			Chat_ServerPrivateMessage(player, TW_SERVER_ERROR, false, false)
		}

		NSHttpRequest( request, onSuccess, onFailure );
	} catch(e){print("[timewasted] [error] [TW_SaveConfig] " + e)}
}

/*
 *	HELPER FUNCTIONS
 */

void function GetPlayer(entity player, TW_PlayerData tmp){
	print("[timewasted] [GetPlayer]")
	HttpRequest request;
	request.method = HttpRequestMethod.GET;
	request.url = "http://localhost:8080";
	request.headers["t_querytype"] <- ["timewasted_queryplayer"];
	request.headers["t_returnraw"] <- ["true"];
	request.headers["t_uid"] <- [player.GetUID().tostring()];

	void functionref( HttpRequestResponse ) onSuccess = void function ( HttpRequestResponse response ) : ( player, tmp )
	{
		// failed to get player
		if(!NSIsSuccessHttpCode(response.statusCode)){
			print("uninitialized player, setting up default for " + player.GetPlayerName())
			tmp.name = player.GetPlayerName() 
			tmp.uid = player.GetUID()
			FlagSet("TW_ReceivedGetPlayer")
			return
		}
			
		// got player successfully
		table json = DecodeJSON(response.body)

		tmp.name = player.GetPlayerName() // maybe they changed their name? idk just gonna do it like this
		tmp.uid = player.GetUID()
		tmp.minutesPlayed = json.rawget("minutesPlayed").tofloat()
		FlagSet("TW_ReceivedGetPlayer")
	}

	void functionref( HttpRequestFailure ) onFailure = void function ( HttpRequestFailure failure ) : ( player )
	{
		Chat_ServerPrivateMessage(player, TW_SERVER_ERROR, false, false)
	}
	
	NSHttpRequest( request, onSuccess, onFailure )
}

string function PlayerDataToJson(entity player, TW_PlayerData player_data){
	print("[timewas] [PlayerDataToJson]")
	table tab_inner = {}
	tab_inner[ "mod" ] <- "timewasted"
	tab_inner[ "uid" ] <- player.GetUID()
	tab_inner[ "name" ] <- player.GetPlayerName()
	tab_inner[ "minutesPlayed" ] <- player_data.minutesPlayed

	var mods = []
	mods.append(tab_inner)

	table tab_mods = {}
	tab_mods[ "mods" ] <- mods

	var players = []
	players.append(tab_mods)

	table tab_players = {}
	tab_players[ "players" ] <- players

	return EncodeJSON(tab_players)
}