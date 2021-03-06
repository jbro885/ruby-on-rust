// note about extracting values(token/node) in production
// 
// var_ref
//     : keyword_variable {
//         |$1:Node| -> Node;
// 
//         $$ = builders::accessible($1);
//     }
// ;
// 
// `|$1:Node|` means a `pop` and an `unwrap`, so `$1` is already a `Node` unwrapped from `SV`
// 

// TODO
// check out this about transforming token names https://github.com/tenderlove/racc/blob/master/rdoc/en/grammar.en.rdoc#converting-token-symbols

// TODO fake embedded actions
// https://github.com/DmitrySoshnikov/syntax/issues/65
// TODO many embedded actions actually dont need a return value

// TODO `error` in yacc/bison/racc is `a terminal symbol reserved for error recovery`, see http://dinosaur.compilertools.net/bison/bison_9.html#SEC81
// figure out what's the corresponsing word in syntax


%right    tBANG tTILDE tUPLUS
%right    tPOW
%right    tUNARY_NUM tUMINUS
%left     tSTAR2 tDIVIDE tPERCENT
%left     tPLUS tMINUS
%left     tLSHFT tRSHFT
%left     tAMPER2
%left     tPIPE tCARET
%left     tGT tGEQ tLT tLEQ
%nonassoc tCMP tEQ tEQQ tNEQ tMATCH tNMATCH
%left     tANDOP
%left     tOROP
%nonassoc tDOT2 tDOT3
%right    tEH tCOLON
%left     kRESCUE_MOD
%right    tEQL tOP_ASGN
%nonassoc kDEFINED
%right    kNOT
%left     kOR kAND
%nonassoc kIF_MOD kUNLESS_MOD kWHILE_MOD kUNTIL_MOD
%nonassoc tLBRACE_ARG
%nonassoc tLOWEST

%{

use crate::{
    explainer,
    token::token::Token as InteriorToken,
    lexer::stack_state::StackState,
    parser::context::Context,
    parser::token::Token,
    parser::tokenizer::Tokenizer,
    parser::static_env::StaticEnv,
    ast::node::{ Node, Nodes, SomeNode },
    ast::builders,
};

type TDummy = ();

type TSomeNodes = Option<Nodes>;
type TTokenNode = ( InteriorToken, Node );
type TNodeToken = ( Node, InteriorToken );
type TSomeTokenNode = (Option<InteriorToken>, Option<Node>);
type TParenArgs = ( Option<InteriorToken>, Nodes, Option<InteriorToken> );
type TLambdaBody = ( InteriorToken, Node, InteriorToken );
type TLambda = ( Node, TLambdaBody );
type TDoBody = ( Node, Node ); // args/opt_block_param body/bodystmt
type TDoBlock = ( InteriorToken, TDoBody, InteriorToken );
type TBraceBody = ( Node, Node ); // opt_block_param, compstmt
type TBraceBlock = ( InteriorToken, TBraceBody, InteriorToken );
type TBeginBlock = ( InteriorToken, Node, InteriorToken );

pub type TResult = SomeNode;

macro_rules! wip { () => { panic!("WIP"); }; }
macro_rules! interior_token { ($token:expr) => { *$token.interior_token }; }

macro_rules! explain {
    ( $ ( $ arg : tt ) * ) => {
        let message = format!( $($arg)* );
        explainer::explain("parser", message);
    };
}

%}

%%

program: top_compstmt;

top_compstmt
    : top_stmts opt_terms {
        |$1: Nodes| -> SomeNode;
        $$ = builders::compstmt($1);
    }
;

top_stmts
    // nothing
    : {
        || -> Nodes; $$ = vec![];
    }
    | top_stmt {
        |$1: Node| -> Nodes; $$ = vec![$1];
    }
    | top_stmts terms top_stmt {
        |$1: Nodes; $3: Node| -> Nodes;

        $1.push($3);
        $$ = $1;
    }
    // | error top_stmt {
    //     |$2:Node| -> Nodes; $$ = vec![$2];
    // }
;

top_stmt
    : stmt
    | klBEGIN begin_block {
        |$1:Token, $2:TBeginBlock| -> Node;
        let (begin_block_t_lcurly, begin_block_top_compstmt, begin_block_t_rcurly) = $2;
        $$ = builders::preexe($1, begin_block_t_lcurly, begin_block_top_compstmt, begin_block_t_rcurly);
    }
;

// TODO sth wrong with this, top_compstmt is an Option<Node> right?
begin_block: tLCURLY top_compstmt tRCURLY {
    |$1:Token, $2:Node, $3:Token| -> TBeginBlock;
    $$ = ($1, $2, $3);
};

bodystmt
    : compstmt opt_rescue opt_else opt_ensure {
        |$1:SomeNode, $2:Nodes, $3:TSomeTokenNode, $4:TSomeTokenNode| -> SomeNode;

        let rescue_bodies = $2;
        let (else_t, else_) = $3;
        let (ensure_t, ensure_) = $4;

        // if rescue_bodies.empty? && !else_.nil?
        //   diagnostic :error, :useless_else, nil, else_t
        // end
        if rescue_bodies.is_empty() && !else_.is_none() {
            // TODO
            panic!("diagnostic error");
        }

        $$ = builders::begin_body($1, rescue_bodies, else_t, else_, ensure_t, ensure_);
    }
;

compstmt: stmts opt_terms {
    |$1:Nodes| -> SomeNode;
    $$ = builders::compstmt($1);
};

stmts
    : {
        || -> Nodes; $$ = vec![];
    }
    | stmt_or_begin {
        |$1:Node| -> Nodes; $$ = vec![$1];
    }
    | stmts terms stmt_or_begin {
        |$1:Nodes, $3:Node| -> Nodes;
        $1.push($3);
        $$ = $1;
    }
    // | error stmt {
    //     // result = [ val[1] ]
    //     ||->TDummy;
    //     wip!();
    //     $$=();
    // }
;

stmt_or_begin
    : stmt
    | klBEGIN begin_block {
        || -> TDummy; $$ = ();

        // diagnostic :error, :begin_in_method, nil, val[0]
        panic!("diagnostic error");
    }
;

fake_embedded_action__stmt__1: {
    || -> TDummy; $$ = ();

    self.tokenizer.interior_lexer.set_state("expr_fname");
};

stmt
    : kALIAS fitem fake_embedded_action__stmt__1 fitem {
        |$1: Token, $2: Node, $4: Node| -> Node;
        $$ = builders::alias($1, $2, $4);
    }
    | kALIAS tGVAR tGVAR {
        |$1: Token, $2: Token, $3: Token| -> Node;
        $$ = builders::alias(
                $1,
                builders::gvar($2),
                builders::gvar($3));
    }
    | kALIAS tGVAR tBACK_REF {
        |$1: Token, $2: Token, $3: Token| -> Node;
        $$ = builders::alias(
                $1,
                builders::gvar($2),
                builders::back_ref($3));
    }
    | kALIAS tGVAR tNTH_REF {
        ||->TDummy; $$=();
        // diagnostic :error, :nth_ref_alias, nil, val[2]
        panic!("diagnostic error");
    }
    | kUNDEF undef_list {
        |$1:Token, $2:Nodes| -> Node;
        $$ = builders::undef_method($1, $2);
    }
    | stmt kIF_MOD expr_value {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::condition_mod(Some($1), None, $2, $3);
    }
    | stmt kUNLESS_MOD expr_value {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::condition_mod(None, Some($1), $2, $3);
    }
    | stmt kWHILE_MOD expr_value {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::loop_mod("while", $1, $2, $3);
    }
    | stmt kUNTIL_MOD expr_value {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::loop_mod("until", $1, $2, $3);
    }
    | stmt kRESCUE_MOD stmt {
        |$1:Node, $2:Token, $3:Node| -> Node;
        let rescue_body = builders::rescue_body($2, None, None, None, None, $3);

        $$ = builders::begin_body(Some($1), vec![ rescue_body ], None, None, None, None).expect("unexpected None");
    }
    | klEND tLCURLY compstmt tRCURLY {
        |$1:Token, $2:Token, $3:Node, $4:Token| -> Node;
        $$ = builders::postexe($1, $2, $3, $4);
    }
    | command_asgn
    | mlhs tEQL command_call {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::multi_assign($1, $2, $3);
    }
    | lhs tEQL mrhs {
        |$1:Node, $2:Token, $3:Nodes| -> Node;
        $$ = builders::assign($1, $2, builders::array(None, $3, None) );
    }
    | mlhs tEQL mrhs_arg {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::multi_assign($1, $2, $3);
    }
    | expr
;

command_asgn
    : lhs tEQL command_rhs {
        |$1: Node, $2: Token, $3: Node| -> Node; $$ = builders::assign($1, $2, $3);
    }
    | var_lhs tOP_ASGN command_rhs {
        |$1: Node, $2: Token, $3: Node| -> Node; $$ = builders::op_assign($1, $2, $3);
    }
    | primary_value tLBRACK2 opt_call_args rbracket tOP_ASGN command_rhs {
        |$1: Node, $2: Token, $3: Nodes, $4:Token, $5:Token, $6:Node| -> Node;

        $$ = builders::op_assign(
            builders::index($1, $2, $3, $4),
            $5, $6
        );
    }
    | primary_value call_op tIDENTIFIER tOP_ASGN command_rhs {
        |$1: Node, $2: Token, $3: Token, $4:Token, $5:Node| -> Node;

        $$ = builders::op_assign(
            builders::call_method(Some($1), Some($2), Some($3), None, vec![], None),
            $4, $5
        );
    }
    | primary_value call_op tCONSTANT tOP_ASGN command_rhs {
        |$1: Node, $2: Token, $3: Token, $4:Token, $5:Node| -> Node;

        $$ = builders::op_assign(
            builders::call_method(Some($1), Some($2), Some($3), None, vec![], None),
            $4, $5
        );
    }
    | primary_value tCOLON2 tCONSTANT tOP_ASGN command_rhs {
        |$1:Node, $2:Token, $3:Token, $4:Token, $5:Node| -> Node;

        let const_node = builders::const_op_assignable(builders::const_fetch($1, $2, $3));
        $$ = builders::op_assign(const_node, $4, $5);
    }
    | primary_value tCOLON2 tIDENTIFIER tOP_ASGN command_rhs {
        |$1: Node, $2: Token, $3: Token, $4:Token, $5:Node| -> Node;

        $$ = builders::op_assign(
            builders::call_method(Some($1), Some($2), Some($3), None, vec![], None),
            $4, $5
        );
    }
    | backref tOP_ASGN command_rhs {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::op_assign($1, $2, $3);
    }
;

command_rhs
    : command_call %prec tOP_ASGN
    | command_call kRESCUE_MOD stmt {
        |$1:Node, $2:Token, $3:Node| -> SomeNode;
        let rescue_body = builders::rescue_body($2, None, None, None, None, $3);

        $$ = builders::begin_body(Some($1), vec![ rescue_body ], None, None, None, None);
    }
    | command_asgn
;

expr
    : command_call
    | expr kAND expr {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::logical_op("and", $1, $2, $3);
    }
    | expr kOR expr {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::logical_op("or", $1, $2, $3);
    }
    | kNOT opt_nl expr {
        |$1:Token, $3:Node| -> Node;
        $$ = builders::not_op($1, None, Some($3), None);
    }
    | tBANG command_call {
        |$1:Token, $2:Node| -> Node;
        $$ = builders::not_op($1, None, Some($2), None);
    }
    | arg
