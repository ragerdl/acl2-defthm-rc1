; VL Verilog Toolkit
; Copyright (C) 2008-2014 Centaur Technology
;
; Contact:
;   Centaur Technology Formal Verification Group
;   7600-C N. Capital of Texas Highway, Suite 300, Austin, TX 78731, USA.
;   http://www.centtech.com/
;
; License: (An MIT/X11-style license)
;
;   Permission is hereby granted, free of charge, to any person obtaining a
;   copy of this software and associated documentation files (the "Software"),
;   to deal in the Software without restriction, including without limitation
;   the rights to use, copy, modify, merge, publish, distribute, sublicense,
;   and/or sell copies of the Software, and to permit persons to whom the
;   Software is furnished to do so, subject to the following conditions:
;
;   The above copyright notice and this permission notice shall be included in
;   all copies or substantial portions of the Software.
;
;   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
;   FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
;   DEALINGS IN THE SOFTWARE.
;
; Original author: Jared Davis <jared@centtech.com>

(in-package "VL")
(include-book "datatypes")
(include-book "../descriptions")
(local (include-book "../../util/arithmetic"))
(local (include-book "tools/do-not" :dir :system))
(local (acl2::do-not generalize fertilize))

;; type_declaration ::=
;;    'typedef' data_type type_identifier { variable_dimension } ';'
;;  | 'typedef' interface_instance_identifier constant_bit_select '.' type_identifier type_identifier ';'
;;  | 'typedef' [ 'enum' | 'struct' | 'union' | 'class' | 'interface class' ] type_identifier ';'

(defparser vl-parse-fwd-typedef (atts)
  ;; Matches 'typedef' [ 'enum' | 'struct' | 'union' | 'class' | 'interface class' ] type_identifier ';'
  :guard (and (vl-atts-p atts)
              (vl-is-token? :vl-kwd-typedef))
  :result (vl-description-p val)
  :resultp-of-nil nil
  :fails gracefully
  :count strong
  (seqw tokens warnings
        (typedef := (vl-match))  ;; guard ensures it starts with 'typedef'

        (when (vl-is-token? :vl-kwd-interface)
          (:= (vl-match))
          (:= (vl-match-token :vl-kwd-class))
          (name := (vl-match-token :vl-idtoken))
          (:= (vl-match-token :vl-semi))
          (return (make-vl-fwdtypedef :kind :vl-interfaceclass
                                      :name (vl-idtoken->name name)
                                      :loc (vl-token->loc typedef)
                                      :atts atts)))

        (when (vl-is-some-token? '(:vl-kwd-enum :vl-kwd-struct :vl-kwd-union :vl-kwd-class))
          (type := (vl-match))
          (name := (vl-match-token :vl-idtoken))
          (:= (vl-match-token :vl-semi))
          (return (make-vl-fwdtypedef :kind (case (vl-token->type type)
                                              (:vl-kwd-enum   :vl-enum)
                                              (:vl-kwd-struct :vl-struct)
                                              (:vl-kwd-union  :vl-union)
                                              (:vl-kwd-class  :vl-class))
                                      :name (vl-idtoken->name name)
                                      :loc (vl-token->loc typedef)
                                      :atts atts)))

        (return-raw
         (vl-parse-error "Not a valid forward typedef."))))


(defparser vl-parse-type-declaration (atts)
  :guard (and (vl-atts-p atts)
              (vl-is-token? :vl-kwd-typedef))
  :result (vl-description-p val)
  :resultp-of-nil nil
  :fails gracefully
  :count strong
  ;; We use backtracking to figure out if it's a forward or regular type
  ;; declaration.  We try forward declarations first because they're less
  ;; likely to have problems, and we'd probably rather see errors about
  ;; full type declarations.
  (b* (((mv erp fwd fwd-tokens fwd-warnings)
        (vl-parse-fwd-typedef atts))
       ((unless erp)
        ;; Got a valid fwd typedef, so return it.
        (mv erp fwd fwd-tokens fwd-warnings)))

    ;; Else, not a fwd typedef, so try to match a full one.
    (seqw tokens warnings
          (typedef := (vl-match))  ;; guard ensures it starts with 'typedef'

          ;; BOZO the following probably isn't right for the 2nd production.
          (datatype := (vl-parse-datatype))
          (id := (vl-match-token :vl-idtoken))
          (when (vl-is-token? :vl-lbrack)
            (return-raw
             (vl-parse-error "BOZO need to add support for dimensions on typedefs.")))
          (semi := (vl-match-token :vl-semi))
          (return
           (make-vl-typedef :name (vl-idtoken->name id)
                            :type datatype
                            :dims nil ;; BOZO add dimensions
                            :minloc (vl-token->loc typedef)
                            :maxloc (vl-token->loc semi)
                            :atts atts)))))

