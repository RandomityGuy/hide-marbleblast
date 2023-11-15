package hide.comp;

using hide.tools.Extensions;

import cdb.Data;

class MissionInfoEditor extends Popup {
	var contentModal:Element;
	var form:Element;

	public function new(?parent, ?el, mi:hrt.mis.MissionInfo) {
		super(parent, el);

		contentModal = new Element("<div tabindex='0'>").addClass("content-modal").appendTo(popup);

		new Element("<h2> Mission Info </h2>").appendTo(contentModal);
		new Element("<p id='errorModal'></p>").appendTo(contentModal);

		var fieldDefs = mi.getMissionInfoFields();

		form = new Element('
			<table>
			<tbody style="height: 80vh; overflow-y: scroll; display: block;">
			</tbody>
			</table>
			<p class="buttons" style="display: flex; justify-content: space-evenly;">
				<input class="edit" type="submit" value="Save" id="editBtn" />
				<input type="submit" value="Cancel" id="cancelBtn" />
			</p>').appendTo(contentModal);

		form.find("#cancelBtn").click(function(e) {
			close();
		});
		form.find("#editBtn").click(function(e) {
			mi.toMissionInfo();
			close();
		});

		var tbody = form.find('tbody');

		var haxeTypeToHTMLType = [
			"String" => "text",
			"Int" => "number",
			"Float" => "number",
			"Bool" => "checkbox",
			"MissionInfoGame" => "string"
		];

		var fieldDeps:Map<String, Array<{field:hrt.mis.MissionInfoField, elem:Element}>> = [];

		function propagateFieldDeps(fieldDep:String) {
			mi.exportFields.set(fieldDep, true);
			if (fieldDeps.exists(fieldDep)) {
				for (elem in fieldDeps.get(fieldDep)) {
					elem.field.dependencyFunc() ? elem.elem.show() : elem.elem.hide();
				}
			}
		}

		for (field in fieldDefs) {
			if (field.isSeparator) {
				var elem = new Element('<tr><td></td><td><h3>${field.display}</h3></td><td></td></tr>').appendTo(tbody);
				if (field.dependency != null) {
					if (fieldDeps.exists(field.dependency)) {
						fieldDeps.get(field.dependency).push({field: field, elem: elem});
					} else {
						fieldDeps.set(field.dependency, [{field: field, elem: elem}]);
					}
					field.dependencyFunc() ? elem.show() : elem.hide();
				}
			} else {
				if (!field.serialize) {
					if (field.fieldName == "gameMode") {
						var elem = new Element('
						<tr>
							<td style="width: 5px;"><input type="checkbox" id="exportcheck"/></td>
							<td>Main Game Mode</td>
							<td>
							<select id="gameModeSel">
							<option value="null">none</option>
							<option value="hunt">Hunt</option>
							<option value="GemMadness">Gem Madness</option>
							<option value="quota">Quota</option>
							</select>
							</td>
						</tr>
						<tr>
							<td style="width: 5px;"></td>
							<td>Additional Game Modes</td>
							<td>
							<label>2D</label><input type="checkbox" id="twoD"/><br/>
							<label>Haste</label><input type="checkbox" id="haste"/><br/>
							<label>Consistency</label><input type="checkbox" id="consistency"/><br/>
							<label>Laps</label><input type="checkbox" id="laps"/><br/>
							</td>
						</tr>');
						elem.appendTo(tbody);

						var gameModeSel = elem.find('#gameModeSel');
						var twoD = elem.find('#twoD');
						var haste = elem.find('#haste');
						var consistency = elem.find('#consistency');
						var laps = elem.find('#laps');
						var exportcheck = elem.find('#exportcheck');
						if (mi.exportFields.exists(field.fieldName)) {
							exportcheck.prop('checked', true);
						}
						exportcheck.change((_) -> {
							if (exportcheck.prop('checked')) {
								mi.exportFields.set(field.fieldName, true);
							} else {
								mi.exportFields.remove(field.fieldName);
							}
						});

						if (field.getterFn().toLowerCase().indexOf("2d") >= 0) {
							twoD.prop('checked', true);
						}
						if (field.getterFn().toLowerCase().indexOf("haste") >= 0) {
							haste.prop('checked', true);
						}
						if (field.getterFn().toLowerCase().indexOf("consistency") >= 0) {
							consistency.prop('checked', true);
						}
						if (field.getterFn().toLowerCase().indexOf("laps") >= 0) {
							laps.prop('checked', true);
						}
						gameModeSel.val("null");
						if (field.getterFn().toLowerCase().indexOf("hunt") >= 0) {
							gameModeSel.val("hunt");
						} else if (field.getterFn().toLowerCase().indexOf("gemmadness") >= 0) {
							gameModeSel.val("gemmadness");
						} else if (field.getterFn().toLowerCase().indexOf("quota") >= 0) {
							gameModeSel.val("quota");
						}

						function buildGameModeStr() {
							var mode = gameModeSel.val();
							var list = [mode];
							if (twoD.is(':checked'))
								list.push("2D");
							if (haste.is(':checked'))
								list.push("Haste");
							if (consistency.is(':checked'))
								list.push("Consistency");
							if (laps.is(':checked'))
								list.push("Laps");
							return list.join(" ");
						}

						gameModeSel.change((_) -> {
							field.setterFn(buildGameModeStr());
							exportcheck.prop('checked', true);
							propagateFieldDeps(field.fieldName);
						});
						twoD.change((_) -> {
							field.setterFn(buildGameModeStr());
							propagateFieldDeps(field.fieldName);
						});
						haste.change((_) -> {
							field.setterFn(buildGameModeStr());
							exportcheck.prop('checked', true);
							propagateFieldDeps(field.fieldName);
						});
						consistency.change((_) -> {
							field.setterFn(buildGameModeStr());
							exportcheck.prop('checked', true);
							propagateFieldDeps(field.fieldName);
						});
						laps.change((_) -> {
							field.setterFn(buildGameModeStr());
							exportcheck.prop('checked', true);
							propagateFieldDeps(field.fieldName);
						});

						if (field.dependency != null) {
							if (fieldDeps.exists(field.dependency)) {
								fieldDeps.get(field.dependency).push({field: field, elem: elem});
							} else {
								fieldDeps.set(field.dependency, [{field: field, elem: elem}]);
							}
							field.dependencyFunc() ? elem.show() : elem.hide();
						}
					} else {
						if (field.fieldName == "game") {
							var elem = new Element('
						<tr>
							<td style="width: 5px;"><input type="checkbox" id="exportcheck"/></td>
							<td>Game</td>
							<td>
							<select id="gameSel">
							<option value="gold">Gold</option>
							<option value="ultra">Ultra</option>
							<option value="platinum">Platinum</option>
							<option value="platinumquest">PlatinumQuest</option>
							<option value="custom">Custom</option>
							</select>
							</td>
						</tr>');
							elem.appendTo(tbody);

							var gameSel = elem.find('#gameSel');
							var exportcheck = elem.find('#exportcheck');
							if (mi.exportFields.exists(field.fieldName)) {
								exportcheck.prop('checked', true);
							}
							exportcheck.change((_) -> {
								if (exportcheck.prop('checked')) {
									mi.exportFields.set(field.fieldName, true);
								} else {
									mi.exportFields.remove(field.fieldName);
								}
							});

							if (field.getterFn().toLowerCase().indexOf("ultra") >= 0) {
								gameSel.val("ultra");
							} else if (field.getterFn().toLowerCase().indexOf("platinum") >= 0) {
								gameSel.val("platinum");
							} else if (field.getterFn().toLowerCase().indexOf("platinumquest") >= 0) {
								gameSel.val("platinumquest");
							} else if (field.getterFn().toLowerCase().indexOf("custom") >= 0) {
								gameSel.val("custom");
							}

							gameSel.change((_) -> {
								field.setterFn(gameSel.val());
								exportcheck.prop('checked', true);
								propagateFieldDeps(field.fieldName);
							});
						} else if (field.fieldName == "customRadarRule") {
							var elem = new Element('
							<tr>
								<td style="width: 5px;"><input type="checkbox" id="exportcheck"/></td>
								<td>Custom Radar Rule</td>
								<td>
								<label>Gems</label><input type="checkbox" id="crrgem"/><br/>
								<label>Time Travels</label><input type="checkbox" id="crrtt"/><br/>
								<label>Endpad</label><input type="checkbox" id="crrpad"/><br/>
								<label>Checkpoints</label><input type="checkbox" id="crrcheck"/><br/>
								<label>Cannons</label><input type="checkbox" id="crrcannon"/><br/>
								<label>Powerups</label><input type="checkbox" id="crrpw"/><br/>
								</td>
							</tr>');
							elem.appendTo(tbody);
							var crrgem = elem.find('#crrgem');
							var crrtt = elem.find('#crrtt');
							var crrpad = elem.find('#crrpad');
							var crrcheck = elem.find('#crrcheck');
							var crrcannon = elem.find('#crrcannon');
							var crrpw = elem.find('#crrpw');
							var exportcheck = elem.find('#exportcheck');
							if (mi.exportFields.exists(field.fieldName)) {
								exportcheck.prop('checked', true);
							}
							exportcheck.change((_) -> {
								if (exportcheck.prop('checked')) {
									mi.exportFields.set(field.fieldName, true);
								} else {
									mi.exportFields.remove(field.fieldName);
								}
							});

							if (field.getterFn().indexOf("$Radar") >= 0) {
								// Its a radar rule defined by |
								var ruleValue = field.getterFn().toLowerCase();
								if (ruleValue.indexOf("$radar::flags::gems") >= 0)
									crrgem.prop('checked', true);
								if (ruleValue.indexOf("$radar::flags::timetravels") >= 0)
									crrtt.prop('checked', true);
								if (ruleValue.indexOf("$radar::flags::endpads") >= 0)
									crrpad.prop('checked', true);
								if (ruleValue.indexOf("$radar::flags::checkpoints") >= 0)
									crrcheck.prop('checked', true);
								if (ruleValue.indexOf("$radar::flags::cannons") >= 0)
									crrcannon.prop('checked', true);
								if (ruleValue.indexOf("$radar::flags::powerups") >= 0)
									crrpw.prop('checked', true);
							} else {
								var ruleInt = Std.parseInt(field.getterFn());
								if ((ruleInt & 1) != 0)
									crrgem.prop('checked', true);
								if ((ruleInt & 2) != 0)
									crrtt.prop('checked', true);
								if ((ruleInt & 4) != 0)
									crrpad.prop('checked', true);
								if ((ruleInt & 8) != 0)
									crrcheck.prop('checked', true);
								if ((ruleInt & 16) != 0)
									crrcannon.prop('checked', true);
								if ((ruleInt & 32) != 0)
									crrpw.prop('checked', true);
							}

							function buildRadarRule() {
								var rule = 0;
								if (crrgem.is(':checked'))
									rule |= 1;
								if (crrtt.is(':checked'))
									rule |= 2;
								if (crrpad.is(':checked'))
									rule |= 4;
								if (crrcheck.is(':checked'))
									rule |= 8;
								if (crrcannon.is(':checked'))
									rule |= 16;
								if (crrpw.is(':checked'))
									rule |= 32;
								return '${rule}';
							}
							crrgem.change((_) -> {
								field.setterFn(buildRadarRule());
								exportcheck.prop('checked', true);
								propagateFieldDeps(field.fieldName);
							});
							crrtt.change((_) -> {
								field.setterFn(buildRadarRule());
								exportcheck.prop('checked', true);
								propagateFieldDeps(field.fieldName);
							});
							crrpad.change((_) -> {
								field.setterFn(buildRadarRule());
								exportcheck.prop('checked', true);
								propagateFieldDeps(field.fieldName);
							});
							crrcheck.change((_) -> {
								field.setterFn(buildRadarRule());
								exportcheck.prop('checked', true);
								propagateFieldDeps(field.fieldName);
							});
							crrcannon.change((_) -> {
								field.setterFn(buildRadarRule());
								exportcheck.prop('checked', true);
								propagateFieldDeps(field.fieldName);
							});
							crrpw.change((_) -> {
								field.setterFn(buildRadarRule());
								exportcheck.prop('checked', true);
								propagateFieldDeps(field.fieldName);
							});
						} else if (field.fieldName == "gemGroups") {
							var elem = new Element('
						<tr>
							<td style="width: 5px;"><input type="checkbox" id="exportcheck"/></td>
							<td>Gem Groups</td>
							<td>
							<select id="gemGroupSel">
							<option value="0">No</option>
							<option value="1">Spawn Whole Group</option>
							<option value="2">Random Spawn In Group</option>
							</select>
							</td>
						</tr>');
							elem.appendTo(tbody);

							var ggSel = elem.find('#gemGroupSel');
							var exportcheck = elem.find('#exportcheck');
							if (mi.exportFields.exists(field.fieldName)) {
								exportcheck.prop('checked', true);
							}
							exportcheck.change((_) -> {
								if (exportcheck.prop('checked')) {
									mi.exportFields.set(field.fieldName, true);
								} else {
									mi.exportFields.remove(field.fieldName);
								}
							});

							ggSel.val(field.getterFn());

							ggSel.change((_) -> {
								field.setterFn(ggSel.val());
								exportcheck.prop('checked', true);
								propagateFieldDeps(field.fieldName);
							});

							if (field.dependency != null) {
								if (fieldDeps.exists(field.dependency)) {
									fieldDeps.get(field.dependency).push({field: field, elem: elem});
								} else {
									fieldDeps.set(field.dependency, [{field: field, elem: elem}]);
								}
								field.dependencyFunc() ? elem.show() : elem.hide();
							}
						} else {
							var elem = !field.isBigText ? new Element('
						<tr>
							<td style="width: 5px;"><input type="checkbox" id="exportcheck"/></td>
							<td>${field.display}</td>
							<td><input type="${haxeTypeToHTMLType[field.type]}" id="inpfield"/></td>
						</tr>') : new Element('
						<tr>
							<td style="width: 5px;"><input type="checkbox" id="exportcheck"/></td>
							<td>${field.display}</td>
							<td><textarea></textarea></td>
						</tr>');
							elem.appendTo(tbody);
							var exportcheck = elem.find('#exportcheck');
							if (mi.exportFields.exists(field.fieldName)) {
								exportcheck.prop('checked', true);
							}
							exportcheck.change((_) -> {
								if (exportcheck.prop('checked')) {
									mi.exportFields.set(field.fieldName, true);
								} else {
									mi.exportFields.remove(field.fieldName);
								}
							});

							var inp = field.isBigText ? elem.find('textarea') : elem.find('#inpfield');
							if (field.type == "Bool") {
								inp.change((_) -> {
									field.setterFn(inp.prop('checked'));
									exportcheck.prop('checked', true);
									propagateFieldDeps(field.fieldName);
								});
								inp.prop('checked', field.getterFn());
							} else {
								inp.change((_) -> {
									field.setterFn(inp.val());
									exportcheck.prop('checked', true);
									propagateFieldDeps(field.fieldName);
								});
								inp.val(field.getterFn());
							}

							if (field.dependency != null) {
								if (fieldDeps.exists(field.dependency)) {
									fieldDeps.get(field.dependency).push({field: field, elem: elem});
								} else {
									fieldDeps.set(field.dependency, [{field: field, elem: elem}]);
								}
								field.dependencyFunc() ? elem.show() : elem.hide();
							}
						}
					}
				}
			}
		}
	}
}
