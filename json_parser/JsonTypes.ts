export interface JSONElement {
  equals(other: JSONElement): boolean
  elementType: string
}

export class JNull implements JSONElement {
  elementType: string;
  constructor() {
    this.elementType = 'null';
  }
  equals(other: JSONElement): boolean { return false; }
}

export class JBoolean implements JSONElement {
  elementType: string;
  value: boolean;
  constructor(value: boolean) {
    this.elementType = 'boolean';
    this.value = value;
  }
  equals(other: JSONElement): boolean { return false; }
}

export class JNumber implements JSONElement {
  elementType: string;
  constructor(public value: number) {
    this.elementType = 'number';
  }
  equals(other: JSONElement): boolean { return false; }
}

export class JInteger implements JSONElement {
  elementType: string;
  constructor(public value: number) {
    this.elementType = 'integer';
  }
  equals(other: JSONElement): boolean { return false; }
}

export class JString implements JSONElement {
  elementType: string;
  toString(): string {
    return this.value;
  }
  constructor(public value: string) {
    this.elementType = 'string';
  }
  equals(other: JSONElement): boolean { return false; }
}

export class JArray implements JSONElement {
  elementType: string;
  constructor(public value: Array<JSONElement>) {
    this.elementType = 'array';
  }
  equals(other: JSONElement): boolean { return false; }
}

export class JObject extends Object implements JSONElement {
  elementType: string;
  constructor() {
    super();
    this.elementType = 'object';
  }
  equals(other: JSONElement): boolean { return false; }
}


export class JObjectEntry {
  constructor(public key: JString, public value: JSONElement) {}
}
