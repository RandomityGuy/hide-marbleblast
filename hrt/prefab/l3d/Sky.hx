package hrt.prefab.l3d;

import haxe.io.Path;
import h3d.mat.Texture;
import h3d.Vector;

class Sky extends TorqueObject {
	@:s var materialList:String;
	@:s var fogColor:Int;
	@:s var skySolidColor:Int;
	@:s var useSkyTextures:Bool;

	var skyShader:hrt.shader.Skybox;

	public override function loadFromPath(p:String) {
		materialList = p;
		return true;
	}

	override function getEditorClassName():String {
		return "Sky";
	}

	override function makeInstance(ctx:Context):Context {
		if (materialList != null) {
			var texture = createSkyboxCubeTextured(this.materialList);
			if (texture != null) {
				ctx = ctx.clone(this);
				var rootObject = new h3d.scene.Object(ctx.local3d);

				var sky = new h3d.prim.Sphere(1, 128, 128);
				sky.addNormals();
				sky.addUVs();
				var skyMesh = new h3d.scene.Mesh(sky, rootObject);
				skyMesh.material.mainPass.culling = Front;
				skyMesh.material.mainPass.enableLights = false;
				skyMesh.material.shadows = false;
				skyMesh.material.blendMode = None;
				skyMesh.ignoreCollide = true;

				skyMesh.scale(100);
				var shad = new hrt.shader.Skybox(texture);
				skyMesh.material.mainPass.removeShader(skyMesh.material.textureShader);
				skyMesh.material.mainPass.addShader(shad);
				skyMesh.material.mainPass.depth(false, h3d.mat.Data.Compare.LessEqual);
				skyMesh.material.mainPass.depthWrite = false;
				skyMesh.material.mainPass.layer = -1;

				skyShader = shad;

				ctx.local3d = rootObject;
				ctx.local3d.name = name;
				updateInstance(ctx);
			}
		}
		return ctx;
	}

	function createSkyboxCubeTextured(dmlPath:String) {
		if (hxd.res.Loader.currentInstance.fs.exists(dmlPath)) {
			var dmlFile = hxd.res.Loader.currentInstance.fs.get(dmlPath).getText();
			var dmlDirectory = Path.directory(dmlPath);
			var lines = dmlFile.split('\n').map(x -> x.toLowerCase());
			var skyboxImages = [];

			// 5: bottom, to be rotated/flipped
			// 0: front
			var skyboxIndices = [3, 1, 2, 0, 4, 5];

			var filestoload = [];
			for (i in 0...6) {
				var line = StringTools.trim(lines[i]);
				var filenames = getFullNamesOf(dmlDirectory + '/' + line);
				if (filenames.length != 0) {
					filestoload.push(filenames[0]);
				}
			}
			var skySolidColor2 = Vector.fromColor(skySolidColor);
			var skyColor = Vector.fromColor(fogColor);
			if (skySolidColor2.x != 0.6 || skySolidColor2.y != 0.6 || skySolidColor2.z != 0.6)
				skyColor = skySolidColor2;
			if (skyColor.x > 1)
				skyColor.x = 1 - (skyColor.x - 1) % 256 / 256;
			if (skyColor.y > 1)
				skyColor.y = 1 - (skyColor.y - 1) % 256 / 256;
			if (skyColor.z > 1)
				skyColor.z = 1 - (skyColor.z - 1) % 256 / 256;

			var noSkyTexture = !useSkyTextures;

			for (i in 0...6) {
				var line = StringTools.trim(lines[i]);
				var filenames = getFullNamesOf(dmlDirectory + '/' + line);
				if (filenames.length == 0 || noSkyTexture) {
					var pixels = Texture.fromColor(skyColor.toColor()).capturePixels(0, 0);
					skyboxImages.push(pixels);
					// var tex = new h3d.mat.Texture();
					// skyboxImages.push(new BitmapData(128, 128));
				} else {
					try {
						var image = hxd.res.Loader.currentInstance.load(filenames[0]).toImage().toBitmap();
						var pixels = image.getPixels();
						skyboxImages.push(pixels);
					} catch (e:Dynamic) {
						var pixels = Texture.fromColor(skyColor.toColor()).capturePixels(0, 0);
						skyboxImages.push(pixels);
					}
				}
			}
			var maxwidth = 0;
			var maxheight = 0;
			for (texture in skyboxImages) {
				if (texture.height > maxheight)
					maxheight = texture.height;
				if (texture.width > maxwidth)
					maxwidth = texture.width;
			}

			flipImage(skyboxImages[0], true, false);
			flipImage(skyboxImages[4], true, false);
			rotateImage(skyboxImages[5], Math.PI);
			flipImage(skyboxImages[5], true, false);
			rotateImage(skyboxImages[1], -Math.PI / 2);
			flipImage(skyboxImages[1], true, false);
			rotateImage(skyboxImages[2], Math.PI);
			flipImage(skyboxImages[2], true, false);
			rotateImage(skyboxImages[3], Math.PI / 2);
			flipImage(skyboxImages[3], true, false);

			var cubemaptexture = new Texture(maxheight, maxwidth, [Cube]);
			for (i in 0...6) {
				cubemaptexture.uploadPixels(skyboxImages[skyboxIndices[i]], 0, i);
			}
			return cubemaptexture;
		} else {
			return null;
		}
	}

