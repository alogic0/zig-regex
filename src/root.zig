//! Allocator-owned regular expressions. Match and capture offsets are bytes.
const core = @import("regex/root.zig");

pub const CompileOptions = core.CompileOptions;
pub const Compiled = core.Compiled;
pub const compileRe = core.compileRe;
pub const compile = core.compile;
pub const Match = core.vm.Match;
pub const Capture = core.vm.Capture;
pub const MatchError = core.vm.MatchError;

// Low-level syntax and engine interfaces retained for existing callers.
pub const reader = core.reader;
pub const lexer = core.lexer;
pub const parser = core.parser;
pub const ast = core.ast;
pub const unicode = core.unicode;
pub const ReaderError = core.ReaderError;
pub const CodePointReader = core.CodePointReader;
pub const Token = core.Token;
pub const LexError = core.LexError;
pub const Parser = core.Parser;
pub const Ast = core.Ast;
pub const Node = core.Node;
pub const NodeId = core.NodeId;
pub const ParseError = core.ParseError;
pub const ParseDiagnostic = core.ParseDiagnostic;
pub const hir = core.hir;
pub const Hir = core.Hir;
pub const Literal = core.Literal;
pub const Nfa = core.Nfa;
pub const vm = core.vm;
pub const Vm = core.Vm;
pub const Dfa = core.Dfa;

test {
    @import("std").testing.refAllDecls(@This());
    _ = @import("root_test.zig");
}
