package heaps.coroutine.effect;

import heaps.coroutine.CoroutineSystem.StartCoroutine;
import ludi.commons.messaging.Topic;
import heaps.coroutine.Coroutine.CoroutineOnFrameResult;

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

    var currentResult: CoroutineOnFrameResult;
    function update(dt: Float): CoroutineOnFrameResult {
      //  trace("update: " + this + " num children: " + children.length);
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
         //   trace(effect + " effect.seqGroup: " + effect.seqGroup + " this.currentSeqGroup: " + this.currentSeqGroup);
            if(effect.seqGroup == this.currentSeqGroup){
                if(!effect.isComplete){
                   
                    //trace("executing in effect: " + this + " child: " + effect);
                    updateResult = (effect.update(edt) == Stop) && updateResult;
                }
                else{
                  //  trace("not executing " + effect + " in " + this + " because it is complete");
                }
                childrenInSeqGroup++;
            }
            if(effect.isCompleteInternal && effect.isComplete){
             //   trace("effect.isCompleteInternal: " + effect.isCompleteInternal + " effect.isComplete: " + effect.isComplete);
                if(effect.seqGroup == this.currentSeqGroup){
                    completedChildrenInSeqGroup++;
                }
                completedChildren++;
            }
        }

        if(completedChildrenInSeqGroup == childrenInSeqGroup){
            this.currentSeqGroup++;
        }

        currentResult = (updateResult && (completedChildren == this.children.length)) ? {
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

    function onUpdate(dt: Float): CoroutineOnFrameResult {
        return Stop;
    }

    function onComplete() {
        
    }

    public function addChild(child: Effect) {
        this.children.push(child);
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
}

enum EffectEvent {
    Start;
    Complete;
}