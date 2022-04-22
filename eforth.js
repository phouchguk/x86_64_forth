"use strict";

const CELLL = 8;
const INLINE = 5;

let id = 1;

const vars = {};
const cnsts = {};
const output = {};

function isInline(name) {
  return bifs[name].length <= INLINE;
}

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

function build(code, out) {
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
      const name = tokens[++i];
      const wId = id++;

      words[name] = wId;

      out.text = out.text.concat([
        `w${wId}:`,
        `  ; ${name}`,
        "  xchg rbp, rsp",
      ]);

      continue;
    }

    if (token === ";") {
      out.text = out.text.concat(["", "  xchg rbp, rsp", "  ret", ""]);

      continue;
    }

    if (bifs[token]) {
      if (isInline(token)) {
        out.text.push("");
        out.text.push(`  ; ${token}`);
        out.text = out.text.concat(bifs[token]);
      } else {
        if (!output[token]) {
          // don't render in the middle of a word. signal that it needs to be rendered.
          output[token] = id++;
        }

        const bId = output[token];
        out.text = out.text.concat([
          "",
          `  ; ${token}`,
          "  xchg rbp, rsp",
          `  call b${bId}`,
          "  xchg rbp, rsp",
        ]);
      }
    } else if (words[token]) {
      const wId = words[token];
      out.text = out.text.concat([
        "",
        `  ; ${token}`,
        "  xchg rbp, rsp",
        `  call w${wId}`,
        "  xchg rbp, rsp",
      ]);
    } else if (cnsts[token]) {
      out.text = out.text.concat([
        "",
        `  ; constant ${token}`,
        `  mov rax, ${cnsts[token]}`,
        "  push rax",
      ]);
    } else if (vars[token]) {
      out.text = out.text.concat([
        "",
        `  ; variable ${token}`,
        `  lea rax, [v${vars[token]}]`,
        "  push rax",
      ]);
    } else {
      const n = parseInt(token, 10);

      if (isNaN(n)) {
        console.log(token, "?");
      } else {
        if (tokens[i + 1] === "constant") {
          cnsts[tokens[i + 2]] = n;
          i += 2;
        } else {
          out.text = out.text.concat(["", `  mov rax, ${n}`, "  push rax"]);
        }
      }
    }
  }
}

const pre = { text: [] };
const out = { text: [] };

build(std, out);
build(code, out);

for (const k in output) {
  if (!output.hasOwnProperty(k)) {
    continue;
  }

  pre.text.push(`b${output[k]}:`);
  pre.text.push(`  ; ${k}`);
  pre.text = pre.text.concat(bifs[k]);
  pre.text.push("");
}

pre.text.forEach((x) => console.log(x));
out.text.forEach((x) => console.log(x));
