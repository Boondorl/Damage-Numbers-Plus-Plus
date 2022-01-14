class DamageNumber : Object ui
{
	private int translation;
	private Font f;
	private Vector3 pos;
	private Vector3 vel;
	private string val;
	private double alpha;
	private double lifeTime;
	
	virtual void Initialize(Vector3 p, Font fnt, int fntTrans, string v)
	{
		f = fnt;
		translation = fntTrans;
		pos = p;
		vel = (Actor.AngleToVector(FRandom[DamageNumber](double.epsilon,360), FRandom[DamageNumber](48,80)), FRandom[DamageNumber](48,80));
		val = v;
		alpha = 1;
		lifeTime = 0.75;
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
				p.x -= f.StringWidth(val)*scale.x / 2;
				p.y -= f.GetHeight()*scale.y;
				
				Screen.DrawText(f, translation, p.x, p.y, val, DTA_Alpha, alpha,
								DTA_ScaleX, scale.x, DTA_ScaleY, scale.y);
			}
		}
		
		if (menuactive && !multiplayer)
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

class DamageInfo : Object
{
	Actor mo;
	int damage;
	name damageType;
	Vector3 pos;
	bool bDied;
	int overkillDamage;
}

class DamageFontInfo : Object
{
	int fontIndex;
	int fontTranslation;
}