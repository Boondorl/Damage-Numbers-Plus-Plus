class DamageNumber ui
{
	private int8 translation;
	private Font f;
	private FVector3 pos;
	private FVector3 vel;
	private string val;
	private float alpha;
	private float lifeTime;

	private int8 width;
	
	virtual void Initialize(Vector3 p, Font fnt, int fntTrans, string v)
	{
		f = fnt;
		translation = fntTrans;
		pos = p;
		vel = (Actor.AngleToVector(FRandom[DamageNumber](0,360), FRandom[DamageNumber](48,80)), FRandom[DamageNumber](48,80));
		val = v;
		alpha = 1.0;
		lifeTime = 0.75;

		width = f.StringWidth(val) / 2;
	}
	
	virtual void Draw(double t, DScreenInfo info)
	{
		if (!automapactive)
		{
			Vector2 p;
			bool inView;
			[p, inView] = info.ConvertPoint(pos);
			if (inView)
			{
				Vector2 scale = (2, 2*level.pixelStretch) * info.scale;
				p.x -= width * scale.x;
				p.y -= f.GetHeight() * scale.y;
				
				Screen.DrawText(f, translation, p.x, p.y, val, DTA_Alpha, alpha,
								DTA_ScaleX, scale.x, DTA_ScaleY, scale.y);
			}
		}
		
		if (!multiplayer && (menuActive || consoleState != c_up))
			return;
		
		lifeTime -= t;
		if (lifeTime <= 0)
		{
			Destroy();
			return;
		}
		
		pos += vel*t;
		vel.z -= 384*t;
		if (lifeTime < 0.25)
			alpha -= t*4;
	}
}

class DamageInfo
{
	Actor mo;
	int damage;
	Name damageType;
	FVector3 pos;
	bool bDied;
	int overkillDamage;
}

class DamageFontInfo
{
	int8 fontIndex;
	int8 fontTranslation;
}