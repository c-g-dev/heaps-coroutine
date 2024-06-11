package heaps.coroutine.util;

class CommonCoroutines {
    public static function Wait(t: Float): ManagedCoroutine {
        return new ManagedCoroutine((info) -> {
            if(info.elapsedTime >= t){
                return Stop;
            }
            return WaitNextFrame;
        });
    }
}