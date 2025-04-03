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

    public static function RunWhen(checkFunc: Void -> Bool, callb: Void -> Void): ManagedCoroutine {
        return new ManagedCoroutine((info) -> {
           if(checkFunc()){
               callb();
               return Stop;
           }
           return WaitNextFrame;
        });
    }
}