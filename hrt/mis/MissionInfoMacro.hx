package hrt.mis;

import haxe.macro.Context;

class MissionInfoMacro {
	#if macro
	public static function buildMissionInfo() {
		var fields = Context.getBuildFields();

		var fieldDefBlocks = [];
		var loadStmts = [];
		var saveStmts = [];

		for (field in fields) {
			if (field.meta.length > 0 && field.meta[0].name == ':missionInfoProperty') {
				switch (field.kind) {
					case FVar(TPath({
						name: "Int",
					}), _):
						loadStmts.push(macro {
							var fval = mi.getDynamicFieldValue($v{field.name.toLowerCase()});
							if (fval != null) {
								$i{field.name} = cast hrt.mis.MisParser.parseNumber(fval);
								exportFields.set($v{field.name}, true);
							}
						});

					case FVar(TPath({
						name: "Float",
					}), _):
						loadStmts.push(macro {
							var fval = mi.getDynamicFieldValue($v{field.name.toLowerCase()});
							if (fval != null) {
								$i{field.name} = hrt.mis.MisParser.parseNumber(fval);
								exportFields.set($v{field.name}, true);
							}
						});

					case FVar(TPath({
						name: "String",
					}), _):
						loadStmts.push(macro {
							var fval = mi.getDynamicFieldValue($v{field.name.toLowerCase()});
							if (fval != null) {
								$i{field.name} = fval;
								exportFields.set($v{field.name}, true);
							} else {
								$i{field.name} = "";
							}
						});

					case FVar(TPath({
						name: "Bool",
					}), _):
						loadStmts.push(macro {
							var fval = mi.getDynamicFieldValue($v{field.name.toLowerCase()});
							if (fval != null) {
								$i{field.name} = fval == "1" ? true : false;
								exportFields.set($v{field.name}, true);
							}
						});
					case _:
						{}
				};
				saveStmts.push(macro {
					if (exportFields.exists($v{field.name}))
						mi.setDynamicFieldValue($v{field.name.toLowerCase()}, Std.string($i{field.name}));
					else
						mi.setDynamicFieldValue($v{field.name.toLowerCase()}, null);
				});

				var fieldDefExprs = [];

				fieldDefExprs.push(macro {fieldData.fieldName = $v{field.name};});
				var hasDep = false;
				var depField = null;
				var depFieldVal = null;
				var depFieldVal2 = null;
				var depContains = false;
				var depInverse = false;
				for (param in field.meta[0].params) {
					switch (param.expr) {
						case EConst(CString(disp)):
							fieldDefExprs.push(macro {fieldData.display = $v{disp};});

						case EConst(CIdent("serialize")):
							fieldDefExprs.push(macro {fieldData.serialize = true;});

						case EConst(CIdent("textarea")):
							fieldDefExprs.push(macro {fieldData.isBigText = true;});

						case EBinop(OpAssign, e1, e2):
							switch [e1.expr, e2.expr] {
								case [EConst(CIdent("separator")), EConst(CIdent("true"))]:
									fieldDefExprs.push(macro {fieldData.isSeparator = true;});

								case [EConst(CIdent("dependency")), EConst(CString(depval))]:
									fieldDefExprs.push(macro {fieldData.dependency = $v{depval};});
									depField = depval;
									hasDep = true;

								case [EConst(CIdent("dependencyval")), EBinop(OpOr, val1, val2)]:
									depFieldVal = haxe.macro.ExprTools.getValue(val1);
									depFieldVal2 = haxe.macro.ExprTools.getValue(val2);

								case [EConst(CIdent("dependencyval")), _]:
									depFieldVal = haxe.macro.ExprTools.getValue(e2);

								case [EConst(CIdent("contains")), EConst(CIdent("true"))]:
									fieldDefExprs.push(macro {fieldData.contains = true;});
									depContains = true;

								case [EConst(CIdent("inverseDependency")), EConst(CIdent("true"))]:
									fieldDefExprs.push(macro {fieldData.inverseDependency = true;});
									depInverse = true;

								case _:
									throw 'Unknown field metadata parameter: ' + Std.string(param.expr);
							}
						case _:
							{}
					}
				}
				if (hasDep) {
					if (depContains) {
						if (depFieldVal2 != null) {
							!depInverse ? fieldDefExprs.push(macro {
								fieldData.dependencyFunc = () -> {
									return StringTools.contains($i{depField}, $v{depFieldVal})
										|| StringTools.contains($i{depField}, $v{depFieldVal2});
								}
							}) : fieldDefExprs.push(macro {
								fieldData.dependencyFunc = () -> {
									return !StringTools.contains($i{depField}, $v{depFieldVal})
										|| StringTools.contains($i{depField}, $v{depFieldVal2});
								}
							});
						} else {
							!depInverse ? fieldDefExprs.push(macro {
								fieldData.dependencyFunc = () -> {
									return StringTools.contains($i{depField}, $v{depFieldVal});
								}
							}) : fieldDefExprs.push(macro {
								fieldData.dependencyFunc = () -> {
									return !StringTools.contains($i{depField}, $v{depFieldVal});
								}
							});
						}
					} else {
						if (depFieldVal2 != null) {
							!depInverse ? fieldDefExprs.push(macro {
								fieldData.dependencyFunc = () -> {
									return $i{depField} == $v{depFieldVal} || $i{depField} == $v{depFieldVal2};
								}
							}) : fieldDefExprs.push(macro {
								fieldData.dependencyFunc = () -> {
									return $i{depField} != $v{depFieldVal} || $i{depField} != $v{depFieldVal2};
								}
							});
						} else {
							!depInverse ? fieldDefExprs.push(macro {
								fieldData.dependencyFunc = () -> {
									return $i{depField} == $v{depFieldVal};
								}
							}) : fieldDefExprs.push(macro {
								fieldData.dependencyFunc = () -> {
									return $i{depField} != $v{depFieldVal};
								}
							});
						}
					}
				} else {
					fieldDefExprs.push(macro {
						fieldData.dependencyFunc = () -> {
							return true;
						};
					});
				}
				fieldDefExprs.push(macro {
					fieldData.getterFn = () -> {
						return $i{field.name};
					};
				});

				fieldDefExprs.push(macro {
					fieldData.setterFn = (val) -> {
						$i{field.name} = val;
					};
				});
				switch (field.kind) {
					case FVar(t, e):
						if (e != null)
							fieldDefExprs.push(macro {fieldData.defaultValue = $v{haxe.macro.ExprTools.getValue(e)};});
						switch (t) {
							case TPath(tp):
								fieldDefExprs.push(macro {fieldData.type = $v{tp.name};});
							case _:
								{}
						};
					case _:
						{}
				}
				fieldDefExprs.push(macro {fieldDefs.push(fieldData);});

				fieldDefBlocks.push(macro {
					var fieldData = new hrt.mis.MissionInfoField();
					$b{fieldDefExprs}
				});
			}
		}

		fields.push({
			name: 'getMissionInfoFields',
			pos: Context.currentPos(),
			access: [APublic],
			kind: FFun({
				args: [],
				expr: macro {
					var fieldDefs = [];
					$b{fieldDefBlocks} return fieldDefs;
				}
			})
		});

		fields.push({
			name: 'fromMissionInfo',
			pos: Context.currentPos(),
			access: [APublic],
			kind: FFun({
				args: [
					{
						name: 'mi',
						type: haxe.macro.TypeTools.toComplexType(Context.getType('hrt.prefab.l3d.ScriptObject'))
					}
				],
				expr: macro {
					$b{loadStmts} so = mi;
				}
			})
		});

		fields.push({
			name: 'toMissionInfo',
			pos: Context.currentPos(),
			access: [APublic],
			kind: FFun({
				args: [],
				expr: macro {
					var mi = so;
					$b{saveStmts}
				}
			})
		});

		return fields;
	}
	#end
}