;

expr_value: expr;

fake_embedded__expr_value_do: {
    ||->TDummy;$$=();
    self.tokenizer.interior_lexer.cond.push(true);
};

expr_value_do: fake_embedded__expr_value_do expr_value do {
    |$2: Node, $3:Token| -> TNodeToken;

    self.tokenizer.interior_lexer.cond.pop();
    $$ = ($2, $3);
};

command_call
    : command
    | block_command
;

block_command
    : block_call
    | block_call dot_or_colon operation2 command_args {
        |$1:Node, $2:Token, $3:Token, $4:Nodes| -> Node;
        $$ = builders::call_method(Some($1), Some($2), Some($3), None, $4, None);
    }
;

fake_embedded_action__cmd_brace_block: {
    || -> TDummy; $$ = ();
    self.tokenizer.context.push("block");
};

cmd_brace_block: tLBRACE_ARG fake_embedded_action__cmd_brace_block brace_body tRCURLY {
    |$1:Token, $3:TBraceBody, $4:Token| -> TBraceBlock;

    $$ = ($1, $3, $4);
    self.tokenizer.context.pop();
};

fcall: operation;

command
    : fcall command_args %prec tLOWEST {
        |$1: Token, $2: Nodes| -> Node;

        $$ = builders::call_method(None, None, Some($1), None, $2, None);
    }
    | fcall command_args cmd_brace_block {
        |$1:Token, $2:Nodes, $3:TBraceBlock| -> Node;

        let method_call = builders::call_method(None, None, Some($1), None, $2, None);
        let (begin_t, (args, body), end_t) = $3;
        $$ = builders::block(method_call, begin_t, args, body, end_t);
    }
    | primary_value call_op operation2 command_args %prec tLOWEST {
        |$1:Node, $2:Token, $3:Token, $4:Nodes| -> Node;
        $$ = builders::call_method(Some($1), Some($2), Some($3), None, $4, None);
    }
    | primary_value call_op operation2 command_args cmd_brace_block {
        |$1:Node, $2:Token, $3:Token, $4:Nodes, $5:TBraceBlock| -> Node;

        let method_call = builders::call_method(Some($1), Some($2), Some($3), None, $4, None);
        let (begin_t, (args, body), end_t) = $5;
        $$ = builders::block(method_call, begin_t, args, body, end_t);
    }
    | primary_value tCOLON2 operation2 command_args %prec tLOWEST {
        |$1:Node, $2:Token, $3:Token, $4:Nodes| -> Node;
        $$ = builders::call_method(Some($1), Some($2), Some($3), None, $4, None);
    }
    | primary_value tCOLON2 operation2 command_args cmd_brace_block {
        |$1:Node, $2:Token, $3:Token, $4:Nodes, $5:TBraceBlock| -> Node;

        let method_call = builders::call_method(Some($1), Some($2), Some($3), None, $4, None);
        let (begin_t, (args, body), end_t) = $5;
        $$ = builders::block(method_call, begin_t, args, body, end_t);
    }
    | kSUPER command_args {
        |$1:Token, $2:Nodes| -> Node;
        $$ = builders::keyword_cmd("super", $1, None, $2, None);
    }
    | kYIELD command_args {
        |$1:Token, $2:Nodes| -> Node;
        $$ = builders::keyword_cmd("yield", $1, None, $2, None);
    }
    | k_return call_args {
        |$1:Token, $2:Nodes| -> Node;
        $$ = builders::keyword_cmd("return", $1, None, $2, None);
    }
    | kBREAK call_args {
        |$1:Token, $2:Nodes| -> Node;
        $$ = builders::keyword_cmd("break", $1, None, $2, None);
    }
    | kNEXT call_args {
        |$1:Token, $2:Nodes| -> Node;
        $$ = builders::keyword_cmd("next", $1, None, $2, None);
    }
;

mlhs
    : mlhs_basic {
        |$1: Nodes| -> Node; $$ = builders::multi_lhs(None, $1, None);
    }
    | tLPAREN mlhs_inner rparen {
        |$1: Token, $2: Node, $3: Token| -> Node; $$ = builders::begin($1, Some($2), $3);
    }
;

mlhs_inner
    : mlhs_basic {
        |$1: Nodes| -> Node; $$ = builders::multi_lhs(None, $1, None);
    }
    | tLPAREN mlhs_inner rparen {
        |$1: Token, $2: Nodes, $3: Token| -> Node; $$ = builders::multi_lhs(Some($1), $2, Some($3));
    }
;

mlhs_basic
    : mlhs_head
    | mlhs_head mlhs_item {
        |$1:Nodes, $2:Node| -> Nodes;
        $1.push($2);
        $$ = $1;
    }
    | mlhs_head tSTAR mlhs_node {
        |$1:Nodes, $2:Token, $3:Node| -> Nodes;
        $1.push( builders::splat($2, Some($3)) );
        $$ = $1;
    }
    | mlhs_head tSTAR mlhs_node tCOMMA mlhs_post {
        |$1:Nodes, $2:Token, $3:Node, $5:Nodes| -> Nodes;

        $1.push( builders::splat($2, Some($3)) );
        $1.append(&mut $5);
        $$ = $1;
    }
    | mlhs_head tSTAR {
        |$1:Nodes, $2:Token| -> Nodes;
        $1.push( builders::splat($2, None) );
        $$ = $1;
    }
    | mlhs_head tSTAR tCOMMA mlhs_post {
        |$1:Nodes, $2:Token, $4:Nodes| -> Nodes;

        $1.push( builders::splat($2, None) );
        $1.append(&mut $4);
        $$ = $1;
    }
    | tSTAR mlhs_node {
        |$1:Token, $2:Node| -> Nodes;
        $$ = vec![ builders::splat($1, Some($2)) ];
    }
    | tSTAR mlhs_node tCOMMA mlhs_post {
        |$1:Token, $2:Node, $4:Nodes| -> Nodes;

        let mut r = vec![ builders::splat($1, Some($2)) ];
        r.append(&mut $4);
        $$ = r;
    }
    | tSTAR {
        |$1:Token| -> Nodes;
        $$ = vec![ builders::splat($1, None) ];
    }
    | tSTAR tCOMMA mlhs_post {
        |$1:Token, $3:Nodes| -> Nodes;

        let mut r = vec![ builders::splat($1, None) ];
        r.append(&mut $3);
        $$ = r;
    }
;

mlhs_item
    : mlhs_node
    | tLPAREN mlhs_inner rparen {
        |$1: Token, $2: Node, $3: Token| -> Node;
        $$ = builders::begin($1, Some($2), $3);
    }
;

mlhs_head
    : mlhs_item tCOMMA {
        |$1: Node| -> Nodes; $$ = vec![ $1 ];
    }
    | mlhs_head mlhs_item tCOMMA {
        |$1: Nodes, $2: Node| -> Nodes;
        $1.push($2);
        $$ = $1;
    }
;

mlhs_post
    : mlhs_item {
        |$1: Node| -> Nodes; $$ = vec![$1];
    }
    | mlhs_post tCOMMA mlhs_item {
        |$1: Nodes, $3: Node| -> Nodes;
        $1.push($3);
        $$ = $1;
    }
;

mlhs_node
    : user_variable {
        |$1:Node| -> Node;
        $$ = builders::assignable($1, &mut self.tokenizer.static_env);
    }
    | keyword_variable {
        |$1:Node| -> Node;
        $$ = builders::assignable($1, &mut self.tokenizer.static_env);
    }
    | primary_value tLBRACK2 opt_call_args rbracket {
        |$1: Node, $2: Token, $3: Nodes, $4:Token| -> Node;

        $$ = builders::index_asgn($1, $2, $3, $4);
    }
    | primary_value call_op tIDENTIFIER {
        |$1:Node, $2:Token, $3:Token| -> Node;
        $$ = builders::attr_asgn($1, $2, $3)
    }
    | primary_value tCOLON2 tIDENTIFIER {
        |$1:Node, $2:Token, $3:Token| -> Node;
        $$ = builders::attr_asgn($1, $2, $3)
    }
    | primary_value call_op tCONSTANT {
        |$1:Node, $2:Token, $3:Token| -> Node;
        $$ = builders::attr_asgn($1, $2, $3)
    }
    | primary_value tCOLON2 tCONSTANT {
        |$1:Node, $2:Token, $3:Token| -> Node;
        $$ = builders::assignable(builders::const_fetch($1, $2, $3), &mut self.tokenizer.static_env);
    }
    | tCOLON3 tCONSTANT {
        |$1:Token, $2:Token| -> Node;
        $$ = builders::assignable(builders::const_global($1, $2), &mut self.tokenizer.static_env);
    }
    | backref {
        |$1:Node| -> Node;
        $$ = builders::assignable($1, &mut self.tokenizer.static_env);
    }
;

lhs
    : user_variable {
        |$1:Node| -> Node;
        $$ = builders::assignable($1, &mut self.tokenizer.static_env);
    }
    | keyword_variable {
        |$1:Node| -> Node;
        $$ = builders::assignable($1, &mut self.tokenizer.static_env);
    }
    | primary_value tLBRACK2 opt_call_args rbracket {
        |$1: Node, $2: Token, $3: Nodes, $4:Token| -> Node;

        $$ = builders::index_asgn($1, $2, $3, $4);
    }
    | primary_value call_op tIDENTIFIER {
        |$1:Node, $2:Token, $3:Token| -> Node;
        $$ = builders::attr_asgn($1, $2, $3)
    }
    | primary_value tCOLON2 tIDENTIFIER {
        |$1:Node, $2:Token, $3:Token| -> Node;
        $$ = builders::attr_asgn($1, $2, $3)
    }
    | primary_value call_op tCONSTANT {
        |$1:Node, $2:Token, $3:Token| -> Node;
        $$ = builders::attr_asgn($1, $2, $3)
    }
    | primary_value tCOLON2 tCONSTANT {
        |$1:Node, $2:Token, $3:Token| -> Node;
        $$ = builders::assignable(builders::const_fetch($1, $2, $3), &mut self.tokenizer.static_env);
    }
    | tCOLON3 tCONSTANT {
        |$1:Token, $2:Token| -> Node;
        $$ = builders::assignable(builders::const_global($1, $2), &mut self.tokenizer.static_env);
    }
    | backref {
        |$1:Node| -> Node;
        $$ = builders::assignable($1, &mut self.tokenizer.static_env);
    }
;

cname
    : tIDENTIFIER {
        ||->TDummy; $$=();

        //   diagnostic :error, :module_name_const, nil, val[0]
        panic!("diagnostic error");
    }
    | tCONSTANT
;

cpath
    : tCOLON3 cname {
        |$1:Token, $2:Token| -> Node; $$ = builders::const_global($1, $2);
    }
    | cname {
        |$1:Token| -> Node; $$ = builders::build_const($1);
    }
    | primary_value tCOLON2 cname {
        |$1:Node, $2:Token, $3:Token| -> Node; $$ = builders::const_fetch($1, $2, $3);
    }
;

fname
    : tIDENTIFIER | tCONSTANT | tFID
    | op
    | reswords
;

fsym
    : fname {
        |$1:Token| -> Node; $$ = builders::symbol($1);
    }
    | symbol
