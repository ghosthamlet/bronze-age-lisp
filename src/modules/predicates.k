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

  ($bind-immediate-predicate! fixint?  #x00000001 #x00000003)
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
  ($bind-header-predicate! bigint? bigint-header-tag #xFF)
  ($bind-header-predicate! continuation? cont-header-tag #xFF)
  ($bind-header-predicate! environment? environment-header-tag #xFF)
  ($bind-header-predicate! port? txt-in-header-tag #b11110011)
  ($bind-header-predicate! promise? promise-header-tag #xFF)
  ($bind-header-predicate! library? library-header-tag #xFF)
  ($bind-header-predicate! hash-table? hash-table-header-tag #xFF)

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
  ($bind-native-predicate! combiner? "pred_combiner")
  ($bind-native-predicate! mutable-pair? "pred_mutable_pair")
  ($bind-native-predicate! immutable-pair? "pred_immutable_pair")
  ($bind-native-predicate! integer? "pred_integer")
  ($bind-native-predicate! number? "pred_number")
  ($bind-native-predicate! finite? "pred_finite_number")
  ($bind-native-predicate! zero? "pred_zero")
  ($bind-native-predicate! positive? "pred_positive")
  ($bind-native-predicate! negative? "pred_negative")
  ($bind-native-predicate! odd? "pred_odd")
  ($bind-native-predicate! even? "pred_even")
  ($bind-native-predicate! finite-list? "pred_finite_list")
  ($bind-native-predicate! countable-list? "pred_countable_list")
  ($bind-native-predicate! char-whitespace? "pred_char" (make-nonlisp-value "white_space_code"))
  ($bind-native-predicate! char-alphabetic? "pred_char" (make-nonlisp-value "alphabetic_code"))
  ($bind-native-predicate! library-name-component? "pred_library_name_component")
  ($bind-native-predicate! u8? "pred_u8")
  ($bind-native-predicate! formal-parameter-tree? "pred_ptree")
  ($bind-native-predicate! file-exists? "pred_file_exists")

  ($when ($configured stdio)
    ($bind-header-predicate! textual-port? txt-in-header-tag #b11111011)
    ($bind-header-predicate! binary-port? bin-in-header-tag  #b11111011)
    ($bind-header-predicate! input-port? txt-out-header-tag #b11110111)
    ($bind-header-predicate! output-port? txt-out-header-tag  #b11110111)
    ($bind-native-predicate! port-open? "pred_port_open")
    ($bind-native-predicate! file-port? "pred_file_port")
    ($bind-native-predicate! terminal-port? "pred_terminal_port")))

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

  ($define! $bind-order-predicate!
    ($vau (symbol procedure on-le on-eq on-gt) denv
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
            (make-nonlisp-value procedure)
            (+ ($if on-le 1 0) ($if on-eq 2 0) ($if on-gt 4 0)))))))

  ($bind-order-predicate!  <? "rel_integer" #t #f #f)
  ($bind-order-predicate! <=? "rel_integer" #t #t #f)
  ($bind-order-predicate!  =? "rel_integer" #f #t #f)
  ($bind-order-predicate! >=? "rel_integer" #f #t #t)
  ($bind-order-predicate!  >? "rel_integer" #f #f #t)

  ($bind-order-predicate!  char<? "rel_char" #t #f #f)
  ($bind-order-predicate! char<=? "rel_char" #t #t #f)
  ($bind-order-predicate!  char=? "rel_char" #f #t #f)
  ($bind-order-predicate! char>=? "rel_char" #f #t #t)
  ($bind-order-predicate!  char>? "rel_char" #f #f #t)

  ($bind-order-predicate!  string<? "rel_string" #t #f #f)
  ($bind-order-predicate! string<=? "rel_string" #t #t #f)
  ($bind-order-predicate!  string=? "rel_string" #f #t #f)
  ($bind-order-predicate! string>=? "rel_string" #f #t #t)
  ($bind-order-predicate!  string>? "rel_string" #f #f #t)

  ($bind-order-predicate!  bytevector<? "rel_bytevector" #t #f #f)
  ($bind-order-predicate! bytevector<=? "rel_bytevector" #t #t #f)
  ($bind-order-predicate!  bytevector=? "rel_bytevector" #f #t #f)
  ($bind-order-predicate! bytevector>=? "rel_bytevector" #f #t #t)
  ($bind-order-predicate!  bytevector>? "rel_bytevector" #f #f #t))
