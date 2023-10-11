struct DScreenInfo ui
{
	const STANDARD_RATIO = 4.0 / 3.0;

	Vector3 forward, right, down;
	Vector3 pos;
	double scale;
	
	Vector2 resolution;
	Vector2 origin;
	Vector2 size;
	Vector2 minBoundary, maxBoundary;
	
	void SetScreenInformation(Vector3 angs, Vector3 cam, double fov)
	{
		resolution = (Screen.GetWidth(), Screen.GetHeight());
		double aspect = Screen.GetAspectRatio();
		
		Vector2 screenToNormal = (1.0/resolution.x, 1.0/resolution.y);
		
		let [x, y, w, h] = Screen.GetViewWindow();
		minBoundary = (x, y);
		maxBoundary = (x+w, y+h);
		Vector2 vpOrigin = (x*screenToNormal.x, y*screenToNormal.y);
		
		double s = w / resolution.x;
		size = (s, s);
		origin = vpOrigin - (0.0, 0.5*(s - h*screenToNormal.y));
		
		scale = h / 1080.0;
		
		pos = cam;
		Vector2 fovScale;
		fovScale.x = tan(fov * 0.5) * aspect / STANDARD_RATIO;
		fovScale.y = fovScale.x / aspect;
		
		angs.y = atan2(sin(angs.y)*level.pixelStretch, cos(angs.y));
		
		double ac, as, pc, ps, rc, rs;
		ac = cos(angs.x);
		as = sin(angs.x);
		pc = cos(angs.y);
		ps = sin(angs.y);
		rc = cos(angs.z);
		rs = sin(angs.z);
			
		forward = (ac*pc, as*pc, -ps * level.pixelStretch);
		right = (-1.0*rs*ps*ac + -1.0*rc*-as, -1.0*rs*ps*as + -1.0*rc*ac, -1.0*rs*pc * level.pixelStretch) / fovScale.x;
		down = -(rc*ps*ac + -rs*-as, rc*ps*as + -rs*ac, rc*pc * level.pixelStretch) / fovScale.y;
	}
	
	Vector2, bool ConvertPoint(Vector3 end)
	{
		Vector3 diff = level.Vec3Diff(pos, end);
		
		double depth = diff dot forward;
		if (depth <= 0.0)
			return (0.0, 0.0), false;
			
		Vector2 cam = (diff dot right, diff dot down) / depth;
		Vector2 norm = 0.5 * ((cam.x+1.0)*size.x, (cam.y+1.0)*size.y);
		
		return ((origin.x+norm.x)*resolution.x, (origin.y+norm.y)*resolution.y), true;
	}
}
