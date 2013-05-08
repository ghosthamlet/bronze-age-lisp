;;;
;;; platform.k
;;;
;;; Linux-dependent features.
;;;

($when ($configured stdio)
  (for-each
    ($lambda (symbol)
      (bind-ground! symbol
        (make-nonlisp-value (string-append* "platform_port_" symbol))))
    ($quote* stdin stdout stderr))
  ($define! emit-platform-ports
    ($lambda ()
      ($define! $define-port
        ($vau (symbol filedes input) #ignore
          (asm (string-append* "platform_port_" symbol ":"))
          (asm "dd" (immediate-value-repr
                      (($if input bin-in-header* bin-out-header*) 6)))
          (asm "dd" (pack-fixint filedes))
          ($define! method
            ($lambda (name)
              (asm "dd" (string-append* "primitive_value(linux_" name ")"))))
          (method "close")
          (method ($if input "read" "write"))
          (method "nop")
          (asm "dd" "inert_tag")))
      ($define-port stdin 0 #t)
      ($define-port stdout 1 #f)
      ($define-port stderr 2 #f))))