;

fitem
    : fsym
    | dsym
;

undef_list
    : fitem {
        |$1:Node| -> Nodes; $$ = vec![$1];
    }
    | undef_list tCOMMA fake_embedded_action_undef_list fitem {
        |$1:Nodes, $4: Node| -> Nodes;
        $1.push($4);
        $$ = $1;
    }
;

fake_embedded_action_undef_list: {
    ||->TDummy; $$=();
    self.tokenizer.interior_lexer.set_state("expr_fname");
};

              op:   tPIPE    | tCARET  | tAMPER2  | tCMP  | tEQ     | tEQQ
                |   tMATCH   | tNMATCH | tGT      | tGEQ  | tLT     | tLEQ
                |   tNEQ     | tLSHFT  | tRSHFT   | tPLUS | tMINUS  | tSTAR2
                |   tSTAR    | tDIVIDE | tPERCENT | tPOW  | tBANG   | tTILDE
                |   tUPLUS   | tUMINUS | tAREF    | tASET | tDSTAR  | tBACK_REF2
;

        reswords: k__LINE__ | k__FILE__ | k__ENCODING__ | klBEGIN | klEND
                | kALIAS    | kAND      | kBEGIN        | kBREAK  | kCASE
                | kCLASS    | kDEF      | kDEFINED      | kDO     | kELSE
                | kELSIF    | kEND      | kENSURE       | kFALSE  | kFOR
                | kIN       | kMODULE   | kNEXT         | kNIL    | kNOT
                | kOR       | kREDO     | kRESCUE       | kRETRY  | kRETURN
                | kSELF     | kSUPER    | kTHEN         | kTRUE   | kUNDEF
                | kWHEN     | kYIELD    | kIF           | kUNLESS | kWHILE
                | kUNTIL
;

arg
    : lhs tEQL arg_rhs {
        |$1: Node; $2: Token, $3: Node| -> Node;
        $$ = builders::assign($1, $2, $3)
    }
    | var_lhs tOP_ASGN arg_rhs {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::op_assign($1, $2, $3);
    }
    | primary_value tLBRACK2 opt_call_args rbracket tOP_ASGN arg_rhs {
        |$1: Node, $2: Token, $3: Nodes, $4:Token, $5:Token, $6:Node| -> Node;

        $$ = builders::op_assign(
            builders::index($1, $2, $3, $4),
            $5, $6
        );
    }
    | primary_value call_op tIDENTIFIER tOP_ASGN arg_rhs {
        |$1: Node, $2: Token, $3: Token, $4:Token, $5:Node| -> Node;

        $$ = builders::op_assign(
            builders::call_method(Some($1), Some($2), Some($3), None, vec![], None),
            $4, $5
        );
    }
    | primary_value call_op tCONSTANT tOP_ASGN arg_rhs {
        |$1: Node, $2: Token, $3: Token, $4:Token, $5:Node| -> Node;

        $$ = builders::op_assign(
            builders::call_method(Some($1), Some($2), Some($3), None, vec![], None),
            $4, $5
        );
    }
    | primary_value tCOLON2 tIDENTIFIER tOP_ASGN arg_rhs {
        |$1: Node, $2: Token, $3: Token, $4:Token, $5:Node| -> Node;

        $$ = builders::op_assign(
            builders::call_method(Some($1), Some($2), Some($3), None, vec![], None),
            $4, $5
        );
    }
    | primary_value tCOLON2 tCONSTANT tOP_ASGN arg_rhs {
        |$1:Node, $2:Token, $3:Token, $4:Token, $5:Node| -> Node;

        let const_node = builders::const_op_assignable(builders::const_fetch($1, $2, $3));
        $$ = builders::op_assign(const_node, $4, $5);
    }
    | tCOLON3 tCONSTANT tOP_ASGN arg_rhs {
        |$1:Token, $2:Token, $3:Token, $4:Node| -> Node;

        let const_node = builders::const_op_assignable(builders::const_global($1, $2));
        $$ = builders::op_assign(const_node, $3, $4);
    }
    | backref tOP_ASGN arg_rhs {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::op_assign($1, $2, $3);
    }
    | arg tDOT2 arg {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::range_inclusive($1, $2, Some($3));
    }
    | arg tDOT3 arg {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::range_exclusive($1, $2, Some($3));
    }
    | arg tDOT2 {
        |$1:Node, $2:Token| -> Node;
        $$ = builders::range_inclusive($1, $2, None);
    }
    | arg tDOT3 {
        |$1:Node, $2:Token| -> Node;
        $$ = builders::range_exclusive($1, $2, None);
    }
    | arg tPLUS arg {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::binary_op($1, $2, $3);
    }
    | arg tMINUS arg {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::binary_op($1, $2, $3);
    }
    | arg tSTAR2 arg {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::binary_op($1, $2, $3);
    }
    | arg tDIVIDE arg {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::binary_op($1, $2, $3);
    }
    | arg tPERCENT arg {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::binary_op($1, $2, $3);
    }
    | arg tPOW arg {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::binary_op($1, $2, $3);
    }
    | tUNARY_NUM simple_numeric tPOW arg {
        |$1:Token, $2:Node, $3:Token, $4:Node| -> Node;
        $$ = builders::unary_op($1, builders::binary_op($2, $3, $4));
    }
    | tUPLUS arg {
        |$1:Token, $2:Node| -> Node;
        $$ = builders::unary_op($1, $2);
    }
    | tUMINUS arg {
        |$1:Token, $2:Node| -> Node;
        $$ = builders::unary_op($1, $2);
    }
    | arg tPIPE arg {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::binary_op($1, $2, $3);
    }
    | arg tCARET arg {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::binary_op($1, $2, $3);
    }
    | arg tAMPER2 arg {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::binary_op($1, $2, $3);
    }
    | arg tCMP arg {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::binary_op($1, $2, $3);
    }
    | rel_expr %prec tCMP
    | arg tEQ arg {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::binary_op($1, $2, $3);
    }
    | arg tEQQ arg {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::binary_op($1, $2, $3);
    }
    | arg tNEQ arg {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::binary_op($1, $2, $3);
    }
    | arg tMATCH arg {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::match_op($1, $2, $3);
    }
    | arg tNMATCH arg {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::binary_op($1, $2, $3);
    }
    | tBANG arg {
        |$1:Token, $2:Node| -> Node;
        $$ = builders::not_op($1, None, Some($2), None);
    }
    | tTILDE arg {
        |$1:Token, $2:Node| -> Node;
        $$ = builders::unary_op($1, $2);
    }
    | arg tLSHFT arg {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::binary_op($1, $2, $3);
    }
    | arg tRSHFT arg {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::binary_op($1, $2, $3);
    }
    | arg tANDOP arg {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::logical_op("and", $1, $2, $3);
    }
    | arg tOROP arg {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::logical_op("or", $1, $2, $3);
    }
    | kDEFINED opt_nl arg {
        |$1:Token, $3:Node| -> Node;
        $$ = builders::keyword_cmd("defined?", $1, None, vec![$3], None);
    }
    | arg tEH arg opt_nl tCOLON arg {
        |$1:Node, $2:Token, $3:Node, $5:Token, $6:Node| -> Node;
        $$ = builders::ternary($1, $2, $3, $5, $6);
    }
    | primary
;

relop: tGT | tLT | tGEQ | tLEQ;

rel_expr
    : arg relop arg %prec tGT {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::binary_op($1, $2, $3);
    }
    | rel_expr relop arg %prec tGT {
        |$1:Node, $2:Token, $3:Node| -> Node;
        $$ = builders::binary_op($1, $2, $3);
    }
;

arg_value: arg;

aref_args
    : {
        || -> Nodes; $$ = vec![];
    }
    | args trailer { $$ = $1; }
    | args tCOMMA assocs trailer {
        |$1: Nodes, $3: Nodes| -> Nodes;
        $1.push(builders::associate(None, $3, None));
        $$ = $1;
    }
    | assocs trailer {
        |$1: Nodes|->Nodes; $$ = vec![ builders::associate(None, $1, None) ];
    }
;

arg_rhs
    : arg %prec tOP_ASGN
    | arg kRESCUE_MOD arg {
        |$1:Node, $2:Token, $3:Node| -> SomeNode;
        let rescue_body = builders::rescue_body($2, None, None, None, None, $3);

        $$ = builders::begin_body(Some($1), vec![ rescue_body ], None, None, None, None);
    }
;

paren_args: tLPAREN2 opt_call_args rparen {
    |$1:Token, $2:Nodes, $3:Token| -> TParenArgs; $$ = (Some($1), $2, Some($3));
};

opt_paren_args
    : {
        || -> TParenArgs; $$ = (None, vec![], None);
    }
    | paren_args
;

opt_call_args
    : {
        || -> Nodes; $$ = vec![];
    }
    | call_args
    | args tCOMMA
    | args tCOMMA assocs tCOMMA {
        |$1:Nodes, $3:Nodes| -> Nodes;

        $1.push(builders::associate(None, $3, None));
        $$ = $1;
    }
    | assocs tCOMMA {
        |$1:Nodes| -> Nodes;

        $$ = vec![ builders::associate(None, $1, None) ];
    }
;

call_args
    : command {
        |$1:Node| -> Nodes; $$ = vec![$1];
    }
    | args opt_block_arg {
        |$1:Nodes, $2:Nodes| -> Nodes;

        $1.append(&mut $2);
        $$ = $1;
    }
    | assocs opt_block_arg {
        |$1:Nodes, $2:Nodes| -> Nodes;

        let mut result = vec![builders::associate(None, $1, None)];
        result.append(&mut $2);
        $$ = result;
    }
    | args tCOMMA assocs opt_block_arg {
        |$1:Nodes, $3:Nodes, $4:Nodes| -> Nodes;

        let mut assocs = builders::associate(None, $3, None);
        $1.push(assocs);
        $1.append(&mut $4);
        $$ = $1;
    }
    | block_arg {
        |$1:Node|->Nodes; $$ = vec![$1];
    }
;

command_args: fake_embedded_action__command_args call_args {
    |$2:Nodes| -> Nodes;

    //   # call_args can be followed by tLBRACE_ARG (that does cmdarg.push(0) in the lexer)
    //   # but the push must be done after cmdarg.pop() in the parser.
    //   # So this code does cmdarg.pop() to pop 0 pushed by tLBRACE_ARG,
    //   # cmdarg.pop() to pop 1 pushed by command_args,
    //   # and cmdarg.push(0) to restore back the flag set by tLBRACE_ARG.
    //   last_token = @last_token[0]
    //   lookahead = last_token == :tLBRACE_ARG
    //   if lookahead
    //     top = @lexer.cmdarg.pop
    //     @lexer.cmdarg.pop
    //     @lexer.cmdarg.push(top)
    //   else
    //     @lexer.cmdarg.pop
    //   end

    if let Some(last_token) = &self.tokenizer.last_token {
        match *last_token.interior_token {
            InteriorToken::T_LPAREN_ARG => {
                let top = self.tokenizer.interior_lexer.cmdarg.pop();
                self.tokenizer.interior_lexer.cmdarg.pop();
                self.tokenizer.interior_lexer.cmdarg.push(top);
            },
            _ => {
                self.tokenizer.interior_lexer.cmdarg.pop();
            }
        }
    } else { panic!("no last token"); }

    $$ = $2;
};

