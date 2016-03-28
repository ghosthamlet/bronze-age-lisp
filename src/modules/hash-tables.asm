;;;
;;; hash-tables.asm
;;;
;;; Hash tables and hash functions (asm part).
;;;

;;
;; app_make_hash_table.{eq,equal} (continuation passing procedures)
;;
;; Implementation of private hash table constructors
;;
;;  (make-eq-hash-table VECTOR HASH-FUNCTION RECONSTRUCTOR)
;;  (make-equal-hash-table VECTOR HASH-FUNCTION RECONSTRUCTOR)
;;  (make-equal-hash-table VECTOR (HASH-FUNCTION . EQ-OP) RECONSTRUCTOR)
;;
;; preconditions:  EBX = vector (even length)
;;                 ECX = hash function or a pair (hash function . eq-op)
;;                 EDX = reconstructor function
;;
app_make_hash_table:
  .user:
    push dword cdr(ecx)
    mov ecx, car(ecx)
    push dword hash_table_user_bucket_lookup
    jmp .com
  .eq:
    push dword rn_eq
    push dword hash_table_native_bucket_lookup
    jmp .com
  .equal:
    push dword rn_equal
    push dword hash_table_native_bucket_lookup
  .com:
    mov esi, ecx
    mov ecx, 8
    call rn_allocate
    mov ecx, [ebx]
    shr ecx, 8
    lea ecx, [4*(ecx - 2) + 1]
    mov [eax + hash_table.header], dword hash_table_header
    mov [eax + hash_table.bucket_count], ecx
    mov [eax + hash_table.vector], ebx
    pop dword [eax + hash_table.list_lookup]
    mov dword [eax + hash_table.length], fixint_value(0)
    mov [eax + hash_table.hashf], esi
    mov [eax + hash_table.reconstructor], edx
    pop dword [eax + hash_table.eq_proc]
    jmp [ebp + cont.program]

;;
;; app_replace_hash_tableB (continuation passing procedures)
;;
;; Implementation of private combiner
;;
;;  (replace-hash-table! H1 H2) => #inert
;;
;; The combiner replaces contents of H1 by the contents of H1.
;;
;; preconditions:  EBX = destination hash table
;;                 ECX = source hash function
;;
;;
app_replace_hash_tableB:
  .A2:
    instrumentation_point
    lea edi, [ebx + 4]
    lea esi, [ecx + 4]
    mov ecx, 7
    rep movsd
    xor esi, esi
    xor edi, edi
    mov eax, inert_tag
    jmp [ebp + cont.program]

;;
;; hash_table_native_bucket_lookup (continuation passing procedure)
;;
;; Search in hash table bucket using native equality predicate.
;;
;; preconditions: ECX = key
;;                EDX = bucket index (tagged fixint)
;;                ESI = bucket list (not null)
;;                EDI = hash table object
;;                EBP = current continuation
;;
hash_table_native_bucket_lookup:
  .next:
    mov ebx, car(esi)
    mov ebx, car(ebx)
    call [edi + hash_table.eq_proc]
    test eax, eax
    jnz .found
    mov esi, cdr(esi)
    cmp esi, nil_tag
    jne .next
  .found:
    push edx
    push esi
    call rn_cons
    jmp [ebp + cont.program]

;;
;; hash_table_user_bucket_lookup (continuation passing procedure)
;;
;; Search in hash table bucket using user-defined equality predicate.
;;
;; preconditions: ECX = key
;;                EDX = bucket index (tagged fixint)
;;                ESI = bucket list (not null)
;;                EDI = hash table object
;;                EBP = current continuation
;;
hash_table_user_bucket_lookup:
    mov ebx, ecx
    mov ecx, -8
    call rn_allocate_transient
    mov ecx, ebx
    mov [eax + cont.header], dword cont_header(8)
    mov [eax + cont.program], dword .continue
    mov [eax + cont.parent], ebp
    mov [eax + cont.var0], ecx              ; key
    mov [eax + cont.var1], edx              ; bucket index
    mov [eax + cont.var2], esi              ; bucket contents
    mov [eax + cont.var3], edi              ; hash table object
    mov [eax + cont.var4], dword inert_tag  ; padding
    mov ebp, eax
  .call_user:
    mov ebx, car(esi)
    push dword car(ebx)
    push dword nil_tag
    call rn_cons
    push ecx
    push eax
    call rn_cons
    mov ebx, eax
    mov eax, [edi + hash_table.eq_proc]
    mov edi, empty_env_object
    jmp rn_combine
  .continue:
    mov esi, [ebp + cont.var2]
    cmp eax, boolean_value(1)
    je .done
    cmp eax, boolean_value(0)
    jne .error
    mov esi, cdr(esi)
    cmp esi, nil_tag
    je .done
  .try_next:
    call rn_force_transient_continuation
    mov [ebp + cont.var2], esi
    mov edi, [ebp + cont.var3]
    mov ecx, [ebp + cont.var0]
    jmp .call_user
  .done:
    push dword [ebp + cont.var1]
    push esi
    mov ebp, [ebp + cont.parent]
    call rn_cons
    jmp [ebp + cont.program]
  .error:
    mov ebx, eax
    mov eax, err_not_bool
    mov ecx, symbol_value(rom_string_hash_table_lookup)
    jmp rn_error

