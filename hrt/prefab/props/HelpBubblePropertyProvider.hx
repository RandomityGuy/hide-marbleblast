package hrt.prefab.props;

class HelpBubblePropertyProvider extends PropertyProvider {
	var g:h3d.scene.Sphere;

	var selected:Bool = false;

	#if editor
	override function onSelected(s:Bool) {
		selected = s;
		if (g != null)
			g.visible = s;
	}
	#end

	override function updateInstance(ctx:Context, ?propName:String) {
		super.updateInstance(ctx, propName);
		var triggerRadius = Std.parseFloat(obj.getCustomFieldValue('triggerradius'));
		if (g == null) {
			g = new h3d.scene.Sphere(0xFFFF0000, triggerRadius, true, ctx.local3d);
			g.ignoreParentTransform = true;
			g.material.mainPass.setPassName("overlay");
			g.material.mainPass.depth(false, LessEqual);
			g.visible = selected;
			g.ignoreBounds = true;
		}
		g.setPosition(obj.x, obj.y, obj.z);
		g.radius = triggerRadius;
		// drawCannonTrajectory();
	}

	override function onTransformApplied() {
		if (g != null)
			g.setPosition(obj.x, obj.y, obj.z);
	}

	static var _ = PropertyProvider.registerPropertyProvider("HelpBubble", HelpBubblePropertyProvider);
}
