// TODO
// set starting cs as lexer_en_line_begin

use std::rc::Rc;
use std::cell::RefCell;
use token::token::Token;
use lexer::literal::Literal;

%%{
    machine lexer;

    include "_character_classes.rs.rl";
    include "_token_definitions.rs.rl";
    # include "_numeric.rs.rl";
    include "_escape_sequence.rs.rl";
    include "_string_and_heredoc.rs.rl";
    include "_interpolation.rs.rl";
    include "_whitespace.rs.rl";
    include "_expression.rs.rl";
    #
    include "_expr_variable.rs.rl";
    # include "_expr_fname.rs.rl";
    include "_expr_endfn.rs.rl";
    include "_expr_dot.rs.rl";
    # include "_expr_arg.rs.rl";
    # include "_expr_cmdarg.rs.rl";
    include "_expr_endarg.rs.rl";
    # include "_expr_mid.rs.rl";
    include "_expr_beg.rs.rl";
    include "_expr_labelarg.rs.rl";
    include "_expr_value.rs.rl";
    include "_expr_end.rs.rl";
    # include "_leading_dot.rs.rl";
    # include "_line_comment.rs.rl";
    include "_line_begin.rs.rl";
}%%

%% write data nofinal;

pub struct Lexer {
    input: String,

    // ragel
    cs: i32,
    p: i32,
    pe: i32,
    ts: i32,
    te: i32,
    tm: i32,
    act: i32,
    stack: [i32; 16],
    top: i32,

    tokens: Rc<RefCell<Vec<Token>>>,
    pub literal_stack: Vec<Literal>,
}

impl Lexer {
    pub fn new(input: String) -> Lexer {
        // %% write init;
        let cs = ( lexer_start ) as i32;
        let top = 0;
        let ts = 0;
        let te = 0;
        let act = 0;

        let tm = 0;
        let pe = input.len() as i32;
        let stack = [0; 16];

        Lexer {
            input,

            cs, ts, te, tm,
            stack, top,
            p: 0,
            pe,
            act,

            tokens: Rc::new(RefCell::new(vec![])),
            literal_stack: vec![]
        }
    }

    // TODO DOC
    // return a Token
    pub fn advance(&mut self) -> Option<Token> {
        println!("---\nlexer.advance");

        if !self.tokens.borrow().is_empty() { return Some(self.tokens.borrow_mut().remove(0)); }

        // TODO MAJOR utf8 uncompatible
        let _input = self.input.clone();
        let data = _input.as_bytes();

        // TODO macro
        let mut cs = self.cs;
        let mut p = self.p;
        let mut pe = self.pe;
        let mut ts = self.ts;
        let mut te = self.te;
        let mut tm = self.tm;
        let mut act = self.act;
        let mut stack = self.stack;
        let mut top = self.top;

        // NOTE
        // pe - Data end pointer.
        // This should be initialized to p plus the data length on every run of the machine.
        // In Go, Java and Ruby code this should be initialized to the data length.
        // Seems like rust is same with ruby, since they're languages without `goto`

        let eof = self.pe;

        %% write exec;

        self.cs = cs;
        self.p = p;
        self.pe = pe;
        self.ts = ts;
        self.te = te;
        self.tm = tm;
        self.act = act;
        self.stack = stack;
        self.top = top;

        if self.tokens.borrow().is_empty() {
            return None;
        } else {
            return Some(self.tokens.borrow_mut().remove(0));
        }
    }

    // TODO CRITICAL utf8 uncompatible
    fn current_slice(&self, ts: i32, te: i32) -> String {
        self.input.chars().skip(ts as usize).take( ( te - ts ) as usize ).collect()
    }

    fn current_slice_as_token_from_table(&mut self, table_name: &str, current_slice: String) -> Token {
        match table_name {
            !write token tables matching
            _ => { panic!("unreachable! no such table"); }
        }
    }

    fn emit(&mut self, token: Token) {
        println!("lexer.emit: {:?}", token);
        self.tokens.borrow_mut().push(token);
    }

}