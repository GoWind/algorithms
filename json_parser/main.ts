import { json } from './PrimitiveJsonParser.ts';

let data = await Deno.readTextFile('random.json');
//your text editor like vim can sneakily add a newline character to the 
//file `random.json`. Thus always trim the end of the file content read
//as string
let dataAsJSON = json.parseStringToCompletion(data.trimEnd());

console.log(`${JSON.stringify(data)}`);
