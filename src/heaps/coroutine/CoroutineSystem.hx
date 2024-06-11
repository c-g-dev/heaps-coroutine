package heaps.coroutine;

import heaps.coroutine.Coroutine.CoroutineOption;
import heaps.coroutine.Coroutine.CoroutineOnFrameResult;
import heaps.coroutine.Coroutine.CoroutinePriority;
import haxe.Timer;
import ludi.commons.util.UUID;
import hxd.System;

class CoroutineSystem {
    public static var FRAME_ID = 0;
    public static var MAIN = new CoroutineSystem();
    var routines: Map<String, InternalCoroutineContext> = [];
    var routinesByPriority: Map<CoroutinePriority, Array<String>> = [];
    var suspendedDependentRoutines: Map<String, Array<InternalCoroutineContext>> = [];

    public function new() {
        routinesByPriority[Controls] = [];
        routinesByPriority[Processing] = [];
        routinesByPriority[Rendering] = [];
    }

    var didInit: Bool = false;
    var isWiredToMainLoop: Bool = false;
    private function init() {
        if(!didInit){
            #if coroutine_manual_wiring
            #else
            wireCoroutineSystemToMainLoop(MAIN);
            #end
            didInit = true;
        }
    }

    private static var CurrentLoopFunction: Void -> Void;
    private static var RegisteredLoopFunc: Void -> Void;
    private static function wireCoroutineSystemToMainLoop(system: CoroutineSystem) {
        Timer.delay(() -> {
            if((System.getCurrentLoop() != CurrentLoopFunction) || CurrentLoopFunction == null){
                RegisteredLoopFunc = System.getCurrentLoop();
                CurrentLoopFunction = () -> {
                    RegisteredLoopFunc();
                    system.update(hxd.Timer.dt);
                }
                System.setLoop(CurrentLoopFunction);
                system.isWiredToMainLoop = true;
            }
        }, 0);
    }

    var routinesToRemove: Array<CoroutineContextResult> = [];
    var eachFireResult: CoroutineContextResult = null;
    var eachRoutine: InternalCoroutineContext;
    public function update(dt: Float) {
        FRAME_ID++;
        routinesToRemove = [];
        for(currentRoutines in routinesByPriority){
            for(eachRoutineTag in currentRoutines){
                eachRoutine = routines[eachRoutineTag];
                if(eachRoutine.checkIfShouldFire(dt)){
                    eachFireResult = eachRoutine.fire(dt);
                    switch eachFireResult {
                        case Dispose(_) | Suspend(_, _): {
                            routinesToRemove.push(eachFireResult);
                        }
                        default:
                    }
                }
            }
        }
        for (r in routinesToRemove) {
            switch r {
                case Dispose(cc): {
                    routines.remove(cc.tag);
                    routinesByPriority[cc.priority].remove(cc.tag);
                    if(suspendedDependentRoutines.exists(cc.tag)){
                        for (cc in suspendedDependentRoutines.get(cc.tag)) {
                            routines[cc.tag] = cc;
                            routinesByPriority[cc.priority].push(cc.tag);
                        }
                        suspendedDependentRoutines.remove(cc.tag);
                    }
                }
                case Suspend(context, waitForCoroutine): {
                    suspend(context.tag, waitForCoroutine);
                }
                default:
            }
           
           
        }
    }

    
    public function add(cb: (Float) -> CoroutineOnFrameResult, ?ops: Array<CoroutineOption>): String {
        init();
        var cc = new InternalCoroutineContext(cb, ops);
        routines[cc.tag] = cc;
        routinesByPriority[cc.priority].push(cc.tag);
        return cc.tag;
    }

    public function remove(tag: String) {
        var cc = routines[tag];
        routines.remove(tag);
        routinesByPriority[cc.priority].remove(tag);
    }

    public function suspend(tagToSuspend: String, dependentTag: String) {
        var cc = routines[tagToSuspend];
        remove(tagToSuspend);
        if(!suspendedDependentRoutines.exists(dependentTag)){
            suspendedDependentRoutines[dependentTag] = [];
        }
        suspendedDependentRoutines[dependentTag].push(cc);
    }

    
}

class InternalCoroutineContext {
    public var tag: String; 
    public var priority: CoroutinePriority = Processing;
    public var args: Dynamic;

    var didStart: Bool = false;
    var framesToWait: Int = 0;
    var timeToWait: Float = 0;
    var lastResult: CoroutineOnFrameResult = null;

    var onStart: Void -> Void = null;
    var onComplete: Void -> Void = null;
    var onFrame: (Float) -> CoroutineOnFrameResult = null;
    
    public function new(onFrame: (Float) -> CoroutineOnFrameResult, options: Array<CoroutineOption>) {
      this.tag = UUID.generate();
      this.onFrame = onFrame;
      if(options != null){
        for (option in options) {
            switch option {
                case Priority(p): {
                    priority = p;
                }
                case OnStart(cb): {
                    onStart = cb;
                }
                case OnComplete(cb): {
                    onComplete = cb;
                }
            }
          }
      }
    }

    public function checkIfShouldFire(dt: Float): Bool {
        if(this.lastResult == null){
            return true;
        }
        switch this.lastResult {
            case Suspend(_): {
                return true;
            }
            case Stop: {
                return false;
            }
            case WaitNextFrame: {
                return true;
            }
            case WaitFrames(f): {
                if(this.framesToWait > 0){
                    this.framesToWait -= 1;
                    return false;
                }
                return true;
            }
            case WaitSeconds(f): {
                if(this.timeToWait > 0){
                    this.timeToWait -= dt;
                    return false;
                }
                return true;
            }
        }
        return false;
    }

    public function fire(dt: Float): CoroutineContextResult {
        if(!didStart && (onStart != null)){
            onStart();
            didStart = true;
        }
        if(onFrame != null){
            lastResult = onFrame(dt); 
            switch lastResult {
                case WaitFrames(f): {
                    this.framesToWait = f;
                }
                case WaitSeconds(f): {
                    this.timeToWait = f;
                }
                default:
            }
        }
        switch lastResult {
            case Suspend(waitForCoroutine): return Suspend(this, waitForCoroutine);
            case Stop: return Dispose(this);
            default: return Retain;
        }
    }
    
}

enum CoroutineContextResult {
    Retain;
    Dispose(context: InternalCoroutineContext);
    Suspend(context: InternalCoroutineContext, waitForCoroutine: String);
}


function StartCoroutine<T>(cb: (Float) -> CoroutineOnFrameResult, ?ops: Array<CoroutineOption>): String {
    return CoroutineSystem.MAIN.add(cb, ops);
}

function StopCoroutine<T>(tag: String): Void {
    return CoroutineSystem.MAIN.remove(tag);
}
