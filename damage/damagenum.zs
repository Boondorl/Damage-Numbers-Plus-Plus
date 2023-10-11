class DamageNumber ui
{
	private Font fnt;
	private int translation;
	private string number;
	private int width, height;
	private Vector3 pos, vel;
	private double alpha;
	private double lifeTime;

	static DamageNumber Create(Vector3 pos, Font fnt, int translation, int number, Vector3 vel = (0.0, 0.0, 0.0), double alpha = 1.0, double lifeTime = 0.75)
	{
		let dn = new("DamageNumber");
		dn.fnt = fnt;
		dn.translation = translation;
		dn.number = String.Format("%d", number);
		dn.width = dn.fnt.StringWidth(dn.number) / 2;
		dn.height = dn.fnt.GetHeight();

		dn.pos = pos;
		dn.vel = vel;
		dn.alpha = alpha;
		dn.lifeTime = lifeTime;

		return dn;
	}
	
	virtual bool Draw(double t, DScreenInfo info)
	{
		if (!autoMapActive)
		{
			let [p, inView] = info.ConvertPoint(pos);
			if (inView)
			{
				Vector2 scale = (2.0, 2.0 * level.pixelStretch) * info.scale;
				p.x -= width * scale.x;
				p.y -= height * scale.y;
				
				Screen.DrawText(fnt, translation, p.x, p.y, number, DTA_Alpha, alpha,
								DTA_ScaleX, scale.x, DTA_ScaleY, scale.y);
			}
		}
		
		if (menuActive == Menu.On || menuActive == Menu.WaitKey || consoleState != c_up)
			return true;
		
		lifeTime -= t;
		if (lifeTime <= 0.0)
		{
			Destroy();
			return false;
		}
		
		pos += vel * t;
		vel.z -= 384.0 * t;
		if (lifeTime < 0.25)
			alpha -= t * 4.0;

		return true;
	}
}
