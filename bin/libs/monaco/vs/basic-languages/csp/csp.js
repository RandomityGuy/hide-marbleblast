/*!-----------------------------------------------------------------------------
 * Copyright (c) Microsoft Corporation. All rights reserved.
 * monaco-languages version: 1.5.1(d085b3bad82f8b59df390ce976adef0c83a9289e)
 * Released under the MIT license
 * https://github.com/Microsoft/monaco-languages/blob/master/LICENSE.md
 *-----------------------------------------------------------------------------*/
define("vs/basic-languages/csp/csp", ["require", "exports"], function (t, e) {
    "use strict";
    Object.defineProperty(e, "__esModule", { value: !0 }),
        (e.conf = {
            comments: { lineComment: "//", blockComment: ["/*", "*/"] },
            brackets: [
                ["{", "}"],
                ["[", "]"],
                ["(", ")"],
            ],
            autoClosingPairs: [
                { open: "{", close: "}" },
                { open: "[", close: "]" },
                { open: "(", close: ")" },
                { open: '"', close: '"' },
                { open: "'", close: "'" },
                { open: "`", close: "`" },
            ],
            surroundingPairs: [
                { open: "{", close: "}" },
                { open: "[", close: "]" },
                { open: "(", close: ")" },
                { open: '"', close: '"' },
                { open: "'", close: "'" },
                { open: "`", close: "`" },
            ],
    }),
        (e.language =  {
            defaultToken: "",
            tokenPostfix: ".cs",
            keywords: [
                "datablock",
                "package",
                "continue",
                "for",
                "function",
                "switch",
                "new",
                "goto",
                "if",
                "break",
                "else",
                "return",
                "while",
                "true",
                "false",
                "case",
                "default",
                "or",
            ],

            typeKeywords: [],

            operators: [
                "=",
                ">",
                "<",
                "!",
                "~",
                "?",
                ":",
                "==",
                "<=",
                ">=",
                "!=",
                "&&",
                "||",
                "++",
                "--",
                "+",
                "-",
                "*",
                "/",
                "&",
                "|",
                "^",
                "%",
                "<<",
                ">>",
                "+=",
                "-=",
                "*=",
                "/=",
                "&=",
                "|=",
                "^=",
                "%=",
                "<<=",
                ">>=",
                "@",
                "SPC",
                "TAB",
                "NL",
                "$=",
                "!$=",
            ],

            // we include these common regular expressions
            symbols: /[=><!~?:&|+\-*\/\^%]+/,

            // C# style strings
            escapes: /\\(?:[abfnrtv\\"']|x[0-9A-Fa-f]{1,4}|u[0-9A-Fa-f]{4}|U[0-9A-Fa-f]{8})/,

            // The main tokenizer for our languages
            tokenizer: {
                root: [
                    // identifiers and keywords
                    [/[a-z_$][\w$]*/, { cases: { "@typeKeywords": "keyword", "@keywords": "keyword", "@default": "identifier" } }],
                    [/[$%][a-zA-Z][\w\$]*/, "type.identifier"], // to show class names nicely

                    // whitespace
                    { include: "@whitespace" },

                    // delimiters and operators
                    [/[{}()\[\]]/, "@brackets"],
                    [/[<>](?!@symbols)/, "@brackets"],
                    [/@symbols/, { cases: { "@operators": "operator", "@default": "" } }],

                    // @ annotations.
                    // As an example, we emit a debugging log message on these tokens.
                    // Note: message are supressed during the first load -- change some lines to see them.
                    [/@\s*[a-zA-Z_\$][\w\$]*/, { token: "annotation", log: "annotation token: $0" }],

                    // numbers
                    [/\d*\.\d+([eE][\-+]?\d+)?/, "number.float"],
                    [/0[xX][0-9a-fA-F]+/, "number.hex"],
                    [/\d+/, "number"],

                    // delimiter: after number because of .\d floats
                    [/[;,.]/, "delimiter"],

                    // strings
                    [/"([^"\\]|\\.)*$/, "string.invalid"], // non-teminated string
                    [/"/, { token: "string.quote", bracket: "@open", next: "@string" }],

                    // characters
                    [/'[^\\']'/, "string"],
                    [/(')(@escapes)(')/, ["string", "string.escape", "string"]],
                    [/'/, "string.invalid"],
                ],

                comment: [
                    [/[^\/*]+/, "comment"],
                    [/\/\*/, "comment", "@push"], // nested comment
                    ["\\*/", "comment", "@pop"],
                    [/[\/*]/, "comment"],
                ],

                string: [
                    [/[^\\"]+/, "string"],
                    [/@escapes/, "string.escape"],
                    [/\\./, "string.escape.invalid"],
                    [/"/, { token: "string.quote", bracket: "@close", next: "@pop" }],
                ],

                whitespace: [
                    [/[ \t\r\n]+/, "white"],
                    [/\/\*/, "comment", "@comment"],
                    [/\/\/.*$/, "comment"],
                ],
            },
        });
});
