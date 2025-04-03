package heaps.coroutine.effect;

import heaps.coroutine.Coroutine.CoroutineOnFrameResult;

class EffectGroup extends Effect {
    var orientation: EffectGroupOrientation;

    public function new(orientation: EffectGroupOrientation) {
        super();
        this.orientation = orientation;
    }

    override function update(dt: Float): CoroutineOnFrameResult {
        //trace("EffectGroup update " + orientation);
        return super.update(dt);
    }

    public override function addChild(child:Effect) {
        switch (orientation) {
            case Sequential: {
                child.seqGroup = this.children.length;
            }
            case Concurrent: {
                // seqGroup remains the default, which is 0
            }
        }
        super.addChild(child);
    }
}

enum EffectGroupOrientation {
    Sequential;
    Concurrent;
}