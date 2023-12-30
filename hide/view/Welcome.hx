package hide.view;

class Welcome extends hide.ui.View<{}> {
	public function new(state) {
		super(state);
	}

	override function onDisplay() {
		var buildDate = "";

		var el = new Element('
			<div class="welcome-content">
				<h1>
					Welcome
				</h1>
				<div class="welcome-options">
					<h2>Start</h2>
					<div class="welcome-start-options">
					<span class="welcome-open"><div class="ico icon ico-folder"></div> Open Folder</span>
					</div>
					<h2>Recents</h2>
					<div class="welcome-recent-options">
					</div>
				</div>
			</div>
		');
		el.appendTo(element);

		var recentOptions = el.find(".welcome-recent-options");

		for (opt in hide.Ide.inst.ideConfig.recentProjects) {
			var optElement = new Element('<span><div class="ico icon ico-folder"></div> ${opt}</span>');
			optElement.on('click', () -> {
				@:privateAccess hide.Ide.inst.setProject(opt);
			});
			optElement.appendTo(recentOptions);
		}

		var openFolder = el.find(".welcome-open");
		openFolder.on('click', () -> {
			hide.Ide.inst.chooseDirectory(function(dir) {
				if (dir == null)
					return;
				if (StringTools.endsWith(dir, "/res") || StringTools.endsWith(dir, "\\res"))
					dir = dir.substr(0, -4);
				@:privateAccess hide.Ide.inst.setProject(dir);
			}, true);
		});
	}

	static var _ = hide.ui.View.register(Welcome, {position: Center});
}
