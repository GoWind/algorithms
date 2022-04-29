
import { Parser, Source } from './ParserBase.ts';
import * as jp from './JsonParser.ts';
import * as jt from './JsonTypes.ts';
import { assertNotEquals, assertEquals } from './deps.ts';

Deno.test("Integer parser test", () => {
  let s = new Source("-45", 0);
  let res = jp.integer.parse(s);
  assertEquals(res?.value, -45);
  let s2 = new Source("abcde", 0);
  res = jp.integer.parse(s2);
  assertEquals(res, null);
});

Deno.test('fraction test', () => {
  let s = new Source(".456", 0);
  let f = jp.fraction.parse(s);
  assertEquals(f?.value, 456);
});


Deno.test('exponent test', () => {
  let s = new Source("e04", 0);
  let e = jp.exponent.parse(s);
  assertEquals(e?.value, 4);
});

Deno.test('exponent test', () => {
  let s = new Source("null", 0);
  let e = jp.jsonNull.parse(s);
  assertEquals(e?.value.elementType, "null");
});


Deno.test('jsonNumber test' , () => {
  let s = new Source('4567e-01', 0);
  let n = jp.jsonNumber.parse(s);
  assertEquals(n?.value instanceof jt.JNumber, true);
  let nv = n?.value as jt.JNumber;
  assertEquals(nv.value, 456.7);
  s = new Source('-4567e-01', 0);
  n = jp.jsonNumber.parse(s);
  assertEquals(n?.value instanceof jt.JNumber, true);
});

Deno.test('array elements', () => {
  let s = new Source("[ 1, 2, 3, 4.5 ]", 0);
  let n = jp.jsonArray.parse(s);
  assertNotEquals(n, null);
  assertEquals(n?.value instanceof jt.JArray, true);
  assertEquals(n?.value.value.length, 4);
});


Deno.test('jsonObject test', () => {
  let s = new Source('{ "a": 1, "b": 2, "3": 4.5 }', 0);
  let s2 = new Source('{"a": 1, "b": 2, "3": 4.5}', 0);
  let o = jp.jsonObject.parse(s);
  let o2 = jp.jsonObject.parse(s2);
  assertNotEquals(o, null);
  assertNotEquals(o2, null);
  assertEquals(o?.value.elementType, 'object');
  assertEquals(o2?.value.elementType, 'object');
// @ts-ignore
  assertEquals(o?.value["b"], new jt.JNumber(2));
// @ts-ignore
  assertEquals(o2?.value["b"], new jt.JNumber(2));
});

Deno.test('jsonBoolean test', () => {
  let ts = new Source('true', 0);
  let fs = new Source('false', 0);
  let t = jp.jsonBoolean.parse(ts);
  let f = jp.jsonBoolean.parse(fs);
  assertEquals(t?.value, new jt.JBoolean(true));
  assertEquals(f?.value, new jt.JBoolean(false));
  let n = jp.jsonNumber.parse(ts);
  console.log(`n is giving ${JSON.stringify(n)}`);
});

Deno.test('jsonEntry test', () => {
  let s = new Source('"3":4.5', 0);
  let three = jp.jsonEntry.parse(s);
  assertNotEquals(three, null);
  s = new Source('"3":false', 0);
  let maybeFalse = jp.jsonEntry.parse(s);
  assertNotEquals(maybeFalse, null);
});

Deno.test('jsonEntries test', () => {
  let s = new Source('"3":4.5,"4":1900', 0);
  let three = jp.jsonEntries.parse(s);
  assertNotEquals(three, null);
  console.log(`${JSON.stringify(three)}`);
  s = new Source('"3":4.5,"5":false', 0);
  let maybeFalse = jp.jsonEntries.parse(s);
  assertNotEquals(maybeFalse, null);
  console.log(`maybeFalse: ${JSON.stringify(maybeFalse)}`);
});

Deno.test('jsonObject2 test', () => {
  let s = new Source('{"a":{"x": [1, 2, 3]},"b":2,"3":4.5,"d":null, "e": true, "f": "foxpro"}', 0);
  let o = jp.jsonObject.parse(s);
  assertNotEquals(o, null);
  // @ts-ignore
  assertEquals(o?.value["b"], new jt.JNumber(2));
  // @ts-ignore
  assertEquals(o?.value["3"], new jt.JNumber(4.5));
  // @ts-ignore
  assertEquals(o?.value["d"], new jt.JNull());
  // @ts-ignore
  assertEquals(o?.value["e"], new jt.JBoolean(true));
  // @ts-ignore
  assertEquals(o?.value["f"], new jt.JString("foxpro"));
});

Deno.test('json parser test', () => {
  let objectSource = new Source('{"a":{"x": [1, 2, 3]},"b":2,"3":4.5,"d":null, "e": true, "f": "foxpro"}', 0);
  let arraySource = new Source('[1, 2, 3, "5"]', 0);
  let stringSource = new Source('"String of the strong of the night"', 0);
  let numberSource = new Source('-44.67e03', 0);
  let booleanSource = new Source('true', 0);
  let nullSource = new Source('null', 0);
  let o = jp.json.parse(objectSource);
  assertNotEquals(o, null);
  // @ts-ignore
  assertEquals(o?.value["b"], new jt.JNumber(2));
  // @ts-ignore
  assertEquals(o?.value["3"], new jt.JNumber(4.5));
  // @ts-ignore
  assertEquals(o?.value["d"], new jt.JNull());
  // @ts-ignore
  assertEquals(o?.value["e"], new jt.JBoolean(true));
  // @ts-ignore
  assertEquals(o?.value["f"], new jt.JString("foxpro"));

  let array = jp.json.parse(arraySource);
  assertNotEquals(array, null);
  assertEquals(array?.value, new jt.JArray([new jt.JNumber(1), new jt.JNumber(2), new jt.JNumber(3), new jt.JString("5")]));

  let str = jp.json.parse(stringSource);
  assertEquals(str?.value, new jt.JString("String of the strong of the night"));

  let num = jp.json.parse(numberSource);
  assertEquals(num?.value, new jt.JNumber(-44670));

  let boo = jp.json.parse(booleanSource);
  assertEquals(boo?.value, new jt.JBoolean(true));

  let nu = jp.json.parse(nullSource);
  assertEquals(nu?.value, new jt.JNull());
});
