; VL Verilog Toolkit
; Copyright (C) 2008-2014 Centaur Technology
;
; Contact:
;   Centaur Technology Formal Verification Group
;   7600-C N. Capital of Texas Highway, Suite 300, Austin, TX 78731, USA.
;   http://www.centtech.com/
;
; This program is free software; you can redistribute it and/or modify it under
; the terms of the GNU General Public License as published by the Free Software
; Foundation; either version 2 of the License, or (at your option) any later
; version.  This program is distributed in the hope that it will be useful but
; WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
; FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
; more details.  You should have received a copy of the GNU General Public
; License along with this program; if not, write to the Free Software
; Foundation, Inc., 51 Franklin Street, Suite 500, Boston, MA 02110-1335, USA.
;
; Original author: Jared Davis <jared@centtech.com>

(in-package "VL")
(include-book "../descriptions")
(include-book "error")
(include-book "modules")
(include-book "udps")
(include-book "interfaces")
(include-book "packages")
(include-book "programs")
(include-book "configs")
(include-book "imports")
(include-book "typedefs")
(local (include-book "../../util/arithmetic"))

(defxdoc parser
  :parents (loader)
  :short "A parser for a subset of Verilog and SystemVerilog."

  :long "<h3>Introduction</h3>

<p>Our parser is responsible for processing a list of @(see tokens) into our
internal representation of Verilog @(see syntax).  Typically these tokens are
produced by the @(see lexer).  Note that before parsing begins, any whitespace
or comment tokens should be removed from the token list; see for instance @(see
vl-kill-whitespace-and-comments).</p>

<p>We use essentially a manual recursive-descent style parser.  Having the
entire token stream available gives us arbitrary lookahead, and we occasionally
make use of backtracking.</p>

<h3>Scope</h3>

<p>Verilog and SystemVerilog are huge languages, and we can parse only a subset
of these languages.</p>

<p>We can currently support most of the constructs in the Verilog 1364-2005
standard.  Notably, we do not yet support user-defined primitives, generate
statements, specify blocks, specparams, and genvars.  In some cases, the parser
will just skip over unrecognized constructs (adding @(see warnings) when it
does so.)  Depending on what you are doing, this behavior may be actually
appropriate, e.g., skipping specify blocks may be okay if you aren't trying to
deal with low-level timing issues.</p>

<p>We are beginning to work toward supporting SystemVerilog based on the
1800-2012 standard.  But this is preliminary work and you should not yet expect
VL to correctly handle any interesting fragment of SystemVerilog.</p>")


; -----------------------------------------------------------------------------
;
;                              Source Text
;
; -----------------------------------------------------------------------------

; Verilog-2005:
;
; description ::=
;    module_declaration
;  | udp_declaration
;  | config_declaration
;
; SystemVerilog-2012 adds:
;
;  | interface_declaration
;  | program_declaration
;  | package_declaration
;  | {attribute_instance} package_item         <-- not supported yet
;  | {attribute_instance} bind_directive       <-- not supported yet



(defparser vl-parse-description ()
  ;; Note: we return a list of descriptions because sometimes a 'single'
  ;; construct actually introduces several things.  For instance, an import
  ;; statement like "import foo::bar, foo::baz;" turns into two parsed imports.
  :result (vl-descriptionlist-p val)
  :resultp-of-nil t
  :true-listp t
  :fails gracefully
  :count strong
  (seqw tokens warnings
        (atts := (vl-parse-0+-attribute-instances))
        (when (atom tokens)
          (return-raw (vl-parse-error "Unexpected EOF.")))
        (when (vl-is-token? :vl-kwd-config)
          (cfg := (vl-parse-config-declaration atts))
          (return (list cfg)))
        (when (vl-is-token? :vl-kwd-primitive)
          (udp := (vl-parse-udp-declaration atts))
          (return (list udp)))
        (when (vl-is-some-token? '(:vl-kwd-module :vl-kwd-macromodule))
          (mod := (vl-parse-module-declaration atts))
          (return (list mod)))
        (when (eq (vl-loadconfig->edition config) :verilog-2005)
          ;; Other things aren't supported
          (return-raw
           (vl-parse-error "Expected a module, primitive, or config.")))
        (when (vl-is-token? :vl-kwd-interface)
          (interface := (vl-parse-interface-declaration atts))
          (return (list interface)))
        (when (vl-is-token? :vl-kwd-program)
          (program := (vl-parse-program-declaration atts))
          (return (list program)))
        (when (vl-is-token? :vl-kwd-package)
          (package := (vl-parse-package-declaration atts))
          (return (list package)))

        (when (vl-is-token? :vl-kwd-bind)
          (return-raw
           (vl-parse-error "Bind directives are not implemented.")))

        (when (vl-is-token? :vl-kwd-task)
          (task := (vl-parse-task-declaration atts))
          (return (list task)))
        (when (vl-is-token? :vl-kwd-function)
          (fn := (vl-parse-function-declaration atts))
          (return (list fn)))
        (when (vl-is-token? :vl-kwd-import)
          (imports := (vl-parse-package-import-declaration atts))
          (return imports))
        (when (vl-is-some-token? '(:vl-kwd-parameter :vl-kwd-localparam))
          (params := (vl-parse-param-or-localparam-declaration atts '(:vl-kwd-parameter :vl-kwd-localparam)))
          (:= (vl-match-token :vl-semi))
          (return params))

        ;; (when (member-eq (vl-token->type (car tokens)) *vl-netdecltypes-kwds*)
        ;;   (return-raw
        ;;    ;; bleh, have to do something here to deal with assignments in the nets?
        ;;    (vl-parse-error "Top-level net declarations are not implemented.")))

        (when (vl-is-token? :vl-kwd-typedef)
          (typedef := (vl-parse-type-declaration atts))
          (return (list typedef)))

        ;; BOZO lots of other things

        (return-raw
         (vl-parse-error "Unsupported top-level construct?"))))


; Verilog-2005:
; source_text ::= { description };
;
; SystemVerilog-2012 adds:
; source_text ::= [timeunits_declaration] { description }
;
; But we don't support this timeunit declaration yet.

(defparser vl-parse-source-text ()
  :result (vl-descriptionlist-p val)
  :resultp-of-nil t
  :true-listp t
  :fails gracefully
  :count strong-on-value
  (seqw tokens warnings
        (when (atom tokens)
          (return nil))
        (first := (vl-parse-description))
        (rest := (vl-parse-source-text))
        (return (append first rest))))


(define vl-parse
  :parents (parser)
  :short "Top level parsing function."
  ((tokens   vl-tokenlist-p)
   (warnings vl-warninglist-p)
   (config   vl-loadconfig-p))
  :returns
  (mv (successp)
      (items    vl-descriptionlist-p :hyp :fguard)
      (warnings vl-warninglist-p))
  (b* (((mv err val tokens warnings)
        (vl-parse-source-text))
       ((when err)
        (vl-report-parse-error err tokens)
        (mv nil nil warnings)))
    (mv t val warnings)))
