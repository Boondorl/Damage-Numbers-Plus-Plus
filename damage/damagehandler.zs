class DamageInfo ui
{
	Actor mo;
	int damage;
	Name damageType;
	Vector3 pos;
	bool bDied;
	int overkillDamage;

	static DamageInfo Create(Actor mo, int damage, Name damageType)
	{
		let di = new("DamageInfo");
		di.mo = mo;
		di.damage = damage;
		di.damageType = damageType;
		di.bDied = di.mo.bKilled;
		di.overkillDamage = di.bDied ? abs(di.mo.health) : 0;
		di.pos = di.mo.pos.PlusZ((di.bDied ? di.mo.default.height : di.mo.height) - di.mo.floorClip);

		return di;
	}

	void Update(int dmg, Name dmgType)
	{
		damage += dmg;
		damageType = dmgType;
		if (!bDied && mo.bKilled)
		{
			bDied = true;
			overkillDamage = abs(mo.health);
		}
	}
}

class DamageFontInfo ui
{
	Font fnt;
	int8 translation;
	bool bGlobal;

	static DamageFontInfo Create(Font fnt, int translation, bool bGlobal = false)
	{
		let dfi = new("DamageFontInfo");
		dfi.fnt = fnt;
		dfi.translation = translation;
		dfi.bGlobal = bGlobal;

		return dfi;
	}
}

class DamageFontInfoBucket ui
{
	Array<DamageFontInfo> dmgFonts;
}

class DamageNumberHandler : StaticEventHandler
{
	const EMPTY_STRING = "";
	const MS_TO_S = 1.0 / 1000.0;

	// General font information
	private ui bool bInitialized;
	private ui string game;
	private ui Map<Name, DamageFontInfoBucket> fonts;
	private ui Font globalFonts[10];
	
	// Draw behavior
	private ui DScreenInfo sInfo;
	private ui double prevTime;
	private ui Array<DamageNumber> dmgNums;
	private ui Array<DamageInfo> damaged;

	// For passing damaged Actor information
	private Actor currentlyDamaging;
	private Name currentDamageType;

	override void InterfaceProcess(ConsoleEvent e)
	{
		if (!e.isManual && e.name ~== "DamagePopupEvent")
		{
			int type = clamp(CVar.GetCVar("damagenumbers_type", players[consolePlayer]).GetInt(), 0, 1);
			int i = FindDamageActor(currentlyDamaging);
			if (type == 1 || i >= damaged.Size())
				damaged.Push(DamageInfo.Create(currentlyDamaging, e.args[0], currentDamageType));
			else
				damaged[i].Update(e.args[0], currentDamageType);
		}
	}

	private ui int FindDamageActor(Actor mo)
	{
		int i = 0;
		for (; i < damaged.Size(); ++i)
		{
			if (damaged[i].mo == mo)
				break;
		}
		
		return i;
	}
	
	// Damage numbers
	override void RenderUnderlay(RenderEvent e)
	{
		double curTime = MSTimeF();
		if (!prevTime)
			prevTime = curTime;
		
		double delta = curTime - prevTime;
		if (delta > 200.0)
			delta = 200.0;
		
		prevTime = curTime;
		
		double frac = delta * MS_TO_S;
		sInfo.SetScreenInformation((e.viewAngle, e.viewPitch, e.viewRoll), e.viewPos, e.camera.player ? players[consolePlayer].FOV : e.camera.cameraFOV);

		let [cx, cy, cw, ch] = Screen.GetClipRect();
		Screen.SetClipRect(int(sInfo.minBoundary.x), int(sInfo.minBoundary.y),
							int(sInfo.maxBoundary.x-sInfo.minBoundary.x), int(sInfo.maxBoundary.y-sInfo.minBoundary.y));

		for (int i = dmgNums.Size()-1; i >= 0; --i)
		{
			if (!dmgNums[i].Draw(frac, sInfo))
			{
				dmgNums.Delete(i);
				continue;
			}
		}
		
		Screen.SetClipRect(cx, cy, cw, ch);
	}
	