fake_embedded_action__command_args: {
    ||->TDummy;$$=();

    // # When branch gets invoked by RACC's lookahead
    // # and command args start with '[' or '('
    // # we need to put `true` to the cmdarg stack
    // # **before** `false` pushed by lexer
    // #   m [], n
    // #     ^
    // # Right here we have cmdarg [...0] because
    // # lexer pushed it on '['
    // # We need to modify cmdarg stack to [...10]
    // #
    // # For all other cases (like `m n` or `m n, []`) we simply put 1 to the stack
    // # and later lexer pushes corresponding bits on top of it.
    // last_token = @last_token[0]
    // lookahead = last_token == :tLBRACK || last_token == :tLPAREN_ARG
    // 
    // if lookahead
    //   top = @lexer.cmdarg.pop
    //   @lexer.cmdarg.push(true)
    //   @lexer.cmdarg.push(top)
    // else
    //   @lexer.cmdarg.push(true)
    // end

    if let Some(last_token) = &self.tokenizer.last_token {
        match *last_token.interior_token {
            InteriorToken::T_LBRACK | InteriorToken::T_LPAREN_ARG => {
                let top = self.tokenizer.interior_lexer.cmdarg.pop();
                self.tokenizer.interior_lexer.cmdarg.push(true);
                self.tokenizer.interior_lexer.cmdarg.push(top);
            },
            _ => {
                self.tokenizer.interior_lexer.cmdarg.push(true);
            }
        }
    } else { panic!("no last token"); }
};

block_arg
    : tAMPER arg_value {
        |$1:Token, $2:Node| -> Node;
        $$ = builders::block_pass($1, $2);
    }
;

opt_block_arg
    : tCOMMA block_arg {
        |$2:Node|->Nodes; $$ = vec![$2];
    }
    | {
        ||->Nodes; $$ = vec![];
    }
;

args
    : arg_value {
        |$1:Node| -> Nodes; $$ = vec![$1];
    }
    | tSTAR arg_value {
        |$1:Token, $2:Node| -> Nodes;
        $$ = vec![ builders::splat($1, Some($2)) ];
    }
    | args tCOMMA arg_value {
        |$1:Nodes, $2:Token, $3:Node| -> Nodes;

        $1.push($3); $$ = $1;
    }
    | args tCOMMA tSTAR arg_value {
        |$1:Nodes, $3:Token, $4:Node| -> Nodes;

        $1.push(builders::splat($3, Some($4)));
        $$ = $1;
    }
;

mrhs_arg
    : mrhs {
        |$1: Nodes| -> Node;
        $$ = builders::array(None, $1, None);
    }
    | arg_value
;

mrhs
    : args tCOMMA arg_value {
        |$1:Nodes, $3:Node| -> Nodes;

        $1.push($3); $$ = $1;
    }
    | args tCOMMA tSTAR arg_value {
        |$1:Nodes, $3:Token, $4: Node| -> Nodes;
        $1.push(builders::splat($3, Some($4)));
        $$ = $1;
    }
    | tSTAR arg_value {
        |$1:Token, $2:Node|->Nodes;
        $$ = vec![ builders::splat($1, Some($2)) ];
    }
;

fake_embedded_action_primary_kBEGIN: {
    || -> StackState;

    $$ = self.tokenizer.interior_lexer.cmdarg.clone();
    self.tokenizer.interior_lexer.cmdarg.clear();
};

fake_embedded_action_primary_tLPAREN_ARG_stmt: {
    ||->TDummy; $$=();
    self.tokenizer.interior_lexer.set_state("expr_endarg");
};

fake_embedded_action_primary_tLPAREN_ARG_2: {
    ||->TDummy; $$=();
    self.tokenizer.interior_lexer.set_state("expr_endarg");
};

fake_embedded_action__primary__kCLASS_1: {
    ||->TDummy; $$=();

    self.tokenizer.static_env.extend_static();
    self.tokenizer.interior_lexer.push_cmdarg();
    self.tokenizer.interior_lexer.push_cond();
    self.tokenizer.context.push("class");
};

fake_embedded_action__primary__kCLASS_2: {
    ||->TDummy; $$=();

    self.tokenizer.static_env.extend_static();
    self.tokenizer.interior_lexer.push_cmdarg();
    self.tokenizer.interior_lexer.push_cond();
    self.tokenizer.context.push("sclass");
};

fake_embedded_action__primary__kMODULE_1: {
    ||->TDummy; $$=();

    self.tokenizer.static_env.extend_static();
    self.tokenizer.interior_lexer.push_cmdarg();
};

fake_embedded_action__primary__kDEF_1: {
    ||->TDummy; $$=();

    self.tokenizer.static_env.extend_static();
    self.tokenizer.interior_lexer.push_cmdarg();
    self.tokenizer.interior_lexer.push_cond();
    self.tokenizer.context.push("def");
};

fake_embedded_action__primary__kDEF_2: {
    ||->TDummy; $$=();
    self.tokenizer.interior_lexer.set_state("expr_fname");
};

fake_embedded_action__primary__kDEF_3: {
    ||->TDummy; $$=();

    self.tokenizer.static_env.extend_static();
    self.tokenizer.interior_lexer.push_cmdarg();
    self.tokenizer.interior_lexer.push_cond();
    self.tokenizer.context.push("defs");
};

primary
    : literal
    | strings
    | xstring
    | regexp
    | words
    | qwords
    | symbols
    | qsymbols
    | var_ref
    | backref
    | tFID {
        |$1: Token| -> Node;
        $$ = builders::call_method(None, None, Some($1), None, vec![], None);
    }
    | kBEGIN fake_embedded_action_primary_kBEGIN bodystmt kEND {
        |$1: Token, $2: StackState, $3: SomeNode, $4: Token| -> Node;

        self.tokenizer.interior_lexer.cmdarg = $2;

        $$ = builders::begin_keyword($1, $3, $4);
    }
    | tLPAREN_ARG stmt fake_embedded_action_primary_tLPAREN_ARG_stmt rparen {
        |$1: Token, $2: Node, $4: Token| -> Node;

        $$ = builders::begin($1, Some($2), $4);
    }
    | tLPAREN_ARG fake_embedded_action_primary_tLPAREN_ARG_2 opt_nl tRPAREN {
        |$1: Token, $4: Token| -> Node;

        $$ = builders::begin($1, None, $4);
    }
    | tLPAREN compstmt tRPAREN {
        |$1: Token, $2: SomeNode, $3: Token| -> Node;

        $$ = builders::begin($1, $2, $3);
    }
    | primary_value tCOLON2 tCONSTANT {
        |$1:Node; $2:Token, $3:Token| -> Node;

        $$ = builders::const_fetch($1, $2, $3);
    }
    | tCOLON3 tCONSTANT {
        |$1:Token, $2:Token| -> Node;

        $$ = builders::const_global($1, $2);
    }
    | tLBRACK aref_args tRBRACK {
        |$1:Token; $2:Nodes; $3:Token| -> Node;

        $$ = builders::array( Some($1), $2, Some($3) );
    }
    | tLBRACE assoc_list tRCURLY {
        |$1:Token; $2:Nodes; $3:Token| -> Node;

        $$ = builders::associate( Some($1), $2, Some($3) );
    }
    | k_return {
        |$1:Token| -> Node; $$ = builders::keyword_cmd("return", $1, None, vec![], None);
    }
    | kYIELD tLPAREN2 call_args rparen {
        |$1:Token, $2:Token, $3:Nodes, $4:Token| -> Node;
        $$ = builders::keyword_cmd("yield", $1, Some($2), $3, Some($4));
    }
    | kYIELD tLPAREN2 rparen {
        |$1:Token, $2:Token, $3:Token| -> Node;
        $$ = builders::keyword_cmd("yield", $1, Some($2), vec![], Some($3));
    }
    | kYIELD {
        |$1:Token| -> Node; $$ = builders::keyword_cmd("yield", $1, None, vec![], None);
    }
    | kDEFINED opt_nl tLPAREN2 expr rparen {
        |$1:Token, $3:Token, $4:Node, $5:Token| -> Node;
        $$ = builders::keyword_cmd("defined?", $1, Some($3), vec![$4], Some($5));
    }
    | kNOT tLPAREN2 expr rparen {
        |$1:Token, $2:Token, $3:Node, $4:Token| -> Node;
        $$ = builders::not_op($1, Some($2), Some($3), Some($4));
    }
    | kNOT tLPAREN2 rparen {
        |$1:Token, $2:Token, $3:Token| -> Node;
        $$ = builders::not_op($1, Some($2), None, Some($3));
    }
    | fcall brace_block {
        |$1:Token, $2:TBraceBlock| -> Node;

        let method_call = builders::call_method(None, None, Some($1), None, vec![], None);
        let (begin_t, (args, body), end_t) = $2;
        $$ = builders::block(method_call, begin_t, args, body, end_t);
    }
    | method_call
    | method_call brace_block {
        |$1:Node, $2:TBraceBlock| -> Node;

        let (begin_t, (args, body), end_t) = $2;
        $$ = builders::block($1, begin_t, args, body, end_t);
    }
    | tLAMBDA lambda {
        |$1:Token, $2:TLambda| -> Node;

        let lambda_call = builders::call_lambda($1);
        let (args, ( begin_t, body, end_t )) = $2;

        $$ = builders::block(lambda_call, begin_t, args, body, end_t);
    }
    | kIF expr_value then compstmt if_tail kEND {
        |$1:Token, $2:Node, $3:Token, $4:SomeNode, $5:TSomeTokenNode, $6:Token| -> Node;

        let (else_t, else_) = $5;
        $$ = builders::condition($1, $2, $3, $4, else_t, else_, Some($6));
    }
    | kUNLESS expr_value then compstmt opt_else kEND {
        |$1:Token, $2:Node, $3:Token, $4:SomeNode, $5:TSomeTokenNode, $6:Token| -> Node;

        let (else_t, else_) = $5;
        $$ = builders::condition($1, $2, $3, else_, else_t, $4, Some($6));
    }
    | kWHILE expr_value_do compstmt kEND {
        |$1:Token, $2:TNodeToken, $3:Node, $4:Token| -> Node;
        let (expr_value_node, expr_value_token) = $2;
        $$ = builders::build_loop("while", $1, expr_value_node, expr_value_token, $3, $4);
    }
    | kUNTIL expr_value_do compstmt kEND {
        |$1:Token, $2:TNodeToken, $3:Node, $4:Token| -> Node;
        let (expr_value_node, expr_value_token) = $2;
        $$ = builders::build_loop("until", $1, expr_value_node, expr_value_token, $3, $4);
    }
    | kCASE expr_value opt_terms case_body kEND {
        |$1:Token, $2:Node| -> TDummy;

        //   *when_bodies, (else_t, else_body) = *val[3]

        //   result = @builder.case(val[0], val[1],
        //                          when_bodies, else_t, else_body,
        //                          val[4])

        $$=();
        wip!();
    }
    | kCASE            opt_terms case_body kEND {
        || -> TDummy;

        //   *when_bodies, (else_t, else_body) = *val[2]

        //   result = @builder.case(val[0], nil,
        //                          when_bodies, else_t, else_body,
        //                          val[3])

        $$=();
        wip!();
    }
    | kFOR for_var kIN expr_value_do compstmt kEND {
        |$1:Token, $2:Node, $3:Token, $4:TNodeToken, $5:Node, $6:Token| -> Node;
        let (expr_value_node, expr_value_token) = $4;
        $$ = builders::build_for($1, $2, $3, expr_value_node, expr_value_token, $5, $6);
    }
    | kCLASS cpath superclass fake_embedded_action__primary__kCLASS_1 bodystmt kEND {
        |$1:Token, $2:Node, $3:TSomeTokenNode, $5:SomeNode, $6:Token| -> Node;

        if !self.tokenizer.context.is_class_definition_allowed() {
            //     diagnostic :error, :class_in_def, nil, val[0]
            wip!();
        }

        // TODO RENAMING what's a lt?
        let (lt_t, superclass) = $3;
        $$ = builders::def_class($1, $2, lt_t, superclass, $5, $6);

        self.tokenizer.interior_lexer.pop_cmdarg();
        self.tokenizer.interior_lexer.pop_cond();
        self.tokenizer.static_env.unextend();
        self.tokenizer.context.pop();
    }
    | kCLASS tLSHFT expr term fake_embedded_action__primary__kCLASS_2 bodystmt kEND {
        |$1:Token, $2:Token, $3:Node, $6:SomeNode, $7:Token| -> TDummy;

        //   result = @builder.def_sclass(val[0], val[1], val[2],
        //                                val[5], val[6])

        //   @lexer.pop_cmdarg
        //   @lexer.pop_cond
        //   @static_env.unextend

        //   @context.pop

        $$=();
        wip!();
    }
    | kMODULE cpath fake_embedded_action__primary__kMODULE_1 bodystmt kEND {
        |$1:Token, $2:Node, $4:SomeNode, $5:Token| -> Node;

        if !self.tokenizer.context.is_class_definition_allowed() {
            //     diagnostic :error, :module_in_def, nil, val[0]
            wip!();
        }

        $$ = builders::def_module($1, $2, $4, $5);

        self.tokenizer.interior_lexer.pop_cmdarg();
        self.tokenizer.static_env.unextend();
    }
    | kDEF fname fake_embedded_action__primary__kDEF_1 f_arglist bodystmt kEND {
        |$1:Token, $2:Token, $4:Node, $5:SomeNode, $6:Token| -> Node;

        $$ = builders::def_method($1, $2, $4, $5, $6);

        self.tokenizer.interior_lexer.pop_cmdarg();
        self.tokenizer.interior_lexer.pop_cond();
        self.tokenizer.static_env.unextend();
        self.tokenizer.context.pop();
    }
    | kDEF singleton dot_or_colon fake_embedded_action__primary__kDEF_2 fname fake_embedded_action__primary__kDEF_3 f_arglist bodystmt kEND {
        ||->TDummy;

        //   result = @builder.def_singleton(val[0], val[1], val[2],
        //               val[4], val[6], val[7], val[8])

        //   @lexer.pop_cmdarg
        //   @lexer.pop_cond
        //   @static_env.unextend
        //   @context.pop

        $$=();
        wip!();
    }
    | kBREAK {
        |$1:Token| -> Node; $$ = builders::keyword_cmd("break", $1, None, vec![], None);
    }
    | kNEXT {
        |$1:Token| -> Node; $$ = builders::keyword_cmd("next", $1, None, vec![], None);
    }
    | kREDO {
        |$1:Token| -> Node; $$ = builders::keyword_cmd("redo", $1, None, vec![], None);
    }
    | kRETRY {
        |$1:Token| -> Node; $$ = builders::keyword_cmd("retry", $1, None, vec![], None);
    }
