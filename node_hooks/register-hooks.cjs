const { register } = require('node:module');
const { pathToFileURL } = require('node:url');

const { port1, port2 } = new MessageChannel();

const pfUrl = pathToFileURL(__filename);
console.log(pfUrl);
register('./hooks.mjs', {parentURL: pfUrl.href, data: {number: 1, port: port2 }, transferList: [port2]});
