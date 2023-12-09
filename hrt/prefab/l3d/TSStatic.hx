package hrt.prefab.l3d;

import hrt.dts.DtsFile;

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
				dts = new DtsFile();
				dts.read(path);
				this.dtsPath = path;
				this.path = path;
				var local3d = ctxObject.parent;
				this.skin = "";
				for (gnode in graphNodes) {
					rootObject.removeChild(gnode);
				}
				for (insts in meshInstances)
					insts.remove();
				init(local3d, ctx.getContext(this));
				updateInteractiveMesh(ctx.getContext(this));
			}
		});

		addDynFieldsEdit(ctx);
	}

	override function getHideProps():HideProps {
		return {
			icon: "cog",
			name: "TSStatic",
			fileSource: ["dts"],
			allowChildren: function(s) return false
		};
	}
	#end

	override function getEditorClassName():String {
		return "TSStatic";
	}

	static var _ = Library.register("tsstatic", TSStatic, "dts");
}
