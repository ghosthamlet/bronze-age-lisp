;;;
;;; predicates.k
;;;
;;; Type, character and relational predicates.
;;;

($provide! ()

  ($define! make-predicate
    ($lambda (stem rest)
      (make-unbounded-applicative
        (list 0 1)
        (list
          (string-append* stem ".A0")
          (string-append* stem ".A1"))
        (apply make-operative
          (list* (string-append* stem ".operate") rest)))))

  ($define! $bind-immediate-predicate!
    ($vau (symbol type-tag mask) denv
      (bind-ground! symbol
        (make-predicate "op_immediate_type_predicate"
          (list (eval mask denv) (eval type-tag denv))))))

  ($bind-immediate-predicate! integer? #x00000001 #x00000003)
  ($bind-immediate-predicate! pair?    #x00000003 #x00000003)
  ($bind-immediate-predicate! null?       nil-tag #x000000FF)
  ($bind-immediate-predicate! eof-object? eof-tag #x000000FF)
  (for-each
    (wrap ($vau (s) denv
            (eval (list $bind-immediate-predicate!
                        (symbol-append* s "?")
                        (symbol-append* s "-tag")
                        #xFF)
                  denv)))
    ($quote*
      inert ignore
      symbol keyword string bytevector
      char boolean))

  ($define! $bind-header-predicate!
    ($vau (symbol type-tag mask) denv
      (bind-ground! symbol
        (make-predicate "op_header_type_predicate"
          (list (eval mask denv) (eval type-tag denv))))))

  ($bind-header-predicate! vector? vector-header-tag #xFF)
  ($bind-header-predicate! error-object? error-header-tag #xFF)
  ($bind-header-predicate! applicative? applicative-header-tag #xFF)
  ($bind-header-predicate! continuation? cont-header-tag #xFF)
  ($bind-header-predicate! environment? environment-header-tag #xFF)
  ($bind-header-predicate! port? txt-in-header-tag #b11110011)

  ($define! $bind-native-predicate!
    ($vau (symbol procedure . more) denv
      (bind-ground! symbol
        (make-unbounded-applicative
          (list 0 1)
          (list "op_native_type_predicate.A0"
                "op_native_type_predicate.A1")
          (apply make-operative
            (list*
              "op_native_type_predicate.operate"
              symbol
              (make-nonlisp-value procedure)
              (map ($lambda (x) (eval x denv)) more)))))))

  ($bind-native-predicate! operative? "pred_operative")
  ($bind-native-predicate! char-whitespace? "pred_char" (make-nonlisp-value "white_space_code"))
  ($bind-native-predicate! char-alphabetic? "pred_char" (make-nonlisp-value "alphabetic_code")))

($provide! ()

  ($define! $bind-relational-predicate!
    ($vau (symbol procedure) denv
      (bind-ground! symbol
        (make-unbounded-applicative
          (list 0 3)
          (list "op_relational_predicate.A0"
                "op_relational_predicate.A1"
                "op_relational_predicate.A2"
                "op_relational_predicate.A3")
          (make-operative
            "op_relational_predicate.operate"
            symbol
            (make-nonlisp-value procedure))))))

  ($bind-relational-predicate! eq? "rn_eq")
  ($bind-relational-predicate! equal? "rn_equal")
  ($bind-relational-predicate! char<=? "rel_char_leq")
  ($bind-relational-predicate! <? "rel_fixint_le")
  )

#|

($let
  ((make-predicate
    ($lambda (label . rest)
      (make-unbounded-applicative
        0
        1
        (list "app_0_predicate" "app_1_predicate")
        (apply make-operative
          (list* "op_predicate" label rest)))))
   (make-relation
    ($lambda (label . rest)
      (make-unbounded-applicative
        0
        3
        (list "app_0_relation" "app_1_relation" "app_2_relation" "app_3_relation")
        (apply make-operative
          (list* "op_relation" label rest))))))
  ($bind-ground! integer? (make-predicate "pred_fixint"))
  ($bind-ground! pair? (make-predicate "pred_pair"))
  ($bind-ground! operative? (make-predicate "pred_operative"))
  ($bind-ground! combiner? (make-predicate "pred_combiner"))
  (for-each
    (wrap
      ($vau ((s tag)) e
        (bind-ground! s
          (make-predicate "pred_tag" (eval tag e)))))
    ($quote*
      (null? nil-tag)
      (inert? inert-tag)
      (ignore? ignore-tag)
      (eof-object? eof-tag)
      (char? char-tag)
      (boolean? boolean-tag)
      (symbol? symbol-tag)
      (keyword? keyword-tag)
      (string? string-tag)
      (bytevector? bytevector-tag)))
  (for-each
    (wrap
      ($vau ((s tag mask)) e
        (bind-ground! s
          (make-predicate "pred_tag"
            (+ (eval tag e) (* 256 (eval mask e)))))))
    ($quote*
      (applicative? applicative-header-tag #b11111011)
      (port? txt-in-header-tag #b11110011)
      (vector? vector-header-tag #xFF)
      (error-object? error-header-tag #xFF)
      (continuation? cont-header-tag #xFF)
      (environment? environment-header-tag #xFF)))
  ($when ($configured character-predicates)
    ($bind-ground! char-whitespace? (make-predicate "pred_char" "white_space_code"))
    ($bind-ground! char-alphabetic? (make-predicate "pred_char" "alphabetic_code")))
  ($bind-ground! eq? (make-relation "rel_eq"))
  ($bind-ground! equal? (make-relation "rel_equal"))
  ($bind-ground! char<=? (make-relation "rel_char_leq"))
  ($bind-ground! <? (make-relation "rel_fixint_le")))
|#