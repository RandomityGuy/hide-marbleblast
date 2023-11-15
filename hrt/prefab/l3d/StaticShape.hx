package hrt.prefab.l3d;

class StaticShape extends DtsMesh {
	#if editor
	override function edit(ctx:EditContext) {
		super.edit(ctx);

		addDynFieldsEdit(ctx);
	}

	override function getHideProps():HideProps {
		return {icon: "cog", name: "StaticShape"};
	}
	#end

	override function getEditorClassName():String {
		return "StaticShape";
	}

	static var _ = Library.register("staticshape", StaticShape);
}
