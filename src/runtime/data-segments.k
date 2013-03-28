;;;
;;; data-segments.k
;;;
;;; Print assembly language definition of data segments
;;; of the interpreter.
;;;
;;; The read-only segment .rodata contains:
;;;   - pairs (built-in lisp code)
;;;       - built-in combiners
;;;       - initialization code
;;;       - user-defined start form
;;;   - ground and private environment objects
;;;   - root continuation object
;;;   - built-in closures
;;;   - contents of built-in blobs
;;;       - symbols
;;;       - keywords
;;;       - strings (including all error messages)
;;;   - tables for the UTF-8 decoder automaton
;;;   - extra binary data
;;;
;;; The read-write initialized segment .data contains:
;;;   - blob heap descriptor table
;;;
;;; The uninitialized segment .bss contains:
;;;   - lisp heap
;;;   - string heap
;;;   - lisp stack
;;;   - scratch buffer
;;;   - global variables for the interpreter
;;;       - current continuation
;;;   - global variables of system dependent code
;;;       - pointer to command line arguments, ...
;;;

($provide! (bind-ground! $bind-ground! $bind-ground-quoted!
            bind-private! $bind-private!
            rodata-extra-add! init-forms-add!
            emit-data-segments)

  ;; list of applicatives, which print assembly language
  ;; definition of additional raw data in the read-only
  ;; segment
  ($define-add! rodata-extra () cons)

  ;; list (SYMBOL . VALUE) pairs of the ground environment
  ($define-add! ground-bindings () cons)

  ;; list (SYMBOL . VALUE) pairs of the private environment
  ($define-add! private-bindings () cons)

  ;; list of initialization forms (reversed)
  ($define-add! init-forms ($quote* $sequence) cons)

  ($define! bind-builtin!
    ($lambda (add! sym val)
      ($unless (symbol? sym)
        (error "expected symbol" bind-ground! sym val))
      ($when ($or? (pair? (assoc sym private-bindings))
                   (pair? (assoc sym ground-bindings)))
        (error "duplicate builtin binding" bind-builtin! sym val))
      (add! (cons sym val))))

  ($define! bind-ground!
    ($lambda (s v) (bind-builtin! ground-bindings-add! s v)))
  ($define! bind-private!
    ($lambda (s v) (bind-builtin! private-bindings-add! s v)))
  ($define! $bind-ground!
    ($vau (s v) denv (bind-ground! s (eval v denv))))
  ($define! $bind-private!
    ($vau (s v) denv (bind-private! s (eval v denv))))
  ($define! $bind-ground-quoted!
    (unwrap bind-ground!))

  ($define! collect-objects
    ($lambda roots
      ($define! tmp (make-dictionary))
      ($define-add! objects () cons)
      ($define! visit
        ($lambda (x)
          ($cond
            ((dictionary-exists? tmp x)
              #inert)
            (($or? (symbol? x) (string? x) (keyword? x))
              (dictionary-add! tmp x #t)
              (objects-add! x))
            ((rom-object? x)
              (dictionary-add! tmp x #t)
              (objects-add! x)
              (for-each visit (rom-object-fields x)))
            ((pair? x)
              (dictionary-add! tmp x #t)
              (objects-add! x)
              (visit (car x))
              (visit (cdr x))))))
      (for-each visit roots)
      objects))

  ($define! harvest-objects
    ($lambda (selector objects)
      ($define! dict (make-dictionary))
      ($define-add! ordinal 0 +)
      ($define-add! lst () cons)
      ($define! add-pair
        ($lambda (x)
          (lst-add! (cons x ordinal))
          (dictionary-add! dict x ordinal)
          (ordinal-add! 1)))
      (for-each add-pair (filter selector objects))
      (list (dictionary-getter dict) (reverse lst))))

  ($define! list-of-all-objects
    ($lambda args
      (append
        (list ($configured start-form))
        args
        (map car ground-bindings)
        (map cdr ground-bindings)
        (map car private-bindings)
        (map cdr private-bindings)
        (map cadr error-messages))))

  ($define! emit-data-segments
    ($lambda ()
      ($define! init-form (reverse init-forms))
      ($define! objects (apply collect-objects (list-of-all-objects init-form)))
      ($define! all-bindings (append ground-bindings private-bindings))
      ($define! (s-ind s-contents s-names s-descriptors) (rom-blobs (append (map car all-bindings) (list "") objects)))
      ($define! (p-ind p-lst) (harvest-objects pair? objects))
      ($define! (r-ind r-lst) (harvest-objects rom-object? objects))
      ($define! asm-repr
        ($lambda (x)
          ($cond
            ((null? x) nil-tag)
            ((inert? x) inert-tag)
            ((ignore? x) ignore-tag)
            ((char? x) (pack char-tag (char->integer x)))
            ((boolean? x #t) (pack boolean-tag ($if x 1 0)))
            ((integer? x)
              ($if (<=? min-fixint x max-fixint)
                (pack-fixint x)
                (string-append* "TODO_BIGINT_" x)))
            ((symbol? x)
              (pack symbol-tag (s-ind (symbol->string x))))
            ((keyword? x)
              (pack keyword-tag (s-ind (keyword->string x))))
            ((string? x)
              (pack string-tag (s-ind x)))
            ((pair? x)
              (string-append* "rom_pair_value(rom_pair_" (p-ind x) ")"))
            ((rom-object? x)
              (string-append* "rom_object_" (r-ind x)))
            ((immediate-value? x)
              (immediate-value-repr x))
            (#t
              "TODO_ASM_REPR"))))
      (asm)
      (asm "section .lisp_rom")
      (asm "align 8")
      (asm-label "lisp_rom_base")
      ($define-add! rodata-size 0 +)
      ;; output pairs
      (asm "\n;; lisp object in read-only memory")
      (for-each
        ($lambda ((x . index))
          (asm (string-append* "rom_pair_" index ":")
            "dd"
            (asm-repr (car x)) ","
            (asm-repr (cdr x))))
        p-lst)
      (rodata-size-add! (* 8 (length p-lst)))
      ;; output other objects
      (for-each
        ($lambda ((x . index))
          (asm (string-append* "rom_object_" index ":"))
          ($let ((fs (rom-object-fields x)))
            (for-each
              ($lambda (f) (asm "dd" f))
              (map asm-repr (rom-object-fields x)))
            (rodata-size-add! (* 4 (length fs)))))
        r-lst)
      ;; output ground, private and empty environment objects
      (asm "ground_env_object:")
      (asm " dd" (asm-repr (environment-header* 3)) ","
           "ground_env_lookup" "," inert-tag)
      (asm "private_env_object:")
      (asm " dd" (asm-repr (environment-header* 3)) ","
           "private_env_lookup" "," "ground_env_object")
      (asm "empty_env_object:")
      (asm " dd" (asm-repr (environment-header* 3)) ","
           "empty_env_lookup" "," inert-tag)
      (rodata-size-add! (* 3 3 4))
      (asm-label "lisp_rom_limit")
      ;; output assembler reference to root and error continuations
      (asm "root_continuation equ " (asm-repr (cdr (assoc ($quote root-continuation) ground-bindings))))
      (asm "error_continuation equ " (asm-repr (cdr (assoc ($quote error-continuation) ground-bindings))))
      ;; output rom strings
      (s-contents)
      (s-names
        (map symbol->string
          (cons ($quote intern) (map car ground-bindings))))
      ;; define initialization and start object
      (asm)
      (display ";; init form = ")
      (write init-form)
      (newline)
      (asm "init_form" "equ" (asm-repr init-form))
      (asm)
      (display ";; start form = ")
      (write ($configured start-form))
      (newline)
      (asm "start_form" "equ" (asm-repr ($configured start-form)))
      ;; output extra raw data
      (asm "section .rodata")
      (asm "\n;; raw objects in read-only memory")
      (for-each
        ($lambda (f) (f))
        rodata-extra)
      ;; include UTF-8 decoder tables
      (asm)
      (asm ";; UTF-8 decored tables")
      (asm-include "runtime/utf8-dfa.asm")
      ($when ($configured character-predicates)
        (asm-include "unicode/generated-data.asm"))
      ;; output table of ground and private bindings (mutated by initialization forms)
      (asm)
      (asm "section .data")
      (asm "ground_lookup_table_length" "equ"
        (length ground-bindings))
      (asm "private_lookup_table_length" "equ"
        (+ (length ground-bindings) (length private-bindings)))
      (asm "align 4")
      (asm "ground_private_lookup_table:")
      ($let*
        ((n (length all-bindings))
         (v (make-vector (+ 1 n) #inert)))
        (for-each
          ($lambda (p)
            (vector-set! v (s-ind (symbol->string (car p))) p))
          all-bindings)
        ($for (i 1 n)
          ($let (((s . t) (vector-ref v i)))
            (asm " dd" (asm-repr t) "; " i s "=>" t))))
      ;; output initial contents of string heap
      (asm)
      (s-descriptors)
      rodata-size)))

($let*
  ((rc (make-builtin-continuation "cont_root" #inert))
   (ec (make-builtin-continuation "cont_error" rc)))
  ($bind-ground! root-continuation rc)
  ($bind-ground! error-continuation ec))

