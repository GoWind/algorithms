import console from 'node:console';
import { readFile } from 'node:fs/promises';

export async function initialize(arg){
}

export async function resolve(specifier, context, nextResolve) {
   const { parentURL = null } = context;
 
  // Take an `import` or `require` specifier and resolve it to a URL.
  console.log(`got ${specifier} to resolve`);
  if(specifier.startsWith('.') || specifier.startsWith('..')) {
    if(!specifier.endsWith('.js')) {
      specifier = specifier + ".js";
    }
  }
  /*
  if(specifier.startsWith("file")) {
    console.log(`resolving specifier with file: ${specifier}`);
    if(specifier.endsWith('.js')) {
      console.log(`replacing commonjs with module`);
      return {
        type: "module",
        shortCircuit: true,
        url:  parentURL ? new URL(specifier, parentURL).href :
              new URL(specifier).href,
      };
    }
  } else {
          return nextResolve(specifier, context);
  }
  */
  return nextResolve(specifier, context);
}

export async function load(url, context, nextLoad) {
  // Take a resolved URL and return the source code to be evaluated.
  // const result = await nextLoad(url, context);
  console.log(`calling load for ${url}`);
  if(url.endsWith(".js")) {
      const source = await readFile(new URL(url));
      return { format: "module", source: source, shortCircuit: true};
  } else {
    return nextLoad(url, context);
  }
} 
