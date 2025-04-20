package heaps.coroutine.effect;

import heaps.coroutine.effect.Effects.CoroutineAsEffect;
import heaps.coroutine.CoroutineSystem.StartCoroutine;
import ludi.commons.messaging.Topic;
import heaps.coroutine.Coroutine.FrameYield;

typedef Easing = Float -> Float;

class Effect {
    public var children: Array<Effect> = [];
    public var easing: Easing;
    public var seqGroup: Int = 0;
    public var isComplete: Bool = false;
    public var topic: Topic<EffectEvent> = new Topic();
    
    public var elapsedTime: Float = 0;
    public var elapsedFrames: Int = 0;

    var isCompleteInternal: Bool;
    var hasStarted: Bool;
    var currentSeqGroup: Int = 0;

    var updateResult: Bool = true;
    var completedChildren = 0;
    var childrenInSeqGroup = 0;
    var completedChildrenInSeqGroup = 0;

    public function new() {
        
    }

    var currentResult: FrameYield;
    public function update(dt: Float): FrameYield {
        var edt = (easing != null) ? easing(dt) : dt;
        updateResult = true;

        elapsedFrames++;

        if(!hasStarted){
            hasStarted = true;
            onStart();
            topic.notify(Start);
        }
        else {
            elapsedTime += dt;
        }

        if(!isCompleteInternal){
            isCompleteInternal = (onUpdate(edt) == Stop);
            updateResult = isCompleteInternal;
        }

        completedChildren = 0;
        childrenInSeqGroup = 0;
        completedChildrenInSeqGroup = 0;
        for (effect in children) {
            if(effect.seqGroup == this.currentSeqGroup){
                if(!effect.isComplete){
                    updateResult = (effect.update(edt) == Stop) && updateResult;
                }
                else{
                  
                }
                childrenInSeqGroup++;
            }
            if(effect.isCompleteInternal && effect.isComplete){
                if(effect.seqGroup == this.currentSeqGroup){
                    completedChildrenInSeqGroup++;
                }
                completedChildren++;
            }
        }

        if(completedChildrenInSeqGroup == childrenInSeqGroup){
            this.currentSeqGroup++;
        }

        currentResult = (updateResult && (completedChildren >= this.children.length)) ? {
            isComplete = true;
            topic.notify(Complete);    
            Stop;
        } : WaitNextFrame;

        if(currentResult == Stop) {
            onComplete();
        }

        return currentResult;
    }

    public function forceStop() {
        currentResult = Stop;
        isComplete = true;
        completedChildren = this.children.length;

        for (effect in this.children) {
            effect.forceStop();
        }
        
        topic.notify(Complete);
    }

    function onStart(): Void {
        
    }

    function onUpdate(dt: Float): FrameYield {
        return Stop;
    }

    function onComplete() {
        
    }

    public function addChild(child: Effect) {
        this.children.push(child);
        child.seqGroup = this.currentSeqGroup;
    }

    public function removeChild(child: Effect) {
        this.children.splice(this.children.indexOf(child), 1);
    }

    public function run(): Void {
        StartCoroutine(toCoroutine());
    }

    public function toCoroutine(): Coroutine {
        return (dt) -> {
            this.update(dt);
            if(this.isComplete){
                return Stop;
            }
            return WaitNextFrame;
        };
    }

    public function addChildren(children: Array<Effect>) {
        for (child in children) {
            this.addChild(child);
        }
    }

    public static function from(cb: Float -> FrameYield): Effect {
        return new CoroutineAsEffect(cb);
    }
}

enum EffectEvent {
    Start;
    Complete;
}