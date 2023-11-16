package hrt.prefab.l3d;

import h3d.Quat;
import h3d.Matrix;
import hrt.mis.MisParser;
import hrt.prefab.props.PropertyProvider;
import hrt.prefab.props.PathNodeAnimator;
import hrt.prefab.props.ParentingAnimator;

using Lambda;

class TorqueObject extends Object3D {
	@:s public var dynamicFields:Array<{field:String, value:String}> = [];

	@:s public var customFields:Array<{field:String, value:String}> = [];

	@:s public var customFieldProvider:String;

	var pna:PathNodeAnimator;
	var pa:ParentingAnimator;

	var renderObject:h3d.scene.Object;

	var propertyProvider:PropertyProvider;

	public function assignPropertyProvider() {
		propertyProvider = PropertyProvider.getPropertyProvider(customFieldProvider, this);
	}

	override function updateInstance(ctx:Context, ?propName:String) {
		super.updateInstance(ctx, propName);
		if (propertyProvider != null)
			propertyProvider.updateInstance(ctx, propName);
	}

	override public function getTransform(?m:h3d.Matrix) {
		if (m == null)
			m = new h3d.Matrix();
		var sx = scaleX;
		var sy = scaleY;
		var sz = scaleZ;
		if (sx == 0)
			sx = 0.0001;
		if (sy == 0)
			sy = 0.0001;
		if (sz == 0)
			sz = 0.0001;
		m.initScale(sx, sy, sz);
		m.rotate(hxd.Math.degToRad(rotationX), hxd.Math.degToRad(rotationY), hxd.Math.degToRad(rotationZ));
		m.translate(x, y, z);
		return m;
	}

	override function applyTransform(o:h3d.scene.Object) {
		o.x = x;
		o.y = y;
		o.z = z;

		var sx = scaleX;
		var sy = scaleY;
		var sz = scaleZ;
		if (sx == 0)
			sx = 0.0001;
		if (sy == 0)
			sy = 0.0001;
		if (sz == 0)
			sz = 0.0001;

		o.scaleX = sx;
		o.scaleY = sy;
		o.scaleZ = sz;
		o.setRotation(hxd.Math.degToRad(rotationX), hxd.Math.degToRad(rotationY), hxd.Math.degToRad(rotationZ));
		if (propertyProvider != null)
			propertyProvider.onTransformApplied();
	}

	public function getEditorClassName() {
		return "TorqueObject";
	}

	public function getCustomFieldValue(f:String) {
		var field = customFields.find(x -> x.field == f);
		if (field == null)
			return ""; // ew lol
		return field.value;
	}

	public function setCustomFieldValue(f:String, value:String) {
		var field = customFields.find(x -> x.field == f);
		if (field == null)
			customFields.push({field: f, value: value});
		else
			field.value = value;
	}

	public function getDynamicFieldValue(f:String) {
		var field = dynamicFields.find(x -> x.field == f);
		if (field == null)
			return ""; // ew lol
		return field.value;
	}

	public function getRenderTransform():Matrix {
		return null; // not impl
	}

	public function buildAnimators(renderObject:h3d.scene.Object, ctx:Context) {
		pna = new PathNodeAnimator(this, ctx);
		pa = new ParentingAnimator(this, ctx);
		this.renderObject = renderObject;
	}

	override function tick(ctx:Context, elapsedTime:Float, dt:Float) {
		super.tick(ctx, elapsedTime, dt);
		if (pna != null || pa != null) {
			pna.updateObjPosition(renderObject, elapsedTime);
			pa.updateTransform(renderObject);
		}
	}

	#if editor
	public override function setSelected(ctx:Context, b:Bool):Bool {
		var r = super.setSelected(ctx, b);
		if (propertyProvider != null)
			propertyProvider.onSelected(b);
		return r;
	}

	function propagatePropertyChanged(ctx:EditContext, p:String) {
		if (propertyProvider != null)
			propertyProvider.onPropertyChanged(ctx, p);
		if (["parent", "parentsimple", "parentoffset", "parentnorot", "parentmodtrans"].contains(p) && pa != null)
			pa.updateProps();
		if (p == "path" && pna != null)
			pna.regeneratePath();
	}

