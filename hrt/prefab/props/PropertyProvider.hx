package hrt.prefab.props;

import hrt.prefab.l3d.TorqueObject;

class PropertyProvider {
	static var registeredPropertyProviders:Map<String, Class<PropertyProvider>> = [];

	var obj:TorqueObject;

	public function new(obj:TorqueObject) {
		this.obj = obj;
	}

	public function updateInstance(ctx:hrt.prefab.Context, ?propName:String) {}

	public function onTransformApplied() {}

	#if editor
	public function edit(ctx:EditContext) {}

	public function onSelected(s:Bool) {}

	public function onPropertyChanged(ctx:EditContext, p:String) {}
	#end

	public static function registerPropertyProvider(name:String, pprovider:Class<PropertyProvider>) {
		registeredPropertyProviders[name.toLowerCase()] = pprovider;
		return true;
	}

	public static function getPropertyProvider(name:String, obj:TorqueObject):PropertyProvider {
		if (name == null)
			return null;
		var lowercase = name.toLowerCase();
		var pprovider:Class<PropertyProvider> = registeredPropertyProviders[lowercase];
		return (pprovider != null ? Type.createInstance(pprovider, [obj]) : null);
	}
}
