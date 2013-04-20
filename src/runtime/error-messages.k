;;;
;;; error-messages.k
;;;
;;; Error messages of the interpreter.
;;;
;;; Each message has a key (e.g. unbound-symbol) and a text
;;; (e.g. "Unbound symbol."). The text is included in the
;;; interpreter binary as a string. The 32-bit word representing
;;; the string is available to the assembly language
;;; implementation as a constant (e.g. err_unbound_symbol).
;;; See also data-segments.k.
;;;

($define! error-messages
  ($quote*
    (not-a-combiner "Not a combiner in combiner position.")
    (unbound-symbol "Unbound symbol.")
    (not-implemented "Feature not implemented.")
    (manyargs-not-implemented "Long argument lists not yet implemented.")
    (invalid-argument "Invalid argument.")
    (invalid-arity "Invalid number of arguments.")
    (invalid-argument-structure "Invalid argument structure.")
    (not-bool "Expected boolean argument in $if/$when/$unless/$and?/$or?/not?.")
    (not-a-number "Expected numeric argument(s).")
    (not-an-environment "Expected environment argument(s).")
    (out-of-lisp-memory "Out of memory (lisp).")
    (out-of-blob-memory "Out of memory (blobs).")
    (cannot-traverse "Cannot traverse list structure.")
    (immutable-environment "Attempted to mutate immutable environment.")
    (immutable-pair "Attempted to mutate immutable pair.")
    (match-failure "Match failure")
    (io "I/O error")
    (invalid-codepoint "Not a valid unicode code point")
    (invalid-utf8 "Invalid UTF-8 sequence.")
    (undefined-private-binding "Attempted to mutate unknown binding in interpreter private environment.")
    (port-incompatibility "Invalid result from the underlying port.")
    (invalid-blob-heap-operation "Invalid blob heap operation.")
    (error-in-error "Invalid use of (error ...) applicative.")
    (improper-argument-list "Improper argument list.")
    (invalid-buffer-size "Invalid buffer size.")
    (invalid-base "Invalid base for numeric conversion.")
    (not-a-digit "Not a digit.")
    (division-by-zero "Division by zero.")
    (not-an-applicative "Not an applicative combiner.")
    (repeated-symbol "Repeated symbol in formal parameter tree.")
    (invalid-ptree "Invalid formal parameter tree.")
    (cyclic-ptree "Cyclic formal parameter tree.")
    (incompatible-encapsulation "Incompatible encapsulation type.")
    (internal-error "Internal error.")
    (unbound-dynamic-variable "Unbound keyed dynamic variable.")
    (undefined-arithmetic-operation "Undefined arithmetic operation.")
    (index-out-of-bounds "Index out of bounds.")
    (numeric-overflow "Numeric overflow (the result is finite but cannot be represented).")
  ))
