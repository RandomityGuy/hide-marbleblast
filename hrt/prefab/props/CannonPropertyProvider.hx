package hrt.prefab.props;

import h3d.Vector;
import h3d.Matrix;

using Lambda;

class CannonPropertyProvider extends PropertyProvider {
	var g:h3d.scene.Graphics;

	var selected:Bool = false;

	#if editor
	override function onSelected(s:Bool) {
		selected = s;
		if (g != null)
			g.visible = s;
		if (g.visible)
			drawCannonTrajectory();
	}
	#end

	override function updateInstance(ctx:Context, ?propName:String) {
		super.updateInstance(ctx, propName);
		if (g == null) {
			g = new h3d.scene.Graphics(ctx.local3d);
			g.ignoreParentTransform = true;
			g.lineStyle(2, 0xFFFF0000);
			g.material.mainPass.setPassName("overlay");
			g.material.mainPass.depth(false, LessEqual);
			g.ignoreBounds = true;
		}
		// drawCannonTrajectory();
		updateCannonParams(ctx);
	}

	function updateCannonParams(ctx:Context) {
		var rotQuat = ctx.local3d.getRotationQuat();
		rotQuat.x *= -1;
		rotQuat.w *= -1;
		var rotMat = new Matrix();
		rotQuat.toMatrix(rotMat);
		var dir = new Vector(0, 1, 0);
		dir.transform3x3(rotMat);

		var yaw = (Math.atan2(dir.x, dir.y)) * 180 / Math.PI;
		var pitch = (Math.atan2(dir.z, Math.sqrt(dir.x * dir.x + dir.y * dir.y))) * 180 / Math.PI;

		obj.setCustomFieldValue('yaw', '${yaw}');
		obj.setCustomFieldValue('pitch', '${pitch}');
	}

	override function onTransformApplied() {
		drawCannonTrajectory();
	}

	override function onPropertyChanged(ctx:EditContext, p:String) {
		super.onPropertyChanged(ctx, p);
		if (['force'].contains(p)) {
			drawCannonTrajectory();
		}
	}

	function drawCannonTrajectory() {
		if (g == null)
			return;
		var gravity = 20;
		var force = Std.parseFloat(obj.getCustomFieldValue('force'));
		var rotQuat = g.parent.getRotationQuat();
		var rotMat = new Matrix();
		rotQuat.toMatrix(rotMat);
		var dir = new Vector(0, 1, 0);
		dir.transform3x3(rotMat);

		g.clear();

		var vel = dir.multiply(force);
		var gravityDir = new Vector(0, 0, -gravity);

		var startPos = g.parent.getAbsPos().getPosition();

		var timeStep = 0.02;

		for (i in 0...250) {
			var start = startPos.add(vel.multiply(i * timeStep)).add(gravityDir.multiply(0.5 * Math.pow(i * timeStep, 2)));
			var end = startPos.add(vel.multiply((i + 1) * timeStep)).add(gravityDir.multiply(0.5 * Math.pow((i + 1) * timeStep, 2)));
			g.moveTo(start.x, start.y, start.z);
			g.lineTo(end.x, end.y, end.z);
		}
	}

	static var _ = PropertyProvider.registerPropertyProvider("DefaultCannon", CannonPropertyProvider);
	static var _2 = PropertyProvider.registerPropertyProvider("Cannon_Low", CannonPropertyProvider);
	static var _3 = PropertyProvider.registerPropertyProvider("Cannon_Mid", CannonPropertyProvider);
	static var _4 = PropertyProvider.registerPropertyProvider("Cannon_High", CannonPropertyProvider);
	static var _5 = PropertyProvider.registerPropertyProvider("Cannon_Custom", CannonPropertyProvider);
}
