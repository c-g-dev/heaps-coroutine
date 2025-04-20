import heaps.coroutine.CoroutineSystem;
import heaps.coroutine.Coroutine.FrameYield;
import heaps.coroutine.effect.Effect;

// TestEffect subclass to override onStart, onUpdate, and onComplete
class TestEffect extends Effect {
    public var counter:Int = 0; // Tracks updates or custom logic
    public var started:Bool = false; // Tracks onStart
    public var completed:Bool = false; // Tracks onComplete
    public var maxUpdates:Int = -1; // Controls when to stop (-1 for no limit)

    public function new() {
        super();
    }

    override function onStart():Void {
        started = true;
    }

    override function onUpdate(dt:Float):FrameYield {
        counter++;
        if (maxUpdates >= 0 && counter >= maxUpdates) {
            return Stop;
        }
        return WaitNextFrame;
    }

    override function onComplete():Void {
        completed = true;
    }
}


class EffectTests {
    public static function main() {
        var runner = new EffectTests();
        runner.runAllTests();
    }

    public function new() {}

    public function runAllTests() {
        var tests = [
            { name: "testEffectRunsOnFrame", func: testEffectRunsOnFrame },
            { name: "testElapsedFramesAndTime", func: testElapsedFramesAndTime },
            { name: "testOnStartUpdateComplete", func: testOnStartUpdateComplete },
            { name: "testChildRunsConcurrently", func: testChildRunsConcurrently },
            { name: "testParentWaitsForChildren", func: testParentWaitsForChildren }
        ];

        var passed = 0;
        var failed = 0;

        for (test in tests) {
            trace('Running test: ${test.name}');
            try {
                test.func();
                trace('Test ${test.name} PASSED');
                passed++;
            } catch (e:Dynamic) {
                trace('Test ${test.name} FAILED: $e');
                failed++;
            }
        }

        trace('Test Summary: $passed passed, $failed failed');
    }

    // Assertion helpers
    function assertEquals<T>(expected:T, actual:T, ?delta:Float, ?msg:String) {
        if (delta != null) {
            if (Math.abs(cast(expected, Float) - cast(actual, Float)) > delta) {
                var errorMsg = msg != null ? msg : 'Expected $expected but got $actual';
                throw errorMsg;
            }
        } else if (expected != actual) {
            var errorMsg = msg != null ? msg : 'Expected $expected but got $actual';
            throw errorMsg;
        }
    }

    function assertTrue(value:Bool, ?msg:String) {
        if (!value) {
            var errorMsg = msg != null ? msg : 'Expected true but got false';
            throw errorMsg;
        }
    }

    function assertFalse(value:Bool, ?msg:String) {
        if (value) {
            var errorMsg = msg != null ? msg : 'Expected false but got true';
            throw errorMsg;
        }
    }

    // Test functions
    function testEffectRunsOnFrame() {
        var system = CoroutineSystem.MAIN;
        var effect = new TestEffect();
        effect.maxUpdates = 3; // Stop after 3 updates
        effect.run();

        system.update(0.016); // First frame
        assertEquals(1, effect.counter);

        system.update(0.016); // Second frame
        assertEquals(2, effect.counter);

        system.update(0.016); // Third frame, stops
        assertEquals(3, effect.counter);

        system.update(0.016); // Fourth frame, should not run
        assertEquals(3, effect.counter);
    }

    function testElapsedFramesAndTime() {
        var system = CoroutineSystem.MAIN;
        var effect = new TestEffect();
        effect.maxUpdates = 3; // Stop after 3 frames
        effect.run();

        system.update(0.016); // Frame 1
        assertEquals(1, effect.elapsedFrames);
        

        system.update(0.016); // Frame 2
        assertEquals(2, effect.elapsedFrames);
        assertEquals(0.016, effect.elapsedTime, 0.001);
        

        system.update(0.016); // Frame 3, stops
        assertEquals(3, effect.elapsedFrames);
        assertEquals(0.032, effect.elapsedTime, 0.001);
        

        system.update(0.016); // Frame 4, should not update
        assertEquals(3, effect.elapsedFrames);
        
    }

    function testOnStartUpdateComplete() {
        var system = CoroutineSystem.MAIN;
        var effect = new TestEffect();
        effect.maxUpdates = 2; // Stop after 2 updates
        effect.run();

        system.update(0.016); // Start, Update 1
        assertTrue(effect.started);
        assertEquals(1, effect.counter);
        assertFalse(effect.completed);

        system.update(0.016); // Update 2, Complete
        assertEquals(2, effect.counter);
        assertTrue(effect.completed);
    }

    function testChildRunsConcurrently() {
        var system = CoroutineSystem.MAIN;
        var parent = new TestEffect();
        parent.maxUpdates = 3; // Stop after 3 updates

        var child = new TestEffect();
        child.maxUpdates = 3; // Stop after 3 updates

        parent.addChild(child);
        parent.run();

        system.update(0.016); // Both run once
        assertEquals(1, parent.counter);
        assertEquals(1, child.counter);

        system.update(0.016); // Both run twice
        assertEquals(2, parent.counter);
        assertEquals(2, child.counter);

        system.update(0.016); // Both run thrice, stop
        assertEquals(3, parent.counter);
        assertEquals(3, child.counter);
    }

    function testParentWaitsForChildren() {
        var system = CoroutineSystem.MAIN;
        var parent = new TestEffect();
        parent.maxUpdates = 1; // Stop immediately after 1 update

        var child = new TestEffect();
        child.maxUpdates = 2; // Stop after 2 updates

        parent.addChild(child);
        parent.run();

        system.update(0.016); // Parent tries to stop, child still running
        assertFalse(parent.completed);
        assertFalse(child.completed);

        system.update(0.016); // Child completes, parent can now complete
        assertTrue(child.completed);
        assertTrue(parent.completed);
    }
}