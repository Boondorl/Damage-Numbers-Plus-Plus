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
		di.pos = di.mo.pos.PlusZ(di.mo.height - di.mo.floorClip);
		di.Update(damage, damageType);

		return di;
	}

	void Update(int dmg, Name dmgType)
	{
		damage += dmg;
		damageType = dmgType;
		if (!bDied && mo.health <= 0)
		{
			bDied = true;
			overkillDamage = abs(mo.health);
		}
	}
}

class DamageFontInfo ui
{
	Font fnt;
	int translation;

	static DamageFontInfo Create(Font fnt, int translation)
	{
		let dfi = new("DamageFontInfo");
		dfi.fnt = fnt;
		dfi.translation = translation;

		return dfi;
	}
}

class DamageFontInfoBucket ui
{
	int defaultTranslation;
	Array<DamageFontInfo> dmgFonts;

	static DamageFontInfoBucket Create(string translations, DamageNumberHandler handler)
	{
		let dfib = new("DamageFontInfoBucket");
		dfib.defaultTranslation = Font.CR_UNTRANSLATED;

		Array<string> fontTypes;
		translations.Split(fontTypes, ":", TOK_SKIPEMPTY);
		foreach (type : fontTypes)
		{
			Array<string> translation;
			type.Split(translation, ",", TOK_SKIPEMPTY);
			int s = translation.Size();
			if (!s)
				continue;
			
			if (s == 1)
			{
				dfib.defaultTranslation = handler.FetchTranslation(translation[0]);
			}
			else
			{
				Font fnt = handler.FetchFont(translation[0]);
				int trans = handler.FetchTranslation(translation[1]);

				int i;
				for (; i < dfib.dmgFonts.Size(); ++i)
				{
					if (dfib.dmgFonts[i].fnt == fnt)
					{
						dfib.dmgFonts[i].translation = trans;
						break;
					}
				}

				if (i >= dfib.dmgFonts.Size())
					dfib.dmgFonts.Push(DamageFontInfo.Create(fnt, trans));
			}
		}

		return dfib;
	}

	int GetFontTranslation(Font fnt)
	{
		int translation;
		int i;
		for (; i < dmgFonts.Size(); ++i)
		{
			if (dmgFonts[i].fnt == fnt)
			{
				translation = dmgFonts[i].translation;
				break;
			}
		}
		
		if (i >= dmgFonts.Size())
			translation = defaultTranslation;

		return translation;
	}
}

class DamageNumberHandler : StaticEventHandler
{
	const MS_TO_S = 1.0 / 1000.0;
	const BASE_RES = 1.0 / 1080.0;

	// General font information
	private ui string game;
	private ui Map<Name, DamageFontInfoBucket> fonts;
	
	// Draw behavior
	private ui DamNumGMProjectionCache sInfo;
	private ui double prevTime;
	private ui Array<DamageNumber> dmgNums;
	private ui Array<DamageInfo> damaged;

	ui int FetchTranslation(string translation)
	{
		int index = Font.FindFontColor(translation);
		return index != Font.CR_UNTRANSLATED ? index : translation.toInt();
	}

	ui Font FetchFont(string fnt)
	{
		Font f = Font.FindFont(fnt);
		if (!f)
			f = BigFont;

		return f;
	}

	override void OnEngineInitialize()
	{
		EventHandler.SendInterfaceEvent(consoleplayer, "InitializeDamagePopups");
	}

	override void InterfaceProcess(ConsoleEvent e)
	{
		if (e.isManual)
			return;

		if (e.name ~== "InitializeDamagePopups")
		{
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

			return;
		}

		Array<String> cmd;
		e.name.Split(cmd, ":", TOK_SKIPEMPTY);
		if (cmd.Size() != 2)
			return;
			
		if (cmd[0] ~== "DamagePopupEvent")
		{
			Actor mo = Actor(GetNetworkEntity(e.Args[0]));
			int i = damagenumbers_type == 1 ? damaged.Size() : FindDamageActor(mo);
			if (i >= damaged.Size())
				damaged.Push(DamageInfo.Create(mo, e.args[1], cmd[1]));
			else
				damaged[i].Update(e.args[1], cmd[1]);
		}
	}

	private ui int FindDamageActor(Actor mo)
	{
		int i;
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
		
		if (!sInfo)
			sInfo = new("DamNumGMProjectionCache");

		sInfo.CalculateMatrices(Screen.GetAspectRatio(), e.camera.player ? e.camera.player.fov : e.camera.cameraFOV,
                                e.viewPos, e.viewAngle, e.viewPitch, e.viewRoll);

		let [x, y, w, h] = Screen.GetViewWindow();
		let [cx, cy, cw, ch] = Screen.GetClipRect();
		Screen.SetClipRect(x, y, w, h);

		double frac = delta * MS_TO_S;
		double scalar = h * BASE_RES;
		for (int i = dmgNums.Size()-1; i >= 0; --i)
		{
			if (!dmgNums[i].Draw(frac, scalar, sInfo))
			{
				dmgNums.Delete(i);
				continue;
			}
		}
		
		Screen.SetClipRect(cx, cy, cw, ch);
	}
	
	override void UITick()
	{
		if (!damaged.Size())
			return;

		Font curFont = FetchFont(damagenumbers_fonttype);
		bool allowDmgTypes = damagenumbers_allowdamagetypes;
		bool dmgNumDeath = damagenumbers_allowdeath;
		bool dmgNumOverkill = damagenumbers_allowoverkill;
		foreach (hit : damaged)
		{
			string lookUp;
			string dmgType = hit.damageType;

			// Look up death translation value
			if (hit.bDied && dmgNumDeath)
			{
				lookUp = allowDmgTypes ? CheckValidKey(game.."_DEATH_"..dmgType) : "";
				if (!lookUp.Length())
				{
					lookUp = allowDmgTypes ? CheckValidKey("DEATH_"..dmgType) : "";
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
				lookUp = allowDmgTypes ? CheckValidKey(game..dmgType) : "";
				if (!lookUp.Length())
				{
					lookUp = allowDmgTypes ? CheckValidKey(dmgType) : "";
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
			
			dmgNums.Push(DamageNumber.Create(hit.pos, curFont, trans, dmg,
										(Actor.AngleToVector(FRandom[DamageNumber](0.0, 360.0), FRandom[DamageNumber](48.0, 80.0)), FRandom[DamageNumber](48.0, 80.0))));
		}

		damaged.Clear();
	}

	private ui string CheckValidKey(string key)
	{
		string localized = "$"..key;
		return StringTable.Localize(localized) == key ? "" : localized;
	}

	private ui int FetchFontTranslation(Name key, Font fnt)
	{
		let fontBucket = fonts.GetIfExists(key);
		if (!fontBucket)
		{
			fontBucket = DamageFontInfoBucket.Create(StringTable.Localize(key), self);
			fonts.Insert(key, fontBucket);
		}

		return fontBucket.GetFontTranslation(fnt);
	}

	// Popup spawning event
	override void WorldThingDamaged(WorldEvent e)
	{
		if (!e.thing || e.damage <= 0)
			return;
		
		// Check enabled
		if (!damagenumbers_enabled)
			return;
		
		// Check actor type
		if (!damagenumbers_actortype && !e.thing.bIsMonster)
			return;
		
		// Check damage dealer type
		if (!damagenumbers_damagetype && e.damageSource != players[consolePlayer].mo)
			return;

		EventHandler.SendInterfaceEvent(consolePlayer, "DamagePopupEvent:"..e.damageType, e.thing.GetNetworkID(), e.damage);
	}
}
