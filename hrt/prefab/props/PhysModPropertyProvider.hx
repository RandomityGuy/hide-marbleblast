package hrt.prefab.props;

import hrt.mis.MisParser;

class PhysModPropertyProvider extends PropertyProvider {
	static var marbleAttributeData = [
		{
			name: "maxRollVelocity",
			display: "Max Roll Velocity",
			def: "15",
			megaDef: "12",
			tooltip: "How fast you can roll forwards without diagonal or jumping."
		},
		{
			name: "angularAcceleration",
			display: "Angular Acceleration",
			def: "75",
			megaDef: "60",
			tooltip: "How quickly the you speed up when you roll forwards."
		},
		{
			name: "brakingAcceleration",
			display: "Braking Acceleration",
			def: "30",
			megaDef: "25",
			tooltip: "How quickly the you slow down when you roll backwards while moving forwards."
		},
		{
			name: "airAcceleration",
			display: "Air Acceleration",
			def: "5",
			megaDef: "5",
			tooltip: "How much moving while airborne (and not touching a wall) will affect your velocity."
		},
		{
			name: "gravity",
			display: "Gravity",
			def: "20",
			megaDef: "22",
			tooltip: "How quickly you speed up when falling.\nNegative would mean you fall upwards, zero means you float forever."
		},
		{
			name: "staticFriction",
			display: "Static Friction",
			def: "1.1",
			megaDef: "1.0",
			tooltip: "How much skidding will slow you down."
		},
		{
			name: "kineticFriction",
			display: "Kinetic Friction",
			def: "0.7",
			megaDef: "0.8",
			tooltip: "How much rolling will slow you down."
		},
		{
			name: "bounceKineticFriction",
			display: "Bounce Kinetic Friction",
			def: "0.2",
			megaDef: "0.3",
			tooltip: "How much your spin affects the way you bounce."
		},
		{
			name: "maxDotSlide",
			display: "Max Dot Slide",
			def: "0.5",
			megaDef: "0.3",
			tooltip: "How high of an angle from which you can hit the ground and slide.\n1 means you can stick to the ground and slide from falling directly downwards."
		},
		{
			name: "bounceRestitution",
			display: "Bounce Restitution",
			def: "0.5",
			megaDef: "0.5",
			tooltip: "How much higher you will go after bouncing. Less than 1 means you'll bounce less high.\n1 means you'll bounce forever at the same height, and greater than 1 means you bounce higher every time."
		},
		{
			name: "jumpImpulse",
			display: "Jump Impulse",
			def: "7.5",
			megaDef: "7.5",
			tooltip: "How strong your jumps are; your velocity after jumping will be at least this much."
		},
		{
			name: "maxForceRadius",
			display: "Max Force Radius",
			def: "50",
			megaDef: "75",
			tooltip: "From how far you are affected by fans and tornadoes."
		},
		{
			name: "minBounceVel",
			display: "Minimum Bounce Velocity",
			def: "0.1",
			megaDef: "0.1",
			tooltip: "You'll bounce only if you hit the ground going faster than this."
		},
		{
			name: "mass",
			display: "Mass",
			def: "1",
			megaDef: "1",
			tooltip: "How much less fans and tornadoes (and other hazards) will affect you.\nHigher means your marble is \"heavier\" so they don't affect you as much."
		},
		{
			name: "powerUpTime[3]",
			display: "Super Bounce Duration",
			def: "5000",
			megaDef: "5000",
			tooltip: "How long the Super Bounce powerup will last."
		},
		{
			name: "powerUpTime[4]",
			display: "Shock Absorber Duration",
			def: "5000",
			megaDef: "5000",
			tooltip: "How long the Shock Absorber powerup will last."
		},
		{
			name: "powerUpTime[5]",
			display: "Helicopter Duration",
			def: "5000",
			megaDef: "5000",
			tooltip: "How long the Gyrocopter powerup will last."
		},
		{
			name: "cameraSpeedMultiplier",
			display: "Camera Speed Multiplier",
			def: "1",
			megaDef: "1",
			tooltip: "Multiplies how fast your camera moves by default.\n1 for regular camera, 0 to disable camera movement, -1 to make the camera backwards."
		},
		{
			name: "movementSpeedMultiplier",
			display: "Movement Speed Multiplier",
			def: "1",
			megaDef: "1",
			tooltip: "Multiplies how fast your marble moves when you roll."
		},
		{
			name: "timeScale",
			display: "Time Scale",
			def: "1",
			megaDef: "1",
			tooltip: "Multiplies the speed at which the game is running.\n0.5 would be half-speed slow motion, and 2 would be double speed."
		},
		{
			name: "superJumpVelocity",
			display: "Super Jump Velocity",
			def: "20",
			megaDef: "20",
			tooltip: "Applied velocity when using a Super Jump."
		},
		{
			name: "superSpeedVelocity",
			display: "Super Speed Velocity",
			def: "25",
			megaDef: "25",
			tooltip: "Applied velocity when using a Super Speed."
		},
		{
			name: "superBounceRestitution",
			display: "Super Bounce Restitution",
			def: "0.9",
			megaDef: "0.9",
			tooltip: "When using a Super Bounce, restitution is set to this."
		},
		{
			name: "shockAbsorberRestitution",
			display: "Shock Absorber Restitution",
			def: "0.01",
			megaDef: "0.01",
			tooltip: "When using a Shock Absorber, restitution is set to this."
		},
		{
			name: "helicopterGravityMultiplier",
			display: "Gyrocopter Gravity Multiplier",
			def: "0.25",
			megaDef: "0.25",
			tooltip: "When using a Gyrocopter, Gravity will be multiplied by this factor."
		},
		{
			name: "helicopterAirAccelerationMultiplier",
			display: "Gyrocopter Air Acceleration Multiplier",
			def: "2",
			megaDef: "2",
			tooltip: "When using a Gyrocopter, Air Acceleration will be multiplied by this factor."
		}
	];

