package hrt.prefab.l3d;

class TSStatic extends DtsMesh {
	#if editor
	override function edit(ctx:EditContext) {
		super.edit(ctx);

		ctx.properties.add(new hide.Element('<div class="group" name="TSStatic">
			<dl>
				<dt>Shape</dt><dd><input type="fileselect" extensions="dts" field="path" /></dd>
			</dl></div>'), this, function(pname) {
			ctx.onChange(this, pname);

			if (pname == "path") {
				this.dtsPath = path;
				this.path = path;
				var local3d = rootObject.parent.parent;
				this.skin = "";
				for (gnode in graphNodes) {
					rootObject.removeChild(gnode);
				}
				init(local3d, ctx.getContext(this));
			}
		});

		addDynFieldsEdit(ctx);
	}

	override function getHideProps():HideProps {
		return {icon: "cog", name: "TSStatic", fileSource: ["dts"]};
	}
	#end

	override function getEditorClassName():String {
		return "TSStatic";
	}

	static var _ = Library.register("tsstatic", TSStatic);
}
