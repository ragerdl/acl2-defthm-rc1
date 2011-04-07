; ACL2 Version 4.2 -- A Computational Logic for Applicative Common Lisp
; Copyright (C) 2011  University of Texas at Austin

; This version of ACL2 is a descendent of ACL2 Version 1.9, Copyright
; (C) 1997 Computational Logic, Inc.  See the documentation topic NOTE-2-0.

; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.

; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.

; You should have received a copy of the GNU General Public License
; along with this program; if not, write to the Free Software
; Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

; Written by:  Matt Kaufmann               and J Strother Moore
; email:       Kaufmann@cs.utexas.edu      and Moore@cs.utexas.edu
; Department of Computer Science
; University of Texas at Austin
; Austin, TX 78701 U.S.A.

; This file, defpkgs.lisp, illustrates the idea that defpkg forms
; should be off in files all by themselves.  We require defpkg forms
; to be in files all by themselves to support the compilation of
; files.  Files with defpkg forms should only be loaded, never
; compiled.  Of course, during the compilation of other files, it will
; be necessary for defpkg files to be loaded at the appropriate time.
; The idea of putting defpkg forms in separate files is in the spirit
; of the CLTL2 idea of putting DEFPACKAGE forms in separate files.  By
; keeping package creation separate from compilation, one avoids many
; pitfalls and inconsistencies between Common Lisp implementations.

(in-package "ACL2")

; Someday we may choose to give a more careful treatment to the issue of
; providing handy lists of symbols to export from the ACL2 package.  The
; constant *acl2-exports* below is a rough, but perhaps adequate, first cut.
; The following forms allow us to create some other lists, based on what is
; currently documentated.  Our thought is that the set of currently documented
; topics has some correspondence with what one may want to export from ACL2,
; but for now we provide this utility only as a comment.

