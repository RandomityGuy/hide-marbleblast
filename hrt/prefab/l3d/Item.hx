package hrt.prefab.l3d;

class Item extends DtsMesh {
	@:s var collideable:Bool;
	@:s var isStatic:Bool;
	@:s var rotate:Bool;

	#if editor
	override function edit(ctx:EditContext) {
		super.edit(ctx);

		var group = new hide.Element('
			<div class="group" name="Item">
				<dl>
					<dt>Collideable</dt><dd><input type="checkbox" field="collideable"/></dd>
                    <dt>Static</dt><dd><input type="checkbox" field="isStatic"/></dd>
					<dt>Rotate</dt><dd><input type="checkbox" field="rotate"/></dd>
				</dl>
			</div>
		');

		ctx.properties.add(group, this, function(pname) {
			ctx.onChange(this, pname);
		});

		addDynFieldsEdit(ctx);
	}

	override function getHideProps():HideProps {
		return {icon: "puzzle-piece", name: "Item"};
	}
	#end

	override function getEditorClassName():String {
		return "Item";
	}

	override function tick(ctx:hrt.prefab.Context, elapsedTime:Float, dt:Float) {
		if (rotate) {
			var spinAnimation = new h3d.Quat();
			spinAnimation.initRotateAxis(0, 0, -1, elapsedTime * -1 / 6 * Math.PI * 2);
			this.rootObject.setRotationQuat(spinAnimation);
		}
		super.tick(ctx, elapsedTime, dt);
	}

	static var _ = Library.register("item", Item);
}
