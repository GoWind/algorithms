### Toy JSON parser
A parser for JSON written using PEG grammar. 
The code is implemented in deno flavored Typescript

While reading this book on how to [build](https://keleshev.com/compiling-to-assembly-from-scratch/) a compiler, I 
got very interested in using PEG to parse JSON, so decided to do an experiment. 


You can test the parser by running `deno run --allow-read main.ts`.

To be more thorough, you can generate more JSON fro [json-generator](https://json-generator.com/#) and run the generated
JSON against the parser here to find potential bugs in the implementation. 


The code consists of 3 files:

1. `ParserBase.ts` - Provides the basic combinators for a PEG parser.
2. `JsonParser.ts` - Provides uses the building blocks from `ParserBase` to provide an AST of the parsed JSON.
3. `JsonTypes.ts` - Provides the types specified in the json [spec](json.org). 

The parser parses the JSON into the type that implement `JSONElement` in `JSONTypes` rather than into the primitives or native types (array, object in js). Needless to say, creating an object for each primitive type is inefficient, but this is just a toy parser
for the purpose of understanding how PEG parsers work.

An interesting future experiment would be: 

1. Using this parser to emit primitives like `boolean` , `number`, `string` instead of types like `JBoolean`, `JNumber`, `JString` etc.
   This should not be too tricky and will only required fiddling with the type annotations in the code.
2. Comparing this against a custom recursive descent parser to see how fast (or slow) this might be.