;

primary_value: primary;

k_return: kRETURN {
    ||->TDummy; $$=();

    if self.tokenizer.context.is_in_class() {
        //   diagnostic :error, :invalid_return, nil, val[0]
        panic!("diagnostic error invalid_return");
    }
};

then
    : term
    | kTHEN
    | term kTHEN {
        |$2: Token| -> Token; $$ = $2.wrap_as_token();
    }
;

do
    : term
    | kDO_COND
;

if_tail
    : opt_else
    | kELSIF expr_value then compstmt if_tail {
        |$1:Token, $2:Node, $3:Token, $4:SomeNode, $5:TSomeTokenNode| -> TSomeTokenNode;

        let k_elseif_clone = $1.clone();
        let (else_t, else_) = $5;
        $$ = (
            Some($1),
            Some(builders::condition(k_elseif_clone, $2, $3, $4, else_t, else_, None))
        );
    }
;

opt_else
    : {
        || -> TSomeTokenNode; $$ = (None, None);
    }
    | kELSE compstmt {
        |$1:Token, $2:SomeNode| -> TSomeTokenNode;
        $$ = (Some($1), $2);
    }
;

for_var
    : lhs
    | mlhs
;

f_marg
    : f_norm_arg {
        |$1:Token| -> Node; $$ = builders::arg($1);
    }
    | tLPAREN f_margs rparen {
        |$1: Token, $2: Nodes, $3: Token| -> Node; $$ = builders::multi_lhs(Some($1), $2, Some($3));
    }
;

f_marg_list
    : f_marg {
        |$1:Node|->Nodes; $$ = vec![$1];
    }
    | f_marg_list tCOMMA f_marg {
        |$1:Nodes, $3: Node| -> Nodes;
        $1.push($3);
        $$ = $1;
    }
;

f_margs
    : f_marg_list
    | f_marg_list tCOMMA tSTAR f_norm_arg {
        |$1: Nodes, $3: Token, $4: Token| -> Nodes;
        $1.push(builders::restarg($3, Some($4) ));
        $$ = $1;
    }
    | f_marg_list tCOMMA tSTAR f_norm_arg tCOMMA f_marg_list {
        |$1: Nodes, $3: Token, $4: Token, $6: Nodes| -> Nodes;
        $1.push(builders::restarg($3, Some($4) ));
        $1.append(&mut $6);
        $$ = $1;
    }
    | f_marg_list tCOMMA tSTAR {
        |$1: Nodes, $3: Token| -> Nodes;

        $1.push(builders::restarg($3, None ));
        $$ = $1;
    }
    | f_marg_list tCOMMA tSTAR            tCOMMA f_marg_list {
        |$1: Nodes, $3: Token, $5: Nodes| -> Nodes;

        $1.push(builders::restarg($3, None ));
        $1.append(&mut $5);
        $$ = $1;
    }
    |                    tSTAR f_norm_arg {
        |$1: Token, $2: Token| -> Nodes;
        $$ = vec![ builders::restarg($1, Some($2)) ];
    }
    |                    tSTAR f_norm_arg tCOMMA f_marg_list {
        |$1: Token, $2: Token, $4: Nodes| -> Nodes;
        let mut result = vec![ builders::restarg( $1, Some($2) ) ];
        result.append(&mut $4);
        $$ = result;
    }
    |                    tSTAR {
        |$1: Token| -> Nodes;
        $$ = vec![ builders::restarg($1, None) ];
    }
    |                    tSTAR tCOMMA f_marg_list {
        |$1: Token, $3: Nodes| -> Nodes;
        let mut result = vec![ builders::restarg($1, None) ];
        result.append(&mut $3);
        $$ = result;
    }
;

 block_args_tail
    : f_block_kwarg tCOMMA f_kwrest opt_f_block_arg {
        |$1: Nodes, $3: Nodes, $4: Nodes| -> Nodes;
        $1.append(&mut $3);
        $1.append(&mut $4);
        $$ = $1;
    }
    | f_block_kwarg opt_f_block_arg {
        |$1: Nodes, $2: Nodes| -> Nodes;
        $1.append(&mut $2);
        $$ = $1;
    }
    | f_kwrest opt_f_block_arg {
        |$1: Nodes, $2: Nodes| -> Nodes;
        $1.append(&mut $2);
        $$ = $1;
    }
    | f_block_arg {
        |$1:Node| -> Nodes;
        $$ = vec![ $1 ];
    }
;

opt_block_args_tail
    : tCOMMA block_args_tail {
        |$2: Nodes| -> Nodes;
        $$ = $2;
    }
    | {
        ||->Nodes; $$ = vec![];
    }
;

block_param
    : f_arg tCOMMA f_block_optarg tCOMMA f_rest_arg              opt_block_args_tail {
        |$1:Nodes, $3:Nodes, $5:Nodes, $6:Nodes| -> Nodes;

        $1.append(&mut $3);
        $1.append(&mut $5);
        $1.append(&mut $6);
        $$ = $1;
    }
    | f_arg tCOMMA f_block_optarg tCOMMA f_rest_arg tCOMMA f_arg opt_block_args_tail {
        |$1:Nodes, $3:Nodes, $5:Nodes, $7:Nodes, $8:Nodes| -> Nodes;

        $1.append(&mut $3);
        $1.append(&mut $5);
        $1.append(&mut $7);
        $1.append(&mut $8);
        $$ = $1;
    }
    | f_arg tCOMMA f_block_optarg                                opt_block_args_tail {
        |$1:Nodes, $3:Nodes, $4:Nodes| -> Nodes;

        $1.append(&mut $3);
        $1.append(&mut $4);
        $$ = $1;
    }
    | f_arg tCOMMA f_block_optarg tCOMMA                   f_arg opt_block_args_tail {
        |$1:Nodes, $3:Nodes, $5:Nodes, $6:Nodes| -> Nodes;

        $1.append(&mut $3);
        $1.append(&mut $5);
        $1.append(&mut $6);
        $$ = $1;
    }
    | f_arg tCOMMA                       f_rest_arg              opt_block_args_tail {
        |$1:Nodes, $3:Nodes, $4:Nodes| -> Nodes;

        $1.append(&mut $3);
        $1.append(&mut $4);
        $$ = $1;
    }
    | f_arg tCOMMA
    | f_arg tCOMMA                       f_rest_arg tCOMMA f_arg opt_block_args_tail {
        |$1:Nodes, $3:Nodes, $5:Nodes, $6:Nodes| -> Nodes;

        $1.append(&mut $3);
        $1.append(&mut $5);
        $1.append(&mut $6);
        $$ = $1;
    }
    | f_arg                                                      opt_block_args_tail {
        |$1:Nodes, $2:Nodes| -> Nodes;

        $$ = if ( $2.is_empty() && $1.len() == 1 ) {
            vec![
                // TODO
                // @builder.procarg0(val[0][0])
            ]
        } else {
            $1.append(&mut $2);
            $1
        }
    }
    | f_block_optarg tCOMMA              f_rest_arg              opt_block_args_tail {
        |$1:Nodes, $3:Nodes, $4:Nodes| -> Nodes;

        $1.append(&mut $3);
        $1.append(&mut $4);
        $$ = $1;
    }
    | f_block_optarg tCOMMA              f_rest_arg tCOMMA f_arg opt_block_args_tail {
        |$1:Nodes, $3:Nodes, $5:Nodes, $6:Nodes| -> Nodes;

        $1.append(&mut $3);
        $1.append(&mut $5);
        $1.append(&mut $6);
        $$ = $1;
    }
    | f_block_optarg                                             opt_block_args_tail {
        |$1:Nodes, $2:Nodes| -> Nodes;

        $1.append(&mut $2);
        $$ = $1;
    }
    | f_block_optarg tCOMMA                                f_arg opt_block_args_tail {
        |$1:Nodes, $3:Nodes, $4:Nodes| -> Nodes;

        $1.append(&mut $3);
        $1.append(&mut $4);
        $$ = $1;
    }
    |                                    f_rest_arg              opt_block_args_tail {
        |$1:Nodes, $2:Nodes| -> Nodes;

        $1.append(&mut $2);
        $$ = $1;
    }
    |                                    f_rest_arg tCOMMA f_arg opt_block_args_tail {
        |$1:Nodes, $3:Nodes, $4:Nodes| -> Nodes;

        $1.append(&mut $3);
        $1.append(&mut $4);
        $$ = $1;
    }
    |                                                                block_args_tail
