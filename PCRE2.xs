/* -*- c-basic-offset:4 -*- */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#define PCRE2_CODE_UNIT_WIDTH 8
#include <pcre2.h>
#include "PCRE2.h"
#include "regcomp.h"
#define HAVE_JIT

#ifndef strEQc
# define strEQc(s, c) strEQ(s, ("" c ""))
#endif

static char retbuf[64];

#if PERL_VERSION > 10
#define RegSV(p) SvANY(p)
#else
#define RegSV(p) (p)
#endif

REGEXP *
#if PERL_VERSION < 12
PCRE2_comp(pTHX_ const SV * const pattern, const U32 flags)
#else
PCRE2_comp(pTHX_ SV * const pattern, U32 flags)
#endif
{
    REGEXP *rx;
    regexp *re;
    pcre2_code *ri = NULL;

    STRLEN plen;
    char  *exp = SvPV((SV*)pattern, plen);
    char *xend = exp + plen;
    U32 extflags = flags;
    SV * wrapped = newSVpvn_flags("(?", 2, SVs_TEMP);
    SV * wrapped_unset = newSVpvn_flags("", 0, SVs_TEMP);

    /* pcre2_compile */
    int errcode;
    PCRE2_SIZE erroffset;

    /* pcre2_pattern_info */
    PCRE2_SIZE length;
    U32 nparens;

    /* pcre_compile */
    U32 options = PCRE2_DUPNAMES;

#if PERL_VERSION >= 14
    /* named captures */
    I32 namecount;
#endif

    /* C<split " ">, bypass the PCRE2 engine alltogether and act as perl does */
    if (flags & RXf_SPLIT && plen == 1 && exp[0] == ' ')
        extflags |= (RXf_SKIPWHITE|RXf_WHITE);

    /* RXf_NULL - Have C<split //> split by characters */
    if (plen == 0)
        extflags |= RXf_NULL;

    /* RXf_START_ONLY - Have C<split /^/> split on newlines */
    else if (plen == 1 && exp[0] == '^')
        extflags |= RXf_START_ONLY;

    /* RXf_WHITE - Have C<split /\s+/> split on whitespace */
    else if (plen == 3 && strnEQ("\\s+", exp, 3))
        extflags |= RXf_WHITE;

    /* Perl modifiers to PCRE2 flags, /s is implicit and /p isn't used
     * but they pose no problem so ignore them */
    /* qr// stringification, TODO: (?flags:pattern) */
    if (flags & RXf_PMf_FOLD) {
        options |= PCRE2_CASELESS;  /* /i */
        sv_catpvn(wrapped, "i", 1);
    }
    if (flags & RXf_PMf_SINGLELINE) {
        sv_catpvn(wrapped, "s", 1);
    }
    if (flags & RXf_PMf_EXTENDED) {
        options |= PCRE2_EXTENDED;  /* /x */
        sv_catpvn(wrapped, "x", 1);
    }
#ifdef RXf_PMf_EXTENDED_MORE
    if (flags & RXf_PMf_EXTENDED_MORE) {
        /* allow space and tab in [ ] classes */
        Perl_ck_warner(aTHX_ packWARN(WARN_REGEXP), "/xx ignored by pcre2");
        return Perl_re_compile(aTHX_ pattern, flags);
        /*options |= PCRE2_EXTENDED;
          sv_catpvn(wrapped, "x", 1);*/
    }
#endif
    if (flags & RXf_PMf_MULTILINE) {
        options |= PCRE2_MULTILINE; /* /m */
        sv_catpvn(wrapped, "m", 1);
    }
#ifdef RXf_PMf_NOCAPTURE
    if (flags & RXf_PMf_NOCAPTURE) {
        options |= PCRE2_NO_AUTO_CAPTURE; /* (?: and /n */
        sv_catpvn(wrapped, "n", 1);
    }
#endif
#ifdef RXf_PMf_CHARSET
    if (flags & RXf_PMf_CHARSET) {
      regex_charset cs;
      if ((cs = get_regex_charset(flags)) != REGEX_DEPENDS_CHARSET) {
        switch (cs) {
        case REGEX_UNICODE_CHARSET:
          options |= (PCRE2_UTF|PCRE2_NO_UTF_CHECK);
          sv_catpvn(wrapped, "u", 1);
          break;
        case REGEX_ASCII_RESTRICTED_CHARSET:
          options |= PCRE2_NEVER_UCP; /* /a */
          sv_catpvn(wrapped, "a", 1);
          break;
        case REGEX_ASCII_MORE_RESTRICTED_CHARSET:
          options |= PCRE2_NEVER_UTF; /* /aa */
          sv_catpvn(wrapped, "aa", 2);
          break;
        default:
#if PERL_VERSION > 10
          Perl_ck_warner(aTHX_ packWARN(WARN_REGEXP),
#else
          Perl_warner(aTHX_ packWARN(WARN_REGEXP),
#endif
                         "local charset option ignored by pcre2");
          return Perl_re_compile(aTHX_ pattern, flags);
        }
      }
    }
#endif
    /* TODO: e r l d g c */

    /* The pattern is known to be UTF-8. Perl wouldn't turn this on unless it's
     * a valid UTF-8 sequence so tell PCRE2 not to check for that */
#ifdef RXf_UTF8
    if (flags & RXf_UTF8)
#else
    if (SvUTF8(pattern))
#endif
        options |= (PCRE2_UTF|PCRE2_NO_UTF_CHECK);

    ri = pcre2_compile(
        (PCRE2_SPTR8)exp, plen,    /* pattern */
        options,      /* options */
        &errcode,     /* errors */
        &erroffset,   /* error offset */
        NULL          /* &pcre2_compile_context */
    );

    if (ri == NULL) {
        PCRE2_UCHAR buf[256];
        pcre2_get_error_message(errcode, buf, sizeof(buf));
#if PERL_VERSION > 10
        Perl_ck_warner(aTHX_ packWARN(WARN_REGEXP),
#else
        Perl_warner(aTHX_ packWARN(WARN_REGEXP),
#endif
            "PCRE2 compilation failed at offset %u: %s\n",
            (unsigned)erroffset, buf);
        return Perl_re_compile(aTHX_ pattern, flags);
    }
#ifdef HAVE_JIT
    /* pcre2_config_8(PCRE2_CONFIG_JIT, &have_jit);
    if (have_jit) */
    pcre2_jit_compile(ri, PCRE2_JIT_COMPLETE); /* no partial matches */
#endif

#if PERL_VERSION >= 12
    rx = (REGEXP*) newSV_type(SVt_REGEXP);
#else
    Newxz(rx, 1, REGEXP);
    rx->refcnt = 1;
#endif

    re = RegSV(rx);
    re->intflags = options;
    re->extflags = extflags;
    re->engine   = &pcre2_engine;

    if (SvCUR(wrapped_unset)) {
        sv_catpvn(wrapped, "-", 1);
        sv_catsv(wrapped, wrapped_unset);
    }
    sv_catpvn(wrapped, ":", 1);
#if PERL_VERSION > 10
    re->pre_prefix = SvCUR(wrapped);
#endif
    sv_catpvn(wrapped, exp, plen);
    sv_catpvn(wrapped, ")", 1);

#if PERL_VERSION == 10
    re->wraplen = SvCUR(wrapped);
    re->wrapped = savepvn(SvPVX(wrapped), SvCUR(wrapped));
#else
    RX_WRAPPED(rx) = savepvn(SvPVX(wrapped), SvCUR(wrapped));
    RX_WRAPLEN(rx) = SvCUR(wrapped);
    DEBUG_r(sv_dump((SV*)rx));
#endif

#if PERL_VERSION == 10
    /* Preserve a copy of the original pattern */
    re->prelen = (I32)plen;
    re->precomp = SAVEPVN(exp, plen);
#endif

    /* Store our private object */
    re->pprivate = ri;

    /* If named captures are defined make rx->paren_names */
#if PERL_VERSION >= 14
    (void)pcre2_pattern_info(ri, PCRE2_INFO_NAMECOUNT, &namecount);

    if ((namecount <= 0) || (options & PCRE2_NO_AUTO_CAPTURE)) {
        re->paren_names = NULL;
    } else {
        PCRE2_make_nametable(re, ri, namecount);
    }
#endif

    /* Check how many parens we need */
    (void)pcre2_pattern_info(ri, PCRE2_INFO_CAPTURECOUNT, &nparens);
    re->nparens = re->lastparen = re->lastcloseparen = nparens;
    Newxz(re->offs, nparens + 1, regexp_paren_pair);

    /* return the regexp */
    return rx;
}

#if PERL_VERSION >= 18
/* code blocks are extracted like this:
  /a(?{$a=2;$b=3;($b)=$a})b/ =>
  expr: list - const 'a' + getvars + const '(?{$a=2;$b=3;($b)=$a})' + const 'b'
 */
REGEXP*  PCRE2_op_comp(pTHX_ SV ** const patternp, int pat_count,
                       OP *expr, const struct regexp_engine* eng,
                       REGEXP *old_re,
                       bool *is_bare_re, U32 orig_rx_flags, U32 pm_flags)
{
    SV *pattern = NULL;
    if (!patternp) {
        OP *o = expr;
        for (; !o || OP_CLASS(o) != OA_SVOP; o = o->op_next) ;
        if (o && OP_CLASS(o) == OA_SVOP) {
            /* having a single const op only? */
            if (o->op_next == o || o->op_next->op_type == OP_LIST)
                pattern = cSVOPx_sv(o);
            else { /* no, fallback to core with codeblocks */
                return Perl_re_op_compile
                    (aTHX_ patternp, pat_count, expr,
                     &PL_core_reg_engine,
                     old_re, is_bare_re, orig_rx_flags, pm_flags);
            }
        }
    } else {
        pattern = *patternp;
    }
    return PCRE2_comp(aTHX_ pattern, orig_rx_flags);
}
#endif

#ifdef HAVE_JIT
static pcre2_jit_stack *jit_stack = NULL;
static pcre2_match_context *match_context;

/* default is 32k already */
static pcre2_jit_stack *get_jit_stack(void)
{
    if (!jit_stack)
        jit_stack = pcre2_jit_stack_create(32*1024, 1024*1024, NULL);
    return jit_stack;
}
#endif

I32
#if PERL_VERSION < 20
PCRE2_exec(pTHX_ REGEXP * const rx, char *stringarg, char *strend,
          char *strbeg, I32 minend, SV * sv,
          void *data, U32 flags)
#else
PCRE2_exec(pTHX_ REGEXP * const rx, char *stringarg, char *strend,
          char *strbeg, SSize_t minend, SV * sv,
          void *data, U32 flags)
#endif
{
    I32 rc;
    I32 i;
    int have_jit;
    PCRE2_SIZE *ovector;
    pcre2_match_data *match_data;
    regexp * re = RegSV(rx);
    pcre2_code *ri = re->pprivate;

    match_data = pcre2_match_data_create_from_pattern(ri, NULL);
#ifdef HAVE_JIT
    pcre2_config_8(PCRE2_CONFIG_JIT, &have_jit);
    if (have_jit) {
        match_context = NULL; /*pcre2_match_context_create(NULL);*/
        /*pcre2_jit_stack_assign(match_context, NULL, get_jit_stack());*/
        rc = (I32)pcre2_jit_match(
            ri,
            (PCRE2_SPTR8)stringarg,
            strend - strbeg,      /* length */
            stringarg - strbeg,   /* offset */
            re->intflags,         /* the options (again) */
            match_data,           /* block for storing the result */
            match_context
        );
    } else
#endif
        rc = (I32)pcre2_match(
            ri,
            (PCRE2_SPTR8)stringarg,
            strend - strbeg,      /* length */
            stringarg - strbeg,   /* offset */
            0,                    /* the options (again?) re->intflags */
            match_data,           /* block for storing the result */
            NULL                  /* use default match context */
        );

    /* Matching failed */
    if (rc < 0) {
        pcre2_match_data_free(match_data);
#ifdef HAVE_JIT
        if (have_jit && match_context)
            pcre2_match_context_free(match_context);
#endif
        if (rc != PCRE2_ERROR_NOMATCH) {
            croak("PCRE2 error %d\n", rc);
        }
        return 0;
    }

    re->subbeg = strbeg;
    re->sublen = strend - strbeg;

    rc = pcre2_get_ovector_count(match_data);
    ovector = pcre2_get_ovector_pointer(match_data);
    for (i = 0; i < rc; i++) {
        re->offs[i].start = ovector[i * 2];
        re->offs[i].end   = ovector[i * 2 + 1];
    }

    for (i = rc; i <= re->nparens; i++) {
        re->offs[i].start = -1;
        re->offs[i].end   = -1;
    }

    /* XXX: nparens needs to be set to CAPTURECOUNT */
    pcre2_match_data_free(match_data);
#ifdef HAVE_JIT
    if (have_jit && match_context)
        pcre2_match_context_free(match_context);
#endif
    return 1;
}

char *
#if PERL_VERSION < 20
PCRE2_intuit(pTHX_ REGEXP * const rx, SV * sv,
             char *strpos, char *strend, const U32 flags, re_scream_pos_data *data)
#else
PCRE2_intuit(pTHX_ REGEXP * const rx, SV * sv, const char *strbeg,
             char *strpos, char *strend, U32 flags, re_scream_pos_data *data)
#endif
{
	PERL_UNUSED_ARG(rx);
	PERL_UNUSED_ARG(sv);
#if PERL_VERSION >= 20
	PERL_UNUSED_ARG(strbeg);
#endif
	PERL_UNUSED_ARG(strpos);
	PERL_UNUSED_ARG(strend);
	PERL_UNUSED_ARG(flags);
	PERL_UNUSED_ARG(data);
    return NULL;
}

SV *
PCRE2_checkstr(pTHX_ REGEXP * const rx)
{
    PERL_UNUSED_ARG(rx);
    return NULL;
}

void
PCRE2_free(pTHX_ REGEXP * const rx)
{
    regexp * re = RegSV(rx);
    pcre2_code_free(re->pprivate);
}

void *
PCRE2_dupe(pTHX_ REGEXP * const rx, CLONE_PARAMS *param)
{
    PERL_UNUSED_ARG(param);
    regexp * re = RegSV(rx);
    return re->pprivate;
}

SV *
PCRE2_package(pTHX_ REGEXP * const rx)
{
    PERL_UNUSED_ARG(rx);
    return newSVpvs("re::engine::PCRE2");
}

/*
 * Internal utility functions
 */

#if PERL_VERSION >= 14
void
PCRE2_make_nametable(regexp * const re, pcre2_code * const ri, const I32 namecount)
{
    unsigned char *name_table, *tabptr;
    U32 name_entry_size;
    int i;

    /* The name table */
    (void)pcre2_pattern_info(ri, PCRE2_INFO_NAMETABLE, &name_table);

    /* Size of each entry */
    (void)pcre2_pattern_info(ri, PCRE2_INFO_NAMEENTRYSIZE, &name_entry_size);

    re->paren_names = newHV();
    tabptr = name_table;

    for (i = 0; i < namecount; i++) {
        const char *key = (char*)tabptr + 2;
        int npar = (tabptr[0] << 8) | tabptr[1];
        SV *sv_dat = *hv_fetch(re->paren_names, key, strlen(key), TRUE);

        if (!sv_dat)
            croak("panic: paren_name hash element allocation failed");

        if (!SvPOK(sv_dat)) {
            /* The first (and maybe only) entry with this name */
            (void)SvUPGRADE(sv_dat, SVt_PVNV);
            sv_setpvn(sv_dat, (char *)&(npar), sizeof(I32));
            SvIOK_on(sv_dat);
            SvIVX(sv_dat) = 1;
        } else {
            /* An entry under this name has appeared before, append */
            IV count = SvIV(sv_dat);
            I32 *pv = (I32*)SvPVX(sv_dat);
            IV j;

            for (j = 0 ; j < count ; j++) {
                if (pv[i] == npar) {
                    count = 0;
                    break;
                }
            }

            if (count) {
                pv = (I32*)SvGROW(sv_dat, SvCUR(sv_dat) + sizeof(I32)+1);
                SvCUR_set(sv_dat, SvCUR(sv_dat) + sizeof(I32));
                pv[count] = npar;
                SvIVX(sv_dat)++;
            }
        }

        tabptr += name_entry_size;
    }
}
#endif

MODULE = re::engine::PCRE2	PACKAGE = re::engine::PCRE2
PROTOTYPES: ENABLE

void
ENGINE(...)
PROTOTYPE:
PPCODE:
    mXPUSHs(newSViv(PTR2IV(&pcre2_engine)));

# pattern options

U32
_alloptions(REGEXP *rx)
PROTOTYPE: $
CODE:
    regexp * re = RegSV(rx);
    pcre2_pattern_info(re->pprivate, PCRE2_INFO_ALLOPTIONS, &RETVAL);
OUTPUT:
    RETVAL

U32
_argoptions(REGEXP *rx)
PROTOTYPE: $
CODE:
    regexp * re = RegSV(rx);
    pcre2_pattern_info(re->pprivate, PCRE2_INFO_ARGOPTIONS, &RETVAL);
OUTPUT:
    RETVAL

U32
backrefmax(REGEXP *rx)
PROTOTYPE: $
CODE:
    regexp * re = RegSV(rx);
    pcre2_pattern_info(re->pprivate, PCRE2_INFO_BACKREFMAX, &RETVAL);
OUTPUT:
    RETVAL

U32
bsr(REGEXP *rx)
PROTOTYPE: $
CODE:
    regexp * re = RegSV(rx);
    pcre2_pattern_info(re->pprivate, PCRE2_INFO_BSR, &RETVAL);
OUTPUT:
    RETVAL

U32
capturecount(REGEXP *rx)
PROTOTYPE: $
CODE:
    regexp * re = RegSV(rx);
    pcre2_pattern_info(re->pprivate, PCRE2_INFO_CAPTURECOUNT, &RETVAL);
OUTPUT:
    RETVAL

# returns a 256-bit table
void
firstbitmap(REGEXP *rx)
PROTOTYPE: $
PPCODE:
    char* table;
    regexp * re = RegSV(rx);
    pcre2_pattern_info(re->pprivate, PCRE2_INFO_FIRSTBITMAP, table);
    if (table)
        mXPUSHp(table, 256/8);

U32
firstcodetype(REGEXP *rx)
PROTOTYPE: $
CODE:
    regexp * re = RegSV(rx);
    pcre2_pattern_info(re->pprivate, PCRE2_INFO_FIRSTCODETYPE, &RETVAL);
OUTPUT:
    RETVAL

U32
firstcodeunit(REGEXP *rx)
PROTOTYPE: $
CODE:
    regexp * re = RegSV(rx);
    pcre2_pattern_info(re->pprivate, PCRE2_INFO_FIRSTCODEUNIT, &RETVAL);
OUTPUT:
    RETVAL

U32
hasbackslashc(REGEXP *rx)
PROTOTYPE: $
CODE:
    regexp * re = RegSV(rx);
    pcre2_pattern_info(re->pprivate, PCRE2_INFO_HASBACKSLASHC, &RETVAL);
OUTPUT:
    RETVAL

U32
hascrorlf(REGEXP *rx)
PROTOTYPE: $
CODE:
    regexp * re = RegSV(rx);
    pcre2_pattern_info(re->pprivate, PCRE2_INFO_HASCRORLF, &RETVAL);
OUTPUT:
    RETVAL

U32
jchanged(REGEXP *rx)
PROTOTYPE: $
CODE:
    regexp * re = RegSV(rx);
    pcre2_pattern_info(re->pprivate, PCRE2_INFO_JCHANGED, &RETVAL);
OUTPUT:
    RETVAL

U32
jitsize(REGEXP *rx)
PROTOTYPE: $
CODE:
    regexp * re = RegSV(rx);
    pcre2_pattern_info(re->pprivate, PCRE2_INFO_JITSIZE, &RETVAL);
OUTPUT:
    RETVAL

U32
lastcodetype(REGEXP *rx)
PROTOTYPE: $
CODE:
    regexp * re = RegSV(rx);
    pcre2_pattern_info(re->pprivate, PCRE2_INFO_LASTCODETYPE, &RETVAL);
OUTPUT:
    RETVAL

U32
lastcodeunit(REGEXP *rx)
PROTOTYPE: $
CODE:
    regexp * re = RegSV(rx);
    pcre2_pattern_info(re->pprivate, PCRE2_INFO_LASTCODEUNIT, &RETVAL);
OUTPUT:
    RETVAL

U32
matchempty(REGEXP *rx)
PROTOTYPE: $
CODE:
    regexp * re = RegSV(rx);
    pcre2_pattern_info(re->pprivate, PCRE2_INFO_MATCHEMPTY, &RETVAL);
OUTPUT:
    RETVAL

U32
matchlimit(REGEXP *rx)
PROTOTYPE: $
CODE:
    regexp * re = RegSV(rx);
    if (pcre2_pattern_info(re->pprivate, PCRE2_INFO_MATCHLIMIT, &RETVAL) < 0)
        XSRETURN_EMPTY;
OUTPUT:
    RETVAL

U32
maxlookbehind(REGEXP *rx)
PROTOTYPE: $
CODE:
    regexp * re = RegSV(rx);
    pcre2_pattern_info(re->pprivate, PCRE2_INFO_MAXLOOKBEHIND, &RETVAL);
OUTPUT:
    RETVAL

U32
minlength(REGEXP *rx)
PROTOTYPE: $
CODE:
    regexp * re = RegSV(rx);
    pcre2_pattern_info(re->pprivate, PCRE2_INFO_MINLENGTH, &RETVAL);
OUTPUT:
    RETVAL

U32
namecount(REGEXP *rx)
PROTOTYPE: $
CODE:
    regexp * re = RegSV(rx);
    pcre2_pattern_info(re->pprivate, PCRE2_INFO_NAMECOUNT, &RETVAL);
OUTPUT:
    RETVAL

U32
nameentrysize(REGEXP *rx)
PROTOTYPE: $
CODE:
    regexp * re = RegSV(rx);
    pcre2_pattern_info(re->pprivate, PCRE2_INFO_NAMEENTRYSIZE, &RETVAL);
OUTPUT:
    RETVAL

#if 0

void
nametable(REGEXP *rx)
PROTOTYPE: $
PPCODE:
    U8* table;
    regexp * re = RegSV(rx);
    pcre2_pattern_info(re->pprivate, PCRE2_INFO_NAMETABLE, &RETVAL);
    if (table)
        mXPUSHp(table, strlen(table));

#endif

U32
newline(REGEXP *rx)
PROTOTYPE: $
CODE:
    regexp * re = RegSV(rx);
    pcre2_pattern_info(re->pprivate, PCRE2_INFO_NEWLINE, &RETVAL);
OUTPUT:
    RETVAL

U32
recursionlimit(REGEXP *rx)
PROTOTYPE: $
CODE:
    regexp * re = RegSV(rx);
    if (pcre2_pattern_info(re->pprivate, PCRE2_INFO_RECURSIONLIMIT, &RETVAL) < 0)
        XSRETURN_EMPTY;
OUTPUT:
    RETVAL

U32
size(REGEXP *rx)
PROTOTYPE: $
CODE:
    regexp * re = RegSV(rx);
    pcre2_pattern_info(re->pprivate, PCRE2_INFO_SIZE, &RETVAL);
OUTPUT:
    RETVAL

void
JIT(...)
PROTOTYPE:
PPCODE:
    uint32_t jit;
    pcre2_config(PCRE2_CONFIG_JIT, &jit);
    mXPUSHi(jit ? 1 : 0);

#define RET_STR(name) \
    if (strEQc(opt, #name)) { \
        if (pcre2_config(PCRE2_CONFIG_##name, &retbuf) >= 0) \
            mXPUSHp(retbuf, strlen(retbuf)); \
    }
#define RET_INT(name) \
    if (strEQc(opt, #name)) { \
        if (pcre2_config(PCRE2_CONFIG_##name, &retint) >= 0) \
            mXPUSHi(retint); \
    }

void
config(char* opt)
PROTOTYPE: $
PPCODE:
    int retint;
    RET_STR(JITTARGET) else
    RET_STR(UNICODE_VERSION) else
    RET_STR(VERSION) else
    RET_INT(BSR) else
    RET_INT(JIT) else
    RET_INT(LINKSIZE) else
    RET_INT(MATCHLIMIT) else
    RET_INT(NEWLINE) else
    RET_INT(PARENSLIMIT) else
#ifdef PCRE2_CONFIG_DEPTHLIMIT
    RET_INT(DEPTHLIMIT) else
#endif
    RET_INT(RECURSIONLIMIT) else
    RET_INT(STACKRECURSE) else
    RET_INT(UNICODE)
