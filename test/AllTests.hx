import heaps.coroutine.util.ManagedCoroutine;
import heaps.coroutine.Coroutine;
import heaps.coroutine.CoroutineSystem;


class Test {
	public var name:String;
	public var testFunction:() -> Bool;

	public function new(name:String, testFunction:() -> Bool) {
		this.name = name;
		this.testFunction = testFunction;
		AllTests.all.push(this);
	}
}

class AllTests {
	public static final all:Array<Test> = [];

	public static function main() {
		LOAD_TESTS();

		var failedTests:Array<String> = [];

		for (test in all) {
			var result = false;
			try {
				trace("Running " + test.name);
				result = test.testFunction();
			} catch (e:Dynamic) {
				result = false;
			}
			if (!result) {
				trace("\t" + test.name + " failed.");
				failedTests.push(test.name);
			} else {
				trace("\t" + test.name + " passed.");
			}
		}

		if (failedTests.length == 0) {
			trace("All tests passed successfully!");
		} else {
			for (failedTest in failedTests) {
				trace("Test failed: " + failedTest);
			}
		}
	}
}

var LOAD_TESTS = () -> {
	var test1 = new Test("Coroutine Add Test", function():Bool {
		var cs = new CoroutineSystem();
		var functionCalled = false;

		var coroutine:Coroutine = (dt:Float) -> {
			functionCalled = true;
			return CoroutineOnFrameResult.Stop;
		};

		cs.add(coroutine, null);
		cs.update(0);

		return functionCalled;
	});
	var test2 = new Test("Coroutine Remove Test", function():Bool {
		var cs = new CoroutineSystem();
		var functionCalled = false;

		var coroutine:Coroutine = (dt:Float) -> {
			functionCalled = true;
			return CoroutineOnFrameResult.Stop;
		};

		var tag = cs.add(coroutine, null);
		cs.remove(tag);
		cs.update(0);

		return !functionCalled;
	});
	var test3 = new Test("Coroutine Priority Test", function():Bool {
		var cs = new CoroutineSystem();

		var results:Array<String> = [];

		var controlCoroutine:Coroutine = (dt:Float) -> {
			results.push("1");
			return CoroutineOnFrameResult.Stop;
		};

		var renderingCoroutine:Coroutine = (dt:Float) -> {
			results.push("2");
			return CoroutineOnFrameResult.Stop;
		};

		cs.add(renderingCoroutine, [CoroutineOption.Priority(CoroutinePriority.Rendering)]);
		cs.add(controlCoroutine, [CoroutineOption.Priority(CoroutinePriority.Controls)]);
		cs.update(0);

		return results[0] == "1" && results[1] == "2";
	});

	new Test("ManagedCoroutine Update Test", function(): Bool {
		var coroutineCalled = false;
		
		var coroutine: (ManagedCoroutine) -> CoroutineOnFrameResult = (mc) -> {
			coroutineCalled = true;
			return CoroutineOnFrameResult.Stop;
		};
		
		var mc = new ManagedCoroutine(coroutine);
		@:privateAccess mc.update(1.0);

		return coroutineCalled;
	});

	new Test("ManagedCoroutine Complete Callback Test", function(): Bool {
		var completeCalled = false;
		
		var coroutine: (ManagedCoroutine) -> CoroutineOnFrameResult = (mc) -> CoroutineOnFrameResult.Stop;

		var mc = new ManagedCoroutine(coroutine);
		mc.onComplete(() -> {
			completeCalled = true;
		});
		@:privateAccess mc.update(1.0);
		
		return completeCalled;
	});


}