;

opt_block_param
    : {
        || -> Node; $$ = builders::args(None, vec![], None);
    }
    | block_param_def {
        ||->TDummy;$$=();
        self.tokenizer.interior_lexer.set_state("expr_value");
    }
;

block_param_def
    : tPIPE opt_bv_decl tPIPE {
        |$1: Token, $2: Nodes, $3: Token| -> Node;
        $$ = builders::args(Some($1), $2, Some($3));
    }
    | tOROP {
        |$1: Token| -> Node;
        let _2 = $1.clone();
        $$ = builders::args(Some($1), vec![], Some(_2));
    }
    | tPIPE block_param opt_bv_decl tPIPE {
        |$1: Token, $2: Nodes, $3: Nodes, $4: Token| -> Node;
        $2.append(&mut $3);
        $$ = builders::args(Some($1), $2, Some($4));
    }
;

opt_bv_decl
    : opt_nl {
        |$1:Node| -> Nodes; $$ = vec![ $1 ];
    }
    | opt_nl tSEMI bv_decls opt_nl {
        |$3:Nodes| -> Nodes; $$ = $3;
    }
;

bv_decls
    : bvar {
        |$1:Node| -> Nodes; $$ = vec![ $1 ];
    }
    | bv_decls tCOMMA bvar {
        |$1:Nodes, $3: Node| -> Nodes;
        
        $1.push($3);
        $$ = $1;
    }
;

bvar
    : tIDENTIFIER {
        |$1: Token| -> Node;

        if let InteriorToken::T_IDENTIFIER(ref t_value) = $1 {
            self.tokenizer.static_env.declare(t_value.clone());
        } else { unreachable!(); }

        $$ = builders::shadowarg($1);
    }
    | f_bad_arg
;

fake_embedded_action_lambda_1: {
    ||->TDummy; $$=();
    self.tokenizer.static_env.extend_dynamic();
};

fake_embedded_action_lambda_2: {
    ||->TDummy; $$=();

    self.tokenizer.interior_lexer.cmdarg.push(false);
};

lambda: fake_embedded_action_lambda_1 f_larglist fake_embedded_action_lambda_2 lambda_body {
    |$2: Node, $4: TLambdaBody| -> TLambda;

    self.tokenizer.interior_lexer.cmdarg.pop();

    $$ = ($2, $4);

    self.tokenizer.static_env.unextend();
};

f_larglist
    : tLPAREN2 f_args opt_bv_decl tRPAREN {
        |$1: Token, $2: Nodes, $3: Nodes, $4: Token| -> Node;
        $2.append(&mut $3);
        $$ = builders::args(Some($1), $2, Some($4));
    }
    | f_args {
        |$1: Nodes| -> Node; $$ = builders::args(None, $1, None);
    }
;

fake_embedded__lambda_body__1: {
    ||->TDummy; $$=();
    self.tokenizer.context.push("lambda");
};

lambda_body
    : tLAMBEG fake_embedded__lambda_body__1 compstmt tRCURLY {
        |$1:Token, $3:Node, $4:Token| -> TLambdaBody;
        $$ = ($1, $3, $4);
        self.tokenizer.context.pop();
    }
    | kDO_LAMBDA fake_embedded__lambda_body__1 bodystmt kEND {
        |$1:Token, $3:Node, $4:Token| -> TLambdaBody;
        $$ = ($1, $3, $4);
        self.tokenizer.context.pop();
    }
;

fake_embedded__do_block__1: {
    ||->TDummy; $$=();
    self.tokenizer.context.push("block");
};

do_block: kDO_BLOCK fake_embedded__do_block__1 do_body kEND {
    |$1:Token, $3:TDoBody, $4:Token| -> TDoBlock;
    $$ = ( $1, $3, $4 );
    self.tokenizer.context.pop();
};

block_call
    : command do_block {
        |$1:Node, $2:TDoBlock| -> Node;

        let (begin_t, ( block_args, body), end_t) = $2;
        $$ = builders::block($1, begin_t, block_args, body, end_t);
    }
    | block_call dot_or_colon operation2 opt_paren_args {
        |$1:Node, $2:Token, $3:Token, $4:TParenArgs| -> Node;

        let (lparen_t, args, rparen_t) = $4;
        $$ = builders::call_method(Some($1), Some($2), Some($3), lparen_t, args, rparen_t);
    }
    | block_call dot_or_colon operation2 opt_paren_args brace_block {
        |$1:Node, $2:Token, $3:Token, $4:TParenArgs, $5:TBraceBlock| -> Node;

        let (lparen_t, args, rparen_t) = $4;
        let method_call = builders::call_method(Some($1), Some($2), Some($3), lparen_t, args, rparen_t);

        let (begin_t, (args, body), end_t) = $5;
        $$ = builders::block(method_call, begin_t, args, body, end_t);
    }
    | block_call dot_or_colon operation2 command_args do_block {
        |$1:Node, $2:Token, $3:Token, $4:Nodes, $5:TDoBlock| -> Node;

        let method_call = builders::call_method(Some($1), Some($2), Some($3), None, $4, None);

        let (begin_t, (args, body), end_t) = $5;
        $$ = builders::block(method_call, begin_t, args, body, end_t);
    }
;

method_call
    : fcall paren_args {
        |$1:Token, $2:TParenArgs| -> Node;

        let (lparen_t, args, rparen_t) = $2;
        $$ = builders::call_method(None, None, Some($1), lparen_t, args, rparen_t);
    }
    | primary_value call_op operation2 opt_paren_args {
        |$1:Node, $2:Token, $3:Token, $4:TParenArgs| -> Node;

        let (lparen_t, args, rparen_t) = $4;
        $$ = builders::call_method(Some($1), Some($2), Some($3), lparen_t, args, rparen_t);
    }
    | primary_value tCOLON2 operation2 paren_args {
        |$1:Node, $2:Token, $3:Token, $4:TParenArgs| -> Node;

        let (lparen_t, args, rparen_t) = $4;
        $$ = builders::call_method(Some($1), Some($2), Some($3), lparen_t, args, rparen_t);
    }
    | primary_value tCOLON2 operation3 {
        |$1:Node, $2:Token, $3:Token| -> Node;

        $$ = builders::call_method(Some($1), Some($2), Some($3), None, vec![], None);
    }
    | primary_value call_op paren_args {
        |$1:Node, $2:Token, $3:TParenArgs| -> Node;

        let (lparen_t, args, rparen_t) = $3;
        $$ = builders::call_method(Some($1), Some($2), None, lparen_t, args, rparen_t);
    }
    | primary_value tCOLON2 paren_args {
        |$1:Node, $2:Token, $3:TParenArgs| -> Node;

        let (lparen_t, args, rparen_t) = $3;
        $$ = builders::call_method(Some($1), Some($2), None, lparen_t, args, rparen_t);
    }
    | kSUPER paren_args {
        |$1:Token, $2:TParenArgs| -> Node;

        let (lparen_t, args, rparen_t) = $2;
        $$ = builders::keyword_cmd("super", $1, lparen_t, args, rparen_t);
    }
    | kSUPER {
        |$1:Token| -> Node;
        $$ = builders::keyword_cmd("zsuper", $1, None, vec![], None);
    }
    | primary_value tLBRACK2 opt_call_args rbracket {
        |$1: Node, $2: Token, $3: Nodes, $4:Token| -> Node;

        $$ = builders::index($1, $2, $3, $4);
    }
;

fake_embedded__brace_block__1: {
    ||->TDummy; $$=();

    self.tokenizer.context.push("block");
};

brace_block
    : tLCURLY fake_embedded__brace_block__1 brace_body tRCURLY {
        |$1:Token, $3:TBraceBody, $4:Token| -> TBraceBlock;
        $$ = ($1, $3, $4);
        self.tokenizer.context.pop();
    }
    | kDO fake_embedded__brace_block__1 do_body kEND {
        |$1:Token, $3:TDoBody, $4:Token| -> TBraceBlock;
        $$ = ($1, $3, $4);
        self.tokenizer.context.pop();
    }
;

fake_embedded_action_brace_body_1: {
    ||->TDummy;$$=();
    self.tokenizer.static_env.extend_dynamic();
};

brace_body: fake_embedded_action_brace_body_1 opt_block_param compstmt {
    |$2:Node, $3:Node| -> TBraceBody;
    $$ = ($2, $3);

    self.tokenizer.static_env.unextend();
};

fake_embedded_action_do_body_1: {
    ||->TDummy; $$=();

    self.tokenizer.static_env.extend_dynamic();
};

fake_embedded_action_do_body_2: {
    ||->StackState;
    $$ = self.tokenizer.interior_lexer.cmdarg.clone();
    self.tokenizer.interior_lexer.cmdarg.clear();
};

do_body: fake_embedded_action_do_body_1 fake_embedded_action_do_body_2 opt_block_param bodystmt {
    |$2: StackState, $3: Node, $4: Node| -> TDoBody;

    $$ = ( $3, $4 );
    self.tokenizer.static_env.unextend();

    self.tokenizer.interior_lexer.cmdarg = $2;
};

case_body: kWHEN args then compstmt cases {
    |$1:Token, $2:Nodes, $3:Token, $4:Node, $5:Nodes| -> Nodes;
    let mut r = vec![ builders::when($1, $2, $3, $4) ];
    r.append(&mut $5);
    $$ = r;
};

cases
    : opt_else {
        |$1:Node| -> Nodes;
        $$ = vec![$1];
    }
    | case_body
;

opt_rescue
    : kRESCUE exc_list exc_var then compstmt opt_rescue {
        |$1:Token, $2:TSomeNodes, $3:TSomeTokenNode, $4:Token, $5:Node, $6:Nodes| -> Nodes;

        let (assoc_t, exc_var) = $3;

        let exc_list = match $2 {
            Some(exc_list_nodes) => Some(builders::array(None, exc_list_nodes, None)),
            None => None
        };

        let mut r = vec![ builders::rescue_body($1, exc_list, assoc_t, exc_var, Some($4), $5) ];
        r.append(&mut $6);
        $$ = r;
    }
    | {
        || -> Nodes; $$ = vec![];
    }
;

exc_list
    : arg_value {
        |$1: Node| -> TSomeNodes;
        $$ = Some( vec![ $1 ] );
    }
    | mrhs
    | {
        || -> TSomeNodes; $$ = None;
    }
;

exc_var
    : tASSOC lhs {
        |$1:Token, $2:Node| -> TSomeTokenNode;
        $$ = (Some($1), Some($2));
    }
    | {
        || -> TSomeTokenNode; $$ = (None, None);
    }
;

opt_ensure
    : kENSURE compstmt {
        |$1:Token, $2:Node| -> TSomeTokenNode;
        $$ = (Some($1), Some($2));
    }
    | {
        || -> TSomeTokenNode; $$ = (None, None);
    }
