interface IParser<T> {
  // Why a Source and not just a string ? 
  // Ans: We need to keep track of the index into the string from which we are 
  // trying to match something. Hence.
  // Also, source can be anything tomorrow (a file, a socket etc) parse(s: Source): ParseResult<T> | null;
}

export class Source {
  constructor(public string: string, 
              public index: number) {}
  match(regexp: RegExp): (ParseResult<string> | null) {
    console.assert(regexp.sticky);
    regexp.lastIndex = this.index;
    let match = this.string.match(regexp);
    //  Be careful here with your regexes. The 
    //  regex might match but with an empty string, instead
    //  of a pattern that you are expecting. In such a case
    //  match will be non-null by match[0] will be "".
    //Solution:
    //  you can check if `value` is "" and return null in such 
    //  a case.
    //  I spent 24 hrs trying to figure out why my boolean
    //  was being parsed as a number because of an issue with 
    //  my number regex
    if (match) {
      let value = match[0];
      let newIndex = this.index + value.length;
      let source = new Source(this.string, newIndex);
      return new ParseResult(value, source);
    }
    return null;
  }

}

export class ParseResult<T> {
  //Why does parse Result have source inside it ? 
  //Ans: We want to keep track of which index to start finding the next item from
  //Hence
  constructor(public value: T,
              public source: Source) {}

}

export class Parser<T> {
  constructor(
    public parse: (source: Source) => (ParseResult<T> | null),
    public debug: boolean = false, 
    //Use the name to debug your parser's flow
    public name: string = "noname") {}

  static regexp(regexp: RegExp): Parser<string> {
    return new Parser( source => source.match(regexp), false,`Regexp: ${regexp}` );
  }

  static constant<U>(value: U): Parser<U> {
    return new Parser((source) => {
      return new ParseResult(value, source)
    }, true, "constant");
  }

  static error<U>(message: string): Parser<U> {
    //TODO: Convert source into a pair of line number : column number
    //and then add it to the message being thrown
    return new Parser(
      (_: Source) => { throw new Error(`${this.name} ${message}`), false, "error parser" });
  }

  // Prioritized Or
  // making it to T|U. Will this work ?
  // ans: no, because in our Parser class signature we type `value` as (source): ParseResult<U> | null
  or(otherParser: Parser<T>): Parser<T> {
    return new Parser( (source) => {
      let result = this.parse(source);
      if (result) {
        return result;
      }
      // The `or` parser Backtracks, when the first parser fails.
      // source.index points to the initial location from which the first parser
      // tries to match. Had it succeeded, the next parser would have started at
      // source.length + result.value.length or something;
      return otherParser.parse(source);
    }, false, "or parsers");
  }

  static zeroOrMore<U>(parser: Parser<U>): Parser<Array<U>> {
    return new Parser((source) => {
      let results = [];
      let item ; 
      while(item = parser.parse(source)) {
        source = item.source;
        results.push(item.value);
      }
      return new ParseResult(results, source);
    }, parser.debug, `zeroOrMore of ${parser.name}`);
  }

  bind<U>(
    callback: (value: T) => Parser<U>,
    debugNext: boolean = false,
  ): Parser<U> {
    return new Parser((source) => {
      let result = this.parse(source);
      if (result) {
        let value = result.value;
        let source = result.source;
        if(debugNext) {
          console.log(`found ${JSON.stringify(value)}. finding next from ${source.string.slice(source.index)}`);
        }
        return callback(value).parse(source);
      } else {
        return null;
      }
    }, false, "bind");
  }

  and<U>(parser: Parser<U>): Parser<U> {
    return this.bind((_) => parser);
  }

  map<U>(callback: (t: T) => U): Parser<U> {
    return this.bind((value) => 
      Parser.constant(callback(value)));
  }

  static maybe<U>(
    parser: Parser<U | null>):
    (Parser<U | null >) {
    return parser.or(Parser.constant(null));
  }

  parseStringToCompletion(string: string): T {
    let source = new Source(string, 0);
    let result = this.parse(source);
    if(!result) {
      throw Error("Parse Error, could not parse anything");
    }
    let index = result.source.index;
    if(index != result.source.string.length) {
      throw Error("Parse error at index " + index);
    }
    return result.value;
  }
}


