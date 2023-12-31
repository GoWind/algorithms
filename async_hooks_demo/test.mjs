import redis from 'ioredis';
import fs from 'fs';
const { fd } = process.stdout;
import async_hooks from 'async_hooks';

let trackingMap = new Map();
function mystacktracefunction(error, callsites) {
  let stackTrace = "";
  for(const site of callsites) {
    const filename = site.getFileName();
     stackTrace += `${site.getFunctionName()} : ${site.getFileName()} : ${site.getLineNumber()} \n`;
       
  }
  return stackTrace;
}

Error.prepareStackTrace = mystacktracefunction;

function showMeTheCulprit(fd) {
  for(const key of trackingMap.keys()) {
    let {type, triggerAsyncId, err, resource} = trackingMap.get(key);
    if(typeof resource.hasRef == "function" && resource.hasRef()) {
      fs.writeSync(fd, `maybe resource holding up is ${key} with parent ${triggerAsyncId} \n ${err.stack}`);   
    }
  }
}

function init(asyncId, type, triggerAsyncId, resource) {
    var err = new Error(`${asyncId}-${type}`);
    trackingMap.set(asyncId, {type, triggerAsyncId, err, resource});
}

function destroy(asyncId) {
    fs.writeSync(fd, `Destroy callback async id -->${asyncId} \n`);
    if(trackingMap.has(asyncId)) {
      trackingMap.delete(asyncId);
    }
}

const asyncHook = async_hooks.createHook({ init: init, destroy });
asyncHook.enable();
/*
setTimeout(() => {
  fs.writeSync(fd, `function run after timeout \n`);
}, 1000);
var p = new Promise((res, rej) => {
  res(4);
});

setImmediate(() => {
  fs.writeSync(fd, `immediately I die`);
});
fs.write(process.stderr.fd, "jajax", () => { });
// fetch("https://www.google.com", () => { fs.writeSync(fd, `after fetch callback`);});

var p = new Promise((res, rej) => {
});

let k = p.then((v) => { fs.writeSync(fd, `the callback after our promise is called`)});
await k;
*/

// only timeouts, immediates have a `hasRef` method to indicate that they keep the event loop alive
// https://nodejs.org/api/timers.html#timers
// let g = setInterval(() => { fs.writeSync(fd, `calling this fn in intervals`)}, 2000);

// setTimeout(() => { fs.writeSync(fd, `clearing the previously set timeout`); clearTimeout(g);}, 10000);

process.on('SIGUSR1', () => { console.log("captured sigterm") ; showMeTheCulprit(fd)});
let client = new redis.Redis({host: "localhost", port: 6379});

