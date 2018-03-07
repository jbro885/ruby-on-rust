use std::collections::HashMap;

use parser::token::Token;

use shared::static_env::StaticEnv;

#[macro_use]
pub mod lexing_state;  use self::lexing_state::LexingState;
#[macro_use]
mod action;            use self::action::Action;
mod input_stream;      use self::input_stream::InputStream;
mod shared_actions;    use self::shared_actions::TSharedActions;
mod machines;
mod matching_patterns;
mod tokens_tables;
mod shared_functions;
mod stack_state;       use self::stack_state::StackState;
mod literal;           use self::literal::Literal;

pub struct Lexer {
    current_state: LexingState, // NOTE like the @cs somehow
    next_state: Option<LexingState>,
    // TODO CLEANUP states_stack: Vec<LexingState>,

    tokens_tables: HashMap<&'static str, HashMap<&'static str, Token>>,
    shared_actions: TSharedActions,
    machines: HashMap<LexingState, Vec<Box<Action>>>,

    input_stream: InputStream,

    is_breaking: bool,

    // @literal_state
    literal_stack: Vec<Literal>,

    // @command_state
    command_state: bool,

    cond: StackState,
    cmdarg: StackState,

    // TODO seems like a Ruby 1.9 thing
    paren_nest: usize,
    lambda_stack: Vec<usize>,

    // @in_kwarg
    // # True at the end of "def foo a:"
    in_kwarg: bool,

    static_env: Option<StaticEnv>,

    pub tokens: Vec<Token>,
}

impl Lexer {
    pub fn new(input_string: String) -> Lexer {
        let shared_actions = shared_actions::construct();

        Lexer {
            // TODO CLEANUP states_stack: vec![LexingState::LineBegin],
            current_state: LexingState::LineBegin, // NOTE setting value here is no use actually, since every time will pop one from states_stack
            next_state: None,

            tokens_tables: tokens_tables::construct(),

            shared_actions: shared_actions.clone(),
            machines: machines::construct(&shared_actions),

            input_stream: InputStream::new(input_string),

            is_breaking: false,

            literal_stack: vec![],
            command_state: false,
            cond: StackState::new(),
            cmdarg: StackState::new(),
            paren_nest: 0,
            lambda_stack: vec![],

            in_kwarg: false,

            static_env: None,

            tokens: Vec::new(),
        }
    }

    // return a token
    // 
    // TODO
    // then the current `emit` is not correct
    // every `exec()` should emit a token
    // 
    // TODO wrap in a Result
    // 
    pub fn advance(&mut self) -> Option<Token> {
        // TODO token queue

        println!("--- lexer: advance ---");

        self.command_state = ( self.current_state == LexingState::ExprValue ) || 
                             ( self.current_state == LexingState::LineBegin );

        // 
        self.exec();

        // TODO INCORRECT
        // token_queue
        Some( ( *self.tokens.last().expect("`tokens` is empty") ).clone())
    }

    // match-state-invoke-action loop
    // 
    // exec machine until encounter break
    // 
    fn exec(&mut self) {
        self.is_breaking = false;

        loop {
            println!("\n--- exec looping, current_state: {:?}, next_state: {:?}, is_breaking: {:?} ---", self.current_state, self.next_state, self.is_breaking);

            // handle breaking
            if self.is_breaking == true {
                println!("breaking...");
                break;
            }

            // handle state transition
            if let Some(next_state) = self.next_state.clone() {
                self.current_state = next_state.clone();
                self.next_state = None;
            }

            // get actions
            let actions = self.machines.get(&self.current_state).unwrap().clone();

            // find matching action
            let action = self.input_stream.longest_matching_action(&actions).expect("cant match any action");
            println!("matched action: {:?}", action.regex);

            // invoke proc
            let procedure = action.procedure;
            procedure(self);
        }
    }

    // parser will use this method to set lexer's state
    pub fn set_state(&mut self, state: LexingState) {
        self.current_state = state;
    }

    fn flag_breaking(&mut self) {
        self.is_breaking = true;
    }

    fn set_next_state(&mut self, state: LexingState) {
        self.next_state = Some(state);
    }

    fn emit_token(&mut self, token: Token) {
        println!("emitting token: {:?}", token);

        self.tokens.push(token);
    }

    // emit current slice as token from table
    // TODO naming
    fn emit_token_from_table(&mut self, table_name: &str) {
        let token_str = self.input_stream.current_token().unwrap().clone();

        let tokens_table = self.tokens_tables.get(table_name).unwrap();
        let token = tokens_table.get(token_str.as_str()).unwrap();

        self.tokens.push((*token).clone());
    }

    fn invoke_proc(&mut self, proc_name: &str) {
        let procedure = self.shared_actions.get(proc_name).expect("no such proc in shared_actions").clone();
        procedure(self);
    }
}
