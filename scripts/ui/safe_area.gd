class_name SafeArea
extends RefCounted
## How far full-screen pages keep in from the screen's edges so nothing ends up under a phone's
## rounded corners, notch or home bar: the browser's own safe-area insets where it reports them,
## and never less than a phone-sized margin (more at the bottom in portrait, at the sides in
## landscape). On a computer: just `base`.

## Least margins on a phone, in points (the browser's CSS pixels): the home bar, the corners.
const PORTRAIT_BOTTOM_PT := 34.0
const PORTRAIT_TOP_PT := 12.0
const LANDSCAPE_SIDE_PT := 44.0
const LANDSCAPE_BOTTOM_PT := 22.0


## Margins in the viewport's units: x = left, y = top, z = right, w = bottom.
static func margins(viewport: Viewport, base := 20.0) -> Vector4:
	var size := viewport.get_visible_rect().size
	var phone := OS.has_feature("web_ios") or OS.has_feature("web_android") or OS.has_feature("mobile")
	var portrait := size.y > size.x
	if not phone and not portrait:
		return Vector4(base, base, base, base)
	var inset := Vector4.ZERO  # in points
	var per_point := 1.0
	if OS.has_feature("web"):
		var measured: Variant = JavaScriptBridge.eval("""(function(){var d=document.createElement('div');
			d.style.cssText='position:fixed;top:0;left:0;visibility:hidden;padding:env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left)';
			document.body.appendChild(d);var s=getComputedStyle(d);
			var r=[s.paddingLeft,s.paddingTop,s.paddingRight,s.paddingBottom].map(parseFloat).join(',')+','+window.innerWidth;
			d.remove();return r;})()""", true)
		if measured is String:
			var parts := (measured as String).split(",")
			if parts.size() == 5 and float(parts[4]) > 0.0:
				inset = Vector4(float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3]))
				per_point = size.x / float(parts[4])
	if per_point == 1.0:  # (not measured: a phone is about 390 points across in portrait)
		per_point = size.x / (390.0 if portrait else 844.0)
	if portrait:
		inset.y = maxf(inset.y, PORTRAIT_TOP_PT)
		inset.w = maxf(inset.w, PORTRAIT_BOTTOM_PT)
	else:
		inset.x = maxf(inset.x, LANDSCAPE_SIDE_PT)
		inset.z = maxf(inset.z, LANDSCAPE_SIDE_PT)
		inset.w = maxf(inset.w, LANDSCAPE_BOTTOM_PT)
	return Vector4(base + inset.x * per_point, base + inset.y * per_point, base + inset.z * per_point, base + inset.w * per_point)


## Sets a MarginContainer's four margins from margins().
static func apply(container: MarginContainer, base := 20.0) -> void:
	var m := margins(container.get_viewport(), base)
	container.add_theme_constant_override("margin_left", int(m.x))
	container.add_theme_constant_override("margin_top", int(m.y))
	container.add_theme_constant_override("margin_right", int(m.z))
	container.add_theme_constant_override("margin_bottom", int(m.w))