	public function addDynFieldsEdit(ectx:EditContext) {
		var db = customFieldProvider != null ? hrt.mis.TorqueConfig.getDataBlock(customFieldProvider) : null;

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
			${db != null ? '<div class="group" name="${db.name}"><dl id="cvars"></dl>
			</div>' : ""}
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
				propagatePropertyChanged(ectx, v.field);
			});
			def.find("dt").contextmenu(function(e) {
				new hide.comp.ContextMenu([
					{
						label: "Remove",
						click: () -> {
							dynamicFields.remove(v);
							ectx.rebuildProperties();

							ectx.properties.undo.change(Custom(isUndo -> {
								if (isUndo) {
									dynamicFields.push(v);
								} else {
									dynamicFields.remove(v);
								}
								propagatePropertyChanged(ectx, v.field);
							}));
						}
					},
				]);
				return false;
			});
		}
		if (db != null) {
			// add the custom fields we didnt add after loading
			for (f => fieldDef in db.fieldMap) {
				if (customFields.filter(x -> x.field == f).length == 0) {
					customFields.push({field: f, value: fieldDef.defaultValue != null ? Std.string(fieldDef.defaultValue) : ""});
				}
			}

			// build display
			var cvars = props.find("#cvars");
			for (v in customFields) {
				var fieldDef = db.fieldMap[v.field.toLowerCase()];
				var fieldType = torqueToHideFieldType[fieldDef.type];
				switch (fieldType) {
					case "enum":
						{
							var def = new hide.Element('<dt title="${fieldDef.desc != null ? fieldDef.desc : ""}" id="field-${fieldDef.name}">${fieldDef.display}</dt>
						<dd>
							<select field="${fieldDef.name.toLowerCase()}">
							</select>
						</dd>');
							var select = def.find("select");
							for (enumval in fieldDef.typeEnums) {
								var opt = new hide.Element('<option value="${enumval.name}" ${v.value == enumval.name ? "selected" : ""}>${enumval.display}</option>');
								opt.appendTo(select);
							}
							def.on("change", function(e) {
								var oldValue = v.value;
								var newValue = e.target.value;
								v.value = e.target.value;
								if (fieldDef.name == "skin") {
									if (this is DtsMesh) {
										var thisdts = cast(this, DtsMesh);
										thisdts.changeSkin(e.target.value, ectx.getContext(this));
									}
								}
								propagatePropertyChanged(ectx, v.field);

								ectx.properties.undo.change(Custom(isUndo -> {
									v.value = isUndo ? oldValue : newValue;
									if (fieldDef.name == "skin") {
										if (this is DtsMesh) {
											var thisdts = cast(this, DtsMesh);
											thisdts.changeSkin(v.value, ectx.getContext(this));
										}
									}
									propagatePropertyChanged(ectx, v.field);
								}));
							});
							def.appendTo(cvars);
						}
					case "object":
						{
							var def = new hide.Element('<dt title="${fieldDef.desc != null ? fieldDef.desc : ""}" id="field-${fieldDef.name}">${fieldDef.display}</dt>
							<dd>
								<select field="object">
									<option value="">-- Choose --</option>
								</select>
								
							</dd>');

							var select = def.find("select");
							for (path in ectx.getNamedObjects()) {
								var hasDot = path.indexOf(".") != -1;
								var properName = path;
								if (hasDot) {
									var split = path.split(".");
									properName = split[split.length - 1];
								}
								if (properName == "" || properName == "_debugDir" || properName == "__selection")
									continue;
								var opt = new hide.Element("<option>").attr("value", properName.toLowerCase()).html(properName);
								select.append(opt);
							}
							select.val(v.value.toLowerCase());

							def.on("change", function(e) {
								var oldValue = v.value;
								var newValue = e.target.value;
								v.value = e.target.value;
								propagatePropertyChanged(ectx, v.field);

								ectx.properties.undo.change(Custom(isUndo -> {
									v.value = isUndo ? oldValue : newValue;
									select.val(v.value.toLowerCase());
									propagatePropertyChanged(ectx, v.field);
								}));
							});

							def.appendTo(cvars);
						}
					case "Point3F":
						{
							var vecValue = MisParser.parseVector3(v.value);
							var ref = {
								vx: vecValue.x,
								vy: vecValue.y,
								vz: vecValue.z,
							};

							var updateFn = function(_) {
								v.value = '${ref.vx} ${ref.vy} ${ref.vz}';
								propagatePropertyChanged(ectx, v.field);
							};

							var def1 = new hide.Element('
								<div><dt title="${fieldDef.desc != null ? fieldDef.desc : ""}">${fieldDef.display} X</dt><dd><input type="range" min="-100" max="100" value="0" field="vx"/></dd></div>')
								.appendTo(cvars);
							ectx.properties.build(def1, ref, updateFn);
							var def2 = new hide.Element('
								<div><dt title="${fieldDef.desc != null ? fieldDef.desc : ""}">${fieldDef.display} Y</dt><dd><input type="range" min="-100" max="100" value="0" field="vy"/></dd></div>')
								.appendTo(cvars);
							ectx.properties.build(def2, ref, updateFn);
							var def3 = new hide.Element('
								<div><dt title="${fieldDef.desc != null ? fieldDef.desc : ""}">${fieldDef.display} Z</dt><dd><input type="range" min="-100" max="100" value="0" field="vz"/></dd></div>')
								.appendTo(cvars);
							ectx.properties.build(def3, ref, updateFn);
						}
					case "AngAxisF":
						{
							var mat = new Matrix();
							var quat = MisParser.parseRotation(v.value);
							quat.x = -quat.x;
							quat.w = -quat.w;
							quat.toMatrix(mat);
							var rot = mat.getEulerAngles();
							var ref = {
								rx: rot.x * 180.0 / Math.PI,
								ry: rot.y * 180.0 / Math.PI,
								rz: rot.z * 180.0 / Math.PI
							};

							var updateFn = function(_) {
								quat.initRotation(ref.rx * Math.PI / 180.0, ref.ry * Math.PI / 180.0, ref.rz * Math.PI / 180.0);
								quat.x = -quat.x;
								quat.w = -quat.w;
								var angle = 2 * Math.acos(quat.w);
								var s = Math.sqrt(1 - quat.w * quat.w);
								var x, y, z;
								if (s < 0.001) {
									x = quat.x;
									y = quat.y;
									z = quat.z;
								} else {
									x = quat.x / s;
									y = quat.y / s;
									z = quat.z / s;
								}
								angle = (angle * -180.0 / Math.PI) % 360.0;
								v.value = '${x} ${y} ${z} ${angle}';
								propagatePropertyChanged(ectx, v.field);
							}

							var def1 = new hide.Element('
								<div><dt title="${fieldDef.desc != null ? fieldDef.desc : ""}">${fieldDef.display} X</dt><dd><input type="range" min="-180" max="180" value="0" field="rx"/></dd></div>')
								.appendTo(cvars);
							ectx.properties.build(def1, ref, updateFn);
							var def2 = new hide.Element('
								<div><dt title="${fieldDef.desc != null ? fieldDef.desc : ""}">${fieldDef.display} Y</dt><dd><input type="range" min="-180" max="180" value="0" field="ry"/></dd></div>')
								.appendTo(cvars);
							ectx.properties.build(def2, ref, updateFn);
							var def3 = new hide.Element('
								<div><dt title="${fieldDef.desc != null ? fieldDef.desc : ""}">${fieldDef.display} Z</dt><dd><input type="range" min="-180" max="180" value="0" field="rz"/></dd></div>')
								.appendTo(cvars);
							ectx.properties.build(def3, ref, updateFn);
						}
					case "MatrixF":
						var vecValue = MisParser.parseVector3(v.value);
						var mat = new Matrix();

						var rotOff = MisParser.parseNumberList(v.value);
						rotOff = rotOff.slice(3);
						while (rotOff.length < 4)
							rotOff.push(0);

						var quat = new Quat();
						quat.initRotateAxis(rotOff[0], rotOff[1], rotOff[2], -rotOff[3] * Math.PI / 180);
						quat.x = -quat.x;
						quat.w = -quat.w;
						quat.toMatrix(mat);
						var rot = mat.getEulerAngles();

						var ref = {
							vx: vecValue.x,
							vy: vecValue.y,
							vz: vecValue.z,
							rx: rot.x * 180.0 / Math.PI,
							ry: rot.y * 180.0 / Math.PI,
							rz: rot.z * 180.0 / Math.PI
						};

						var updateFn = function(_) {
							quat.initRotation(ref.rx * Math.PI / 180.0, ref.ry * Math.PI / 180.0, ref.rz * Math.PI / 180.0);
							quat.x = -quat.x;
							quat.w = -quat.w;
							var angle = 2 * Math.acos(quat.w);
							var s = Math.sqrt(1 - quat.w * quat.w);
							var x, y, z;
							if (s < 0.001) {
								x = quat.x;
								y = quat.y;
								z = quat.z;
							} else {
								x = quat.x / s;
								y = quat.y / s;
								z = quat.z / s;
							}
							angle = (angle * -180.0 / Math.PI) % 360.0;
							v.value = '${ref.vx} ${ref.vy} ${ref.vz} ${x} ${y} ${z} ${angle}';
							propagatePropertyChanged(ectx, v.field);
						};

						// Position field

						var def1 = new hide.Element('
								<div><dt title="${fieldDef.desc != null ? fieldDef.desc : ""}">${fieldDef.display} X</dt><dd><input type="range" min="-100" max="100" value="0" field="vx"/></dd></div>')
							.appendTo(cvars);
						ectx.properties.build(def1, ref, updateFn);
						var def2 = new hide.Element('
								<div><dt title="${fieldDef.desc != null ? fieldDef.desc : ""}">${fieldDef.display} Y</dt><dd><input type="range" min="-100" max="100" value="0" field="vy"/></dd></div>')
							.appendTo(cvars);
						ectx.properties.build(def2, ref, updateFn);
						var def3 = new hide.Element('
								<div><dt title="${fieldDef.desc != null ? fieldDef.desc : ""}">${fieldDef.display} Z</dt><dd><input type="range" min="-100" max="100" value="0" field="vz"/></dd></div>')
							.appendTo(cvars);
						ectx.properties.build(def3, ref, updateFn);

						// Rotation field

						var def1 = new hide.Element('
								<div><dt title="${fieldDef.desc != null ? fieldDef.desc : ""}">${fieldDef.display} Rotation X</dt><dd><input type="range" min="-180" max="180" value="0" field="rx"/></dd></div>')
							.appendTo(cvars);
						ectx.properties.build(def1, ref, updateFn);
						var def2 = new hide.Element('
								<div><dt title="${fieldDef.desc != null ? fieldDef.desc : ""}">${fieldDef.display} Rotation Y</dt><dd><input type="range" min="-180" max="180" value="0" field="ry"/></dd></div>')
							.appendTo(cvars);
						ectx.properties.build(def2, ref, updateFn);
						var def3 = new hide.Element('
								<div><dt title="${fieldDef.desc != null ? fieldDef.desc : ""}">${fieldDef.display} Rotation Z</dt><dd><input type="range" min="-180" max="180" value="0" field="rz"/></dd></div>')
							.appendTo(cvars);
						ectx.properties.build(def3, ref, updateFn);
					case _:
						{
							var ref = {v: v.value};
							var def = new hide.Element('<div><dt title="${fieldDef.desc != null ? fieldDef.desc : ""}" id="field-${fieldDef.name}">${fieldDef.display}</dt><dd><input type="${fieldType}" field="v"/></dd></div>')
								.appendTo(cvars);
							ectx.properties.build(def, ref, function(_) {
								v.value = Std.string(ref.v);
								propagatePropertyChanged(ectx, v.field);
							});
						}
				}
			}

			if (propertyProvider != null)
				propertyProvider.edit(ectx);
		}
	}
	#end
}