;;
;;  (hash-table-vector HASH-TABLE) => VECTOR
;;  (hash-table-reconstructor HASH-TABLE) => APPLICATIVE
;;  (hash-table-bucket-count HASH-TABLE) => FIXINT
;;  (hash-table-length HASH-TABLE) => FIXINT
;;
%macro define_hash_table_getter 1
  app_hash_table_%1:
    call aux_hash_table_check
    mov eax, [ebx + hash_table.%1]
    jmp [ebp + cont.program]
%endmacro

define_hash_table_getter vector
define_hash_table_getter reconstructor
define_hash_table_getter bucket_count
define_hash_table_getter length

app_adjust_hash_table_lengthB:
  .A2:
    instrumentation_point
    call aux_hash_table_check
    mov eax, ecx
    xor cl, 1
    test cl, 3
    jnz aux_hash_table_check.error
    mov edx, [ebx + hash_table.length]
    add edx, ecx
    jo .overflow
    js .overflow
    mov [ebx + hash_table.length], edx
    mov eax, inert_tag
    jmp [ebp + cont.program]
  .overflow:
    mov eax, err_internal_error
    mov ebx, [ebx + hash_table.length]
    mov ecx, symbol_value(rom_string_adjust_hash_table_lengthB)
    jmp rn_error

aux_hash_table_check:
    test bl, 3
    jnz .error
    mov eax, [ebx]
    cmp eax, hash_table_header
    jne .error
    ret
  .error:
    mov eax, err_invalid_argument
    mov ecx, esi
    jmp rn_error

;;
;; app_hash_table_lookup (continuation passing procedure)
;;
;; Implementation of internal combiner
;;
;;  (hash-table-lookup HASH-TABLE KEY) => (HASH-VALUE . BUCKET-TAIL)
;;
;; preconditions:  EBX = hash table
;;                 ECX = key
;;                 EBP = current continuation
;;
app_hash_table_lookup:
  .A2:
    instrumentation_point
    test bl, 3
    jnz .error
    cmp [ebx], dword hash_table_header
    jne .error
    mov edi, [ebx + hash_table.hashf]
    mov eax, [edi]
    cmp al, applicative_header(0)
    jne .error
    mov edi, [edi + applicative.underlying]
    cmp [edi + operative.program], dword rn_asm_operative.L11
    jne .user_hashf
    cmp [edi + operative.var0], dword app_make_hash_function.apply
    jne .user_hashf
    mov eax, [edi + operative.var3]
    cmp eax, [ebx + hash_table.bucket_count]
    jne .user_hashf
  .builtin_hashf:
    push ebx
    push ecx
    mov ebx, ecx
    ;; manually inline make_hash_function.apply
    mov esi, [edi + operative.var1]
    m_get_blob_data esi, esi, edx
    call rn_hash
    call [edi + operative.var2]
    mov ecx, [edi + operative.var3]
    shr ecx, 2
    div ecx
    ;; end of inlined code
    pop ecx ; ecx = key
    pop edi ; edi = hash table object
            ; edx = untagged hash value
    mov ebx, [edi + hash_table.vector]
    mov esi, [ebx + 4*(1 + edx)]
    lea edx, [4*edx + 1] ; edx = tagged hash value
    cmp esi, nil_tag
    je .empty_bucket
    jmp [edi + hash_table.list_lookup]
  .empty_bucket:
    push edx
    push esi
    call rn_cons
    jmp [ebp + cont.program]

  .user_hashf:
    mov edx, ecx
    mov ecx, -6
    call rn_allocate_transient
    mov [eax + cont.header], dword cont_header(6)
    mov [eax + cont.program], dword .continue
    mov [eax + cont.parent], ebp
    mov [eax + cont.var0], ebx ; hash table object
    mov [eax + cont.var1], edx ; key
    mov [eax + cont.var2], edi ; operative underlying the hash function
    mov ebp, eax
    push edx
    push dword nil_tag
    call rn_cons
    mov ebx, eax
    mov eax, edi
    mov edi, empty_env_object
    jmp rn_combine
  .continue:
    ;; check that the argument is a nonnegative fixint
    mov ebx, eax
    mov edx, eax
    xor eax, 1
    test eax, 0x80000003
    jne .error
    mov edi, [ebp + cont.var0]          ; hash table object
    mov ecx, [ebp + cont.var1]          ; key
    mov ebp, [ebp + cont.parent]        ; reinstall continuation
    mov ebx, [edi + hash_table.vector]  ; vector
    mov eax, [ebx]                      ; vector header word
    shr eax, 8                          ; untagged vector object size
    lea eax, [4*eax - 3]                ; fixint: vector length
    cmp edx, eax
    jge .error
    mov esi, [ebx + edx + 3]            ; vector element
    cmp esi, nil_tag
    je .empty_bucket
    test esi, 3
    jz .error
    jnp .error
    jmp [edi + hash_table.list_lookup]

  .error:
    mov eax, err_internal_error
    mov ecx, symbol_value(rom_string_hash_table_lookup)
    jmp rn_error

