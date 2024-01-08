package hide.view;

import hrt.mis.TorqueConfig;

class DiscardAlphaShader extends h3d.shader.ScreenShader {
	static var SRC = {
		@param var texture:Sampler2D;
		function fragment() {
			var pixel:Vec4 = texture.get(calculatedUV);
			// Premultiply alpha to ensure correct transparency.
			if (pixel.r > 0 || pixel.g > 0 || pixel.b > 0) {
				pixel.rgb = pixel.rgb / pixel.a;
				pixel.a = 1;
			}
			pixelColor = pixel;
			// Some other filters directly assign `output.color` and fetch from `input.uv`.
			// While it will work, it does not work well when multiple shaders in one filter are involved.
			// In this case use `calculatedUV` and `pixelColor`.
		}
	}
}

class CreatorView extends hide.ui.View<{}> {
	public function new(state) {
		super(state);
	}

	override function getTitle() {
		return "Creator";
	}

	override function onDisplay() {
		var panel = new Element('<div class="hide-scroll creator-tree">
			<div class="creator-category-container">
				<span>Category</span>
				<select id="creator-category">
				</select>
			</div>
			<div class="creator-grid">
			</div>
			</div>').appendTo(element);

		var creatorSelect = panel.find("#creator-category");
		var kvi = new haxe.iterators.DynamicAccessKeyValueIterator(TorqueConfig.creatorMenuJson.shapes);

		var categories = [];
		for (k => v in kvi) {
			categories.push(k);
		}

		categories.sort(function(l1, l2) return Reflect.compare(l1.toLowerCase(), l2.toLowerCase()));

		for (k in categories) {
			var categoryName = StringTools.replace(k, '.', ' > ');

			var el = new Element('<option value="${k}">${categoryName}</option>').appendTo(creatorSelect);
		}

		var creatorGrid = panel.find(".creator-grid");

		var buildCategoryGrid = null;

		function buildSkinGrid(shape:hrt.mis.TorqueConfig.ShapeCreatorMenuJson) {
			creatorGrid.empty();

			var backBtn = new Element('<div class="creator-back">Back</div>');
			backBtn.appendTo(creatorGrid);
			backBtn.on('click', (e) -> {
				buildCategoryGrid(creatorSelect.val());
			});

			for (skin in shape.fieldMap["skin"].typeEnums) {
				var creatorItem = new Element('<div class="creator-item" data-tooltip="${skin.display}"><div class="creator-scene"></div></div>');
				var creatorScene = creatorItem.find(".creator-scene");
				// var sceneComp = new hide.comp.Scene(config, creatorItem, creatorScene);
				// sceneComp.onReady = () -> {
				// createCreatorSceneElRender(creatorScene, sceneComp, shape);
				createCreatorScene(creatorScene, shape, skin.name);
				// };
				creatorItem.appendTo(creatorGrid);
			}
		}

		buildCategoryGrid = (category:String) -> {
			if (TorqueConfig.creatorMenuJson == null || TorqueConfig.creatorMenuJson.shapes == null)
				return;
			var e:haxe.DynamicAccess<Array<hrt.mis.TorqueConfig.ShapeCreatorMenuJson>> = cast TorqueConfig.creatorMenuJson.shapes;
			var shapes = e.get(category);
			if (shapes == null)
				return;

			creatorGrid.empty();

			for (shape in shapes) {
				var creatorItem = new Element('<div class="creator-item" data-tooltip="${shape.name}"><div class="creator-scene"></div></div>');
				var creatorScene = creatorItem.find(".creator-scene");
				if (shape.fieldMap.exists("skin") && shape.fieldMap["skin"].typeEnums != null) {
					var skinSelect = new Element('<div class="creator-skin-select"><div class="ico icon ico-caret-down" style="scale: 1.5; color: #222222;"></div></div>');
					skinSelect.appendTo(creatorItem);
					skinSelect.on("click", (e) -> {
						buildSkinGrid(shape);
					});
				}
				// var sceneComp = new hide.comp.Scene(config, creatorItem, creatorScene);
				// sceneComp.onReady = () -> {
				// createCreatorSceneElRender(creatorScene, sceneComp, shape);
				createCreatorScene(creatorScene, shape);
				// };
				creatorItem.appendTo(creatorGrid);
			}
		}

		creatorSelect.on("change", (e) -> {
			var category = creatorSelect.val();
			buildCategoryGrid(category);
		});

		var checkFn = null;

		checkFn = () -> {
			if (h3d.Engine.getCurrent() == null) {
				haxe.Timer.delay(checkFn, 1000);
			} else {
				haxe.Timer.delay(() -> buildCategoryGrid(categories[0]), 3000); // If this crashes, then bruh
			}
		};

		checkFn();
	}

	function createCreatorScene(el:Element, shape:hrt.mis.TorqueConfig.ShapeCreatorMenuJson, skin:String = null) {
		var skinToUse = null;
		if (skin == null) {
			skinToUse = shape.skin == "" ? null : shape.skin;
			if (shape.fieldMap.exists("skin") && skinToUse == null) {
				skinToUse = shape.fieldMap["skin"].defaultValue;
				if (skinToUse == "")
					skinToUse = null;
			}
		} else {
			skinToUse = skin;
		}

		var cachePath = 'cache/${TorqueConfig.gameType}_${shape.name}_${skinToUse == null ? "" : skinToUse}.png';
		if (sys.FileSystem.exists(cachePath)) {
			var imgEl = new Element('<img data="${shape.classname}:${shape.name}:${skinToUse == null ? "" : skinToUse}" />');
			imgEl.attr("src", cachePath);
			imgEl.appendTo(el);
			var innerImg = imgEl[0];
			innerImg.ondragstart = (e:js.html.DragEvent) -> {
				e.dataTransfer.setData("text/plain", 'CREATE:${shape.classname}:${shape.name}:${skinToUse == null ? "" : skinToUse}:${shape.shapefile}');
			}
		} else {
			var sceneTarget = new h3d.mat.Texture(50, 50, [Target]);
			sceneTarget.depthBuffer = new h3d.mat.Texture(50, 50, [], Depth24Stencil8);
			sceneTarget.filter = Linear;

			var drawTarget = new h3d.mat.Texture(50, 50, [Target]);
			drawTarget.filter = Linear;

			var scene = new h3d.scene.Scene(false);
			scene.renderer = new h3d.scene.fwd.Renderer();
			scene.addChild(new h3d.scene.fwd.DirLight(new h3d.Vector(0.707, -0.707, -0.707)));

			var shapefile = StringTools.replace(StringTools.replace(shape.shapefile.toLowerCase(), "marble/", ""), "platinum/", "");
			var to = new hrt.prefab.l3d.TSStatic();
			to.path = shapefile;

			to.skin = skinToUse;
			@:privateAccess to.isForPreview = true;
			var ctx = new hrt.prefab.Context();
			ctx.init();
			to.makeInstance(ctx);

			var obj = ctx.local3d;
			var dts = hrt.prefab.l3d.DtsMesh.DtsCache.readDTS(shapefile);
			var minX = 100000000.0;
			var minY = 100000000.0;
			var minZ = 100000000.0;
			var maxX = -100000000.0;
			var maxY = -100000000.0;
			var maxZ = -100000000.0;
			for (mesh in dts.meshes) {
				if (mesh != null) {
					for (vert in mesh.vertices) {
						minX = Math.min(minX, vert.x);
						minY = Math.min(minY, vert.y);
						minZ = Math.min(minZ, vert.z);
						maxX = Math.max(maxX, vert.x);
						maxY = Math.max(maxY, vert.y);
						maxZ = Math.max(maxZ, vert.z);
					}
				}
			}
			var dtsbounds = dts.bounds.center();
			var boundsSize = new h3d.Vector(maxX - minX, maxY - minY, maxZ - minZ);
			var objCenter = new h3d.col.Point(dtsbounds.x, dtsbounds.y, dtsbounds.z);
			var biggestDim = boundsSize.length();

			var angle = Math.PI / 16;
			var bestDist = biggestDim / (2 * Math.tan(angle));
			var sqrt3 = 1.73205080757;
			scene.camera.target = objCenter.toVector();
			scene.camera.pos = objCenter.sub(new h3d.col.Point(bestDist / sqrt3, bestDist / sqrt3, -bestDist / sqrt3)).toVector();

			scene.addChild(obj);
			haxe.Timer.delay(() -> {
				var engine = h3d.Engine.getCurrent();
				engine.pushTarget(sceneTarget);
				var prevBgColor = engine.backgroundColor;
				engine.backgroundColor = 0x00000000;
				engine.clear(0x00000000, 1);
				scene.render(engine);
				engine.popTarget();
				engine.backgroundColor = prevBgColor;

				var tile = h2d.Tile.fromTexture(sceneTarget);
				var bmp = new h2d.Bitmap(tile);
				bmp.filter = new h2d.filter.Shader<DiscardAlphaShader>(new DiscardAlphaShader());
				bmp.drawTo(drawTarget);

				var pixels = drawTarget.capturePixels();
				var pixpng = pixels.toPNG();
				var imgsrc = "data:image/png;base64," + haxe.crypto.Base64.encode(pixpng);
				var imgEl = new Element('<img data="${shape.classname}:${shape.name}:${skinToUse == null ? "" : skinToUse}" />');
				imgEl.attr("src", imgsrc);
				imgEl.appendTo(el);
				var innerImg = imgEl[0];
				innerImg.ondragstart = (e:js.html.DragEvent) -> {
					e.dataTransfer.setData("text/plain", 'CREATE:${shape.classname}:${shape.name}:${skinToUse == null ? "" : skinToUse}:${shape.shapefile}');
				}
				sys.io.File.saveBytes('cache/${TorqueConfig.gameType}_${shape.name}_${skinToUse == null ? "" : skinToUse}.png', pixels.toPNG());

				to.removeInstance(ctx);
				to.cleanup();
				scene.removeChild(obj);
				scene.dispose();
				scene = null;
				sceneTarget.dispose();
				sceneTarget = null;
				drawTarget.dispose();
				drawTarget = null;
				ctx = null;
			}, 1250);
		}
	}

	function createCreatorSceneElRender(el:Element, scene:hide.comp.Scene, shape:hrt.mis.TorqueConfig.ShapeCreatorMenuJson) {
		var sceneTarget = new h3d.mat.Texture(50, 50, [Target]);
		sceneTarget.depthBuffer = new h3d.mat.Texture(50, 50, [], Depth24Stencil8);

		scene.s3d.addChild(new h3d.scene.fwd.DirLight(new h3d.Vector(0.707, -0.707, -0.707)));

		var shapefile = StringTools.replace(StringTools.replace(shape.shapefile.toLowerCase(), "marble/", ""), "platinum/", "");
		var to = new hrt.prefab.l3d.TSStatic();
		to.path = shapefile;
		to.skin = shape.skin == "" ? null : shape.skin;
		@:privateAccess to.isForPreview = true;
		var ctx = new hrt.prefab.Context();
		ctx.init();
		to.makeInstance(ctx);

		var obj = ctx.local3d;
		var bounds = hrt.prefab.l3d.DtsMesh.DtsCache.readDTS(shapefile).bounds;
		var boundsSize = new h3d.Vector(bounds.maxX - bounds.minX, bounds.maxY - bounds.minY, bounds.maxZ - bounds.minZ);
		var bc = bounds.center();
		var objCenter = new h3d.col.Point(bc.x, bc.y, bc.z);
		var biggestDim = Math.max(boundsSize.x, Math.max(boundsSize.y, boundsSize.z));

		var angle = Math.PI / 24;
		var bestDist = biggestDim / (2 * Math.tan(angle));
		var sqrt3 = 1.73205080757;
		scene.s3d.camera.target = objCenter.toVector();
		scene.s3d.camera.pos = objCenter.sub(new h3d.col.Point(bestDist / sqrt3, bestDist / sqrt3, -bestDist / sqrt3)).toVector();

		scene.s3d.addChild(obj);
		haxe.Timer.delay(() -> {
			var engine = scene.engine;
			engine.pushTarget(sceneTarget);
			var prevBgColor = engine.backgroundColor;
			engine.backgroundColor = 0x00000000;
			engine.clear(0x00000000, 1);
			scene.render(engine);
			engine.popTarget();

			engine.backgroundColor = prevBgColor;

			var pixels = sceneTarget.capturePixels();
			var pixpng = pixels.toPNG();
			var imgsrc = "data:image/png;base64," + haxe.crypto.Base64.encode(pixpng);
			var imgEl = new Element('<img/>');
			imgEl.attr("src", imgsrc);
			imgEl.appendTo(el);
		}, 1250);
	}

	function createCreatorSceneEl(scene:hide.comp.Scene, shape:hrt.mis.TorqueConfig.ShapeCreatorMenuJson) {
		scene.s3d.addChild(new h3d.scene.fwd.DirLight(new h3d.Vector(0.707, -0.707, -0.707)));

		var shapefile = StringTools.replace(StringTools.replace(shape.shapefile.toLowerCase(), "marble/", ""), "platinum/", "");
		var to = new hrt.prefab.l3d.TSStatic();
		to.path = shapefile;
		to.skin = shape.skin == "" ? null : shape.skin;
		@:privateAccess to.isForPreview = true;
		var ctx = new hrt.prefab.Context();
		ctx.init();
		to.makeInstance(ctx);

		var obj = ctx.local3d;
		var bounds = hrt.prefab.l3d.DtsMesh.DtsCache.readDTS(shapefile).bounds;
		var boundsSize = new h3d.Vector(bounds.maxX - bounds.minX, bounds.maxY - bounds.minY, bounds.maxZ - bounds.minZ);
		var bc = bounds.center();
		var objCenter = new h3d.col.Point(bc.x, bc.y, bc.z);
		var biggestDim = Math.max(boundsSize.x, Math.max(boundsSize.y, boundsSize.z));

		var angle = Math.PI / 16;
		var bestDist = biggestDim / (2 * Math.tan(angle));
		var sqrt3 = 1.73205080757;
		scene.s3d.camera.target = objCenter.toVector();
		scene.s3d.camera.pos = objCenter.sub(new h3d.col.Point(bestDist / sqrt3, bestDist / sqrt3, -bestDist / sqrt3)).toVector();

		scene.s3d.addChild(obj);
	}

	static var _ = hide.ui.View.register(CreatorView, {width: 350, position: Left});
}
