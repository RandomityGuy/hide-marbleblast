package hrt.prefab.l3d;

import h3d.mat.Material;

class Trigger extends TorqueObject {
	@:s var origin:{x:Float, y:Float, z:Float} = {x: 0, y: 0, z: 0};
	@:s var e1:{x:Float, y:Float, z:Float} = {x: 1, y: 0, z: 0};
	@:s var e2:{x:Float, y:Float, z:Float} = {x: 0, y: 1, z: 0};
	@:s var e3:{x:Float, y:Float, z:Float} = {x: 0, y: 0, z: 1};

	var ctxObject:h3d.scene.Object;
	var g:h3d.scene.Graphics;

	override function getEditorClassName():String {
		return "Trigger";
	}

	override function makeInstance(ctx:Context):Context {
		ctx = ctx.clone(this);

		var mat = Material.create();
		mat.mainPass.wireframe = true;

		ctxObject = new h3d.scene.Object(ctx.local3d);

		g = new h3d.scene.Graphics(ctxObject);
		g.lineStyle(2, 0xFF00FF);
		g.moveTo(origin.x, origin.y, origin.z);
		g.lineTo(origin.x + e1.x, origin.y + e1.y, origin.z + e1.z);
		g.lineTo(origin.x + e1.x + e2.x, origin.y + e1.y + e2.y, origin.z + e1.z + e2.z);
		g.lineTo(origin.x + e2.x, origin.y + e2.y, origin.z + e2.z);
		g.lineTo(origin.x, origin.y, origin.z);
		g.moveTo(origin.x + e3.x, origin.y + e3.y, origin.z + e3.z);
		g.lineTo(origin.x + e1.x + e3.x, origin.y + e1.y + e3.y, origin.z + e1.z + e3.z);
		g.lineTo(origin.x + e1.x + e2.x + e3.x, origin.y + e1.y + e2.y + e3.y, origin.z + e1.z + e2.z + e3.z);
		g.lineTo(origin.x + e2.x + e3.x, origin.y + e2.y + e3.y, origin.z + e2.z + e3.z);
		g.lineTo(origin.x + e3.x, origin.y + e3.y, origin.z + e3.z);
		g.moveTo(origin.x, origin.y, origin.z);
		g.lineTo(origin.x + e3.x, origin.y + e3.y, origin.z + e3.z);
		g.moveTo(origin.x + e1.x, origin.y + e1.y, origin.z + e1.z);
		g.lineTo(origin.x + e1.x + e3.x, origin.y + e1.y + e3.y, origin.z + e1.z + e3.z);
		g.moveTo(origin.x + e1.x + e2.x, origin.y + e1.y + e2.y, origin.z + e1.z + e2.z);
		g.lineTo(origin.x + e1.x + e2.x + e3.x, origin.y + e1.y + e2.y + e3.y, origin.z + e1.z + e2.z + e3.z);
		g.moveTo(origin.x + e2.x, origin.y + e2.y, origin.z + e2.z);
		g.lineTo(origin.x + e2.x + e3.x, origin.y + e2.y + e3.y, origin.z + e2.z + e3.z);

		buildAnimators(g, ctx);

		ctx.local3d = ctxObject;
		ctx.local3d.name = name;
		assignPropertyProvider();
		updateInstance(ctx);
		return ctx;
	}

	#if editor
	override function edit(ctx:EditContext) {
		super.edit(ctx);

		addDynFieldsEdit(ctx);
	}

	override function getHideProps():HideProps {
		return {icon: "square-o", name: "Trigger"};
	}
	#end

	override function getRenderTransform() {
		return g.getAbsPos();
	}

	static var _ = Library.register("trigger", Trigger);
}
