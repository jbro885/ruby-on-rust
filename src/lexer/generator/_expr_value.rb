# # Like expr_beg, but no 1.9 label or 2.2 quoted label possible.
# #
# expr_value := |*
s = Scanner.new :expr_value

#     # a:b: a(:b), a::B, A::B
#     label (any - ':')
#     => { p = @ts - 1
#           fgoto expr_end; };
# s.p p!( :label, :-, p!( :any, :-, ':' ) ), %q{
#     println!("DEBUGGING");
# }

#     # "bar", 'baz'
#     ['"] # '
#     => {
#       fgoto *push_literal(tok, tok, @ts);
#     };

#     w_space_comment;

#     w_newline
#     => { fgoto line_begin; };

#     c_any
#     => { fhold; fgoto expr_beg; };
s.p :c_any, %q{
    fhold;
    fgoto expr_beg;
}

#     c_eof => do_eof;
# *|;
