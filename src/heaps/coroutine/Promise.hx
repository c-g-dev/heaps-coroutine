package heaps.coroutine;

private enum PromiseState {
    Pending;
    Fulfilled(?value: Any);
    Rejected(?error: Any);
}

class Promise {
    var state: PromiseState = Pending;
    var thenHandlers: Array<(Any) -> Void> = [];
    var catchHandlers: Array<(Any) -> Void> = [];
    var finallyHandlers: Array<() -> Void> = [];

    public function new(?executor: ((?value: Any) -> Void, (?error: Any) -> Void) -> Void) {
        try {
            if(executor != null){
                executor(fulfill, reject);
            }
        } catch (e) {
            reject(e);
        }
    }

    public function fulfill(?value: Any) {
        if (state != Pending) return;
        state = Fulfilled(value);
        for (handler in thenHandlers) {
            handler(value);
        }
        runFinallyHandlers();
    }

    public function reject(?error: Any): Void {
        if (state != Pending) return;
        state = Rejected(error);
        for (handler in catchHandlers) {
            handler(error);
        }
        runFinallyHandlers();
    }

    function runFinallyHandlers() {
        for (handler in finallyHandlers) {
            handler();
        }
    }

    public function then<T>(onFulfilled: (value: Any) -> T): Promise {
        return new Promise((resolve, reject) -> {
            switch state {
                case Pending:
                    thenHandlers.push(value -> {
                        try {
                            var result = onFulfilled(value);
                            if (Std.isOfType(result, Promise)) {
                                (cast result : Promise).then(resolve).catchError(reject);
                            } else {
                                resolve(result);
                            }
                        } catch (e) {
                            reject(e);
                        }
                    });
                case Fulfilled(value):
                    try {
                        var result = onFulfilled(value);
                        if (Std.isOfType(result, Promise)) {
                            (cast result : Promise).then(resolve).catchError(reject);
                        } else {
                            resolve(result);
                        }
                    } catch (e) {
                        reject(e);
                    }
                case Rejected(error):
                    reject(error);
            }
        });
    }

    public function catchError(onRejected: Any -> Void): Promise {
        return new Promise((resolve, reject) -> {
            switch state {
                case Pending: {
                    catchHandlers.push(error -> {
                        try {
                            onRejected(error);
                            resolve();
                        } catch (e) {
                            reject(e);
                        }
                    });
                }
                case Fulfilled(value):
                    resolve(value);
                case Rejected(error):
                    try {
                        onRejected(error);
                        resolve();
                    } catch (e) {
                        reject(e);
                    }
            }
        });
    }

    public function finally(onFinally: () -> Void): Promise {
        finallyHandlers.push(onFinally);
        return this;
    }

    // Coroutine integration
    public function toCoroutine(): Coroutine {
        return (dt: Float) -> {
            switch state {
                case Pending:
                    return WaitNextFrame;
                case Fulfilled(_):
                    return Stop;
                case Rejected(error):
                    throw error;
            }
        }
    }

    public static function fromCoroutine(coroutine: Coroutine): Promise {
        return new Promise((resolve, reject) -> {
            var runner: Coroutine = (dt: Float) -> {
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
        });
    }

    public static function all(promises: Array<Promise>): Promise {
        return new Promise((resolve, reject) -> {
            var results = new Array<Any>();
            var completed = 0;
            var total = promises.length;

            if (total == 0) {
                resolve([]);
                return;
            }

            for (i in 0...total) {
                promises[i].then(result -> {
                    results[i] = result;
                    completed++;
                    if (completed == total) {
                        resolve(results);
                    }
                }).catchError(error -> {
                    reject(error);
                });
            }
        });
    }

    public static function race(promises: Array<Promise>): Promise {
        return new Promise((resolve, reject) -> {
            for (promise in promises) {
                promise.then(resolve).catchError(reject);
            }
        });
    }

    public static function resolve() {
        return new Promise((resolve, reject) -> {
            resolve(null);
        });
    }
} 