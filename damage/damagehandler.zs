class DamageNumberHandler : EventHandler
{
	const EMPTY_STRING = "";

	private ui transient DScreenInfo si;
	private ui transient Font fonts[10];
	private ui transient bool bInitialized;
	private ui transient string game;
	
	// Draw behavior
	private ui transient float prevMS;
	private ui transient Array<DamageNumber> dms;
	private ui transient CVar dmgNumFont;
	private ui transient CVar dmgNumOverkill;
	private ui transient CVar dmgNumDeath;
	private ui transient CVar dmgNumHitTypes;
	
	// Creation behavior
	private transient CVar dmgNumEnabled;
	private transient CVar dmgNumType;
	private transient CVar dmgNumActors;
	private transient CVar dmgNumDmgType;
	private transient Array<DamageInfo> damaged;
	private transient bool bClearNextTick;
	
	// Damage numbers
	override void RenderUnderlay(RenderEvent e)
	{
		double curTime = MSTimeF();
		if (!prevMS)
			prevMS = curTime;
		
		double deltatime = curTime - prevMS;
		if (deltaTime > 200)
			deltaTime = 200;
		
		prevMS = curTime;
		
		double frac = deltaTime / 1000.;
		si.SetScreenInformation((e.viewAngle, e.viewPitch, e.viewRoll), e.viewPos, e.camera.player ? players[consoleplayer].FOV : e.camera.cameraFOV);
		int cx, cy, cw, ch;
		[cx, cy, cw, ch] = Screen.GetClipRect();
		
		Screen.SetClipRect(si.minBoundary.x, si.minBoundary.y, si.maxBoundary.x-si.minBoundary.x, si.maxBoundary.y-si.minBoundary.y);
		for (int i = 0; i < dms.Size(); ++i)
		{
			if (!dms[i])
			{
				dms.Delete(i--);
				continue;
			}
			
			dms[i].Draw(frac, si);
		}
		
		Screen.SetClipRect(cx, cy, cw, ch);
	}
	
	override void UITick()
	{
		if (!bInitialized)
		{
			bInitialized = true;
			
			switch (gameinfo.gametype)
			{
				case GAME_Doom:
					game = "DOOM";
					break;
					
				case GAME_Heretic:
					game = "HERETIC";
					break;
					
				case GAME_Hexen:
					game = "HEXEN";
					break;
					
				case GAME_Chex:
					game = "CHEX";
					break;
					
				case GAME_Strife:
					game = "STRIFE";
					break;
			}
			
			fonts[0] = smallfont;
			fonts[1] = newsmallfont;
			fonts[2] = alternativesmallfont;
			fonts[3] = originalsmallfont;
			fonts[4] = smallfont2;
			fonts[5] = bigfont;
			fonts[6] = originalbigfont;
			fonts[7] = intermissionfont;
			fonts[8] = confont;
			fonts[9] = newconsolefont;
		}
		
		if (!dmgNumOverkill)
			dmgNumOverkill = CVar.GetCVar("damagenumbers_allowoverkill", players[consoleplayer]);
		if (!dmgNumDeath)
			dmgNumDeath = CVar.GetCVar("damagenumbers_allowdeath", players[consoleplayer]);
		if (!dmgNumHitTypes)
			dmgNumHitTypes = CVar.GetCVar("damagenumbers_allowdamagetypes", players[consoleplayer]);
		if (!dmgNumFont)
			dmgNumFont = CVar.GetCVar("damagenumbers_fonttype", players[consoleplayer]);
		
		int fontIndex = clamp(dmgNumFont.GetInt(), 0, 9);
		Font curFont = fonts[fontIndex];
		bool allowdt = dmgNumHitTypes.GetBool();
		for (int i = 0; i < damaged.Size(); ++i)
		{
			if (!damaged[i])
				continue;
			
			string lookUp = EMPTY_STRING;
			string dt = damaged[i].damageType;
			// Look up death translation value
			if (damaged[i].bDied && dmgNumDeath.GetBool())
			{
				lookUp = allowdt ? FindStringValue(String.Format("%s_DEATH_%s", game, dt)) : EMPTY_STRING;
				if (lookUp == EMPTY_STRING)
				{
					lookUp = allowdt ? FindStringValue(String.Format("DEATH_%s", dt)) : EMPTY_STRING;
					if (lookUp == EMPTY_STRING)
					{
						lookUp = FindStringValue(String.Format("%s_DEATH_DEFAULT", game));
						if (lookUp == EMPTY_STRING)
							lookUp = FindStringValue("DEATH_DEFAULT");
					}
				}
			}
			
			// Look up regular translation value
			if (lookUp == EMPTY_STRING)
			{
				lookUp = allowdt ? FindStringValue(String.Format("%s_%s", game, dt)) : EMPTY_STRING;
				if (lookUp == EMPTY_STRING)
				{
					lookUp = allowdt ? FindStringValue(dt) : EMPTY_STRING;
					if (lookUp == EMPTY_STRING)
					{
						lookUp = FindStringValue(String.Format("%s_DEFAULT", game));
						if (lookUp == EMPTY_STRING)
							lookUp = FindStringValue("DEFAULT");
					}
				}
			}
			
			// Clean up the value
			lookUp.Replace("\n", EMPTY_STRING);
			lookUp.Replace("\r", EMPTY_STRING);
			lookUp.Replace("\t", EMPTY_STRING);
			lookUp.Replace(" ", EMPTY_STRING);
			
			int trans = Font.CR_UNDEFINED;
			bool setFont = false;
			int globalTrans = Font.CR_UNDEFINED;
			bool setGlobal = false;
			
			// Parse translations
			// TODO: Good lord, precache these
			Array<string> fontTypes;
			lookUp.Split(fontTypes, ":");
			Array<DamageFontInfo> fontInfos;
			for (int j = 0; j < fontTypes.Size(); ++j)
			{
				Array<string> data;
				fontTypes[j].Split(data, ",");
				uint s = data.Size();
				if (!s)
					continue;
				
				if (s == 1)
				{
					if (setGlobal)
						continue;
					
					setGlobal = true;
					globalTrans = data[0].ToInt();
				}
				else
				{
					let dfi = new("DamageFontInfo");
					dfi.fontIndex = data[0].ToInt();
					dfi.fontTranslation = data[1].ToInt();
					
					fontInfos.Push(dfi);
				}
			}
			
			for (uint j = 0; j < fontInfos.Size(); ++j)
			{
				if (fontInfos[i].fontIndex == fontIndex)
				{
					setFont = true;
					trans = fontInfos[i].fontTranslation;
					break;
				}
			}
			
			if (!setFont && setGlobal)
				trans = globalTrans;
			
			int dmg = damaged[i].damage;
			if (!dmgNumOverkill.GetBool())
				dmg -= damaged[i].overkillDamage;
			
			let dm = new("DamageNumber");
			dm.Initialize(damaged[i].pos, curFont, trans, String.Format("%d", dmg));
			dms.Push(dm);
			
			damaged[i].Destroy();
		}
	}
	
	private ui string FindStringValue(string key)
	{
		string v = StringTable.Localize(String.Format("$%s", key));
		return v == key ? "" : v;
	}
	
	override void WorldTick()
	{
		if (bClearNextTick)
		{
			bClearNextTick = false;
			return;
		}
		
		damaged.Clear();
	}
	
	override void WorldThingDamaged(WorldEvent e)
	{
		if (!e.thing || e.damage <= 0)
			return;
		
		// Check enabled
		if (!dmgNumEnabled)
			dmgNumEnabled = CVar.GetCVar("damagenumbers_enabled", players[consoleplayer]);
		
		if (!dmgNumEnabled.GetBool())
			return;
		
		// Check actor type
		if (!dmgNumActors)
			dmgNumActors = CVar.GetCVar("damagenumbers_actortype", players[consoleplayer]);
		
		int aType = clamp(dmgNumActors.GetInt(), 0, 1);
		if (aType == 0 && !e.thing.bIsMonster)
			return;
		
		// Check damage dealer type
		if (!dmgNumDmgType)
			dmgNumDmgType = CVar.GetCVar("damagenumbers_damagetype", players[consoleplayer]);
		
		int dType = clamp(dmgNumDmgType.GetInt(), 0, 1);
		if (dType == 0 && e.DamageSource != players[consoleplayer].mo)
			return;
		
		if (!dmgNumType)
			dmgNumType = CVar.GetCVar("damagenumbers_type", players[consoleplayer]);
		
		bClearNextTick = true;
		int type = clamp(dmgNumType.GetInt(), 0, 1);
		int i = FindDamageActor(e.thing);
		if (type == 1 || i == -1 || !damaged[i])
		{
			let dmg = new("DamageInfo");
			dmg.mo = e.thing;
			dmg.damage = e.damage;
			dmg.damageType = e.damageType;
			dmg.bDied = e.thing.health <= 0;
			dmg.overkillDamage = dmg.bDied ? abs(e.thing.health) : 0;
			dmg.pos = e.thing.pos + (0,0,(dmg.bDied ? e.thing.default.height : e.thing.height) - e.thing.floorclip);
			
			damaged.Push(dmg);
			
			return;
		}
		
		damaged[i].damage += e.damage;
		damaged[i].damageType = e.damageType;
		if (!damaged[i].bDied && e.thing.health <= 0)
		{
			damaged[i].bDied = true;
			damaged[i].overkillDamage = abs(e.thing.health);
		}
	}
	
	private int FindDamageActor(Actor mo)
	{
		for (int i = 0; i < damaged.Size(); ++i)
		{
			if (!damaged[i])
				continue;
			
			if (damaged[i].mo == mo)
				return i;
		}
		
		return -1;
	}
}