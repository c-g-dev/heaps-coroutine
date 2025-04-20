package heaps.coroutine;

typedef Coroutine = (dt: Float) -> FrameYield;

enum FrameYield {
    WaitNextFrame;
    WaitFrames(f: Int);
    WaitSeconds(f: Float);
    Stop;
    Suspend(waitForCoroutineUUID: String);
}

enum abstract CoroutinePriority(Int) from Int to Int {
    var Controls = 0;
    var Processing = 1;
    var Rendering = 2;
}

enum CoroutineOption {
    Priority(p: Int);
    OnStart(cb: Void -> Void);
    OnComplete(cb: Void -> Void);
}
