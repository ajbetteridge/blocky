;;; example3.lisp --- something more interesting

;; Copyright (C) 2011  David O'Toole

;; Author: David O'Toole <dto@gnu.org>
;; Keywords: games

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Preamble

(defpackage :example3 
    (:use :ioforms :common-lisp))
  
(in-package :example3)

(setf *screen-width* 480)
(setf *screen-height* 380)
(setf *window-title* "Blocks demo")

(defparameter *font* "sans-bold-12")

(defblock hello1
  :operation :foo
  :x 20 :y 20 :height 100 :width 200 :category :sensing)

(defblock hello2
  :x 100 :y 140 :height 40 :width 250 :category :control)

(defblock hello3
  :x 20 :y 400 :height 40 :width 40 :category :operators)

(defun example3 ()
  (let ((script (new script))
	(shell (new shell))) 
    (add script (new hello1))
    (add script (new hello2))
    (add script (new hello3))
    (add script (new list) 200 200)
    (add script (new menu) 240 240)

    (add script 
	 (new menu :label "outer menu" 
	           :expanded t
		   :inputs 
		   (list (new menu :label "move north" :action :move-north)
			 (new menu :label "move south" :action :move-south)
			 (new menu :label "move east" :action :move-east)
			 (new menu :label "move west" :action :move-west)
			 (new menu :label "other" 
				   :action (new menu 
						:label "other menu"
						:inputs
						(list (new menu :label "move north" :action :move-north)
						      (new menu :label "move south" :action :move-south)
						      (new menu :label "move east" :action :move-east)
						      (new menu :label "move west" :action :move-west)))))))
    (add script (new listener) 300 100)
    (open-script shell script)
    (add-block shell)))
	     
;;; example3.lisp ends here