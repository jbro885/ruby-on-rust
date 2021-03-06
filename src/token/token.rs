// TODO refine order of token variants
#[derive(Debug, Clone, PartialEq, AsRefStr, ToString)]
#[allow(non_camel_case_types)]
pub enum Token {
    T_INTEGER(isize),
    T_FLOAT(String),
    T_RATIONAL(String),
    T_COMPLEX(String),

    T_GVAR(String),
    T_CVAR(String),
    T_CONSTANT(String),
    T_IDENTIFIER(String),
    T_LABEL(String),
    T_LABEL_END,
    T_IVAR(String),
    T_FID(String),
    T_UNARY_NUM(String),
    T_SYMBOL(String),

    T_STRING(String),
    T_STRING_CONTENT(String),

    T_STRING_BEG,
    T_STRING_END,
    T_QWORDS_BEG,
    T_WORDS_BEG,
    T_QSYMBOLS_BEG,
    T_SYMBOLS_BEG,
    T_SYMBEG(String),
    T_REGEXP_BEG,
    T_XSTRING_BEG,
    T_STRING_DEND,
    T_STRING_DBEG,
    T_STRING_DVAR,

    K_ALIAS,
    K_AND,
    K_BEGIN,
    K_BREAK,
    K_CASE,
    K_CLASS,
    K_DEF,
    K_DEFINED,
    K_DO,
    K_DO_BLOCK,
    K_DO_COND,
    K_DO_LAMBDA,
    K_ELSE,
    K_ELSIF,
    K_END,
    K_ENSURE,
    K_FALSE,
    K_FOR,
    K_IF,
    K_IF_MOD,
    K_IN,
    K_LBEGIN,
    K_LEND,
    K_MODULE,
    K_NEXT,
    K_NIL,
    K_NOT,
    K_OR,
    K_REDO,
    K_RESCUE,
    K_RESCUE_MOD,
    K_RETRY,
    K_RETURN,
    K_SELF,
    K_SUPER,
    K_THEN,
    K_TRUE,
    K_UNDEF,
    K_UNLESS,
    K_UNLESS_MOD,
    K_UNTIL,
    K_UNTIL_MOD,
    K_WHEN,
    K_WHILE,
    K_WHILE_MOD,
    K_YIELD,
    K__ENCODING__,
    K__FILE__,
    K__LINE__,
    T_AMPER,
    T_AMPER2,
    T_ANDDOT,
    T_ANDOP,
    T_AREF,
    T_ASET,
    T_ASSOC,
    T_BACK_REF2,
    T_BANG,
    T_CARET,
    T_CMP,
    T_COLON,
    T_COLON2,
    T_COLON3,
    T_COMMA,
    T_DIVIDE,
    T_DOT,
    T_DOT2,
    T_DOT3,
    T_DSTAR,
    T_EH,
    T_EQ,
    T_EQL,
    T_EQQ,
    T_GEQ,
    T_GT,
    T_LAMBEG,
    T_LAMBDA,
    T_LBRACE,
    T_LBRACE_ARG,
    T_LBRACK,
    T_LBRACK2,
    T_LCURLY,
    T_LEQ,
    T_LPAREN,
    T_LPAREN2,
    T_LPAREN_ARG,
    T_LSHFT,
    T_LT,
    T_MATCH,
    T_MINUS,
    T_NEQ,
    T_NL,
    T_NMATCH,
    T_OROP,
    T_OP_ASGN(String),
    T_PERCENT,
    T_PIPE,
    T_PLUS,
    T_POW,
    T_RBRACK,
    T_RCURLY,
    T_RPAREN,
    T_RSHFT,
    T_SEMI,
    T_STAR,
    T_STAR2,
    T_TILDE,
    T_UMINUS,
    T_UPLUS,
    T_SPACE,

    // NOTE
    // dummy token, so we dont have to use `interior_token: Option<Token>` in parser's wrapped Token
    T_EOF,
}
