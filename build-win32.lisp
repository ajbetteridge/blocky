(in-package :cl-user)

(defvar *dll-pathname* #p"z:/home/dto/blocky/win32/")
(defvar *game* "xalcyon")
(defvar *executable* #p"z:/home/dto/blocky/xalcyon.exe")
(defvar *base-pathname* (make-pathname :name nil :type nil :defaults *load-pathname*))

(pushnew (translate-pathname *base-pathname* "**/" "**/site/cffi_0.10.3/") asdf:*central-registry*)
(pushnew (translate-pathname *base-pathname* "**/" "**/site/babel_0.3.0/") asdf:*central-registry*)
(pushnew (translate-pathname *base-pathname* "**/" "**/site/alexandria/") asdf:*central-registry*)
(pushnew (translate-pathname *base-pathname* "**/" "**/site/trivial-features_0.4/") asdf:*central-registry*)
(pushnew (translate-pathname *base-pathname* "**/" "**/site/rt-20040621/") asdf:*central-registry*)

(pushnew (translate-pathname *base-pathname* "**/" "**/site/lispbuilder/lispbuilder-sdl/") asdf:*central-registry*)
(pushnew (translate-pathname *base-pathname* "**/" "**/site/lispbuilder/lispbuilder-sdl-image/") asdf:*central-registry*)
(pushnew (translate-pathname *base-pathname* "**/" "**/site/lispbuilder/lispbuilder-sdl-mixer/") asdf:*central-registry*)
(pushnew (translate-pathname *base-pathname* "**/" "**/site/lispbuilder/lispbuilder-sdl-ttf/") asdf:*central-registry*)

(pushnew (translate-pathname *base-pathname* "**/" "**/blocky/") asdf:*central-registry*)
;(pushnew (translate-pathname *base-pathname* "**/" "**/xe2/") asdf:*central-registry*)

(asdf:oos 'asdf:load-op :cffi)
(require 'sb-posix)
(sb-posix:chdir *dll-pathname*)
;;(setf *default-pathname-defaults* (make-pathname :directory '(:relative)))

(map nil
#'ql:quickload (list "lispbuilder-sdl-mixer" "lispbuilder-sdl-ttf" "lispbuilder-sdl-image" "cl-opengl" "cl-fad" "uuid")) (require :blocky)

(asdf:oos 'asdf:load-op :blocky)
(pop cffi:*foreign-library-directories*)

(defun main ()
  (setf blocky:*project-directories* (list (make-pathname :directory '(:relative))))
  (blocky:play *game*)
  0)

(sb-ext:save-lisp-and-die *executable* :toplevel #'main :executable t)

;; #+sbcl
;; (progn 
;;   (if (member :sb-core-compression *features*)
;;       (sb-ext:save-lisp-and-die 
;;        "name.exe" 
;;        :executable t :toplevel (function main-prog)
;;        :compression t)
;;       (sb-ext:save-lisp-and-die 
;;        "name.exe" :executable t :toplevel (function main-prog))))


;; TODO try this to get rid of the kitten of death
;; (with-open-file (exe #p"path/to/game.exe" :direction :io :element-type '(unsigned-byte 8))
;;   (file-position exe #x3c)
;;   (let* ((b0 (read-byte exe))
;; 	 (b1 (read-byte exe))
;; 	 (b2 (read-byte exe))
;; 	 (b3 (read-byte exe))
;; 	 (pe-header (dpb (dpb b3 (byte 8 8) b2)
;; 			 (byte 16 16)
;; 			 (dpb b1 (byte 8 8) b0))))
;;     (file-position exe (+ pe-header #x5c))
;;     (write-byte 3 exe)))