	function getFullNamesOf(path:String) {
		var files = hxd.res.Loader.currentInstance.fs.dir(Path.directory(path)); // FileSystem.readDirectory(Path.directory(path));
		var names = [];
		var fname = Path.withoutDirectory(path).toLowerCase();
		for (file in files) {
			var fname2 = file.name;
			if (Path.withoutExtension(fname2).toLowerCase() == fname)
				names.push(file.path);
		}
		return names;
	}

	public static function rotateImage(bitmap:hxd.Pixels, angle:Float) {
		var curpixels = bitmap.clone();
		if (angle == Math.PI / 2)
			for (x in 0...curpixels.width) {
				for (y in 0...curpixels.height) {
					var psrc = ((y + (curpixels.height - x - 1) * curpixels.width) * @:privateAccess curpixels.bytesPerPixel) + curpixels.offset;
					var pdest = ((x + y * curpixels.width) * @:privateAccess curpixels.bytesPerPixel) + curpixels.offset;

					switch (curpixels.format) {
						case R8:
							bitmap.bytes.set(pdest, curpixels.bytes.get(psrc));
						case BGRA | RGBA | ARGB:
							bitmap.bytes.set(pdest, curpixels.bytes.get(psrc));
							bitmap.bytes.set(pdest + 1, curpixels.bytes.get(psrc + 1));
							bitmap.bytes.set(pdest + 2, curpixels.bytes.get(psrc + 2));
							bitmap.bytes.set(pdest + 3, curpixels.bytes.get(psrc + 3));
						case RG8:
							bitmap.bytes.set(pdest, curpixels.bytes.get(psrc));
							bitmap.bytes.set(pdest + 1, curpixels.bytes.get(psrc + 1));
						default:
							null;
					}

					// bitmap.setPixel(x, y, curpixels.getPixel(y, curpixels.height - x - 1));
				}
			}
		if (angle == -Math.PI / 2)
			for (x in 0...curpixels.width) {
				for (y in 0...curpixels.height) {
					var psrc = ((curpixels.width - y - 1) + x * curpixels.width) * @:privateAccess curpixels.bytesPerPixel + curpixels.offset;

					var pdest = ((x + y * curpixels.width) * @:privateAccess curpixels.bytesPerPixel) + curpixels.offset;

					switch (curpixels.format) {
						case R8:
							bitmap.bytes.set(pdest, curpixels.bytes.get(psrc));
						case BGRA | RGBA | ARGB:
							bitmap.bytes.set(pdest, curpixels.bytes.get(psrc));
							bitmap.bytes.set(pdest + 1, curpixels.bytes.get(psrc + 1));
							bitmap.bytes.set(pdest + 2, curpixels.bytes.get(psrc + 2));
							bitmap.bytes.set(pdest + 3, curpixels.bytes.get(psrc + 3));
						case RG8:
							bitmap.bytes.set(pdest, curpixels.bytes.get(psrc));
							bitmap.bytes.set(pdest + 1, curpixels.bytes.get(psrc + 1));
						default:
							null;
					}
				}
			}
		if (angle == Math.PI)
			for (x in 0...curpixels.width) {
				for (y in 0...curpixels.height) {
					var psrc = ((curpixels.width - x - 1)
						+ (curpixels.height - y - 1) * curpixels.width) * @:privateAccess curpixels.bytesPerPixel
						+ curpixels.offset;

					var pdest = ((x + y * curpixels.width) * @:privateAccess curpixels.bytesPerPixel) + curpixels.offset;

					switch (curpixels.format) {
						case R8:
							bitmap.bytes.set(pdest, curpixels.bytes.get(psrc));
						case BGRA | RGBA | ARGB:
							bitmap.bytes.set(pdest, curpixels.bytes.get(psrc));
							bitmap.bytes.set(pdest + 1, curpixels.bytes.get(psrc + 1));
							bitmap.bytes.set(pdest + 2, curpixels.bytes.get(psrc + 2));
							bitmap.bytes.set(pdest + 3, curpixels.bytes.get(psrc + 3));
						case RG8:
							bitmap.bytes.set(pdest, curpixels.bytes.get(psrc));
							bitmap.bytes.set(pdest + 1, curpixels.bytes.get(psrc + 1));
						default:
							null;
					}
				}
			}
	}