; (verify-termination symbol-class)
; 
; (defun member-eq-t (a lst)
;   (or (eq lst t)
;       (member-eq a lst)))
; 
; (defun filter-topics
;   (in-sections out-sections mode doc-alist wrld acc)
;   (declare (xargs :guard (and (member-eq mode '(:logic :program
;                                                        ;; nil for non-functions
;                                                        nil))
;                               (or (eq in-sections t)
;                                   (symbol-listp in-sections))
;                               (symbol-listp out-sections))
;                   :verify-guards nil))
; 
; ; Need to compile this.
; 
;   (cond
;    ((endp doc-alist) acc)
;    ((and (symbolp (caar doc-alist))
;          (not (equal (symbol-package-name (caar doc-alist)) "ACL2-PC"))
;          (member-eq-t (cadr (car doc-alist)) in-sections)
;          (not (member-eq (cadr (car doc-alist)) out-sections))
;          (let ((fn-symb-p (function-symbolp (caar doc-alist) wrld)))
;            (cond ((eq mode :logic)
;                   (if fn-symb-p
;                       (eq (fdefun-mode (caar doc-alist) wrld) :logic)
;                     (or (getprop (caar doc-alist) 'macro-body nil 'current-acl2-world wrld)
;                         (getprop (caar doc-alist) 'const nil 'current-acl2-world wrld))))
;                  ((eq mode :program)
;                   ;; really means "all but logic"
;                   (and fn-symb-p
;                        (eq (fdefun-mode (caar doc-alist) wrld) :program)))
;                  (t
;                   ;; topics other than functions, macros, and constants
;                   (not (or (getprop (caar doc-alist) 'macro-body nil 'current-acl2-world wrld)
;                            (getprop (caar doc-alist) 'const nil 'current-acl2-world wrld)
;                            fn-symb-p))))))
;     (filter-topics in-sections out-sections mode (cdr doc-alist) wrld
;                    (cons (caar doc-alist) acc)))
;    (t
;     (filter-topics in-sections out-sections mode (cdr doc-alist) wrld acc))))
; 
; (comp 'filter-topics)
; 
; ; Now consider the following table (`P' is "Programming", `A' is "Arrays").
; ; "In" lists doc sections that we may want included, while "Out" lists those
; ; to be excluded.  Mode :logic is what we may want to export if we choose to
; ; stay in defun-mode :logic; :program is what is left.
; 
; ; In    Out  Mode
; ; P,A   ()   :logic
; ; P,A   ()   :program
; ; P,A   ()   nil
; ; T     P,A  :logic
; ; T     P,A  :program
; ; T     P,A  nil
; 
; Thus we have:
; 
; In    Out  Mode
; P,A   ()   :logic
; (filter-topics '(programming arrays) nil :logic
;                (global-val 'documentation-alist (w state)) (w state) nil)
; 
; In    Out  Mode
; P,A   ()   :program
; (filter-topics '(programming arrays) nil :program
;                (global-val 'documentation-alist (w state)) (w state) nil)
; 
; In    Out  Mode
; P,A   ()   :logic
; (filter-topics '(programming arrays) nil nil
;                (global-val 'documentation-alist (w state)) (w state) nil)
; 
; In    Out  Mode
; T     P,A  :logic
; 
; (filter-topics t '(programming arrays) :logic
;                (global-val 'documentation-alist (w state)) (w state) nil)
; 
; In    Out  Mode
; T     P,A  :program
; (filter-topics t '(programming arrays) :program
;                (global-val 'documentation-alist (w state)) (w state) nil)
; 
; In    Out  Mode
; T     P,A  nil
; (filter-topics t '(programming arrays) nil
;                (global-val 'documentation-alist (w state)) (w state) nil)

; The following ``policy'' was used to determine this setting of *acl2-exports*.
; First, if the user wishes to program in ACL2, he or she will import
; *common-lisp-symbols-from-main-lisp-package* in addition to *acl2-exports*.
; So this list was set primarily with theorem proving in mind.

; Prior to ACL2 Version_2.4, the list was short.  It contained 55 symbols.
; Before the release of ACL2 Version_2.5 we added symbols to the list.  The
; symbols added were, in some cases dependent on the :DOC topics as of
; 2.5.

; (a) all :logic mode functions
; (b) most of the symbols users had imported into packages in books/,
; (c) selected :program mode functions with :DOC topics,
; (d) all macros with :DOC topics,
; (e) selected constants with :DOC topics,
; (f) certain other constants
; (g) symbols used to write defuns and theorems, gathered by looking
;     at the documentation for DECLARE, HINTS, RULE-CLASSES, MACROS

; This is still not very systematic, because there is a fundamental
; tension: if we make it conveniently large we import symbols the user
; might wish to define.

(defconst *acl2-exports*

; See books/misc/check-acl2-exports.lisp for a list of symbols,
; *acl2-exports-exclusions*, deliberately excluded from this list.

; Let's keep this list sorted (more efficient for defpkg when users choose to
; import these symbols, to avoid having to sort it then).

  (sort-symbol-listp
   (append
    *hons-primitives* ; even for non-hons version, for compatibility of the two
    '(TRACE* ; not defined by ACL2, but may well be defined in a book
      GRANULARITY ; for parallelism primitives
      )
    '(& &ALLOW-OTHER-KEYS &AUX &BODY &KEY
        &OPTIONAL &REST &WHOLE * *ACL2-EXPORTS*
        *COMMON-LISP-SPECIALS-AND-CONSTANTS*
        *COMMON-LISP-SYMBOLS-FROM-MAIN-LISP-PACKAGE*
        *MAIN-LISP-PACKAGE-NAME*
        *STANDARD-CHARS* *STANDARD-CI*
        *STANDARD-CO* *STANDARD-OI*
        + - / /= 1+ 1- 32-BIT-INTEGER-LISTP
        32-BIT-INTEGER-LISTP-FORWARD-TO-INTEGER-LISTP
        32-BIT-INTEGER-STACK
        32-BIT-INTEGER-STACK-LENGTH
        32-BIT-INTEGER-STACK-LENGTH1
        32-BIT-INTEGERP
        32-BIT-INTEGERP-FORWARD-TO-INTEGERP
        < <-ON-OTHERS <= = > >= ?-FN @ A! ABORT!
        ABS ACCUMULATED-PERSISTENCE ACL2-COUNT
        ACL2-INPUT-CHANNEL-PACKAGE ACL2-NUMBERP
        ACL2-ORACLE ACL2-OUTPUT-CHANNEL-PACKAGE
        ACL2-PACKAGE ACONS ACTIVE-RUNEP
        ADD-BINOP ADD-CUSTOM-KEYWORD-HINT
        ADD-DEFAULT-HINTS
        ADD-DEFAULT-HINTS! ADD-INCLUDE-BOOK-DIR
        ADD-INVISIBLE-FNS ADD-MACRO-ALIAS
        ADD-MATCH-FREE-OVERRIDE ADD-NTH-ALIAS
        ADD-OVERRIDE-HINTS ADD-OVERRIDE-HINTS!
        ADD-PAIR ADD-PAIR-PRESERVES-ALL-BOUNDP
        ADD-RAW-ARITY ADD-TIMERS ADD-TO-SET ADD-TO-SET-EQ
        ADD-TO-SET-EQL ADD-TO-SET-EQUAL
        ALISTP ALISTP-FORWARD-TO-TRUE-LISTP
        ALL-BOUNDP ALL-BOUNDP-PRESERVES-ASSOC
        ALL-VARS ALL-VARS1 ALL-VARS1-LST
        ALLOCATE-FIXNUM-RANGE ALPHA-CHAR-P
        ALPHA-CHAR-P-FORWARD-TO-CHARACTERP
        ALPHORDER AND AND-MACRO APPEND
        AREF-32-BIT-INTEGER-STACK AREF-T-STACK
        AREF1 AREF2 ARGS ARRAY1P ARRAY1P-CONS
        ARRAY1P-FORWARD ARRAY1P-LINEAR
        ARRAY2P ARRAY2P-CONS ARRAY2P-FORWARD
        ARRAY2P-LINEAR ASET-32-BIT-INTEGER-STACK
        ASET-T-STACK ASET1 ASET2
        ASH ASSERT$ ASSERT-EVENT ASSIGN ASSOC
        ASSOC-ADD-PAIR ASSOC-EQ ASSOC-EQ-EQUAL
        ASSOC-EQ-EQUAL-ALISTP ASSOC-EQUAL
        ASSOC-KEYWORD ASSOC-STRING-EQUAL ASSOC2
        ASSOCIATIVITY-OF-* ASSOCIATIVITY-OF-+
        ASSUME ATOM ATOM-LISTP
        ATOM-LISTP-FORWARD-TO-TRUE-LISTP
        BACKCHAIN-LIMIT BIG-CLOCK-ENTRY
        BIG-CLOCK-NEGATIVE-P BINARY-*
        BINARY-+ BINARY-APPEND BIND-FREE
        BINOP-TABLE BIT BOOLE$ BOOLEAN-LISTP
        BOOLEAN-LISTP-CONS BOOLEAN-LISTP-FORWARD
        BOOLEAN-LISTP-FORWARD-TO-SYMBOL-LISTP
        BOOLEANP BOOLEANP-CHARACTERP
        BOOLEANP-COMPOUND-RECOGNIZER
        BOUNDED-INTEGER-ALISTP
        BOUNDED-INTEGER-ALISTP-FORWARD-TO-EQLABLE-ALISTP
        BOUNDED-INTEGER-ALISTP2 BOUNDP-GLOBAL
        BOUNDP-GLOBAL1 BREAK$ BREAK-ON-ERROR
        BRR BRR@ BUILD-STATE1 BUTLAST
        CAAAAR CAAADR CAAAR CAADAR CAADDR
        CAADR CAAR CADAAR CADADR CADAR CADDAR
        CADDDR CADDR CADR CANONICAL-PATHNAME
        CAR CAR-CDR-ELIM CAR-CONS CASE
        CASE-LIST CASE-LIST-CHECK CASE-MATCH
        CASE-SPLIT CASE-SPLIT-LIMITATIONS
        CASE-TEST CBD CDAAAR CDAADR
        CDAAR CDADAR CDADDR CDADR CDAR CDDAAR
        CDDADR CDDAR CDDDAR CDDDDR CDDDR CDDR
        CDR CDR-CONS CDRN CEILING CERTIFY-BOOK
        CERTIFY-BOOK! CHAR CHAR-CODE
        CHAR-CODE-CODE-CHAR-IS-IDENTITY
        CHAR-CODE-LINEAR CHAR-DOWNCASE
        CHAR-EQUAL CHAR-UPCASE CHAR< CHAR<=
        CHAR> CHAR>= CHARACTER CHARACTER-ALISTP
        CHARACTER-LISTP CHARACTER-LISTP-APPEND
        CHARACTER-LISTP-COERCE
        CHARACTER-LISTP-FORWARD-TO-EQLABLE-LISTP
        CHARACTER-LISTP-REMOVE-DUPLICATES-EQL
        CHARACTER-LISTP-REVAPPEND
        CHARACTER-LISTP-STRING-DOWNCASE-1
        CHARACTER-LISTP-STRING-UPCASE1-1
        CHARACTERP CHARACTERP-CHAR-DOWNCASE
        CHARACTERP-CHAR-UPCASE CHARACTERP-NTH
        CHARACTERP-PAGE CHARACTERP-RUBOUT
        CHARACTERP-TAB CHECK-VARS-NOT-FREE
        CHECKPOINT-FORCED-GOALS CLAUSE
        CLOSE-INPUT-CHANNEL CLOSE-OUTPUT-CHANNEL
        CLOSE-TRACE-FILE CLOSURE CODE-CHAR
        CODE-CHAR-CHAR-CODE-IS-IDENTITY
        CODE-CHAR-TYPE COERCE COERCE-INVERSE-1
        COERCE-INVERSE-2 COERCE-OBJECT-TO-STATE
        COERCE-STATE-TO-OBJECT
        COMMUTATIVITY-OF-*
        COMMUTATIVITY-OF-+ COMP COMPLETION-OF-*
        COMPLETION-OF-+ COMPLETION-OF-<
        COMPLETION-OF-CAR COMPLETION-OF-CDR
        COMPLETION-OF-CHAR-CODE
        COMPLETION-OF-CODE-CHAR
        COMPLETION-OF-COERCE
        COMPLETION-OF-COMPLEX
        COMPLETION-OF-DENOMINATOR
        COMPLETION-OF-IMAGPART
        COMPLETION-OF-INTERN-IN-PACKAGE-OF-SYMBOL
        COMPLETION-OF-NUMERATOR
        COMPLETION-OF-REALPART
        COMPLETION-OF-SYMBOL-NAME
        COMPLETION-OF-SYMBOL-PACKAGE-NAME
        COMPLETION-OF-UNARY-/
        COMPLETION-OF-UNARY-MINUS
        COMPLEX COMPLEX-0
        COMPLEX-DEFINITION COMPLEX-EQUAL
        COMPLEX-IMPLIES1 COMPLEX-RATIONALP
        COMPLEX/COMPLEX-RATIONALP
        COMPRESS1 COMPRESS11 COMPRESS2
        COMPRESS21 COMPRESS211 CONCATENATE
        COND COND-CLAUSESP COND-MACRO
        CONJUGATE CONS CONS-EQUAL CONSP
        CONSP-ASSOC-EQUAL COROLLARY
        CPU-CORE-COUNT CURRENT-PACKAGE
        CURRENT-THEORY CW CW! CW-GSTACK DECLARE
        DECREMENT-BIG-CLOCK DEFABBREV DEFATTACH
        DEFAULT DEFAULT-*-1 DEFAULT-*-2
        DEFAULT-+-1 DEFAULT-+-2 DEFAULT-<-1
        DEFAULT-<-2 DEFAULT-BACKCHAIN-LIMIT
        DEFAULT-CAR DEFAULT-CDR
        DEFAULT-CHAR-CODE DEFAULT-COERCE-1
        DEFAULT-COERCE-2 DEFAULT-COERCE-3
        DEFAULT-COMPILE-FNS DEFAULT-COMPLEX-1
        DEFAULT-COMPLEX-2 DEFAULT-DEFUN-MODE
        DEFAULT-DEFUN-MODE-FROM-STATE
        DEFAULT-DENOMINATOR
        DEFAULT-HINTS DEFAULT-IMAGPART
        DEFAULT-MEASURE-FUNCTION
        DEFAULT-NUMERATOR DEFAULT-PRINT-PROMPT
        DEFAULT-REALPART DEFAULT-RULER-EXTENDERS
        DEFAULT-SYMBOL-NAME
        DEFAULT-SYMBOL-PACKAGE-NAME
        DEFAULT-UNARY-/ DEFAULT-UNARY-MINUS
        DEFAULT-VERIFY-GUARDS-EAGERNESS
        DEFAULT-WELL-FOUNDED-RELATION
        DEFAXIOM DEFCHOOSE DEFCONG DEFCONST
        DEFDOC DEFEQUIV DEFEVALUATOR DEFEXEC
        DEFINE-PC-ATOMIC-MACRO DEFINE-PC-HELP
        DEFINE-PC-MACRO DEFINE-PC-META
        DEFINE-TRUSTED-CLAUSE-PROCESSOR
        DEFLABEL DEFMACRO DEFMACRO-LAST DEFN DEFPKG
        DEFPROXY DEFREFINEMENT DEFSTOBJ DEFSTUB DEFTHEORY
        DEFTHM DEFTHMD DEFTTAG DEFUN DEFUN-NX
        DEFUN-SK DEFUND DEFUND-NX DEFUNS
        DELETE-ASSOC DELETE-ASSOC-EQ DELETE-ASSOC-EQUAL
        DELETE-INCLUDE-BOOK-DIR DELETE-PAIR
        DENOMINATOR DIGIT-CHAR-P DIGIT-TO-CHAR
        DIMENSIONS DISABLE DISABLE-FORCING
        DISABLE-IMMEDIATE-FORCE-MODEP
        DISABLEDP DISTRIBUTIVITY
        DOC DOC! DOCS DOUBLE-REWRITE
        DUPLICATES E/D E0-ORD-< E0-ORDINALP
        EC-CALL EIGHTH ELIMINATE-DESTRUCTORS
        ELIMINATE-IRRELEVANCE
        ENABLE ENABLE-FORCING
        ENABLE-IMMEDIATE-FORCE-MODEP
        ENCAPSULATE ENDP EQ EQL EQLABLE-ALISTP
        EQLABLE-ALISTP-FORWARD-TO-ALISTP
        EQLABLE-LISTP
        EQLABLE-LISTP-FORWARD-TO-ATOM-LISTP
        EQLABLEP EQLABLEP-RECOG EQUAL
        EQUAL-CHAR-CODE ER ER-PROGN ER-PROGN-FN
        EVENP EVENS EVENT EVISC-TUPLE
        EXECUTABLE-COUNTERPART-THEORY
        EXIT EXPLODE-ATOM
        EXPLODE-NONNEGATIVE-INTEGER EXPT
        EXPT-TYPE-PRESCRIPTION-NON-ZERO-BASE
        EXTEND-32-BIT-INTEGER-STACK
        EXTEND-T-STACK
        EXTEND-WORLD EXTRA-INFO FERTILIZE FC-REPORT
        FGETPROP FIFTH FILE-CLOCK FILE-CLOCK-P
        FILE-CLOCK-P-FORWARD-TO-INTEGERP
        FIRST FIRST-N-AC
        FIX FIX-TRUE-LIST FLET FLOOR FLUSH-COMPRESS
        FMS FMS! FMT FMT! FMT-TO-COMMENT-WINDOW FMT1 FMT1!
        FMS-TO-STRING FMS!-TO-STRING FMT-TO-STRING FMT!-TO-STRING
        FMT1-TO-STRING FMT1!-TO-STRING
        FORCE FOURTH FUNCTION-SYMBOLP
        FUNCTION-THEORY GAG-MODE GC$ GENERALIZE
        GET-GLOBAL GET-OUTPUT-STREAM-STRING$ GET-TIMER GET-WORMHOLE-STATUS
        GETENV$ GETPROP GETPROP-DEFAULT GETPROPS
        GETPROPS1 GLOBAL-TABLE GLOBAL-TABLE-CARS
        GLOBAL-TABLE-CARS1 GLOBAL-VAL
        GOOD-BYE GROUND-ZERO
        GUARD GUARD-OBLIGATION HARD-ERROR
        HAS-PROPSP HAS-PROPSP1 HEADER HELP HIDE
        HONS-ASSOC-EQUAL HONS-COPY-PERSISTENT
        I-AM-HERE ID IDATES IDENTITY
        IF IF* IFF IFF-IMPLIES-EQUAL-IMPLIES-1
        IFF-IMPLIES-EQUAL-IMPLIES-2
        IFF-IMPLIES-EQUAL-NOT
        IFF-IS-AN-EQUIVALENCE IFIX
        IGNORE ILLEGAL IMAGPART IMAGPART-COMPLEX
        IMMEDIATE-FORCE-MODEP IMPLIES
        IMPROPER-CONSP IN-ARITHMETIC-THEORY
        IN-PACKAGE IN-THEORY INCLUDE-BOOK
        INCOMPATIBLE INCREMENT-TIMER
        INDUCT INT= INTEGER INTEGER-0 INTEGER-1
        INTEGER-ABS INTEGER-IMPLIES-RATIONAL
        INTEGER-LENGTH INTEGER-LISTP
        INTEGER-LISTP-FORWARD-TO-RATIONAL-LISTP
        INTEGER-STEP INTEGERP INTERN
        INTERN$ INTERN-IN-PACKAGE-OF-SYMBOL
        INTERN-IN-PACKAGE-OF-SYMBOL-SYMBOL-NAME
        INTERSECTION$ INTERSECTION-EQ
        INTERSECTION-EQUAL INTERSECTION-THEORIES
        INTERSECTP INTERSECTP-EQ
        INTERSECTP-EQUAL INVERSE-OF-*
        INVERSE-OF-+ INVISIBLE-FNS-TABLE
        KEYWORD-PACKAGE KEYWORD-VALUE-LISTP
        KEYWORD-VALUE-LISTP-ASSOC-KEYWORD
        KEYWORD-VALUE-LISTP-FORWARD-TO-TRUE-LISTP
        KEYWORDP KEYWORDP-FORWARD-TO-SYMBOLP
        KNOWN-PACKAGE-ALIST KNOWN-PACKAGE-ALISTP
        KNOWN-PACKAGE-ALISTP-FORWARD-TO-TRUE-LIST-LISTP-AND-ALISTP
        KWOTE
        KWOTE-LST LAMBDA LAST LD LD-ERROR-ACTION
        LD-ERROR-TRIPLES LD-EVISC-TUPLE
        LD-KEYWORD-ALIASES LD-POST-EVAL-PRINT
        LD-PRE-EVAL-FILTER LD-PRE-EVAL-PRINT
        LD-PROMPT LD-QUERY-CONTROL-ALIST
        LD-REDEFINITION-ACTION LD-SKIP-PROOFSP
        LD-VERBOSE LEGAL-CASE-CLAUSESP LEN
        LEN-UPDATE-NTH LENGTH LET* LEXORDER LIST
        LIST* LIST*-MACRO LIST-ALL-PACKAGE-NAMES
        LIST-ALL-PACKAGE-NAMES-LST
        LIST-MACRO LISTP LOCAL LOGAND
        LOGANDC1 LOGANDC2 LOGBITP LOGCOUNT
        LOGEQV LOGIC LOGIOR LOGNAND LOGNOR
        LOGNOT LOGORC1 LOGORC2 LOGTEST LOGXOR
        LOWER-CASE-P LOWER-CASE-P-CHAR-DOWNCASE
        LOWER-CASE-P-FORWARD-TO-ALPHA-CHAR-P
        LOWEST-TERMS LP MACRO-ALIASES MACRO-ARGS
        MAIN-TIMER MAIN-TIMER-TYPE-PRESCRIPTION
        MAKE-CHARACTER-LIST
        MAKE-CHARACTER-LIST-MAKE-CHARACTER-LIST
        MAKE-EVENT
        MAKE-FMT-BINDINGS MAKE-INPUT-CHANNEL
        MAKE-LIST MAKE-LIST-AC MAKE-MV-NTHS
        MAKE-ORD MAKE-OUTPUT-CHANNEL
        MAKE-VAR-LST MAKE-VAR-LST1
        MAKE-WORMHOLE-STATUS MAKUNBOUND-GLOBAL
        MAX MAXIMUM-LENGTH MAY-NEED-SLASHES
        MBE MBT
        MEMBER MEMBER-EQ MEMBER-EQUAL
        MEMBER-SYMBOL-NAME MFC MIN MINIMAL-THEORY MINUSP
        MOD MOD-EXPT MONITOR MONITORED-RUNES
        MORE MORE! MORE-DOC MUST-BE-EQUAL
        MUTUAL-RECURSION MUTUAL-RECURSION-GUARDP
        MV MV? MV-LET MV?-LET MV-LIST
        MV-NTH NATP NEEDS-SLASHES NEWLINE
        NFIX NIL NIL-IS-NOT-CIRCULAR NINTH
        NO-DUPLICATESP NO-DUPLICATESP-EQ NO-DUPLICATESP-EQUAL
        NONNEGATIVE-INTEGER-QUOTIENT
        NONNEGATIVE-PRODUCT NONZERO-IMAGPART
        NOT NQTHM-TO-ACL2 NTH NTH-0-CONS
        NTH-0-READ-RUN-TIME-TYPE-PRESCRIPTION
        NTH-ADD1
        NTH-ALIASES NTH-UPDATE-NTH NTHCDR
        NULL NUMERATOR O-FINP O-FIRST-COEFF
        O-FIRST-EXPT O-INFP O-P O-RST O<
        O<= O> O>= OBSERVATION OBSERVATION-CW ODDP ODDS OK-IF
        OOPS OPEN-CHANNEL-LISTP OPEN-CHANNEL1
        OPEN-CHANNEL1-FORWARD-TO-TRUE-LISTP-AND-CONSP
        OPEN-CHANNELS-P OPEN-CHANNELS-P-FORWARD
        OPEN-INPUT-CHANNEL
        OPEN-INPUT-CHANNEL-ANY-P
        OPEN-INPUT-CHANNEL-ANY-P1
        OPEN-INPUT-CHANNEL-P
        OPEN-INPUT-CHANNEL-P1
        OPEN-INPUT-CHANNELS
        OPEN-OUTPUT-CHANNEL OPEN-OUTPUT-CHANNEL!
        OPEN-OUTPUT-CHANNEL-ANY-P
        OPEN-OUTPUT-CHANNEL-ANY-P1
        OPEN-OUTPUT-CHANNEL-P
        OPEN-OUTPUT-CHANNEL-P1
        OPEN-OUTPUT-CHANNELS OPEN-TRACE-FILE
        OR OR-MACRO ORDERED-SYMBOL-ALISTP
        ORDERED-SYMBOL-ALISTP-ADD-PAIR
        ORDERED-SYMBOL-ALISTP-ADD-PAIR-FORWARD
        ORDERED-SYMBOL-ALISTP-FORWARD-TO-SYMBOL-ALISTP
        ORDERED-SYMBOL-ALISTP-GETPROPS
        ORDERED-SYMBOL-ALISTP-REMOVE-FIRST-PAIR
        OTHERWISE
        OUR-DIGIT-CHAR-P OVERRIDE-HINTS
        P! PKG-IMPORTS PAIRLIS$ PAIRLIS2 PAND PARGS
        PBT PC PCB PCB! PCS PE PE! PEEK-CHAR$
        PF PKG-WITNESS PL PL2 PLET PLIST-WORLDP
        PLIST-WORLDP-FORWARD-TO-ASSOC-EQ-EQUAL-ALISTP
        PLUSP POP-TIMER POR POSITION
        POSITION-AC POSITION-EQ POSITION-EQ-AC
        POSITION-EQUAL POSITION-EQUAL-AC
        POSITIVE POSP POWER-EVAL PPROGN PR
        PR! PREPROCESS PRIN1$ PRIN1-WITH-SLASHES
        PRIN1-WITH-SLASHES1 PRINC$ PRINT-GV
        PRINT-OBJECT$ PRINT-RATIONAL-AS-DECIMAL
        PRINT-TIMER PROG2$ PROGN PROGN! PROGRAM
        PROOF-TREE PROOFS-CO PROPER-CONSP
        PROPS PROVE PSEUDO-TERM-LISTP
        PSEUDO-TERM-LISTP-FORWARD-TO-TRUE-LISTP
        PSEUDO-TERMP PSO PSO! PSOG PSTACK
        PUFF PUFF* PUSH-TIMER PUSH-UNTOUCHABLE
        PUT-ASSOC PUT-ASSOC-EQ PUT-ASSOC-EQL
        PUT-ASSOC-EQUAL PUT-GLOBAL PUTPROP
        QUIT QUOTE QUOTEP R-SYMBOL-ALISTP R-EQLABLE-ALISTP
        RANDOM$ RASSOC RASSOC-EQ RASSOC-EQUAL
        RATIO RATIONAL RATIONAL-IMPLIES1
        RATIONAL-IMPLIES2 RATIONAL-LISTP
        RATIONAL-LISTP-FORWARD-TO-TRUE-LISTP
        RATIONALP RATIONALP-* RATIONALP-+
        RATIONALP-EXPT-TYPE-PRESCRIPTION
        RATIONALP-IMPLIES-ACL2-NUMBERP
        RATIONALP-UNARY--
        RATIONALP-UNARY-/ READ-ACL2-ORACLE
        READ-ACL2-ORACLE-PRESERVES-STATE-P1
        READ-BYTE$ READ-CHAR$ READ-FILE-LISTP
        READ-FILE-LISTP-FORWARD-TO-TRUE-LIST-LISTP
        READ-FILE-LISTP1
        READ-FILE-LISTP1-FORWARD-TO-TRUE-LISTP-AND-CONSP
        READ-FILES READ-FILES-P
        READ-FILES-P-FORWARD-TO-READ-FILE-LISTP
        READ-IDATE READ-OBJECT READ-RUN-TIME
        READ-RUN-TIME-PRESERVES-STATE-P1
        READABLE-FILE
        READABLE-FILE-FORWARD-TO-TRUE-LISTP-AND-CONSP
        READABLE-FILES READABLE-FILES-LISTP
        READABLE-FILES-LISTP-FORWARD-TO-TRUE-LIST-LISTP-AND-ALISTP
        READABLE-FILES-P
        READABLE-FILES-P-FORWARD-TO-READABLE-FILES-LISTP
        REAL/RATIONALP REALFIX REALPART
        REALPART-COMPLEX REALPART-IMAGPART-ELIM
        REBUILD REDEF REDEF!
        REDEF+ REDEF- REDO-FLAT REM REMOVE
        REMOVE-BINOP REMOVE-CUSTOM-KEYWORD-HINT
        REMOVE-DEFAULT-HINTS
        REMOVE-DEFAULT-HINTS!
        REMOVE-DUPLICATES REMOVE-DUPLICATES-EQ REMOVE-DUPLICATES-EQL
        REMOVE-DUPLICATES-EQUAL
        REMOVE-EQ REMOVE-EQUAL REMOVE-FIRST-PAIR
        REMOVE-INVISIBLE-FNS REMOVE-MACRO-ALIAS
        REMOVE-NTH-ALIAS REMOVE-OVERRIDE-HINTS
        REMOVE-OVERRIDE-HINTS!
        REMOVE-RAW-ARITY REMOVE-UNTOUCHABLE
        REMOVE1 REMOVE1-EQ REMOVE1-EQUAL RESET-FC-REPORTING
        RESET-KILL-RING RESET-LD-SPECIALS
        RESET-PREHISTORY RESET-PRINT-CONTROL
        RESIZE-LIST REST RETRACT-WORLD
        RETRIEVE RETURN-LAST RETURN-LAST-TABLE
        REVAPPEND REVERSE REWRITE-STACK-LIMIT
        RFIX ROUND SATISFIES SAVE-EXEC
        SEARCH SECOND SET-BACKCHAIN-LIMIT
        SET-BODY SET-BOGUS-DEFUN-HINTS-OK
        SET-BOGUS-MUTUAL-RECURSION-OK
        SET-CASE-SPLIT-LIMITATIONS
        SET-CBD SET-CHECKPOINT-SUMMARY-LIMIT
        SET-COMPILE-FNS
        SET-COMPILER-ENABLED SET-DEBUGGER-ENABLE
        SET-DEFAULT-BACKCHAIN-LIMIT
        SET-DEFAULT-HINTS SET-DEFAULT-HINTS!
        SET-DEFERRED-TTAG-NOTES
        SET-DIFFERENCE-EQ SET-DIFFERENCE-EQUAL SET-DIFFERENCE$
        SET-DIFFERENCE-THEORIES
        SET-ENFORCE-REDUNDANCY
        SET-EQUALP-EQUAL SET-EVISC-TUPLE
        SET-FC-CRITERIA SET-FC-REPORT-ON-THE-FLY
        SET-FMT-HARD-RIGHT-MARGIN
        SET-FMT-SOFT-RIGHT-MARGIN
        SET-GAG-MODE SET-GUARD-CHECKING
        SET-IGNORE-DOC-STRING-ERROR
        SET-IGNORE-OK SET-INHIBIT-OUTPUT-LST
        SET-INHIBIT-WARNINGS
        SET-INHIBITED-SUMMARY-TYPES
        SET-INVISIBLE-FNS-TABLE
        SET-IPRINT SET-IRRELEVANT-FORMALS-OK
        SET-LD-KEYWORD-ALIASES
        SET-LD-REDEFINITION-ACTION
        SET-LD-SKIP-PROOFS
        SET-LD-SKIP-PROOFSP SET-LET*-ABSTRACTION
        SET-LET*-ABSTRACTIONP
        SET-MATCH-FREE-DEFAULT
        SET-MATCH-FREE-ERROR
        SET-MEASURE-FUNCTION SET-NON-LINEAR
        SET-NON-LINEARP SET-NU-REWRITER-MODE
        SET-OVERRIDE-HINTS SET-OVERRIDE-HINTS!
        SET-PARALLEL-EVALUATION
        SET-PRINT-BASE SET-PRINT-CASE
        SET-PRINT-CIRCLE SET-PRINT-CLAUSE-IDS
        SET-PRINT-ESCAPE SET-PRINT-LENGTH
        SET-PRINT-LEVEL SET-PRINT-LINES
        SET-PRINT-RADIX SET-PRINT-READABLY
        SET-PRINT-RIGHT-MARGIN SET-RAW-MODE
        SET-RAW-MODE-ON! SET-RAW-PROOF-FORMAT
        SET-REWRITE-STACK-LIMIT
        SET-RULER-EXTENDERS
        SET-SAVED-OUTPUT SET-STATE-OK
        SET-PROVER-STEP-LIMIT
        SET-TAINTED-OK SET-TAINTED-OKP
        SET-TIMER SET-TRACE-EVISC-TUPLE
        SET-VERIFY-GUARDS-EAGERNESS
        SET-W SET-WELL-FOUNDED-RELATION
        SET-WORMHOLE-DATA
        SET-WORMHOLE-ENTRY-CODE SET-WRITE-ACL2X SETENV$ SEVENTH
        SGETPROP SHOW-ACCUMULATED-PERSISTENCE
        SHOW-BDD SHOW-BODIES SHOW-CUSTOM-KEYWORD-HINT-EXPANSION
        SHOW-FC-CRITERIA SHRINK-32-BIT-INTEGER-STACK
        SHRINK-T-STACK
        SIGNED-BYTE SIGNUM SIMPLIFY
        SIXTH SKIP-PROOFS SOME-SLASHABLE
        STABLE-UNDER-SIMPLIFICATIONP
        STANDARD-CHAR STANDARD-CHAR-LISTP
        STANDARD-CHAR-LISTP-APPEND
        STANDARD-CHAR-LISTP-FORWARD-TO-CHARACTER-LISTP
        STANDARD-CHAR-P
        STANDARD-CHAR-P-NTH STANDARD-CO
        STANDARD-OI STANDARD-STRING-ALISTP
        STANDARD-STRING-ALISTP-FORWARD-TO-ALISTP
        START-PROOF-TREE
        STATE STATE-GLOBAL-LET*-CLEANUP
        STATE-GLOBAL-LET*-GET-GLOBALS
        STATE-GLOBAL-LET*-PUT-GLOBALS STATE-P
        STATE-P-IMPLIES-AND-FORWARD-TO-STATE-P1
        STATE-P1 STATE-P1-FORWARD
        STATE-P1-UPDATE-MAIN-TIMER
        STATE-P1-UPDATE-NTH-2-WORLD
        STEP-LIMIT
        STOP-PROOF-TREE
        STRING STRING-APPEND STRING-APPEND-LST
        STRING-DOWNCASE STRING-DOWNCASE1
        STRING-EQUAL STRING-EQUAL1
        STRING-IS-NOT-CIRCULAR STRING-LISTP
        STRING-UPCASE STRING-UPCASE1
        STRING< STRING<-IRREFLEXIVE
        STRING<-L STRING<-L-ASYMMETRIC
        STRING<-L-IRREFLEXIVE
        STRING<-L-TRANSITIVE
        STRING<-L-TRICHOTOMY
        STRING<= STRING> STRING>=
        STRINGP STRINGP-SYMBOL-PACKAGE-NAME
        STRIP-CARS STRIP-CDRS SUBLIS
        SUBSEQ SUBSEQ-LIST SUBSETP SUBSETP-EQ SUBSETP-EQUAL
        SUBST SUBSTITUTE SUBSTITUTE-AC SUMMARY
        SYMBOL SYMBOL-< SYMBOL-<-ASYMMETRIC
        SYMBOL-<-IRREFLEXIVE SYMBOL-<-TRANSITIVE
        SYMBOL-<-TRICHOTOMY SYMBOL-ALISTP
        SYMBOL-ALISTP-FORWARD-TO-EQLABLE-ALISTP
        SYMBOL-DOUBLET-LISTP
        SYMBOL-EQUALITY SYMBOL-LISTP
        SYMBOL-LISTP-FORWARD-TO-TRUE-LISTP
        SYMBOL-NAME
        SYMBOL-NAME-INTERN-IN-PACKAGE-OF-SYMBOL
        SYMBOL-PACKAGE-NAME SYMBOLP
        SYMBOLP-INTERN-IN-PACKAGE-OF-SYMBOL
        SYNP SYNTAXP SYS-CALL SYS-CALL-STATUS
        T T-STACK T-STACK-LENGTH T-STACK-LENGTH1
        TABLE TABLE-ALIST TAKE TENTH
        TERM-ORDER THE THE-ERROR THE-FIXNUM
        THE-FIXNUM! THEORY THEORY-INVARIANT
        THIRD THM TIME$ TIMER-ALISTP
        TIMER-ALISTP-FORWARD-TO-TRUE-LIST-LISTP-AND-SYMBOL-ALISTP
        TOGGLE-PC-MACRO
        TOP-LEVEL TRACE! TRACE$ TRANS
        TRANS! TRANS1 TRICHOTOMY TRUE-LIST-LISTP
        TRUE-LIST-LISTP-FORWARD-TO-TRUE-LISTP
        TRUE-LIST-LISTP-FORWARD-TO-TRUE-LISTP-ASSOC-EQUAL
        TRUE-LISTP
        TRUE-LISTP-CADR-ASSOC-EQ-FOR-OPEN-CHANNELS-P
        TRUE-LISTP-UPDATE-NTH
        TRUNCATE TTAGS-SEEN TYPE TYPED-IO-LISTP
        TYPED-IO-LISTP-FORWARD-TO-TRUE-LISTP
        U UBT UBT!
        UBT-PREHISTORY UBU UBU! UNARY-- UNARY-/
        UNARY-FUNCTION-SYMBOL-LISTP UNICITY-OF-0
        UNICITY-OF-1 UNION$ UNION-EQ UNION-EQUAL
        UNION-THEORIES UNIVERSAL-THEORY
        UNMONITOR UNSAVE UNSIGNED-BYTE UNTRACE$
        UNTRANSLATE UPDATE-32-BIT-INTEGER-STACK
        UPDATE-ACL2-ORACLE
        UPDATE-ACL2-ORACLE-PRESERVES-STATE-P1
        UPDATE-BIG-CLOCK-ENTRY UPDATE-FILE-CLOCK
        UPDATE-GLOBAL-TABLE UPDATE-IDATES
        UPDATE-LIST-ALL-PACKAGE-NAMES-LST
        UPDATE-NTH UPDATE-OPEN-INPUT-CHANNELS
        UPDATE-OPEN-OUTPUT-CHANNELS
        UPDATE-READ-FILES
        UPDATE-T-STACK UPDATE-USER-STOBJ-ALIST
        UPDATE-USER-STOBJ-ALIST1
        UPDATE-WRITTEN-FILES
        UPPER-CASE-P UPPER-CASE-P-CHAR-UPCASE
        UPPER-CASE-P-FORWARD-TO-ALPHA-CHAR-P
        USER-STOBJ-ALIST USER-STOBJ-ALIST1
        VALUE-TRIPLE VERBOSE-PSTACK VERIFY
        VERIFY-GUARDS VERIFY-GUARDS-FORMULA
        VERIFY-TERMINATION W WALKABOUT
        WARNING! WET WITH-GUARD-CHECKING
        WITH-LIVE-STATE WITH-LOCAL-STATE WITH-LOCAL-STOBJ WITH-OUTPUT
        WITH-PROVER-STEP-LIMIT WITH-PROVER-TIME-LIMIT WITHOUT-EVISC
        WORLD WORMHOLE WORMHOLE-DATA
        WORMHOLE-ENTRY-CODE WORMHOLE-EVAL
        WORMHOLE-P WORMHOLE-STATUSP
        WORMHOLE1 WRITABLE-FILE-LISTP
        WRITABLE-FILE-LISTP-FORWARD-TO-TRUE-LIST-LISTP
        WRITABLE-FILE-LISTP1
        WRITABLE-FILE-LISTP1-FORWARD-TO-TRUE-LISTP-AND-CONSP
        WRITE-BYTE$
        WRITEABLE-FILES WRITEABLE-FILES-P
        WRITEABLE-FILES-P-FORWARD-TO-WRITABLE-FILE-LISTP
        WRITTEN-FILE
        WRITTEN-FILE-FORWARD-TO-TRUE-LISTP-AND-CONSP
        WRITTEN-FILE-LISTP
        WRITTEN-FILE-LISTP-FORWARD-TO-TRUE-LIST-LISTP-AND-ALISTP
        WRITTEN-FILES WRITTEN-FILES-P
        WRITTEN-FILES-P-FORWARD-TO-WRITTEN-FILE-LISTP
        XARGS XOR XXXJOIN ZERO ZEROP ZIP ZP ZPF

; For ACL2(r):

        DEFTHM-STD DEFUN-STD DEFUNS-STD
        I-CLOSE I-LARGE I-LIMITED I-SMALL
        REAL-LISTP STANDARD-PART STANDARDP)))

  "This is the list of ACL2 symbols that the ordinary user is extremely
likely to want to include in the import list of any package created
because these symbols are the basic hooks for using ACL2.  However,
it is never necessary to do such importing: one can always use the
acl2:: prefix."

  )

(defpkg "ACL2-USER"
  (union-eq *acl2-exports*
            *common-lisp-symbols-from-main-lisp-package*)

  ":Doc-Section ACL2::Programming

  a package the ACL2 user may prefer~/

  This package imports the standard Common Lisp symbols that ACL2
  supports and also a few symbols from package ~c[\"ACL2\"] that are
  commonly used when interacting with ACL2.  You may prefer to select
  this as your current package so as to avoid colliding with ACL2
  system names.~/

  This package imports the symbols listed in
  ~c[*common-lisp-symbols-from-main-lisp-package*], which contains
  hundreds of CLTL function and macro names including those supported
  by ACL2 such as ~ilc[cons], ~ilc[car], and ~ilc[cdr].  It also imports the symbols in
  ~c[*acl2-exports*], which contains a few symbols that are frequently
  used while interacting with the ACL2 system, such as ~ilc[implies],
  ~ilc[defthm], and ~ilc[rewrite].  It imports nothing else.

  Thus, names such as ~ilc[alistp], ~ilc[member-equal], and ~ilc[type-set], which are
  defined in the ~c[\"ACL2\"] package are not present here.  If you find
  yourself frequently colliding with names that are defined in
  ~c[\"ACL2\"] you might consider selecting ~c[\"ACL2-USER\"] as your current
  package (~pl[in-package]).  If you select ~c[\"ACL2-USER\"] as the
  current package, you may then simply type ~ilc[member-equal] to refer to
  ~c[acl2-user::member-equal], which you may define as you see fit.  Of
  course, should you desire to refer to the ~c[\"ACL2\"] version of
  ~ilc[member-equal], you will have to use the ~c[\"ACL2::\"] prefix, e.g.,
  ~c[acl2::member-equal].

  If, while using ~c[\"ACL2-USER\"] as the current package, you find that
  there are symbols from ~c[\"ACL2\"] that you wish we had imported into
  it (because they are frequently used in interaction), please bring
  those symbols to our attention.  For example, should ~ilc[union-theories]
  and ~ilc[universal-theory] be imported?  Except for stabilizing on the
  ``frequently used'' names from ~c[\"ACL2\"], we intend never to define a
  symbol whose ~ilc[symbol-package-name] is ~c[\"ACL2-USER\"].")