;

literal
    : numeric
    | symbol
    | dsym
;

strings: string {
    |$1:Nodes| -> Node;

    $$ = builders::string_compose(None, $1, None);
};

string
    :string1 {
        |$1:Node| -> Nodes; $$ = vec![$1];
    }
    | string string1 {
        |$1:Nodes, $2: Node| -> Nodes;
        $1.push($2);
        $$ = $1;
    }
;

string1
    : tSTRING_BEG string_contents tSTRING_END {
        |$1:Token, $2:Nodes, $3:Token| -> Node;

        let string = builders::string_compose(Some($1), $2, Some($3));
        $$ = builders::dedent_string(string, self.tokenizer.interior_lexer.dedent_level);
    }
    | tSTRING {
        |$1:Token| -> Node;

        let string = builders::string($1);
        $$ = builders::dedent_string(string, self.tokenizer.interior_lexer.dedent_level);
    }
    | tCHARACTER {
        |$1:Token| -> Node; $$ = builders::character($1);
    }
;

xstring: tXSTRING_BEG xstring_contents tSTRING_END {
    |$1:Token, $2:Nodes, $3:Token| -> Node;

    let string = builders::xstring_compose($1, $2, $3);
    $$ = builders::dedent_string(string, self.tokenizer.interior_lexer.dedent_level);
};

regexp: tREGEXP_BEG regexp_contents tSTRING_END tREGEXP_OPT {
    ||->TDummy;

    //   opts   = @builder.regexp_options(val[3])
    //   result = @builder.regexp_compose(val[0], val[1], val[2], opts)

    $$=();
    wip!();
};

words: tWORDS_BEG word_list tSTRING_END {
    |$1:Token, $2:Nodes, $3:Token| -> Node;
    $$ = builders::words_compose($1, $2, $3);
};

word_list
    : {
        || -> Nodes; $$ = vec![];
    }
    | word_list word tSPACE {
        |$1:Nodes, $2:Nodes| -> Nodes;

        $1.push( builders::word($2) );
        $$ = $1;
    }
;

word
    : string_content {
        |$1:Node| -> Nodes; $$ = vec![$1];
    }
    | word string_content {
        |$1:Nodes, $2:Node| -> Nodes;
        $1.push($2); $$ = $1;
    }
;

symbols: tSYMBOLS_BEG symbol_list tSTRING_END {
    |$1:Token, $2:Nodes, $3:Token| -> Node;
    $$ = builders::symbols_compose($1, $2, $3);
};

symbol_list
    : {
        || -> Nodes; $$ = vec![];
    }
    | symbol_list word tSPACE {
        |$1:Nodes, $2: Node| -> Nodes;

        $1.push($2);
        $$ = $1;
    }
;

qwords: tQWORDS_BEG qword_list tSTRING_END {
    |$1: Token, $2: Nodes, $3: Token| -> Node;

    $$ = builders::words_compose($1, $2, $3);
};

qsymbols
    : tQSYMBOLS_BEG qsym_list tSTRING_END {
        |$1:Token, $2:Nodes, $3:Token| -> Node;
        $$ = builders::symbols_compose($1, $2, $3);
    }
;

qword_list
    : {
        || -> Nodes; $$ = vec![];
    }
    | qword_list tSTRING_CONTENT tSPACE {
        |$1:Nodes, $2:Token, $3:Token| -> Nodes;

        $1.push(builders::string_internal($2));
        $$ = $1;
    }
;

qsym_list
    : {
        ||->Nodes; $$ = vec![];
    }
    | qsym_list tSTRING_CONTENT tSPACE {
        |$1:Nodes, $2:Token| -> Nodes;
        $1.push(builders::symbol_internal($2));
        $$ = $1;
    }
;

string_contents
    : {
        || -> Nodes; $$ = vec![];
    }
    | string_contents string_content {
        |$1:Nodes, $2:Node| -> Nodes;

        $1.push($2);
        $$ = $1;
    }
;

xstring_contents
    : {
        || -> Nodes; $$ = vec![];
    }
    | xstring_contents string_content {
        |$1:Nodes, $2:Node| -> Nodes;
        $1.push($2);
        $$ = $1;
    }
;

regexp_contents
    : {
        || -> Nodes; $$ = vec![];
    }
    | regexp_contents string_content {
        |$1: Nodes, $2: Node| -> Nodes;
        $1.push($2); $$ = $1;
    }
;

fake_embedded_action__string_content__tSTRING_DBEG: {
    ||->TDummy; $$=();

    self.tokenizer.interior_lexer.push_cmdarg();
    self.tokenizer.interior_lexer.push_cond();
};

string_content
    : tSTRING_CONTENT {
        |$1:Token| -> Node; $$ = builders::string_internal($1);
    }
    | tSTRING_DVAR string_dvar {
        |$2: Node| -> Node; $$ = $2;
    }
    | tSTRING_DBEG fake_embedded_action__string_content__tSTRING_DBEG compstmt tSTRING_DEND {
        |$1: Token, $3: Node, $4: Token| -> Node;

        self.tokenizer.interior_lexer.pop_cmdarg();
        self.tokenizer.interior_lexer.pop_cond();

        $$ = builders::begin($1, Some($3), $4);
    }
;

string_dvar
    : tGVAR {
        |$1: Token| -> Node; $$ = builders::gvar($1);
    }
    | tIVAR {
        |$1: Token| -> Node; $$ = builders::ivar($1);
    }
    | tCVAR {
        |$1: Token| -> Node; $$ = builders::cvar($1);
    }
    | backref
;

symbol: tSYMBOL {
    |$1:Token| -> Node;

    self.tokenizer.interior_lexer.set_state("expr_end");
    $$ = builders::symbol($1);
};

dsym: tSYMBEG xstring_contents tSTRING_END {
    |$1:Token, $2:Nodes, $3:Token| -> Node;

    self.tokenizer.interior_lexer.set_state("expr_end");
    $$ = builders::symbol_compose($1, $2, $3);
};

numeric
    : simple_numeric
    | tUNARY_NUM simple_numeric %prec tLOWEST {
        |$1:Token, $2:Node| -> Node;
        $$ = builders::unary_num($1, $2);
    }
;

simple_numeric
    : tINTEGER {
        |$1: Token| -> Node;

        self.tokenizer.interior_lexer.set_state("expr_end");
        $$ = builders::integer($1);
    }
    | tFLOAT {
        |$1: Token| -> Node;
        self.tokenizer.interior_lexer.set_state("expr_end");
        $$ = builders::float($1);
    }
    | tRATIONAL {
        |$1: Token| -> Node;
        self.tokenizer.interior_lexer.set_state("expr_end");
        $$ = builders::rational($1);
    }
    | tIMAGINARY {
        |$1: Token| -> Node;
        self.tokenizer.interior_lexer.set_state("expr_end");
        $$ = builders::complex($1);
    }
;

user_variable
    : tIDENTIFIER {
        |$1:Token| -> Node; $$ = builders::ident($1);
    }
    | tIVAR {
        |$1:Token| -> Node; $$ = builders::ivar($1);
    }
    | tGVAR {
        |$1:Token| -> Node; $$ = builders::gvar($1);
    }
    | tCONSTANT {
        |$1:Token| -> Node; $$ = builders::build_const($1);
    }
    | tCVAR {
        |$1:Token| -> Node; $$ = builders::cvar($1);
    }
;

keyword_variable
    : kNIL {
        |$1: Token| -> Node; $$ = Node::Nil;
        // TODO @builder.nil
    }
    | kSELF {
        |$1: Token| -> Node; $$ = Node::NSelf;
        // TODO @builder.self
    }
    | kTRUE {
        |$1: Token| -> Node; $$ = Node::True;
        // TODO @builder.true
    }
    | kFALSE {
        |$1: Token| -> Node; $$ = Node::False;
        // TODO @builder.false
    }
    | k__FILE__ {
        //   result = @builder.__FILE__(val[0])

        ||->TDummy;
        $$=();
        wip!();
    }
    | k__LINE__ {
        //   result = @builder.__LINE__(val[0])

        ||->TDummy;
        $$=();
        wip!();
    }
    | k__ENCODING__ {
        //   result = @builder.__ENCODING__(val[0])

        ||->TDummy;
        $$=();
        wip!();
    }
;

var_ref
    : user_variable {
        |$1:Node| -> Node;
        $$ = builders::accessible($1, &self.tokenizer.static_env);
    }
    | keyword_variable {
        |$1:Node| -> Node;
        $$ = builders::accessible($1, &self.tokenizer.static_env);
    }
;

var_lhs
    : user_variable {
        |$1:Node| -> Node; $$ = builders::assignable($1, &mut self.tokenizer.static_env);
    }
    | keyword_variable {
        |$1:Node| -> Node; $$ = builders::assignable($1, &mut self.tokenizer.static_env);
    }
;

backref
    : tNTH_REF {
        |$1:Token| -> Node; $$ = builders::nth_ref($1);
    }
    | tBACK_REF {
        |$1:Token| -> Node; $$ = builders::back_ref($1);
    }
;

fake_embedded_action__superclass__tLT: {
    ||->TDummy; $$=();
    self.tokenizer.interior_lexer.set_state("expr_value");
};

superclass
    : tLT fake_embedded_action__superclass__tLT expr_value term {
        |$1:Token, $3:Node| -> TSomeTokenNode;
        $$ = (Some($1), Some($3));
    }
    | {
        || -> TSomeTokenNode; $$ = (None, None);
    }
;

fake_embedded_action__f_arglist__episolon: {
    || -> bool;

    $$ = self.tokenizer.interior_lexer.in_kwarg;
    self.tokenizer.interior_lexer.in_kwarg = true;
};

f_arglist
    : tLPAREN2 f_args rparen {
        |$1:Token, $2:Nodes, $3:Token| -> Node;
        $$ = builders::args(Some($1), $2, Some($3));
        self.tokenizer.interior_lexer.set_state("expr_value");
    }
    | fake_embedded_action__f_arglist__episolon f_args term {
        |$1: bool, $2: Nodes| -> Node;

        self.tokenizer.interior_lexer.in_kwarg = $1;
        $$ = builders::args(None, $2, None);
    }
;

args_tail
    : f_kwarg tCOMMA f_kwrest opt_f_block_arg {
        |$1: Nodes, $3: Nodes, $4: Nodes| -> Nodes;
        $1.append(&mut $3);
        $1.append(&mut $4);
        $$ = $1;
    }
    | f_kwarg opt_f_block_arg {
        |$1: Nodes, $2: Nodes| -> Nodes;
        $1.append(&mut $2);
        $$ = $1;
    }
    | f_kwrest opt_f_block_arg {
        |$1: Nodes, $2: Nodes| -> Nodes;
        $1.append(&mut $2);
        $$ = $1;
    }
    | f_block_arg {
        |$1: Node| -> Nodes; $$ = vec![$1];
    }
;

opt_args_tail
    : tCOMMA args_tail {
        |$2: Node| -> Nodes; $$ = vec![$2];
    }
    | {
        || -> Nodes; $$ = vec![];
    }
;