;; app_make_hash_function (continuation passing procedure)
;;
;; Implementation of (make-hash-function BOUND) => APPLICATIVE.
;;
;; (APPLICATIVE X) returns an integer H, 0 <= H < BOUND.
;;
app_make_hash_function:
  .A1:
    instrumentation_point
    mov eax, ebx
    xor eax, 0x80000001
    test eax, 3
    jne .error
    cmp ebx, fixint_value(0)
    je .error
    cmp ebx, fixint_value(256)
    jb .u8
    cmp ebx, fixint_value(65536)
    jb .u16
    mov edx, .mix_u32
    jmp .checked
  .u8:
    mov edx, .mix_u8
    jmp .checked
  .u16:
    mov edx, .mix_u16
  .checked:
    mov edi, ebx
    mov ecx, 16
    call rn_allocate_blob
    mov esi, eax
    mov ebx, eax
    call rn_get_blob_data
    mov eax, [lisp_heap_pointer]
    mov [ebx], eax
    mov [ebx + 4], dword 'xaxa'
    mov [ebx + 8], dword 'bron'
    mov [ebx + 12], dword 'ze'
    mov ecx, 10
    call rn_allocate
    lea ecx, [eax + 16]
    mov [eax + applicative.header], dword applicative_header(4)
    mov [eax + applicative.program], dword rn_asm_applicative.L11
    mov [eax + applicative.underlying], ecx
    mov [eax + applicative.var0], dword .apply
    mov [ecx + operative.header], dword operative_header(6)
    mov [ecx + operative.program], dword rn_asm_operative.L11
    mov [ecx + operative.var0], dword .apply
    mov [ecx + operative.var1], esi
    mov [ecx + operative.var2], edx
    mov [ecx + operative.var3], edi
    jmp [ebp + cont.program]

  .error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_make_hash_function)
    jmp rn_error

  .apply:
    mov edi, eax
    mov esi, [edi + operative.var1]
    m_get_blob_data esi, esi, edx
    mov ecx, [edi + operative.var3]
    shr ecx, 2
    call rn_hash
    call [edi + operative.var2]
    mov ecx, [edi + operative.var3]
    shr ecx, 2
    div ecx
    lea eax, [4*edx + 1]
    jmp [ebp + cont.program]

  .mix_u32:
    xor eax, ebx
    xor ebx, ebx
    ret
  .mix_u16:
    xor eax, ebx
    mov ebx, eax
    shr ebx, 16
    xor ax, bx
    and eax, 0x0000FFFF
    xor ebx, ebx
    ret
  .mix_u8:
    call .mix_u16
    xor al, ah
    xor ah, ah
    ret

;;
;; app_hash (continuation passing procedure)
;;
;; Implementation of (hash OBJECT [SEED])
;;
app_hash:
  .A1:
    instrumentation_point
    mov esi, app_hash ; TODO!
  .compute:
    mov ecx, 142
    call rn_hash
    xor eax, ebx
    and eax, 0x1FFFFFFF
    lea eax, [4*eax + 1]
    xor esi, esi
    jmp [ebp + cont.program]
  .A2:
    instrumentation_point
    mov al, cl
    xor al, symbol_tag
    test al, ~(symbol_tag ^ bytevector_tag)
    jne .other_seed
    mov edx, ecx
    mov esi, ebx
    mov ebx, ecx
    call rn_get_blob_data
    xchg ebx, esi
    xchg ecx, edx
    cmp edx, 16
    je .compute
  .other_seed:
    push ebx
    mov ebx, ecx
    mov ecx, 4
    mov esi, app_hash ; TODO
    call rn_hash
    mov esi, scratchpad_start
    mov [esi], eax
    mov [esi + 4], ebx
    mov [esi + 8], dword 'bron'
    mov [esi + 12], dword 'zage'
    pop ebx
    jmp .compute

;;
;; app_hash_bytevector (continuation passing procedure)
;;
;; Implementation of (hash-bytevector INPUT KEY) => HASH,
;; where INPUT, KEY and HASH are bytevectors, and KEY
;; is 16 bytes (128 bits) long.
;;
app_hash_bytevector:
  .A2:
    instrumentation_point
    cmp bl, bytevector_tag
    jne .error
    xchg ebx, ecx
    cmp bl, bytevector_tag
    jne .error
    mov edx, ecx
    mov eax, ebx
    call rn_get_blob_data
    cmp ecx, 16
    jne .invalid_key_length
    mov esi, ebx
    mov ecx, 8
    call rn_allocate_blob
    mov edi, eax
    mov ebx, edx
    call rn_get_blob_data
    call rn_hash_buffer
    mov edx, edi
    m_get_blob_data edx, edx, ecx
    mov [edx], eax
    mov [edx + 4], ebx
    mov eax, edi
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx
    xor esi, esi
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_hash_bytevector)
    jmp rn_error
  .invalid_key_length:
    mov ebx, eax
    mov eax, err_invalid_key_length
    mov ecx, symbol_value(rom_string_hash_bytevector)
    jmp rn_error
