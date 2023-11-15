package hrt.prefab.l3d;

import h3d.Quat;
import h3d.Matrix;
import hrt.mis.MisParser;
import hrt.prefab.props.PropertyProvider;

class SimGroup extends Prefab {
	@:s public var dynamicFields:Array<{field:String, value:String}> = [];

	#if editor
	override function edit(ctx:EditContext) {
		super.edit(ctx);

		addDynFieldsEdit(ctx);
	}

	override function getHideProps():HideProps {
		return {icon: "folder", name: "SimGroup"};
	}

	public function addDynFieldsEdit(ectx:EditContext) {
		var torqueToHideFieldType = [
			"string" => "text", "boolean" => "checkbox", "time" => "number", "float" => "number", "Point3F" => "Point3F", "enum" => "enum",
			"object" => "object", "int" => "number", "AngAxisF" => "AngAxisF", "MatrixF" => "MatrixF", "ItemData" => "text"
		];

		var props = new hide.Element('
		<div>
			<div class="group" name="Dynamic Fields">
				<dl id="vars">
				</dl>
				<dl>
					<dt></dt>
					<dd><input type="button" value="Add" id="addvar"/></dd>
				</dl>
			</div>
		</div>
		');
		var evars = props.find("#vars");
		props.find("#addvar").click(function(_) {
			var name = ectx.ide.ask("Variable name");
			if (name == null)
				return;
			ectx.makeChanges(this, function() dynamicFields.push({field: name, value: ""}));
			ectx.rebuildProperties();
		});
		ectx.properties.add(props);
		for (v in dynamicFields) {
			var ref = {v: v.value};
			var def = new hide.Element('<div><dt>${v.field}</dt><dd><input type="text" field="v"/></dd></div>').appendTo(evars);
			ectx.properties.build(def, ref, function(_) {
				v.value = ref.v;
			});
			def.find("dt").contextmenu(function(e) {
				new hide.comp.ContextMenu([
					{label: "Set Default", click: () -> v.value = ref.v},
					{
						label: "Remove",
						click: () -> {
							dynamicFields.remove(v);
							ectx.rebuildProperties();
						}
					},
				]);
				return false;
			});
		}
	}
	#end

	public function getEditorClassName():String {
		return "SimGroup";
	}

	static var _ = Library.register("simgroup", SimGroup);
}
