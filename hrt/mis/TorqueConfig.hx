package hrt.mis;

typedef CreatorMenuJson = {
	gameType:String,
	shapes:Dynamic,
	triggers:Array<ShapeCreatorMenuJson>,
}

typedef TorqueFieldEnum = {
	name:String,
	display:String
}

typedef TorqueField = {
	name:String,
	display:String,
	desc:String,
	type:String,
	?defaultValue:Dynamic,
	?typeEnums:Array<TorqueFieldEnum>
}

typedef ShapeCreatorMenuJson = {
	name:String,
	?classname:String,
	?shapefile:String,
	?skin:String,
	?fields:Array<TorqueField>,
	fieldMap:Map<String, TorqueField>
}

class TorqueConfig {
	public static var creatorMenuJson:CreatorMenuJson;

	static var datablockDb:Map<String, ShapeCreatorMenuJson>;

	static var _init = false;

	public static var gameType:String;

	public static function init() {
		if (creatorMenuJson == null) {
			_init = true;
			creatorMenuJson = haxe.Json.parse(hxd.res.Loader.currentInstance.fs.get("datablocks.json").getText());
			gameType = creatorMenuJson.gameType;

			datablockDb = [];

			var kvi = new haxe.iterators.DynamicAccessKeyValueIterator(creatorMenuJson.shapes);
			for (k => v in kvi) {
				var shapeGroup:Array<hrt.mis.TorqueConfig.ShapeCreatorMenuJson> = cast v;
				for (s in shapeGroup) {
					datablockDb[s.name.toLowerCase()] = s;

					s.fieldMap = [];
					if (s.fields != null) {
						for (field in s.fields) {
							s.fieldMap[field.name.toLowerCase()] = field;
						}
					}
				}
			}

			for (item in creatorMenuJson.triggers) {
				datablockDb[item.name.toLowerCase()] = item;
				item.fieldMap = [];
				if (item.fields != null) {
					for (field in item.fields) {
						item.fieldMap[field.name.toLowerCase()] = field;
					}
				}
			}
		}
	}

	public static function getDataBlock(id:String) {
		if (!_init)
			init();
		return datablockDb[id.toLowerCase()];
	}
}
