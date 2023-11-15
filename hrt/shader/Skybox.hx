package hrt.shader;

class Skybox extends hxsl.Shader {
	static var SRC = {
		var pixelColor:Vec4;
		var transformedPosition:Vec3;
		var projectedPosition:Vec4;
		@param var texture:SamplerCube;
		@global var camera:{
			var position:Vec3;
			var viewProj:Mat4;
			var view:Mat4;
			var proj:Mat4;
			var projFlip:Float;
		};
		@input var input:{
			var position:Vec3;
		};
		@global var global:{
			@perObject var modelView:Mat4;
		};
		var output:{
			var position:Vec4;
			var color:Vec4;
			var depth:Float;
		};
		var projNorm:Vec3;
		function __init__() {
			transformedPosition = input.position * global.modelView.mat3x4() + camera.position;
			projectedPosition = vec4(camera.position + input.position * 50, 1) * camera.viewProj;
		}
		function vertex() {
			projNorm = input.position;
			output.position = projectedPosition * vec4(1, camera.projFlip, 1, 1);
		}
		function fragment() {
			output.color = texture.get(normalize(projNorm)).rgba;
		}
	}

	public function new(texture) {
		super();
		this.texture = texture;
	}
}
