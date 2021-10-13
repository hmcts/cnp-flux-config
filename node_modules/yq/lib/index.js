/**
 * @author Boom.Lee <boom11235.gg@gmail.com>
 * Idea from: http://www.2ality.com/2015/03/no-promises.html
 */

/**
 * Check if a generator object
 *
 * @param {Object} obj
 * @returns {Boolean}
 */
function _isGenerator (obj) {
  return typeof obj.next === 'function' && typeof obj.throw === 'function'
}

/**
 * Run generator object to make up async control-flow
 * Get result via the callbacks
 *
 * @param {Generator} gen
 * @param {Object} callbacks
 * @param {Function} callbacks.success Handle async success.
 * @param {Function} callbacks.fail
 * @returns
 */
function runGenObj(gen, callbacks) {
  handleNext()
  
  /**
   * Handle the generator.next, mainly check if done or error.
   *
   * @param {Mixed} prev Last iteration's result.
   */
  function handleNext(prev) {
    try {
      var yielded = gen.next(prev)
      
      if (yielded.done) {
        if (yielded.value !== undefined) {
          callbacks.success(yielded.value)
        }
      } else {
        runYielded(yielded.value)
      }
    } catch (err) {
      if (callbacks) {
        callbacks.fail(err)
      } else {
        throw err
      }
    }
  }
  
  /**
   * Handle yielded value.
   * To return noraml, handle array in parallel, or call `runGenObj` to handle generator.
   *
   * @param {Mixed} value From last `next()`.
   */
  function runYielded(value) {
    if (value === undefined) {
      handleNext(callbacks)
    } else if (Array.isArray(value)) {
      runInParallel(value)
    } else if (_isGenerator(value)){
      runGenObj(value, {
        success: function (re) {
          handleNext(re)
        },
        fail: function (err) {
          gen.throw(err)
        }
      })
    } else {
      handleNext(value)
    }
  }
  
  /**
   * Handle array in parallel.
   * Diff generator and normal value. Count to call `handleNext`
   *
   * @param {Array} array
   */
  function runInParallel(array) {
    var len = array.length
    var count = len
    var results = new Array(len)
    
    // Make function out of loop.
    function _runGen(index) {
      var value = array[index]
      if (_isGenerator(value)) {
        runGenObj(value, {
          success: function (result) {
            results[index] = result
            count--
            if (count <= 0) {
              handleNext(results)
            }
          },
          fail: function (err) {
            gen.throw(err)
          }
        })
      } else {
        results[index] = value
        count--
        if (count <= 0) {
          handleNext(results)
        }
      }
    }
    
    for (var i = 0; i < len; i++) {
      _runGen(i)
    }
  }
}

/**
 * Just exports like co/Q.spawn, to run the generatorFunction.
 *
 * @param {GeneratorFunction} genFunc
 * @param {Object}
 * @param {Function} callbacks.success
 * @param {Function} callbacks.fail
 */
function run(genFunc, callbacks) {
  runGenObj(genFunc(), callbacks)
}

var context = this

/**
 * Wrap generator function to pass arguments.
 *
 * @param {GeneratorFunction} genFunc
 * @param {Object}
 * @param {Function} callbacks.success
 * @param {Function} callbacks.fail
 * @returns {Function} Used to pass arguments.
 */
run.wrap = function wrap(genFunc, callbacks) {
  return function () {
    runGenObj(genFunc.call(context, arguments), callbacks)
  }
}

/**
 * Transform async function to yieldable generator function.
 * Just for callback(error, data ...), others may throw error.
 *
 * @param {Function} func
 * @returns {GeneratorFunction}
 */
run.yield = function (func, ctx) {
  return function *() {
    var args = [].slice.call(arguments, 0)
    var caller = yield undefined
    
    args.push(function (error) {
      if (error) {
        caller.fail(error)
      } else {
        caller.success.apply(caller, [].slice.call(arguments, 1))
      }
    })
    
    func.apply(ctx || context, args)
  }
}

module.exports = run