	override function edit(ctx:EditContext) {
		super.edit(ctx);

		// find <div class="group" name="Dynamic Fields">
		var insertPosition = ctx.properties.element.find('div[name = "Dynamic Fields"]');

		var fieldList = new hide.Element('
        <div class="group" name="PhysMod">
			<span>Attribute | Value | Mega Value</span>
			<dl id="pmvars">
			</dl>
		</div>');
		fieldList.insertBefore(insertPosition);
		var pmvars = fieldList.find('#pmvars');

		var definedAttribMap = new Map();
		for (field in obj.dynamicFields) {
			if (StringTools.startsWith(field.field, "marbleattribute")) {
				var fieldIndex = Std.parseInt(field.field.substring("marbleattribute".length));
				definedAttribMap.set(field.value, {
					value: obj.getDynamicFieldValue('value${fieldIndex}'),
					megaValue: obj.getDynamicFieldValue('megavalue${fieldIndex}'),
				});
			}
		}

		function exportToObj() {
			// Remove all dyn fields related to marbleattrib
			obj.dynamicFields = obj.dynamicFields.filter(field -> {
				return !StringTools.startsWith(field.field, "marbleattribute")
					&& !StringTools.startsWith(field.field, "value")
					&& !StringTools.startsWith(field.field, "megavalue");
			});
			// Add the fields properly
			var i = 0;
			for (attribName => attribData in definedAttribMap) {
				obj.dynamicFields.push({field: 'marbleattribute${i}', value: attribName});
				obj.dynamicFields.push({field: 'value${i}', value: attribData.value});
				obj.dynamicFields.push({field: 'megavalue${i}', value: attribData.megaValue});
				i++;
			}
		}

		var makeAddFieldFn = null;
		var makeEditFieldFn = null;

		var makeEditFieldFn = (dd, marbleAttrib:{
			name:String,
			display:String,
			def:String,
			megaDef:String
		}) -> {
			var editFields = new hide.Element('
				<input type="number" style="width:59px" />');
			editFields.appendTo(dd);
			var editFields2 = new hide.Element('
				<input type="number" style="width:59px" />');
			editFields2.appendTo(dd);
			var removeField = new hide.Element('<input type="button" value="X" style="width:30px"></input>');
			removeField.appendTo(dd);

			var removeFunc = () -> {
				editFields.remove();
				editFields2.remove();
				removeField.remove();
				definedAttribMap.remove(marbleAttrib.name);
				makeAddFieldFn(dd, marbleAttrib);
				exportToObj();
			}

			removeField.click((_) -> removeFunc());

			editFields.val(MisParser.parseNumber(definedAttribMap.get(marbleAttrib.name).value));
			editFields2.val(MisParser.parseNumber(definedAttribMap.get(marbleAttrib.name).megaValue));

			editFields.change((e) -> {
				var oldValue = definedAttribMap.get(marbleAttrib.name).value;
				var newValue = '${editFields.val()}';
				definedAttribMap.get(marbleAttrib.name).value = '${editFields.val()}';
				exportToObj();

				ctx.properties.undo.change(Custom(isUndo -> {
					definedAttribMap.get(marbleAttrib.name).value = isUndo ? oldValue : newValue;
					editFields.val(MisParser.parseNumber(definedAttribMap.get(marbleAttrib.name).value));
					exportToObj();
				}));
			});
			editFields2.change((e) -> {
				var oldValue = definedAttribMap.get(marbleAttrib.name).value;
				var newValue = '${editFields2.val()}';
				definedAttribMap.get(marbleAttrib.name).megaValue = '${editFields2.val()}';
				exportToObj();

				ctx.properties.undo.change(Custom(isUndo -> {
					definedAttribMap.get(marbleAttrib.name).megaValue = isUndo ? oldValue : newValue;
					editFields2.val(MisParser.parseNumber(definedAttribMap.get(marbleAttrib.name).megaValue));
					exportToObj();
				}));
			});

			return removeFunc;
		}

		makeAddFieldFn = (dd, marbleAttrib:{
			name:String,
			display:String,
			def:String,
			megaDef:String,
		}) -> {
			var addbtn = new hide.Element('<input type="button" value="+"></input>');
			addbtn.appendTo(dd);
			addbtn.click((_) -> {
				addbtn.remove();
				definedAttribMap.set(marbleAttrib.name, {value: marbleAttrib.def, megaValue: marbleAttrib.megaDef});
				makeEditFieldFn(dd, marbleAttrib);
				exportToObj();
			});
		}

		for (marbleAttrib in marbleAttributeData) {
			var def = new hide.Element('<div><dt id="field-${marbleAttrib.name}" title="${marbleAttrib.tooltip}">${marbleAttrib.display}</dt><dd></dd></div>')
				.appendTo(pmvars);
			var dd = def.find("dd");
			if (definedAttribMap.exists(marbleAttrib.name)) {
				makeEditFieldFn(dd, marbleAttrib);
			} else {
				makeAddFieldFn(dd, marbleAttrib);
			}
		}

		ctx.properties.add(fieldList);
	}

	static var _ = PropertyProvider.registerPropertyProvider("MarblePhysModTrigger", PhysModPropertyProvider);
}
