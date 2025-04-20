import heaps.coroutine.Coroutine.CoroutinePriority;
import heaps.coroutine.CoroutineSystem;

class CoroutineTests {
    public static function main() {
        var runner = new CoroutineTests();
        runner.runAllTests();
    }

    public function new() {}

    public function runAllTests() {
        var tests = [
            { name: "testStartCoroutineSmoke", func: testStartCoroutineSmoke },
            { name: "testStopCoroutineSmoke", func: testStopCoroutineSmoke },
            { name: "testWaitNextFrame", func: testWaitNextFrame },
            { name: "testWaitFrames", func: testWaitFrames },
            { name: "testWaitSeconds", func: testWaitSeconds },
            { name: "testStopYield", func: testStopYield },
            { name: "testSuspend", func: testSuspend },
            { name: "testPriorities", func: testPriorities },
            { name: "testOnStart", func: testOnStart },
            { name: "testOnComplete", func: testOnComplete },
            { name: "testOptionsCombined", func: testOptionsCombined }
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

    // Assertion helpers to replace framework assertions
    function assertEquals<T>(expected:T, actual:T, ?msg:String) {
        if (expected != actual) {
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

    // Test functions (bodies as previously provided, included for reference but not modified)
    function testStartCoroutineSmoke() {
        var system = CoroutineSystem.MAIN;
        var counter = 0;
        var tag = system.add((dt) -> {
            counter++;
            if (counter < 3) {
                return WaitNextFrame;
            } else {
                return Stop;
            }
        });

        system.update(0.016);
        assertEquals(1, counter);

        system.update(0.016);
        assertEquals(2, counter);

        system.update(0.016);
        assertEquals(3, counter);

        system.update(0.016);
        assertEquals(3, counter);
    }

    function testStopCoroutineSmoke() {
        var system = CoroutineSystem.MAIN;
        var counter = 0;
        var tag = system.add((dt) -> {
            counter++;
            return WaitNextFrame;
        });

        system.update(0.016);
        assertEquals(1, counter);

        system.update(0.016);
        assertEquals(2, counter);

        system.remove(tag);

        system.update(0.016);
        assertEquals(2, counter);
    }

    function testWaitNextFrame() {
        var system = CoroutineSystem.MAIN;
        var counter = 0;
        var tag = system.add((dt) -> {
            counter++;
            if (counter < 3) {
                return WaitNextFrame;
            } else {
                return Stop;
            }
        });

        system.update(0.016);
        assertEquals(1, counter);

        system.update(0.016);
        assertEquals(2, counter);

        system.update(0.016);
        assertEquals(3, counter);
    }

    function testWaitFrames() {
        var system = CoroutineSystem.MAIN;
        var counter = 0;
        var tag = system.add((dt) -> {
            counter++;
            return WaitFrames(2);
        });

        system.update(0.016);
        assertEquals(1, counter);

        system.update(0.016);
        assertEquals(1, counter);

        system.update(0.016);
        assertEquals(1, counter);

        system.update(0.016);
        assertEquals(2, counter);
    }

    function testWaitSeconds() {
        var system = CoroutineSystem.MAIN;
        var timesRun = 0;
        var tag = system.add((dt) -> {
            timesRun++;
            if (timesRun == 1) {
                return WaitSeconds(1.0);
            } else {
                return Stop;
            }
        });

        system.update(0.016);
        assertEquals(1, timesRun);

        system.update(0.5);
        assertEquals(1, timesRun);

        system.update(0.5);
        system.update(0.5);
        assertEquals(2, timesRun);

        system.update(0.016);
        assertEquals(2, timesRun);
    }

    function testStopYield() {
        var system = CoroutineSystem.MAIN;
        var counter = 0;
        var tag = system.add((dt) -> {
            counter++;
            return Stop;
        });

        system.update(0.016);
        assertEquals(1, counter);

        system.update(0.016);
        assertEquals(1, counter);
    }

    function testSuspend() {
        var system = CoroutineSystem.MAIN;
        var aTimesRun = 0;
        var bRan = 0;

        var tagB = system.add((dt) -> {
            bRan++;
            if (bRan < 3) {
                return WaitNextFrame;
            } else {
                return Stop;
            }
        });

        var tagA = system.add((dt) -> {
            aTimesRun++;
            if (aTimesRun == 1) {
                return Suspend(tagB);
            } else {
                return Stop;
            }
        });

        system.update(0.016);
        assertEquals(1, aTimesRun);
        assertEquals(1, bRan);

        system.update(0.016);
        assertEquals(1, aTimesRun);
        assertEquals(2, bRan);

        system.update(0.016);
        assertEquals(1, aTimesRun);
        assertEquals(3, bRan);

        system.update(0.016);
        assertEquals(2, aTimesRun);
    }

    function testPriorities() {
        var system = CoroutineSystem.MAIN;
        var order = [];

        var tag1 = system.add((dt) -> {
            order.push("Controls");
            return Stop;
        }, [Priority(Controls)]);

        var tag2 = system.add((dt) -> {
            order.push("Processing");
            return Stop;
        }, [Priority(Processing)]);

        var tag3 = system.add((dt) -> {
            order.push("Rendering");
            return Stop;
        }, [Priority(Rendering)]);

        system.update(0.016);
        assertEquals(["Controls", "Processing", "Rendering"].join("."), order.join("."));
    }

    function testOnStart() {
        var system = CoroutineSystem.MAIN;
        var started = false;
        var tag = system.add((dt) -> {
            return Stop;
        }, [OnStart(() -> started = true)]);

        system.update(0.016);
        assertTrue(started);
    }

    function testOnComplete() {
        var system = CoroutineSystem.MAIN;
        var completed = false;
        var tag = system.add((dt) -> {
            trace("testOnComplete coroutine");
            return Stop;
        }, [OnComplete(() -> {
            completed = true;
        })]);

        system.update(0.016);
        system.update(0.016);
        assertTrue(completed);
    }

    function testOptionsCombined() {
        var system = CoroutineSystem.MAIN;
        var started = false;
        var order = [];

        var tag1 = system.add((dt) -> {
            order.push("Controls");
            return Stop;
        }, [Priority(Controls), OnStart(() -> started = true)]);

        var tag2 = system.add((dt) -> {
            order.push("Rendering");
            return Stop;
        }, [Priority(Rendering)]);

        system.update(0.016);
        assertTrue(started);
        assertEquals(["Controls", "Rendering"].join("."), order.join("."));
    }
}