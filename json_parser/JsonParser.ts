import { Parser, Source } from './ParserBase.ts';
import * as jt from './JsonTypes.ts';

const decimal = Parser.regexp(/[.]/y);
const digits = Parser.regexp(/[0-9]+/y);
const exponentLiteral = Parser.regexp(/[eE]/y);
const sign = Parser.regexp(/[+-]/y);
const negative = Parser.regexp(/[-]/y);
export const numberToken = Parser.regexp(/-?(0|[1-9]\d*)(?:[.][0-9]+)?(?:[eE][-]?[0-9]+)?/y);
//export const numberToken = Parser.regexp(/[-]?[0-9]*([.][0-9]+)?((e|E)[-]?[0-9]+)*/y);
export const integer = Parser.maybe(negative).bind((neg) =>
  digits.bind((d) => {
    let n = new Number(parseInt(d));
    if (neg) { 
      return Parser.constant(-n);
    } else {
      return Parser.constant(n);
    }
  }));

export const fraction = decimal.and(digits.bind((d) => Parser.constant(parseInt(d))));

export const exponent = exponentLiteral.and(
  Parser.maybe(sign).bind((s) =>
    digits.bind((d) => {
      if(s && s != '-') { return Parser.error("Cannot have any sign except - in exponent")};
      let signM = s ? -1 : 1;
      let exponentVal = parseInt(d);
      return Parser.constant(signM * exponentVal);
    })));

export const jsonNumber: Parser<jt.JSONElement> = 
  numberToken.bind((nStr) => {
    let  n = Number(nStr);
    if(isNaN(n)) { Parser.error(`failed to parse ${nStr} as number`);}
    return Parser.constant(new jt.JNumber(n));
  });

// The guide I used for parsing JSON strings using a Regular expression
// https://dev.to/xowap/the-string-matching-regex-explained-step-by-step-4lkp
// Crockford's JSON spec on json.org is Horrible to grok. 

/* A JSON string *CANNOT* contain special characters like new line , tab etc WITHOUT being escaped
 * by a \. Also, unicode codepoints are encoded as \uxxx in the JSON string
 * Our parser disallows these special characters (codes: 0x0-0x19). 
 * We then unescape these special characters when parsing them from the serialized JSON representation 
 */
const jsonString: Parser<jt.JSONElement> = Parser.regexp(/"(([^\0-\x19"\\]|\\[^\0-\x19])*)"/y).map((v) => {
  const re = /\\(["\\\/bnrt]|u([a-fA-F0-9]{4}))/g;
  const map: {[key: string]: string } = {
    '"': '"',
    '\\': '\\',
    '/': '/',
    'b': '\b',
    'n': '\n',
    'r': '\r',
    't': '\t',
  };
  let replacedString = v.replace(re, (_: any, xchar: string, hexCodePoint: string) => {
    if (xchar[0] === 'u') {
      return String.fromCodePoint(parseInt(hexCodePoint, 16));
    } else {
      return map[xchar];
    }
  });
  replacedString = replacedString.slice(1, -1); //trim leading and trailing "
  return new jt.JString(replacedString);
});

//TODO: Maybe split this into \n\r and space, \t ? 
const whitespace = Parser.regexp(/[ \t\n\r]+/y);
const ignored = Parser.zeroOrMore(whitespace);
const token = (pattern: RegExp) => 
  Parser.regexp(pattern).bind((value) => 
    ignored.and(Parser.constant(value)));
const LEFT_SQUARE = token(/[\[]/y);
const RIGHT_SQUARE = token(/[\]]/y);
const LEFT_PAREN = token(/[{]/y);
const RIGHT_PAREN = token(/[}]/y);
const COLON = token(/[:]/y);
const COMMA = token(/[,]/y);
const trueKeyword = token(/true/y);
const falseKeyword = token(/false/y);
const nullKeyword = token(/null/y);

let json = Parser.error("cannot parse element now");

let jsonObject: Parser<jt.JObject> = Parser.error("cannot parse object now");
let jsonArray: Parser<jt.JArray> = Parser.error("cannot parse array now");

// Primitives
export const jsonNull = nullKeyword.and(Parser.constant(new jt.JNull()));

export const jsonBoolean =  trueKeyword.or(falseKeyword).map((b) => 
  b == "true" ? new jt.JBoolean(true) : new jt.JBoolean(false)

);

export const jsonElement = jsonObject.or(jsonArray).or(jsonString).or(jsonNumber).or(jsonBoolean).or(jsonNull);

export const arrayElements = 
  ignored.and(Parser.maybe(jsonElement).bind((e) =>
    Parser.zeroOrMore(COMMA.and(jsonElement)).map((elements) =>
      { 
        let x: jt.JSONElement[] = [e, ...elements] as jt.JSONElement[];
      return new jt.JArray(x);
      }))); 


jsonArray.parse = 
  (ignored.and(LEFT_SQUARE.and(arrayElements.bind((ae) =>
    ignored.and(RIGHT_SQUARE.and(Parser.constant(ae))))))).parse;


export const jsonEntry =
  ignored.and(jsonString).bind((key) =>  {
    return COLON.and(jsonElement).bind((value) => {
      return Parser.constant(new jt.JObjectEntry(key as unknown as jt.JString, value));},
      false
    )
  }
);

export const jsonEntries = 
  ignored.and(Parser.maybe(jsonEntry).bind((je) => {
    let next = Parser.zeroOrMore(COMMA.and(jsonEntry)).map((entries) => {
      let allEntries = je ? [je, ...entries] : [];
      return allEntries;
    });
    return next;
  } 
));

const createJObject = function(a: any) {
  let x = new jt.JObject();
  // @ts-ignore
  a.forEach((e) => {
    // @ts-ignore
    x[`${e.key}`] = e.value;
  });
  return x;
}

jsonObject.parse = 
  (ignored.and(LEFT_PAREN.and(jsonEntries).bind((entries) =>
    {
      return ignored.and(RIGHT_PAREN.and(Parser.constant(createJObject(entries))));
    }
  ))).parse;

export {json, jsonArray, jsonObject};
json.parse = jsonElement.parse;