f_args
    : f_arg tCOMMA f_optarg tCOMMA f_rest_arg              opt_args_tail {
        |$1: Nodes, $3: Nodes, $5: Nodes, $6: Nodes| -> Nodes;

        $1.append(&mut $3);
        $1.append(&mut $5);
        $1.append(&mut $6);
        $$ = $1;
    }
    | f_arg tCOMMA f_optarg tCOMMA f_rest_arg tCOMMA f_arg opt_args_tail {
        |$1: Nodes, $3: Nodes, $5: Nodes, $7: Nodes, $8: Nodes| -> Nodes;

        $1.append(&mut $3);
        $1.append(&mut $5);
        $1.append(&mut $7);
        $1.append(&mut $8);
        $$ = $1;
    }
    | f_arg tCOMMA f_optarg                                opt_args_tail {
        |$1: Nodes, $3: Nodes, $4: Nodes| -> Nodes;

        $1.append(&mut $3);
        $1.append(&mut $4);
        $$ = $1;
    }
    | f_arg tCOMMA f_optarg tCOMMA                   f_arg opt_args_tail {
        |$1: Nodes, $3: Nodes, $5: Nodes, $6: Nodes| -> Nodes;

        $1.append(&mut $3);
        $1.append(&mut $5);
        $1.append(&mut $6);
        $$ = $1;
    }
    | f_arg tCOMMA                 f_rest_arg              opt_args_tail {
        |$1: Nodes, $3: Nodes, $4: Nodes| -> Nodes;

        $1.append(&mut $3);
        $1.append(&mut $4);
        $$ = $1;
    }
    | f_arg tCOMMA                 f_rest_arg tCOMMA f_arg opt_args_tail {
        |$1: Nodes, $3: Nodes, $5: Nodes, $6: Nodes| -> Nodes;

        $1.append(&mut $3);
        $1.append(&mut $5);
        $1.append(&mut $6);
        $$ = $1;
    }
    | f_arg                                                opt_args_tail {
        |$1: Nodes, $2: Nodes| -> Nodes;

        $1.append(&mut $2);
        $$ = $1;
    }
    |              f_optarg tCOMMA f_rest_arg              opt_args_tail {
        |$1: Nodes, $3: Nodes, $4: Nodes| -> Nodes;

        $1.append(&mut $3);
        $1.append(&mut $4);
        $$ = $1;
    }
    |              f_optarg tCOMMA f_rest_arg tCOMMA f_arg opt_args_tail {
        |$1: Nodes, $3: Nodes, $5: Nodes, $6: Nodes| -> Nodes;

        $1.append(&mut $3);
        $1.append(&mut $5);
        $1.append(&mut $6);
        $$ = $1;
    }
    |              f_optarg                                opt_args_tail {
        |$1: Nodes, $2: Nodes| -> Nodes;

        $1.append(&mut $2);
        $$ = $1;
    }
    |              f_optarg tCOMMA                   f_arg opt_args_tail {
        |$1: Nodes, $3: Nodes, $4: Nodes| -> Nodes;

        $1.append(&mut $3);
        $1.append(&mut $4);
        $$ = $1;
    }
    |                              f_rest_arg              opt_args_tail {
        |$1: Nodes, $2: Nodes| -> Nodes;

        $1.append(&mut $2);
        $$ = $1;
    }
    |                              f_rest_arg tCOMMA f_arg opt_args_tail {
        |$1: Nodes, $3: Nodes, $4: Nodes| -> Nodes;

        $1.append(&mut $3);
        $1.append(&mut $4);
        $$ = $1;
    }
    |                                                          args_tail {
        |$1: Nodes| -> Nodes; $$ = $1;
    }
    | {
        || -> Nodes; $$ = vec![];
    }
;

f_bad_arg
    : tCONSTANT {
        ||->TDummy;$$=(); panic!("diagnostic error"); //   diagnostic :error, :argument_const, nil, val[0]
    }
    | tIVAR {
        ||->TDummy;$$=(); panic!("diagnostic error"); //   diagnostic :error, :argument_ivar, nil, val[0]
    }
    | tGVAR {
        ||->TDummy;$$=(); panic!("diagnostic error"); //   diagnostic :error, :argument_gvar, nil, val[0]
    }
    | tCVAR {
        ||->TDummy;$$=(); panic!("diagnostic error"); //   diagnostic :error, :argument_cvar, nil, val[0]
    }
;

f_norm_arg
    : f_bad_arg
    | tIDENTIFIER {
        |$1: Token| -> Token;

        if let InteriorToken::T_IDENTIFIER(ref t_value) = $1 {
            self.tokenizer.static_env.declare(t_value.clone());
        } else { unreachable!(); }

        $$ = $1.wrap_as_token();
    }
;

f_arg_asgn: f_norm_arg {
    |$1: Token| -> Token; $$ = $1.wrap_as_token();
};

f_arg_item
    : f_arg_asgn {
        |$1: Token| -> Node;
        $$ = builders::arg($1);
    }
    | tLPAREN f_margs rparen {
        |$1: Token, $2: Nodes, $3: Token| -> Node; $$ = builders::multi_lhs(Some($1), $2, Some($3));
    }
;

f_arg
    : f_arg_item {
        |$1: Node| -> Nodes; $$ = vec![$1];
    }
    | f_arg tCOMMA f_arg_item {
        |$1: Nodes, $3: Node| -> Nodes;
        $1.push($3);
        $$ = $1;
    }
;

f_label: tLABEL {
    //   check_kwarg_name(val[0])

    //   @static_env.declare val[0][0]

    //   result = val[0]

    ||->TDummy;
    $$=();
    wip!();
};

f_kw
    : f_label arg_value {
        |$1: Token, $2: Node| -> Node; $$ = builders::kwoptarg($1, $2);
    }
    | f_label {
        |$1: Token| -> Node; $$ = builders::kwarg($1);
    }
;

f_block_kw
    : f_label primary_value {
        |$1: Token, $2: Node| -> Node; $$ = builders::kwoptarg($1, $2);
    }
    | f_label {
        |$1: Token| -> Node; $$ = builders::kwarg($1);
    }
;

f_block_kwarg
    : f_block_kw {
        |$1:Node| -> Nodes; $$ = vec![$1];
    }
    | f_block_kwarg tCOMMA f_block_kw {
        |$1:Nodes, $3: Node| -> Nodes;
        $1.push($3);
        $$ = $1;
    }
;

f_kwarg
    : f_kw {
        |$1:Node| -> Nodes; $$ = vec![$1];
    }
    | f_kwarg tCOMMA f_kw {
        |$1:Nodes, $3: Node| -> Nodes;
        $1.push($3);
        $$ = $1;
    }
;

kwrest_mark: tPOW | tDSTAR;

f_kwrest
    : kwrest_mark tIDENTIFIER {
        |$1:Token, $2:Token| -> Nodes;

        if let InteriorToken::T_IDENTIFIER(ref t_value) = $2 {
            self.tokenizer.static_env.declare(t_value.clone());
        } else { unreachable!(); }

        $$ = vec![ builders::kwrestarg($1, Some($2)) ];
    }
    | kwrest_mark {
        |$1: Token| -> Nodes; $$ = vec![ builders::kwrestarg($1, None) ];
    }
;

f_opt: f_arg_asgn tEQL arg_value {
    |$1: Token, $2: Token, $3: Node| -> Node;
    $$ = builders::optarg($1, $2, $3);
};

f_block_opt: f_arg_asgn tEQL primary_value {
    |$1: Token, $2: Token, $3: Node| -> Node;
    $$ = builders::optarg($1, $2, $3);
};

f_block_optarg
    : f_block_opt {
        |$1:Node| -> Nodes; $$ = vec![$1];
    }
    | f_block_optarg tCOMMA f_block_opt {
        |$1:Nodes, $3: Node| -> Nodes;
        $1.push($3);
        $$ = $1;
    }
;

f_optarg
    : f_opt {
        |$1:Node| -> Nodes; $$ = vec![$1];
    }
    | f_optarg tCOMMA f_opt {
        |$1:Nodes, $3: Node| -> Nodes;
        $1.push($3);
        $$ = $1;
    }
;

restarg_mark: tSTAR2 | tSTAR;

f_rest_arg
    : restarg_mark tIDENTIFIER {
        |$1:Token, $2:Token| -> Nodes;

        if let InteriorToken::T_IDENTIFIER(ref t_value) = $2 {
            self.tokenizer.static_env.declare(t_value.clone());
        } else { unreachable!(); }

        $$ = vec![ builders::restarg($1, Some($2)) ];
    }
    | restarg_mark {
        |$1: Token| -> Nodes; $$ = vec![builders::restarg($1, None)];
    }
;

blkarg_mark: tAMPER2 | tAMPER;

f_block_arg: blkarg_mark tIDENTIFIER {
    |$1:Token, $2:Token| -> Nodes;

    if let InteriorToken::T_IDENTIFIER(ref t_value) = $2 {
        self.tokenizer.static_env.declare(t_value.clone());
    } else { unreachable!(); }

    $$ = vec![ builders::blockarg($1, $2) ];
};

 opt_f_block_arg
    : tCOMMA f_block_arg {
        |$2:Node| -> Nodes; $$ = vec![$2];
    }
    | {
        || -> Nodes; $$ = vec![];
    }
;

singleton
    : var_ref
    | tLPAREN2 expr rparen {
        |$2:Node| -> Nodes; $$ = vec![$2];
    }
;

assoc_list
    : {
        || -> Nodes; $$ = vec![];
    }
    | assocs trailer { $$ = $1; }
;

assocs
    : assoc {
        |$1:Node| -> Nodes;

        $$ = vec![$1];
    }
    | assocs tCOMMA assoc {
        |$1: Nodes; $2: Token; $3: Node| -> Nodes;

        $1.push($3);
        $$ = $1;
    }
;

assoc
    : arg_value tASSOC arg_value {
        |$1: Node; $2: Token; $3: Node| -> Node;
        $$ = builders::pair($1, $2, $3);
    }
    | tLABEL arg_value {
        |$1: Token; $2: Node| -> Node;
        $$ = builders::pair_keyword($1, $2);
    }
    | tSTRING_BEG string_contents tLABEL_END arg_value {
        |$1: Token; $2: Nodes, $3: Token, $4: Node| -> Node;
        $$ = builders::pair_quoted($1, $2, $3, $4);
    }
    | tDSTAR arg_value {
        |$1: Token, $2: Node| -> Node;
        $$ = builders::kwsplat($1, $2);
    }
;

       operation: tIDENTIFIER | tCONSTANT | tFID;
      operation2: tIDENTIFIER | tCONSTANT | tFID | op;
      operation3: tIDENTIFIER | tFID | op;
    dot_or_colon: call_op | tCOLON2;
         call_op: tDOT {
                    || -> Token; $$ = InteriorToken::T_DOT.wrap_as_token();

                    //   result = [:dot, val[0][1]]
                    // TODO
                }
                | tANDDOT {
                    || -> Token; $$ = InteriorToken::T_ANDDOT.wrap_as_token();

                    //   result = [:anddot, val[0][1]]
                    // TODO
                }
;

       opt_terms:  | terms ;

          opt_nl:  | tNL;

          rparen: opt_nl tRPAREN
                    {
                        $$ = $2;
                    };

        rbracket: opt_nl tRBRACK
                    {
                        $$ = $2;
                    }
;

trailer:  | tNL | tCOMMA ;

term
    : tSEMI {
        // yyerrok
        // TODO
        $$ = $1;
    }
    | tNL
;

terms
    : term
    | terms tSEMI
;
