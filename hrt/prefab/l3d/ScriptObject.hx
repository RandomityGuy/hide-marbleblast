package hrt.prefab.l3d;

using Lambda;

class ScriptObject extends Prefab {
	@:s var dynamicFields:Array<{field:String, value:String}> = [];

	#if editor
	public function addDynFieldsEdit(ectx:EditContext) {
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

	#if editor
	override function edit(ctx:EditContext) {
		super.edit(ctx);

		addDynFieldsEdit(ctx);
	}

	override function getHideProps():HideProps {
		return {
			icon: "info",
			name: "ScriptObject",
			allowChildren: function(s) return false
		};
	}
	#end

	public function getDynamicFieldValue(f:String) {
		var flwr = f.toLowerCase();
		var field = dynamicFields.find(x -> x.field == flwr);
		if (field == null)
			return null; // ew lol
		return field.value;
	}

	public function setDynamicFieldValue(f:String, value:String) {
		var flwr = f.toLowerCase();
		var field = dynamicFields.find(x -> x.field == flwr);
		if (field == null && value != null)
			dynamicFields.push({field: flwr, value: value});
		else if (field != null && value != null)
			field.value = value;
		else if (field != null && value == null)
			dynamicFields.remove(field);
	}

	static var _ = Library.register("scriptobject", ScriptObject);
}
