#!/usr/bin/env node
export function greet(name = "world") {
  return `Hello, ${name}!`;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  console.log(greet(process.argv[2]));
}