	override void UITick()
	{
		if (!bInitialized)
		{
			bInitialized = true;

			switch (gameInfo.gameType)
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

			// These can't work in a static const array since the variables themselves aren't marked constant...
			globalFonts[0] = smallFont;
			globalFonts[1] = newSmallFont;
			globalFonts[2] = alternativeSmallFont;
			globalFonts[3] = originalSmallFont;
			globalFonts[4] = smallFont2;
			globalFonts[5] = bigFont;
			globalFonts[6] = originalBigFont;
			globalFonts[7] = intermissionFont;
			globalFonts[8] = conFont;
			globalFonts[9] = newConsoleFont;
		}

		if (!damaged.Size())
			return;

		Font curFont = FetchFont(CVar.GetCVar("damagenumbers_fonttype", players[consolePlayer]).GetString());
		bool allowDmgTypes = CVar.GetCVar("damagenumbers_allowdamagetypes", players[consolePlayer]).GetBool();
		bool dmgNumDeath = CVar.GetCVar("damagenumbers_allowdeath", players[consolePlayer]).GetBool();
		bool dmgNumOverkill = CVar.GetCVar("damagenumbers_allowoverkill", players[consolePlayer]).GetBool();
		foreach (hit : damaged)
		{
			string lookUp = EMPTY_STRING;
			string dmgType = hit.damageType;

			// Look up death translation value
			if (hit.bDied && dmgNumDeath)
			{
				lookUp = allowDmgTypes ? CheckValidKey(game.."_DEATH_"..dmgType) : EMPTY_STRING;
				if (!lookUp.Length())
				{
					lookUp = allowDmgTypes ? CheckValidKey("DEATH_"..dmgType) : EMPTY_STRING;
					if (!lookUp.Length())
					{
						lookUp = CheckValidKey(game.."_DEATH_DEFAULT");
						if (!lookUp.Length())
							lookUp = CheckValidKey("DEATH_DEFAULT");
					}
				}
			}
			
			// Look up regular translation value
			if (!lookUp.Length())
			{
				lookUp = allowDmgTypes ? CheckValidKey(game..dmgType) : EMPTY_STRING;
				if (!lookUp.Length())
				{
					lookUp = allowDmgTypes ? CheckValidKey(dmgType) : EMPTY_STRING;
					if (!lookUp.Length())
					{
						lookUp = CheckValidKey(game.."_DEFAULT");
						if (!lookUp.Length())
							lookUp = CheckValidKey("DEFAULT");
					}
				}
			}

			int trans = FetchFontTranslation(lookUp, curFont);
			int dmg = hit.damage;
			if (!dmgNumOverkill)
				dmg -= hit.overkillDamage;
			
			dmgNums.Push(DamageNumber.Create(hit.pos, curFont, trans, String.Format("%d", dmg),
										(Actor.AngleToVector(FRandom[DamageNumber](0.0, 360.0), FRandom[DamageNumber](48.0, 80.0)), FRandom[DamageNumber](48.0, 80.0))));
		}

		damaged.Clear();
	}

	private ui string CheckValidKey(string key)
	{
		string localized = "$"..key;
		return StringTable.Localize(localized) == key ? EMPTY_STRING : localized;
	}

	private ui int FetchFontTranslation(Name key, Font curFont)
	{
		let fontBucket = fonts.GetIfExists(key);
		if (!fontBucket)
		{
			fontBucket = new("DamageFontInfoBucket");
			string translations = StringTable.Localize(key);
		
			bool setGlobal;
			Array<string> fontTypes;
			translations.Split(fontTypes, ":");
			foreach (type : fontTypes)
			{
				Array<string> translation;
				type.Split(translation, ",");
				int s = translation.Size();
				if (!s)
					continue;
				
				if (s == 1)
				{
					if (setGlobal)
						continue;
					
					setGlobal = true;
					fontBucket.dmgFonts.Insert(0, DamageFontInfo.Create(null, translation[0].ToInt(), true));
				}
				else
				{
					fontBucket.dmgFonts.Push(DamageFontInfo.Create(FetchFont(translation[0]), translation[1].ToInt()));
				}
			}

			fonts.Insert(key, fontBucket);
		}
		
		bool setFont;
		int trans;
		foreach (fInfo : fontBucket.dmgFonts)
		{
			if (fInfo.fnt == curFont)
			{
				setFont = true;
				trans = fInfo.translation;
				break;
			}
		}
		
		if (!setFont && fontBucket.dmgFonts[0].bGlobal)
			trans = fontBucket.dmgFonts[0].translation;

		return trans;
	}

	private ui Font FetchFont(string fnt)
	{
		Font f = Font.FindFont(fnt);
		if (!f)
			f = globalFonts[clamp(fnt.ToInt(), 0, globalFonts.Size()-1)];

		return f;
	}

	// Popup spawning event
	override void WorldThingDamaged(WorldEvent e)
	{
		if (!e.thing || e.damage <= 0)
			return;
		
		// Check enabled
		if (!CVar.GetCVar("damagenumbers_enabled", players[consolePlayer]).GetBool())
			return;
		
		// Check actor type
		int aType = clamp(CVar.GetCVar("damagenumbers_actortype", players[consolePlayer]).GetInt(), 0, 1);
		if (aType == 0 && !e.thing.bIsMonster)
			return;
		
		// Check damage dealer type
		int dType = clamp(CVar.GetCVar("damagenumbers_damagetype", players[consolePlayer]).GetInt(), 0, 1);
		if (dType == 0 && e.damageSource != players[consolePlayer].mo)
			return;

		currentlyDamaging = e.thing;
		currentDamageType = e.damageType;
		EventHandler.SendInterfaceEvent(consolePlayer, "DamagePopupEvent", e.damage);
		currentlyDamaging = null;
		currentDamageType = 'None';
	}
}