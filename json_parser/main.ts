import { json } from './JsonParser.ts';

let data = await Deno.readTextFile('random.json');

let dataAsJSON = json.parseStringToCompletion(data);

console.log(`${JSON.stringify(data)}`);
