;;;
;;; rom-blobs.k
;;;
;;; Blobs (strings, symbols, keywords) in read-only segments
;;; of the interpreter.
;;;

;;
;; (rom-blobs OBJECTS) => (INDEX-FUNC EMIT-CONTENTS EMIT-NAMES EMIT-DESCRIPTORS)
;;
;; where (INDEX-FUNC string) => index
;;       (EMIT-CONTENTS) prints blob data in assembler syntax
;;       (EMIT-NAMES) prints selected names in assembler syntax
;;       (EMIT-DESCRIPTORS) prints definition of blob descriptor table
;;
($provide! (rom-blobs)

  ($define! harvest-blobs
    ($lambda (objects)
      ($define! d (make-dictionary))
      ($define-add! ordinal 0 +)
      ($define-add! lst () cons)
      ($define! add-string
        ($lambda (x)
          ($unless (dictionary-exists? d x)
            (ordinal-add! 1)
            (dictionary-add! d x ordinal)
            (lst-add! (cons x ordinal)))))
      (for-each
        ($lambda (x)
          ($cond
            ((symbol? x) (add-string (symbol->string x)))
            ((string? x) (add-string x))
            ((keyword? x) (add-string (keyword->string x)))
            (#t #inert)))
        objects)
      (list
        d
        (reverse lst)
        ordinal)))

  ($define! emit-blob-contents
    ($lambda (string-alist)
      (asm ";; rom strings in UTF-8")
      (for-each
        ($lambda ((str . index))
          (display (string-append* " rom_string_" index ":"))
          (asm-utf8 str)
          (newline))
        string-alist)
      (asm "rom_string_end:")))

  ;; output assembler names of rom strings and error messages
  ($define! emit-blob-names
    ($lambda (string-index string-subset)
      (asm "\n;; assembler names of strings")
      (asm "rom_empty_string" "equ" (string-index ""))
      (for-each
        ($lambda (str)
          (asm
            (string-append* "rom_string_" (asm-identifier str))
            "equ"
            (string-index str)))
        string-subset)
      (for-each
        ($lambda ((symbol message))
          (asm
            (string-append* "err_" (asm-identifier symbol))
            "equ"
            (pack string-tag (string-index message))))
        error-messages)))

  ;; output initial contents of string heap
  ($define! emit-blob-descriptors
    ($lambda (blob-alist)
      (asm)
      (asm ";; blob heap descriptors")
      (asm "section .bdesc1 progbits alloc noexec write align=8")
      (asm "blob_descriptors:")
      ($define! n (length blob-alist))
      ($define! r (- ($configured blob-descriptor-capacity) n))
      (for-each
        ($lambda ((sym . index))
          (asm "  dd" (string-append* "rom_string_" index) "," (+ 1 index)))
        blob-alist)
      (asm "  dd rom_string_end, " n)
      (asm " .ram:")
      (asm "section .bdesc2 nobits alloc noexec write align=8")
      (asm "  resb" (* 8 r))
      (asm " blob_descriptors.limit:")))

  ($define! rom-blobs
    ($lambda (objects)
      ($let*
        (((dict alist n) (harvest-blobs objects))
         (string-index (dictionary-getter dict)))
        (list
          string-index
          ($lambda () (emit-blob-contents alist))
          ($lambda (subset) (emit-blob-names string-index subset))
          ($lambda () (emit-blob-descriptors alist)))))))

