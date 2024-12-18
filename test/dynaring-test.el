;; Note: we want to retain dynamic binding for these tests because the
;; ERT "fixtures" rely on it.

;; To run the tests from within Emacs, you must `eval-buffer` this test
;; buffer first. Then, run tests using `ert-run-tests-interactively`.

;; Add source paths to load path so the tests can find the source files
;; Adapted from:
;; https://github.com/Lindydancer/cmake-font-lock/blob/47687b6ccd0e244691fb5907aaba609e5a42d787/test/cmake-font-lock-test-setup.el#L20-L27
(defvar dynaring-test-setup-directory
  (if load-file-name
      (file-name-directory load-file-name)
    default-directory))

(dolist (dir '("." ".."))
  (add-to-list 'load-path
               (concat dynaring-test-setup-directory dir)))

;;

(require 'dynaring)
(require 'cl-lib)

;;
;; Fixtures
;;

;; fixture recipe from:
;; https://www.gnu.org/software/emacs/manual/html_node/ert/Fixtures-and-Test-Suites.html
(defun fixture-0-ring (body)
  (let ((ring nil))
    (unwind-protect
        (progn (setq ring (dynaring-make))
               (funcall body))
      (dynaring-destroy ring))))

(defun fixture-1-ring (body)
  (let ((ring nil))
    (unwind-protect
        (progn
          (setq ring (dynaring-make))
          (let ((segment (dynaring-insert ring 1)))
            (funcall body)))
      (dynaring-destroy ring))))

(defun fixture-2-ring (body)
  ;; [2] - 1 - [2]
  (let ((ring nil))
    (unwind-protect
        (progn
          (setq ring (dynaring-make))
          (let ((seg1 (dynaring-insert ring 1))
                (seg2 (dynaring-insert ring 2)))
            (funcall body)))
      (dynaring-destroy ring))))

(defun fixture-3-ring (body)
  ;; [3] - 2 - 1 - [3]
  (let ((ring nil))
    (unwind-protect
        (progn
          (setq ring (dynaring-make))
          (let ((seg1 (dynaring-insert ring 1))
                (seg2 (dynaring-insert ring 2))
                (seg3 (dynaring-insert ring 3)))
            (funcall body)))
      (dynaring-destroy ring))))

(defun fixture-memo (body)
  (cl-letf ((memofn (lambda (arg)
                      (push arg memo)))
            (memo (list)))
    (unwind-protect
        (funcall body))))

(defmacro with-fixture (fixture &rest test)
  "Run TEST using FIXTURE."
  (declare (indent 1))
  `(,fixture
    (lambda ()
      ,@test)))

;;
;; Test utilities
;;

(defun segments-are-linked-p (previous next)
  (and (eq (dynaring-segment-next previous) next)
       (eq (dynaring-segment-previous next) previous)))

(defun segment-is-free-p (segment)
  (and (null (dynaring-segment-next segment))
       (null (dynaring-segment-previous segment))))

;;
;; Tests
;;

(ert-deftest dynaring-test ()
  ;; null constructor
  (should (dynaring-make))

  ;; variadic constructor
  (should (dynaring 1 2 3))
  (let ((ring (dynaring 1 2 3)))
    (should (dynaringp ring))
    ;; see the comment on the "variadic insertion"
    ;; test re: ensuring order of insertion
    (should (= 3 (dynaring-value ring)))
    (should (= 3 (dynaring-size ring)))))

(ert-deftest dynaringp-test ()
  ;; predicate
  (with-fixture fixture-0-ring
    (should (dynaringp ring)))
  (with-fixture fixture-1-ring
    (should (dynaringp ring)))
  (should-not (dynaringp (list 1 2 3)))
  (should-not (dynaringp (cons 1 "hi"))))

(ert-deftest dynaring-empty-p-test ()
  (with-fixture fixture-0-ring
    (should (dynaring-empty-p ring)))
  (with-fixture fixture-1-ring
    (should-not (dynaring-empty-p ring))))

(ert-deftest dynaring-size-test ()
  (with-fixture fixture-0-ring
    (should (= 0 (dynaring-size ring))))
  (with-fixture fixture-1-ring
    (should (= 1 (dynaring-size ring)))))

(ert-deftest dynaring-head-test ()
  (with-fixture fixture-0-ring
    (should (null (dynaring-head ring))))
  (with-fixture fixture-1-ring
    (should-not (null (dynaring-head ring)))))

(ert-deftest dynaring-value-test ()
  (with-fixture fixture-0-ring
    (should (null (dynaring-value ring))))
  (with-fixture fixture-1-ring
    (should (= 1 (dynaring-value ring)))))

(ert-deftest dynaring-equal-p-test ()
  ;; empty ring
  (with-fixture fixture-0-ring
    (let* ((r2 (dynaring-make))
           (r3 (dynaring-make)))
      (dynaring-insert r3 1)
      (should (dynaring-equal-p ring r2))
      (should-not (dynaring-equal-p ring r3))))

  ;; 1-element ring
  (with-fixture fixture-1-ring
    (let* ((r2 (dynaring-make))
           (r3 (dynaring-make)))
      (dynaring-insert r2 1)
      (dynaring-insert r3 1)
      (dynaring-insert r3 1)
      (should (dynaring-equal-p ring r2))
      (should-not (dynaring-equal-p ring r3))))

  ;; 2-element ring
  (with-fixture fixture-2-ring
    (let* ((r2 (dynaring-make))
           (r3 (dynaring-make)))
      (dynaring-insert r2 1)
      (dynaring-insert r2 2)
      (dynaring-insert r3 1)
      (dynaring-insert r3 1)
      (should (dynaring-equal-p ring r2))
      (should-not (dynaring-equal-p ring r3))))

  ;; 3-element ring
  (with-fixture fixture-3-ring
    (let* ((r2 (dynaring-make))
           (r3 (dynaring-make)))
      (dynaring-insert r2 1)
      (dynaring-insert r2 2)
      (dynaring-insert r2 3)
      (dynaring-insert r3 1)
      (dynaring-insert r3 3)
      (dynaring-insert r3 2)
      (should (dynaring-equal-p ring r2))
      (should-not (dynaring-equal-p ring r3)))))

(ert-deftest dynaring-traverse-test ()
  ;; empty ring
  (with-fixture fixture-0-ring
    (with-fixture fixture-memo
      (should-not (dynaring-traverse ring memofn))
      (should (null memo))))

  ;; one-element ring
  (with-fixture fixture-1-ring
    (with-fixture fixture-memo
      (should (dynaring-traverse ring memofn))
      (should (equal memo (list 1)))))

  ;; two-element ring
  (with-fixture fixture-2-ring
    (with-fixture fixture-memo
      (should (dynaring-traverse ring memofn))
      (should (equal memo (list 1 2)))))

  ;; 3-element ring
  (with-fixture fixture-3-ring
    (with-fixture fixture-memo
      (should (dynaring-traverse ring memofn))
      (should (equal memo (list 1 2 3))))))

(ert-deftest dynaring-traverse-collect-test ()
  ;; empty ring
  (with-fixture fixture-0-ring
    (let ((result (dynaring-traverse-collect ring #'1+)))
      (should (null result))))

  ;; one-element ring
  (with-fixture fixture-1-ring
    (let ((result (dynaring-traverse-collect ring #'1+)))
      (should (equal result (list 2)))))

  ;; two-element ring
  (with-fixture fixture-2-ring
    (let ((result (dynaring-traverse-collect ring #'1+)))
      (should (equal result (list 2 3)))))

  ;; 3-element ring
  (with-fixture fixture-3-ring
    (let ((result (dynaring-traverse-collect ring #'1+)))
      (should (equal result (list 2 3 4))))))

(ert-deftest dynaring-insert-test ()
  ;; empty ring
  (with-fixture fixture-0-ring
    (should (dynaring-insert ring 1))
   (should (= 1 (dynaring-value ring)))
   (let ((head (dynaring-head ring)))
     (should (segments-are-linked-p head head))))

  ;; one-element ring
  (with-fixture fixture-1-ring
    (let ((new (dynaring-insert ring 2)))
      (should new)
      (should (= 2 (dynaring-value ring)))
      (should (segments-are-linked-p segment new))
      (should (segments-are-linked-p new segment))))

  ;; two-element ring
  (with-fixture fixture-2-ring
    (let ((new (dynaring-insert ring 3)))
      (should new)
      (should (= 3 (dynaring-value ring)))
      (should (segments-are-linked-p seg1 new))
      (should (segments-are-linked-p new seg2))
      (should (segments-are-linked-p seg2 seg1))))

  ;; variadic insertion
  (with-fixture fixture-0-ring
    (should (dynaring-insert ring 1 2 3))
   ;; although inserting the elements in forward order
   ;; is the current behavior,
   ;; I'm not sure we really need to provide
   ;; an assurance that the elements will be
   ;; inserted in a particular order, as long as it's
   ;; an isomorphic order to the input list (i.e.
   ;; either forward or reverse order could be OK).
   ;; But for now, we will explicitly test this
   ;; to ensure that any changes here are intentional.
   (should (= 3 (dynaring-value ring)))
   (should (= 3 (dynaring-size ring)))))

(ert-deftest dynaring-break-insert-test ()
  ;; empty ring
  (with-fixture fixture-0-ring
    (should (dynaring-break-insert ring 1))
   (should (= 1 (dynaring-value ring)))
   (let ((head (dynaring-head ring)))
     (should (segments-are-linked-p head head))))

  ;; one-element ring
  (with-fixture fixture-1-ring
    (let ((new (dynaring-break-insert ring 2)))
      (should new)
      (should (= 2 (dynaring-value ring)))
      (should (segments-are-linked-p segment new))
      (should (segments-are-linked-p new segment))))
  (with-fixture fixture-1-ring
    (let ((new (dynaring-break-insert ring 1)))
      (should new)
      (should (= 1 (dynaring-value ring)))
      (should (= 1 (dynaring-size ring)))))

  ;; two-element ring
  (with-fixture fixture-2-ring
    (let ((new (dynaring-break-insert ring 3)))
      (should new)
      (should (= 3 (dynaring-value ring)))
      (should (segments-are-linked-p seg1 new))
      (should (segments-are-linked-p new seg2))
      (should (segments-are-linked-p seg2 seg1))))
  (with-fixture fixture-2-ring
    (let ((new (dynaring-break-insert ring 2)))
      (should new)
      (should (= 2 (dynaring-value ring)))
      (should (segments-are-linked-p seg1 new))
      (should (segments-are-linked-p new seg1))))
  (with-fixture fixture-2-ring
    (let ((new (dynaring-break-insert ring 1)))
      (should new)
      (should (= 1 (dynaring-value ring)))
      (should (segments-are-linked-p seg2 new))
      (should (segments-are-linked-p new seg2))))

  ;; 3-element ring
  (with-fixture fixture-3-ring
    (let ((new (dynaring-break-insert ring 3)))
      (should new)
      (should (= 3 (dynaring-value ring)))
      (should (segments-are-linked-p seg1 new))
      (should (segments-are-linked-p new seg2))))
  (with-fixture fixture-3-ring
    (let ((new (dynaring-break-insert ring 2)))
      (should new)
      (should (= 2 (dynaring-value ring)))
      (should (segments-are-linked-p seg1 new))
      (should (segments-are-linked-p new seg3))))
  (with-fixture fixture-3-ring
    (let ((new (dynaring-break-insert ring 1)))
      (should new)
      (should (= 1 (dynaring-value ring)))
      (should (segments-are-linked-p seg2 new))
      (should (segments-are-linked-p new seg3))))

  ;; break-insert should not change the structure
  ;; when the element is already at head
  (with-fixture fixture-3-ring
    (let ((original-order (dynaring-values ring)))
      (let ((new (dynaring-break-insert ring 3)))
        (should new)
        (should (equal original-order (dynaring-values ring))))))
  (with-fixture fixture-3-ring
    (let ((original-order (dynaring-values ring)))
      (let ((new (dynaring-break-insert ring 2)))
        (should new)
        (should-not (equal original-order (dynaring-values ring)))))))

(ert-deftest dynaring-rotate-test ()
  ;; empty ring
  (with-fixture fixture-0-ring
    (should (null (dynaring-rotate-left ring)))
   (should (null (dynaring-rotate-right ring))))

  ;; 1-element ring
  (with-fixture fixture-1-ring
    (should (eq segment (dynaring-rotate-left ring)))
   (should (eq segment (dynaring-rotate-right ring))))

  ;; 2-element ring
  (with-fixture fixture-2-ring
    (should (eq seg1 (dynaring-rotate-left ring)))
   (should (eq seg2 (dynaring-rotate-left ring)))
   (should (eq seg1 (dynaring-rotate-right ring)))
   (should (eq seg2 (dynaring-rotate-right ring))))

  ;; 3-element ring
  (with-fixture fixture-3-ring
    (should (eq seg1 (dynaring-rotate-left ring)))
   (should (eq seg2 (dynaring-rotate-left ring)))
   (should (eq seg3 (dynaring-rotate-left ring)))
   (should (eq seg2 (dynaring-rotate-right ring)))
   (should (eq seg1 (dynaring-rotate-right ring)))
   (should (eq seg3 (dynaring-rotate-right ring)))))

(ert-deftest dynaring-delete-segment-test ()
  ;; empty ring
  (let ((ring (dynaring-make))
        (segment (dynaring-make-segment 1)))
    (should (null (dynaring-delete-segment ring segment)))
    (should (dynaring-empty-p ring)))

  ;; 1-element ring
  (with-fixture fixture-1-ring
    (should (dynaring-delete-segment ring segment))
   (should (dynaring-empty-p ring)))

  ;; 2-element ring
  (with-fixture fixture-2-ring
    ;; delete head
    (should (dynaring-delete-segment ring seg2))
   (should (= 1 (dynaring-size ring)))
   (should (eq seg1 (dynaring-head ring)))
   (should (segments-are-linked-p seg1 seg1)))
  (with-fixture fixture-2-ring
    ;; delete non-head
    (should (dynaring-delete-segment ring seg1))
   (should (= 1 (dynaring-size ring)))
   (should (eq seg2 (dynaring-head ring)))
   (should (segments-are-linked-p seg2 seg2)))

  ;; 3-element ring
  (with-fixture fixture-3-ring
    ;; delete head
    (should (dynaring-delete-segment ring seg3))
   (should (= 2 (dynaring-size ring)))
   (should (eq seg2 (dynaring-head ring)))
   (should (segments-are-linked-p seg2 seg1))
   (should (segments-are-linked-p seg1 seg2)))
  (with-fixture fixture-3-ring
    ;; delete right
    (should (dynaring-delete-segment ring seg2))
   (should (= 2 (dynaring-size ring)))
   (should (eq seg3 (dynaring-head ring)))
   (should (segments-are-linked-p seg3 seg1))
   (should (segments-are-linked-p seg1 seg3)))
  (with-fixture fixture-3-ring
    ;; delete left
    (should (dynaring-delete-segment ring seg1))
   (should (= 2 (dynaring-size ring)))
   (should (eq seg3 (dynaring-head ring)))
   (should (segments-are-linked-p seg3 seg2))
   (should (segments-are-linked-p seg2 seg3))))

(ert-deftest dynaring-delete-test ()
  ;; empty ring
  (let ((ring (dynaring-make)))
    (should-not (dynaring-delete ring 1))
    (should (dynaring-empty-p ring)))

  ;; 1-element ring
  (with-fixture fixture-1-ring
    (should (dynaring-delete ring 1))
   (should (dynaring-empty-p ring)))
  (with-fixture fixture-1-ring
    ;; non-element
    (should-not (dynaring-delete ring 2))
   (should (= 1 (dynaring-size ring))))

  ;; 2-element ring
  (with-fixture fixture-2-ring
    ;; delete head
    (should (dynaring-delete ring 2))
   (should (= 1 (dynaring-size ring))))
  (with-fixture fixture-2-ring
    ;; delete non-head
    (should (dynaring-delete ring 1))
   (should (= 1 (dynaring-size ring))))
  (with-fixture fixture-2-ring
    ;; non-element
    (should-not (dynaring-delete ring 3))
   (should (= 2 (dynaring-size ring))))

  ;; 3-element ring
  (with-fixture fixture-3-ring
    ;; delete head
    (should (dynaring-delete ring 3))
   (should (= 2 (dynaring-size ring))))
  (with-fixture fixture-3-ring
    ;; delete right
    (should (dynaring-delete ring 2))
   (should (= 2 (dynaring-size ring))))
  (with-fixture fixture-3-ring
    ;; delete left
    (should (dynaring-delete ring 1))
   (should (= 2 (dynaring-size ring))))
  (with-fixture fixture-3-ring
    ;; non-element
    (should-not (dynaring-delete ring 4))
   (should (= 3 (dynaring-size ring)))))

(ert-deftest dynaring-destroy-test ()
  ;; empty ring
  (with-fixture fixture-0-ring
    (should-not (dynaring-destroy ring)))

  ;; 1-element ring
  (with-fixture fixture-1-ring
    (should (dynaring-destroy ring))
   (should (null (dynaring-head ring)))
   (should (= 0 (dynaring-size ring)))
   (should (segment-is-free-p segment)))

  ;; 2-element ring
  (with-fixture fixture-2-ring
    (should (dynaring-destroy ring))
   (should (null (dynaring-head ring)))
   (should (= 0 (dynaring-size ring)))
   (should (segment-is-free-p seg1))
   (should (segment-is-free-p seg2)))

  ;; 3-element ring
  (with-fixture fixture-3-ring
    (should (dynaring-destroy ring))
   (should (null (dynaring-head ring)))
   (should (= 0 (dynaring-size ring)))
   (should (segment-is-free-p seg1))
   (should (segment-is-free-p seg2))
   (should (segment-is-free-p seg3))))

(ert-deftest dynaring-rotate-until-test ()
  ;; empty ring
  (with-fixture fixture-0-ring
    (should-not (dynaring-rotate-until ring
                                       #'dynaring-rotate-left
                                       (lambda (element)
                                         t))))

  ;; 1-element ring
  (with-fixture fixture-1-ring
    (should (dynaring-rotate-until ring
                                   #'dynaring-rotate-left
                                   (lambda (element)
                                     t)))
   (should (eq segment (dynaring-head ring))))
  (with-fixture fixture-1-ring
    (should-not (dynaring-rotate-until ring
                                       #'dynaring-rotate-left
                                       (lambda (element)
                                         nil)))
   (should (eq segment (dynaring-head ring))))

  ;; 2-element ring
  (with-fixture fixture-2-ring
    (should (dynaring-rotate-until ring
                                   #'dynaring-rotate-left
                                   (lambda (element)
                                     (not (= 2 element)))))
   (should (eq seg1 (dynaring-head ring))))
  (with-fixture fixture-2-ring
    (should (dynaring-rotate-until ring
                                   #'dynaring-rotate-right
                                   (lambda (element)
                                     (not (= 2 element)))))
   (should (eq seg1 (dynaring-head ring))))

  ;; 3-element ring
  (with-fixture fixture-3-ring
    (should (dynaring-rotate-until ring
                                   #'dynaring-rotate-left
                                   (lambda (element)
                                     (not (= 3 element)))))
   (should (eq seg1 (dynaring-head ring))))
  (with-fixture fixture-3-ring
    (should (dynaring-rotate-until ring
                                   #'dynaring-rotate-right
                                   (lambda (element)
                                     (not (= 3 element)))))
   (should (eq seg2 (dynaring-head ring))))
  ;; non-trivial predicate
  (with-fixture fixture-3-ring
    (should (dynaring-rotate-until ring
                                   #'dynaring-rotate-left
                                   (lambda (element)
                                     (= element 2))))
   (should (eq seg2 (dynaring-head ring))))
  (with-fixture fixture-3-ring
    (should (dynaring-rotate-until ring
                                   #'dynaring-rotate-right
                                   (lambda (element)
                                     (= element 2))))
   (should (eq seg2 (dynaring-head ring))))
  ;; predicate never satisfied
  (with-fixture fixture-3-ring
    (should-not (dynaring-rotate-until ring
                                       #'dynaring-rotate-left
                                       (lambda (element)
                                         nil)))
   (should (eq seg3 (dynaring-head ring))))
  (with-fixture fixture-3-ring
    (should-not (dynaring-rotate-until ring
                                       #'dynaring-rotate-right
                                       (lambda (element)
                                         nil)))
   (should (eq seg3 (dynaring-head ring))))
  ;; if predicate is true on the head, it does not rotate the ring
  (with-fixture fixture-2-ring
    (should (dynaring-rotate-until ring
                                   #'dynaring-rotate-left
                                   (lambda (element)
                                     t)))
   (should (eq seg2 (dynaring-head ring))))
  (with-fixture fixture-2-ring
    (should (dynaring-rotate-until ring
                                   #'dynaring-rotate-right
                                   (lambda (element)
                                     t)))
   (should (eq seg2 (dynaring-head ring)))))

(ert-deftest dynaring-find-forwards-test ()
  ;; empty ring
  (with-fixture fixture-0-ring
    (should-not (dynaring-find-forwards ring
                                        (lambda (element)
                                          t))))

  ;; 1-element ring
  (with-fixture fixture-1-ring
    (should (eq segment
                (dynaring-find-forwards ring
                                        (lambda (element)
                                          (= 1 element)))))
   (should-not (dynaring-find-forwards ring
                                       (lambda (element)
                                         nil))))

  ;; 2-element ring
  (with-fixture fixture-2-ring
    (should (eq seg1
                (dynaring-find-forwards ring
                                        (lambda (element)
                                          (= 1 element)))))
   (should (eq seg2 (dynaring-find-forwards ring
                                            (lambda (element)
                                              (< element 3)))))
   (should (eq seg1 (dynaring-find-forwards ring
                                            (lambda (element)
                                              (< element 2)))))
   (should-not (dynaring-find-forwards ring
                                       (lambda (element)
                                         nil))))

  ;; 3-element ring
  (with-fixture fixture-3-ring
    (should (eq seg1
                (dynaring-find-forwards ring
                                        (lambda (element)
                                          (= 1 element)))))
   (should (eq seg3 (dynaring-find-forwards ring
                                            (lambda (element)
                                              (< element 4)))))
   (should (eq seg2 (dynaring-find-forwards ring
                                            (lambda (element)
                                              (< element 3)))))
   (should-not (dynaring-find-forwards ring
                                       (lambda (element)
                                         nil)))))

(ert-deftest dynaring-find-backwards-test ()
  ;; empty ring
  (with-fixture fixture-0-ring
    (should-not (dynaring-find-backwards ring
                                         (lambda (element)
                                           t))))

  ;; 1-element ring
  (with-fixture fixture-1-ring
    (should (eq segment
                (dynaring-find-backwards ring
                                         (lambda (element)
                                           (= 1 element)))))
   (should-not (dynaring-find-backwards ring
                                        (lambda (element)
                                          nil))))

  ;; 2-element ring
  (with-fixture fixture-2-ring
    (should (eq seg1
                (dynaring-find-backwards ring
                                         (lambda (element)
                                           (= 1 element)))))
   (should (eq seg2 (dynaring-find-backwards ring
                                             (lambda (element)
                                               (< element 3)))))
   (should (eq seg1 (dynaring-find-backwards ring
                                             (lambda (element)
                                               (< element 2)))))
   (should-not (dynaring-find-backwards ring
                                        (lambda (element)
                                          nil))))

  ;; 3-element ring
  (with-fixture fixture-3-ring
    (should (eq seg1
                (dynaring-find-backwards ring
                                         (lambda (element)
                                           (= 1 element)))))
   (should (eq seg3 (dynaring-find-backwards ring
                                             (lambda (element)
                                               (< element 4)))))
   (should (eq seg1 (dynaring-find-backwards ring
                                             (lambda (element)
                                               (< element 3)))))
   (should-not (dynaring-find-backwards ring
                                        (lambda (element)
                                          nil)))))

(ert-deftest dynaring-contains-p-test ()
  ;; empty ring
  (with-fixture fixture-0-ring
    (should-not (dynaring-contains-p ring 1)))

  ;; 1-element ring
  (with-fixture fixture-1-ring
    (should (dynaring-contains-p ring 1))
   (should-not (dynaring-contains-p ring 2)))

  ;; 2-element ring
  (with-fixture fixture-2-ring
    (should (dynaring-contains-p ring 1))
   (should (dynaring-contains-p ring 2))
   (should-not (dynaring-contains-p ring 3)))

  ;; 3-element ring
  (with-fixture fixture-3-ring
    (should (dynaring-contains-p ring 1))
   (should (dynaring-contains-p ring 2))
   (should (dynaring-contains-p ring 3))
   (should-not (dynaring-contains-p ring 4))))

(ert-deftest dynaring-values-test ()
  ;; empty ring
  (with-fixture fixture-0-ring
    (should (null (dynaring-values ring))))

  ;; 1-element ring
  (with-fixture fixture-1-ring
    (should (equal (list 1) (dynaring-values ring))))

  ;; 2-element ring
  (with-fixture fixture-2-ring
    (should (equal (list 1 2) (dynaring-values ring))))

  ;; 3-element ring
  (with-fixture fixture-3-ring
    (should (equal (list 1 2 3) (dynaring-values ring)))))

(ert-deftest dynaring-map-test ()
  ;; empty ring
  (with-fixture fixture-0-ring
    (let ((result (dynaring-map ring #'1+)))
      (should (dynaring-empty-p result))))

  ;; one-element ring
  (with-fixture fixture-1-ring
    (let ((result (dynaring-map ring #'1+)))
      (should (equal (dynaring-values result)
                     (seq-map #'1+ (dynaring-values ring))))))

  ;; two-element ring
  (with-fixture fixture-2-ring
    (let ((result (dynaring-map ring #'1+)))
      (should (equal (dynaring-values result)
                     (seq-map #'1+ (dynaring-values ring))))))

  ;; 3-element ring
  (with-fixture fixture-3-ring
    (let ((result (dynaring-map ring #'1+)))
      (should (equal (dynaring-values result)
                     (seq-map #'1+ (dynaring-values ring))))))
  ;; copy ring
  (with-fixture fixture-3-ring
    (let ((result (dynaring-map ring #'identity)))
      (should (dynaring-equal-p result ring)))))

(ert-deftest dynaring-transform-map-test ()
  ;; empty ring
  (with-fixture fixture-0-ring
    (should-not (dynaring-transform-map ring #'1+)))

  ;; one-element ring
  (with-fixture fixture-1-ring
    (should (dynaring-transform-map ring #'1+))
   (should (equal (list 2) (dynaring-values ring))))

  ;; two-element ring
  (with-fixture fixture-2-ring
    (should (dynaring-transform-map ring #'1+))
   (should (equal (list 2 3) (dynaring-values ring))))

  ;; 3-element ring
  (with-fixture fixture-3-ring
    (should (dynaring-transform-map ring #'1+))
   (should (equal (list 2 3 4) (dynaring-values ring)))))

(ert-deftest dynaring-filter-test ()
  ;; empty ring
  (with-fixture fixture-0-ring
    (let ((result (dynaring-filter ring #'cl-oddp)))
      (should (dynaring-equal-p result ring))))

  ;; one-element ring
  (with-fixture fixture-1-ring
    (let ((result (dynaring-filter ring #'cl-oddp)))
      (should (dynaring-equal-p result ring))))
  (with-fixture fixture-1-ring
    (let ((result (dynaring-filter ring #'cl-evenp)))
      (should (dynaring-empty-p result))))

  ;; two-element ring
  (with-fixture fixture-2-ring
    (let ((result (dynaring-filter ring #'cl-oddp)))
      (should (equal (list 1) (dynaring-values result)))))
  (with-fixture fixture-2-ring
    (let ((result (dynaring-filter ring #'cl-evenp)))
      (should (equal (list 2) (dynaring-values result)))))

  ;; 3-element ring
  (with-fixture fixture-3-ring
    (let ((result (dynaring-filter ring #'cl-oddp)))
      (should (equal (list 1 3) (dynaring-values result)))))

  ;; filter out all
  (with-fixture fixture-3-ring
    (let ((result (dynaring-filter ring (lambda (elem) nil))))
      (should (dynaring-empty-p result))))

  ;; filter out none
  (with-fixture fixture-3-ring
    (let ((result (dynaring-filter ring (lambda (elem) t))))
      (should (dynaring-equal-p result ring))))

  ;; filter should behave the same as deletion for unique elements
  (with-fixture fixture-3-ring
    (let ((result (dynaring-filter ring
                                   (lambda (elem)
                                     (not (= elem 1))))))
      (dynaring-delete ring 1)
      (should (dynaring-equal-p result ring))))
  (with-fixture fixture-3-ring
    (let ((result (dynaring-filter ring
                                   (lambda (elem)
                                     (not (= elem 2))))))
      (dynaring-delete ring 2)
      (should (dynaring-equal-p result ring)))))

(ert-deftest dynaring-transform-filter-test ()
  ;; empty ring
  (with-fixture fixture-0-ring
    (should-not (dynaring-transform-filter ring #'cl-oddp)))

  ;; one-element ring
  (with-fixture fixture-1-ring
    (should (dynaring-transform-filter ring #'cl-oddp))
   (should (= 1 (dynaring-value ring)))
   (should (= 1 (dynaring-size ring))))
  (with-fixture fixture-1-ring
    (should (dynaring-transform-filter ring #'cl-evenp))
   (should (dynaring-empty-p ring)))

  ;; two-element ring
  (with-fixture fixture-2-ring
    (should (dynaring-transform-filter ring #'cl-oddp))
   (should (equal (list 1) (dynaring-values ring))))
  (with-fixture fixture-2-ring
    (should (dynaring-transform-filter ring #'cl-evenp))
   (should (equal (list 2) (dynaring-values ring))))

  ;; 3-element ring
  (with-fixture fixture-3-ring
    (should (dynaring-transform-filter ring #'cl-oddp))
   (should (equal (list 1 3) (dynaring-values ring))))

  ;; filter out all
  (with-fixture fixture-3-ring
    (should (dynaring-transform-filter ring (lambda (elem) nil)))
   (should (dynaring-empty-p ring)))

  ;; filter out none
  (with-fixture fixture-3-ring
    (let ((ring-copy (dynaring-map ring #'identity)))
      (should (dynaring-transform-filter ring (lambda (elem) t)))
      (should (dynaring-equal-p ring ring-copy))))

  ;; filter should behave the same as deletion for unique elements
  (with-fixture fixture-3-ring
    (let ((ring-copy (dynaring-map ring #'identity)))
      (dynaring-transform-filter ring-copy
                                 (lambda (elem)
                                   (not (= elem 1))))
      (dynaring-delete ring 1)
      (should (dynaring-equal-p ring ring-copy))))
  (with-fixture fixture-3-ring
    (let ((ring-copy (dynaring-map ring #'identity)))
      (dynaring-transform-filter ring-copy
                                 (lambda (elem)
                                   (not (= elem 2))))
      (dynaring-delete ring 2)
      (should (dynaring-equal-p ring ring-copy)))))
