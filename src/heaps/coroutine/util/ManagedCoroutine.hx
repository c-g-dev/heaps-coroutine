package heaps.coroutine.util;

import heaps.coroutine.CoroutineSystem.StartCoroutine;
import heaps.coroutine.Coroutine.CoroutineOnFrameResult;


class ManagedCoroutine {

    var cb: (ManagedCoroutine) -> CoroutineOnFrameResult;

    public var dt: Float;
    public var elapsedTime: Float;
    public var isFirstIteration: Bool = true;
    public var elapsedFrames: Int = 0;

    public var uuid: String;
    public var didStart: Bool = false;
    private var completeCallback: Void -> Void;


    public function new(cb: (ManagedCoroutine) -> CoroutineOnFrameResult) {
        this.cb = cb;
    }

    function update(dt: Float): CoroutineOnFrameResult {
        this.dt = dt;
        var r = cb(this);
        elapsedFrames++;
        if(isFirstIteration){
            isFirstIteration = false;
        }
        else{
            elapsedTime += dt;
        }
        switch r {
            case Stop: {
                if (completeCallback != null) { completeCallback(); }
            }
            default:
        }
        return r;
    }

    public function start() {
        if(didStart) return;
        didStart = true;
        this.uuid = StartCoroutine(update);
    }

    public function onComplete(cb: Void -> Void): ManagedCoroutine {
        this.completeCallback = cb;
        return this;
    }
}