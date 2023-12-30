package hrt.prefab.l3d;

class SpawnSphere extends DtsMesh {
	#if editor
	override function edit(ctx:EditContext) {
		super.edit(ctx);

		addDynFieldsEdit(ctx);
	}

	override function getHideProps():HideProps {
		return {
			icon: "cog",
			name: "SpawnSphere",
			allowChildren: function(s) return false
		};
	}
	#end

	override function getEditorClassName():String {
		return "SpawnSphere";
	}

	static var _ = Library.register("spawnsphere", SpawnSphere);
}
