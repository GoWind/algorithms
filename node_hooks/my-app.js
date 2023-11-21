import { hello } from './my-app-x';
import crypto from "node:crypto";
console.log(hello());
console.log(crypto.randomBytes(32).toString('hex'));
