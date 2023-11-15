package hrt.prefab.l3d;

import h3d.Vector;

class Sun extends TorqueObject {
	@:s var directionX:Float;
	@:s var directionY:Float;
	@:s var directionZ:Float;
	@:s var ambient:Int;
	@:s var diffuse:Int;

	var sunlight:hrt.shader.DirLight;

	public function new(?parent) {
		super(parent);
		type = "light";
	}

	override function getEditorClassName():String {
		return "Sun";
	}

	override function makeInstance(ctx:Context):Context {
		ctx = ctx.clone(this);

		var isPbr = Std.isOfType(h3d.mat.MaterialSetup.current, h3d.mat.PbrMaterialSetup);
		if (!isPbr) {
			var ls = cast(ctx.local3d.getScene().lightSystem, h3d.scene.fwd.LightSystem);
			sunlight = new hrt.shader.DirLight(new Vector(directionX, directionY, directionZ), ctx.local3d);
			ctx.local3d = sunlight;

			ls.ambientLight.load(Vector.fromColor(ambient));
			sunlight.color = Vector.fromColor(diffuse);
		}
		ctx.local3d.name = name;

		#if editor
		ctx.custom = hrt.impl.EditorTools.create3DIcon(ctx.local3d, hide.Ide.inst.getHideResPath("icons/PointLight.png"), 0.5, Light);
		#end

		updateInstance(ctx);
		return ctx;
	}

	#if editor
	override function removeInstance(ctx:Context):Bool {
		var icon = Std.downcast(ctx.custom, hrt.impl.EditorTools.EditorIcon);
		if (icon != null) {
			icon.remove();
			ctx.custom = null;
		}
		return super.removeInstance(ctx);
	}
	#end

	override function applyTransform(o:h3d.scene.Object) {
		// super.applyTransform(o); // Disable scaling
		o.x = x;
		o.y = y;
		o.z = z;
		// o.setRotation(hxd.Math.degToRad(rotationX), hxd.Math.degToRad(rotationY), hxd.Math.degToRad(rotationZ));
	}

	override function setSelected(ctx:Context, b:Bool) {
		var sel = ctx.local3d.getObjectByName("__selection");
		if (sel != null)
			sel.visible = b;
		updateInstance(ctx);
		return true;
	}

	override function updateInstance(ctx:Context, ?propName:String) {
		super.updateInstance(ctx, propName);

		sunlight.setDirection(new Vector(directionX, directionY, directionZ));
		sunlight.color.load(Vector.fromColor(diffuse));

		var ls = cast(ctx.local3d.getScene().lightSystem, h3d.scene.fwd.LightSystem);
		ls.ambientLight.load(Vector.fromColor(ambient));

		#if editor
		var debugDir = ctx.local3d.find(c -> if (c.name == "_debugDir") c else null);
		var sel:h3d.scene.Object = null;

		if (debugDir == null) {
			debugDir = new h3d.scene.Object(ctx.local3d);
			debugDir.name = "_debugDir";

			var g = new h3d.scene.Graphics(debugDir);
			g.lineStyle(1, 0xffffff);
			g.moveTo(0, 0, 0);
			g.lineTo(10, 0, 0);
			g.ignoreBounds = true;
			g.ignoreCollide = true;
			g.visible = false;
			g.material.mainPass.setPassName("overlay");
			sel = g;
		} else {
			sel = debugDir.getChildAt(0);
		}

		var icon = Std.downcast(ctx.custom, hrt.impl.EditorTools.EditorIcon);
		if (icon != null) {
			icon.color = h3d.Vector.fromColor(diffuse);

			var ide = hide.Ide.inst;
			icon.texture = ide.getTexture(ide.getHideResPath("icons/DirLight.png"));
		}

		var isSelected = false;
		if (sel != null) {
			isSelected = sel.visible;
			if (debugDir != null)
				debugDir.visible = (isSelected || ctx.shared.editorDisplay);
			sel.name = "__selection";
		}
		#end
	}

	#if editor
	override function edit(ctx:EditContext) {
		super.edit(ctx);

		var group = new hide.Element('
			<div class="group" name="Sun">
				<dl>
					<dt>Color</dt><dd><input type="color" field="diffuse"/></dd>
                    <dt>Ambient</dt><dd><input type="color" field="ambient"/></dd>
                    <dt>Direction X</dt><dd><input type="range" min="-1" max="1" field="directionX"/></dd>
                    <dt>Direction y</dt><dd><input type="range" min="-1" max="1" field="directionY"/></dd>
                    <dt>Direction z</dt><dd><input type="range" min="-1" max="1" field="directionZ"/></dd>
				</dl>
			</div>
		');

		ctx.properties.add(group, this, function(pname) {
			ctx.onChange(this, pname);
		});

		addDynFieldsEdit(ctx);
	}

	override function getHideProps():HideProps {
		return {icon: "sun-o", name: "Sun"};
	}
	#end

	static var _ = Library.register("sun", Sun);
}
