"use strict";

const CELLL = 8;

let id = 1;

const vars = {};
const cnsts = {};

const bifs = {
  "0<": ["  pop rax", "  cqo", "  push rdx"],
  "=": [
    "  xor rax, rax",
    "  pop rdx",
    "  pop rbx",
    "  xor rdx, rbx",
    "  jnz short .equ1",
    "  dec rax",
    ".equ1:",
    "  push rax",
  ],
  over: [`  mov rax, [rsp + ${CELLL}]`, "  push rax"],
  swap: ["  pop rbx", "  pop rax", "  push rbx", "  push rax"],
  "m/mod": [
    "  pop rbx",
    "  pop rdx",
    "  pop rax",
    "  or rbx, rbx",
    "  jz short .msm2",
    ".msm1:",
    "  idiv rbx",
    "  push rdx",
    "  push rax",
    "  jmp short .msm3",
    ".msm2",
    "  mov rax, -1",
    "  push rax",
    "  push rax",
    ".msm3",
  ],
  dup: ["  pop rax", "  push rax", "  push rax"],
  "+!": ["  pop rbx", "  pop rax", "  add [rbx], rax"],
  "r@": ["  push qword [rbp]"],
  drop: ["  pop rax"],
  "@": ["  pop rbx", "  push qword [rbx]"],
};

const words = {};

const std = `
: /mod over 0< swap m/mod ;
: mod /mod drop ;
: / /mod swap drop ;
`;

const code = `
999 constant start
variable sum

: 0= 0 = ;
: nmod over swap mod 0= ;
: acc dup sum +! ;
: mod35 3 nmod if acc else 5 nmod if acc then then ;
: countdown for r@ mod35 drop next ;
: euler1 start countdown sum @ . ;

euler1
`;

function build(code) {
  const trim = (x) => x.trim();
  const rblank = (x) => x !== "";

  const tokens = code.replace(/\n/g, " ").split(" ").map(trim).filter(rblank);

  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i];

    // variable

    if (token === "variable") {
      vars[tokens[++i]] = id++;
      continue;
    }

    // word def

    if (token === ":") {
      words[tokens[++i]] = id++;
      continue;
    }

    if (token === ";") {
      continue;
    }

    if (bifs[token]) {
      //console.log(token, "bif");
    } else if (words[token]) {
      //console.log(token, "word");
    } else if (cnsts[token]) {
      //console.log(token, "const", cnsts[token]);
    } else if (vars[token]) {
      //console.log(token, "var");
    } else {
      const n = parseInt(token, 10);

      if (isNaN(n)) {
        console.log(token, "?");
      } else {
        if (tokens[i + 1] === "constant") {
          cnsts[tokens[i + 2]] = n;
          i += 2;
        }

        //console.log(token, "nr");
      }
    }

    //i += check(token, i, tokens);
  }
}

build(std);
build(code);
