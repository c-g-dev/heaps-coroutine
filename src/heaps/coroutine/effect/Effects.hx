package heaps.coroutine.effect;

import heaps.coroutine.Coroutine.CoroutineOnFrameResult;
import heaps.coroutine.effect.EffectGroup.EffectGroupOrientation;

class Effects {
    public static function Sequential(effects: Array<Effect>): Effect {
        trace("Effects.Sequential: " + effects.length);
        var group = new EffectGroup(EffectGroupOrientation.Sequential);
        for (effect in effects) {
            group.addChild(effect);
        }
        return group;
    }

    public static function Concurrent(effects: Array<Effect>): Effect {
        trace("Effects.Concurrent: " + effects.length);
        var group = new EffectGroup(EffectGroupOrientation.Concurrent);
        for (effect in effects) {
            group.addChild(effect);
        }
        return group;
    }

    public static function Lazy(cb: () -> Effect): Effect {
        return new LazyEffect(cb);
    }

}


class StepsEffect extends Effect {
    public function new(steps: Array<Coroutine>) {
        super();
        var effectChildren: Array<Effect> = [];
        for (eachStep in steps) {
            effectChildren.push(new CoroutineAsEffect(eachStep));
            effectChildren.push(new WaitFramesEffect(10));
        }
        this.addChild(Effects.Sequential(effectChildren));
    }
}

class WaitFramesEffect extends Effect {
    var frames: Int;
    var counter: Int = 0;
    public function new(frames: Int) {
        super();
        this.frames = frames;
    }

    override function onUpdate(dt: Float): CoroutineOnFrameResult {
        if(counter < frames) {
            counter++;
            return WaitNextFrame;
        }
        return Stop;
    }
}

class CoroutineAsEffect extends Effect {
    var coroutine: Coroutine;
    public function new(coroutine: Coroutine) {
        super();
        this.coroutine = coroutine;
    }

    override function onUpdate(dt: Float): CoroutineOnFrameResult {
        return coroutine(dt);
    }
}

class RoutineEffect extends Effect {
    var onFrameCB: (RoutineEffect, Float) -> CoroutineOnFrameResult = (e, dt) -> {return Stop;}
    var onStartCB: RoutineEffect -> Void = (arg) -> {};
    var onEndCB: Void -> Void = () -> {};

    public var completeRoutine: Bool = false;

    public function new(opts: Array<RoutineEffectKinds>) {
        super();
        for (eachOpt in opts) {
            switch eachOpt {
                case MakeOnFrame(gen): {
                    onFrameCB = gen(this);
                }
                case OnFrame(cr): {
                    onFrameCB = cr;
                }
                case OnStart(cb): {
                    onStartCB = cb;
                }
                case OnComplete(cb): {
                    onEndCB = cb;
                }
            }
        }
    }

    override function onUpdate(dt: Float): CoroutineOnFrameResult {
        return onFrameCB(this, dt);
    }

    override function onStart(): Void {
        onStartCB(this);
    }

    override function onComplete(): Void {
        onEndCB();
    }
}

enum RoutineEffectKinds {
    MakeOnFrame(gen: (RoutineEffect) -> ((RoutineEffect, Float) -> CoroutineOnFrameResult));
    OnFrame(cr: (RoutineEffect, Float) -> CoroutineOnFrameResult);
    OnStart(cb: RoutineEffect -> Void);
    OnComplete(cb: Void -> Void);
}

class LazyEffect extends Effect {
    
    var cb: Void -> Effect = () -> {return null;};

    public function new(cb: Void -> Effect) {
        super();
        this.cb = cb;
    }
    override function onStart(): Void {
        var e = cb();
        if(e != null){
            this.addChild(e);
        }
    }

    override function onUpdate(dt:Float):CoroutineOnFrameResult {
        return Stop;
    }
}

class DoNothingEffect extends Effect {

    override function onUpdate(dt:Float):CoroutineOnFrameResult {
        return Stop;
    }
}

class DoAsEffect extends Effect {
    
    var cb: Void -> Void = () -> {};

    public function new(cb: Void -> Void) {
        super();
        this.cb = cb;
    }

    override function onUpdate(dt:Float):CoroutineOnFrameResult {
        cb();
        return Stop;
    }
}

abstract class CompletableEffect extends Effect {

    public override function forceStop() {
        if(!hasStarted){
            hasStarted = true;
            onStart();
            topic.notify(Start);
        }
        setFinalState();
        super.forceStop();
    }
    
    public abstract function setFinalState(): Void;
}

abstract class ContinuousEffect extends Effect {
    public override function onUpdate(dt: Float): CoroutineOnFrameResult {
        onFrame(dt);
        return WaitNextFrame;
    }
    
    public abstract function onFrame(dt: Float): Void;
}