	public static function flipImage(bitmap:hxd.Pixels, hflip:Bool, vflip:Bool) {
		var curpixels = bitmap.clone();
		if (hflip)
			for (x in 0...curpixels.width) {
				for (y in 0...curpixels.height) {
					var psrc = ((curpixels.width - x - 1) + y * curpixels.width) * @:privateAccess curpixels.bytesPerPixel + curpixels.offset;

					var pdest = ((x + y * curpixels.width) * @:privateAccess curpixels.bytesPerPixel) + curpixels.offset;

					switch (curpixels.format) {
						case R8:
							bitmap.bytes.set(pdest, curpixels.bytes.get(psrc));
						case BGRA | RGBA | ARGB:
							bitmap.bytes.set(pdest, curpixels.bytes.get(psrc));
							bitmap.bytes.set(pdest + 1, curpixels.bytes.get(psrc + 1));
							bitmap.bytes.set(pdest + 2, curpixels.bytes.get(psrc + 2));
							bitmap.bytes.set(pdest + 3, curpixels.bytes.get(psrc + 3));
						case RG8:
							bitmap.bytes.set(pdest, curpixels.bytes.get(psrc));
							bitmap.bytes.set(pdest + 1, curpixels.bytes.get(psrc + 1));
						default:
							null;
					}
				}
			}
		if (vflip)
			for (x in 0...curpixels.width) {
				for (y in 0...curpixels.height) {
					var psrc = (x + (curpixels.width - y - 1) * curpixels.width) * @:privateAccess curpixels.bytesPerPixel + curpixels.offset;

					var pdest = ((x + y * curpixels.width) * @:privateAccess curpixels.bytesPerPixel) + curpixels.offset;

					switch (curpixels.format) {
						case R8:
							bitmap.bytes.set(pdest, curpixels.bytes.get(psrc));
						case BGRA | RGBA | ARGB:
							bitmap.bytes.set(pdest, curpixels.bytes.get(psrc));
							bitmap.bytes.set(pdest + 1, curpixels.bytes.get(psrc + 1));
							bitmap.bytes.set(pdest + 2, curpixels.bytes.get(psrc + 2));
							bitmap.bytes.set(pdest + 3, curpixels.bytes.get(psrc + 3));
						case RG8:
							bitmap.bytes.set(pdest, curpixels.bytes.get(psrc));
							bitmap.bytes.set(pdest + 1, curpixels.bytes.get(psrc + 1));
						default:
							null;
					}
				}
			}
	}

	override function updateInstance(ctx:Context, ?propName:String) {
		super.updateInstance(ctx, propName);

		var texture = createSkyboxCubeTextured(this.materialList);
		if (texture != null) {
			skyShader.texture = texture;
		}
	}

	#if editor
	override function edit(ctx:EditContext) {
		super.edit(ctx);

		var group = new hide.Element('
			<div class="group" name="Sky">
				<dl>
					<dt>Solid Color</dt><dd><input type="color" field="skySolidColor"/></dd>
                    <dt>Fog Color</dt><dd><input type="color" field="fogColor"/></dd>
					<dt>Use Sky Textures</dt><dd><input type="checkbox" field="useSkyTextures"/></dd>
                    <dt>Material List</dt><dd><input type="fileselect" extensions="dml" field="materialList"/></dd>
				</dl>
			</div>
		');

		ctx.properties.add(group, this, function(pname) {
			ctx.onChange(this, pname);
		});

		addDynFieldsEdit(ctx);
	}

	override function getHideProps():HideProps {
		return {icon: "photo", name: "Sky"};
	}
	#end

	static var _ = Library.register("sky", Sky);
}
