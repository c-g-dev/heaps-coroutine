package heaps.coroutine.util;

import heaps.coroutine.Coroutine.CoroutineOption;
import heaps.coroutine.CoroutineSystem.StartCoroutine;

class ObjectCoroutine extends h2d.Object {

    var isRemoved: Bool = false;
    var internalCoroutine: Coroutine;
    var options: Array<ObjectCoroutineOption>;
    var eventListeners: Array<ObjectCoroutineEvent -> Void> = [];
    
    public function new(cr: Coroutine, ?options: Array<ObjectCoroutineOption>) {
        super();
        this.options = options != null ? options : [];
        
        internalCoroutine = (dt) -> {
            if(isRemoved){
                return Stop;
            }
            return cr(dt);
        };

        // Handle options
        for (option in this.options) {
            switch option {
                case RetainOnStop: {
                    internalCoroutine = cr;
                }
                case EventListener(cb): {
                    eventListeners.push(cb);
                }
                default:
            }
        }
    }

    override function onAdd() {
        super.onAdd();
        triggerEvent(ObjectCoroutineEvent.OnThisAttached);
        var co: Array<CoroutineOption> = [];

        for (option in this.options) {
            switch option {
                case Priority(p): {
                    co.push(Priority(p));
                }
                default:
            }
        }
        StartCoroutine(internalCoroutine, [
            OnStart(() -> {triggerEvent(OnCoroutineStart);}),
            OnComplete(() -> {triggerEvent(OnCoroutineStopped);}),
        ]);
    }

    override function onRemove() {
        super.onRemove();
        triggerEvent(ObjectCoroutineEvent.OnRemove);
        isRemoved = true;
    }

    function triggerEvent(event: ObjectCoroutineEvent) {
        for (listener in eventListeners) {
            listener(event);
        }
    }
}

enum ObjectCoroutineOption {
    Priority(p: Int);
    RetainOnStop;
    EventListener(cb: ObjectCoroutineEvent -> Void);
}

enum ObjectCoroutineEvent {
    OnThisAttached;
    OnRemove;
    OnCoroutineStart;
    OnCoroutineStopped;
    Custom(payload: Dynamic);
}