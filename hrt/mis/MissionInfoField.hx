package hrt.mis;

@:publicFields
class MissionInfoField {
	var fieldName:String;
	var display:String;
	var type:String;
	var defaultValue:Dynamic;
	var isSeparator:Bool;
	var dependency:String;
	var inverseDependency:Bool;
	var contains:Bool;
	var serialize:Bool;
	var dependencyFunc:Void->Bool;
	var isBigText:Bool;
	var gameDep:Array<String>;

	var getterFn:Void->Dynamic;
	var setterFn:Dynamic->Void;

	public function new() {}
}
