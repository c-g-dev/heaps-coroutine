package heaps.coroutine.helpers;

class CoroutineExtensions {
    public static function run(coroutine:Coroutine):Void {
        StartCoroutine(coroutine);
    }

    public static function toPromise(coroutine:Coroutine, ?start:Bool = true):Promise {
        return new Promise((resolve, reject) -> {
            var wrappedCoroutine = (dt:Float) -> {
                try {
                    var result = coroutine(dt);
                    switch result {
                        case Stop:
                            resolve(null);
                            return Stop;
                        case WaitNextFrame, WaitFrames(_), WaitSeconds(_), Suspend(_):
                            return result;
                    }
                } catch (e) {
                    reject(e);
                    return Stop;
                }
            }
            if(start) {
                StartCoroutine(wrappedCoroutine);
            }
        });
    }
}


