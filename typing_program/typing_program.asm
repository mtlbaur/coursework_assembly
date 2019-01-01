MyStack SEGMENT STACK

	DW 4096 DUP (?)

MyStack ENDS


MyData SEGMENT

	numString DB 10 DUP (?)					; holds the characters that will represent the timer

	color DB (?)						; holds the color that the user's sentence will be

	done DB (?)						; terminating condition

	mismatch DB (?)						; determines whether timer accumulates at twice the rate

	char DW (?)						; character to be placed in user's sentence

	randomNum DW (?)					; the random number that determines which sentence is selected

	bSenPos DW (?)						; pointer to position in sentence

	bSenStartPos DW (?)					; starting location

	bSenLocation DW (?)					; screen location

	bSenLength DW (?)					; length

	aCursorZRow EQU 9					; actual cursor location on screen

	aCursorZCol DB (?)					; actual cursor location on screen

	deleteKeyHit DB (?)					; used to determine behavior of shiftContentsLeft PROC

	uSenEndPos DW (?)					; ending position in user's sentence

	uSenPos DW (?)						; virtual cursor

	uSenStartPos DW (?)					; starting position in user's sentence

	uSenLocation DW (?)					; screen location of user's sentence

	uSenLength DW (?)					; length of user's sentence

	uSen DW 78 DUP (?)					; where user's sentence is contained

	prevTicks DW (?)					; starting system ticks

	currentTicks DW (?)					; current system ticks

	totalTicks DW (?)					; ticks that are used to determine what the timer displays

	deltaTicks DW (?)					; used to increase the timer

	prevTicksInitialized DB (?)				; determines when to update timer

	seconds DW (?)						; holds converted ticks

	sen1 DB "AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz - have fun with that.    "

	sen2 DB "The large blue fish swam in between the vibrant coral reefs.                  "

	sen3 DB "Alfalfa was the favorite word of a certain infuriating learn-to-type game.    "

	sen4 DB "There once was a king who did nothing but sit on his throne.                  "

	sen5 DB "Detective Highglass had a headache - this was not beneficial to his mood.     "

	sen6 DB "The icicle gleamed with a cold light and reflected its surroundings.          "

	sen7 DB "A claustrophobic canned sardine.                                              "

	sen8 DB "(Part 1): When a dragon consumes a knight:                                    "

	sen9 DB "(Part 2): what is the most annoying part of the procedure?                    "

	sen10 DB "(Part 3): Peeling off the armor after they're cooked.                         "

MyData ENDS


MyCode SEGMENT

	ASSUME CS:MyCode, DS:MyData

;==========================================================================================================================================================;

mainProc PROC

	; general setup

	MOV AX, MyData						; setting up data segment
	MOV DS, AX
	MOV AX, 0B800h						; setting up screen segment
	MOV ES, AX

	MOV AX, 0						; initializing to 0

	MOV totalTicks, AX

	MOV deltaTicks, AX

	MOV prevTicksInitialized, AL

	MOV seconds, AX

	MOV done, AH

	MOV mismatch, AH

	MOV bSenLocation, 160*8+2				; location to print base sentence

	MOV uSenLocation, 160*9+2				; location to print user's sentence

	MOV aCursorZCol, 1					; starting column of cursor

	LEA SI, uSen

	MOV color, 00000111b					; setting up default user sentence color

	MOV uSenPos, SI						; uSenPos contains starting location in uSen

	MOV uSenStartPos, SI					; uSenStartPos contains starting location in uSen

	MOV uSenEndPos, SI					; once getSentenceLength is called this variable is set to the correct value

	MOV uSenLength, SI					; current length of uSen - gets updated in various PROCs

	MOV AX, [SI]

	MOV CX, 78

clear_uSenLoop:							; making sure uSen is cleared
	MOV AL, ' '
	MOV AH, 00000111b
	INC SI
	INC SI
	DEC CX
	CMP CX, 0
	JNE clear_uSenLoop	

	MOV AX, 0
	MOV BX, 0
	MOV CX, 0
	MOV DX, 0
	MOV SI, 0
	MOV DI, 0

								; general setup complete - beginning executions

	CALL clearScreen

	CALL createRandomNumber

	CALL selectSentence

	CALL getSentenceLength

	CALL printBaseSentence

	CALL printCursor

	CALL printTimer		

mainLoop:
	MOV AH, 11h						; check for keyboard input
	INT 16h
	JNZ mainCall_processInput				; if yes, process input

	CMP prevTicksInitialized, 1				; if user has typed a key begin updating timer
	JNE skip_timer

	CALL updateTimer

	CALL printTimer	

skip_timer:
	JMP mainLoop

mainCall_processInput:

	CALL processInput	

	CALL compareSentences

	CALL printUserSentence

	CALL printCursor

	MOV DL, done						; check whether a terminating condition has been met
	CMP DL, 1
	JE end_mainLoop

	JMP mainLoop

end_mainLoop:

	MOV AH, 4Ch						; release memory for the program and return control to DOS
	INT 21h

mainProc ENDP

;==========================================================================================================================================================;

processInput PROC
	; This PROC evaluates the keys hit by the user and calls corresponding PROCs.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI

	MOV AH, 10h						; extract key from buffer
	INT 16h

	CMP AL, ' '						; check whether it is an appropriate key for user sentence
	JL skip_handleKey

	CMP AL, 127
	JGE skip_handleKey

	JMP handleKey

skip_handleKey:
	CMP AH, 4Bh						; left-arrow?
	JE handleLeftArrow

	CMP AH, 4Dh						; right-arrow?
	JE handleRightArrow

	CMP AL, 08h						; backspace?
	JE handleBackspace

	CMP AH, 53h						; delete?
	JE handleDelete

	CMP AL, 1Bh						; esc?
	JE endExecution

	JMP continue						; if no correct key combination is hit, skip

handleKey:
	MOV AH, 0

	MOV char, AX

	CALL storeKey

	JMP continue

handleLeftArrow:
	CALL moveCursorLeft

	JMP continue

handleRightArrow:
	CALL moveCursorRight

	JMP continue

handleBackspace:
	CALL deletePrecedingChar

	JMP continue

handleDelete:
	CALL deleteSucceedingChar

	JMP continue

endExecution:
	CALL terminate

continue:

	POP DI SI DX CX BX AX

RET
processInput ENDP

;==========================================================================================================================================================;

storeKey PROC
	; This PROC stores the keys typed by the user in uSen when appropriate.
	; All register are preserved.

	PUSH AX BX CX DX SI DI

	MOV DI, 0
	ADD DI, uSenPos						; get current position in uSen

	INC DI
	INC DI

	CMP DI, uSenEndPos					; check whether the next position is the end position
	JG skip_storeKey

	DEC DI
	DEC DI

	MOV DI, 0
	ADD DI, uSenEndPos

	CMP DI, uSenLength					; check whether inserting a key would make the sentence too long
	JE skip_storeKey

	MOV DI, 0
	ADD DI, uSenPos

	MOV SI, 0
	ADD SI, uSenLength

	CMP DI, SI
	JE skip_shiftContentsRight				; check whether a shiftContentsRight is necessary

	CALL shiftContentsRight

skip_shiftContentsRight:
	MOV AX, char						; get the char the user typed

	MOV AH, 00000111b					; give it the default color

	MOV [DI], AX						; now contains the character of the key

	INC uSenLength						; advance position and length
	INC uSenLength

	INC uSenPos
	INC uSenPos

	INC aCursorZCol						; advance screen cursor

skip_storeKey:

	MOV AX, 1

	CMP prevTicksInitialized, 1				; getting starting ticks - this also determines when the timer starts counting
	JE skip_initialization

	MOV prevTicksInitialized, AL
	MOV AH, 00h
	INT 1Ah

	MOV prevTicks, DX					; starting tick count acquired

skip_initialization:

	POP DI SI DX CX BX AX

RET
storeKey ENDP

;==========================================================================================================================================================;

moveCursorLeft PROC
	; This PROC simply moves the on screen cursor to the left as well as the virtual cursor.
	; All registers are preserved.

	PUSH AX

	MOV AX, uSenPos

	CMP AX, uSenStartPos					; check whether left most position has been reached
	JE skip_moveCursorLeft

	DEC uSenPos
	DEC uSenPos

	DEC aCursorZCol

skip_moveCursorLeft:

	POP AX

RET
moveCursorLeft ENDP

;==========================================================================================================================================================;

moveCursorRight PROC
	; This PROC simply moves the on screen cursor to the right as well as the virtual cursor.
	; All registers are preserved.

	PUSH AX

	MOV AX, uSenPos

	CMP AX, uSenLength					; check whether cursor is moved to the end of user's typed sentence
	JE skip_moveCursorRight

	CMP AX, uSenEndPos					; check whether the cursor is at the right most position possible
	JE skip_moveCursorRight
	
	INC uSenPos						; if not increase pointers
	INC uSenPos

	INC aCursorZCol

skip_moveCursorRight:

	POP AX

RET
moveCursorRight ENDP

;==========================================================================================================================================================;

printCursor PROC
	; This PROC simply prints the cursor in the desired location determined by aCursorZRow and aCursorZCol.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI

	MOV AH, 02h	

	MOV BH, 0
	MOV DH, aCursorZRow					; cursor row
	MOV DL, aCursorZCol					; cursor column

	INT 10h

	POP DI SI DX CX BX AX

RET
printCursor ENDP

;==========================================================================================================================================================;

deletePrecedingChar PROC
	; This PROC deletes the preceding character in uSen and calls shiftContentsLeft when necessary.
	; All registers are preserved.

	PUSH AX

	MOV AX, uSenPos

	CMP AX, uSenStartPos					; check whether pointer is at left most position
	JE skip_deletePrecedingChar				; if so, skip

	CALL shiftContentsLeft

	DEC uSenPos						; decrement pointers
	DEC uSenPos

	DEC uSenLength
	DEC uSenLength

	DEC aCursorZCol	

skip_deletePrecedingChar:

	POP AX

RET
deletePrecedingChar ENDP

;==========================================================================================================================================================;

deleteSucceedingChar PROC
	; This PROC deletes the succeeding character in uSen and calls shiftContentsLeft when necessary.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI

	MOV SI, 0
	MOV SI, uSenLength

	MOV DI, 0
	ADD DI, uSenPos

	CMP DI, SI						; check whether sentence position is at the end of length
	JE skip_deleteSucceedingChar


	MOV AX, 1
	MOV deleteKeyHit, AL					; set the variable that will initiate additional code for the delete key

	CALL shiftContentsLeft

	MOV AX, 0
	MOV deleteKeyHit, AL

	DEC uSenLength						; decrement pointer
	DEC uSenLength

skip_deleteSucceedingChar:

	POP DI SI DX CX BX AX

RET
deleteSucceedingChar ENDP

;==========================================================================================================================================================;

shiftContentsLeft PROC
	; This PROC is responsible for shifting part of the contents of uSen to the left when delete or backspace is hit.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI

	MOV DI, 0
	ADD DI, uSenPos

	MOV SI, DI
		
	DEC DI
	DEC DI							; at this point: SI = uSenPos | DI = (uSenPos - 2)

	MOV CX, uSenLength					; number of required executions = (length - pos)
	SUB CX, uSenPos

	CMP deleteKeyHit, 1					; check whether the delete key was hit
	JNE shiftLeftLoop

	DEC CX							; if so, decrease the number of executions by 1
	DEC CX

	INC SI							; advance pointers to correct positioning for delete
	INC SI

	INC DI
	INC DI

shiftLeftLoop:
	MOV AX, DS:[SI]						; copy a character over
	MOV DS:[DI], AX
	INC SI							; increment pointers
	INC SI
	INC DI
	INC DI
	DEC CX							; decrement counter
	DEC CX
	CMP CX, 0						; all characters shifted?
	JG shiftLeftLoop					; if not, repeat

	MOV SI, 0
	ADD SI, uSenLength

	DEC SI
	DEC SI

	MOV AX, ' '						; replace the last character in the now shifted user sentence with a space
	MOV DS:[SI], AX						; to complete shifting process

	POP DI SI DX CX BX AX

RET
shiftContentsLeft ENDP

;==========================================================================================================================================================;

shiftContentsRight PROC
	; This PROC is responsible for shifting part of the contents of uSen to the right when a key is inserted into the middle of uSen
	; All registers are preserved.

	PUSH AX BX CX DX SI DI

	MOV DI, 0
	ADD DI, uSenLength

	MOV SI, DI

	INC DI
	INC DI							; at this point: SI = length | DI = (length + 2)

	MOV SI, 0
	ADD SI, uSenLength

	MOV CX, uSenLength					; number of required executions = (length - position) + 1
	SUB CX, uSenPos						; the +1 is taken care of later

shiftRightLoop:							; at this point: SI = length | DI = (length + 2)
	MOV AX, DS:[SI]						; copy a character over
	MOV DS:[DI], AX
	DEC SI							; decrement pointers
	DEC SI
	DEC DI
	DEC DI
	DEC CX							; decrement counter
	DEC CX
	CMP CX, 0						; check whether shift is complete
	JGE shiftRightLoop					; must be JGE because it would perform one less swap than required
								; (since length + 2 must be overridden with length)	

	POP DI SI DX CX BX AX

RET
shiftContentsRight ENDP

;==========================================================================================================================================================;

compareSentences PROC
	; This PROC is responsible for comparing the user sentence to the base sentence.
	; It sets two flags: one for whether the user has made and error, and one that indicates the user has successfully typed the sentence.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI

	MOV SI, 0
	MOV DI, 0

	ADD SI, bSenStartPos					; get the starting positions of the base and user sentences

	ADD DI, uSenStartPos

	MOV DX, uSenLength
	CMP DX, uSenStartPos					; check whether the user has a character typed to compare
	JE nothingToCompare					; if not, skip comparison

	MOV DX, 0

	MOV CX, uSenLength					; number of executions = (length - start pos) since these are memory addresses.
	SUB CX, uSenStartPos

	MOV DL, 1

	MOV AX, 0
	MOV BX, 0

compareSentencesLoop:
	MOV BX, DS:[DI]
	MOV BH, 0

	CMP BL, DS:[SI]						; compare two characters
	JE skip_set_mismatch					; if equal, skip

	CMP prevTicksInitialized, DL				; check whether the user has even typed a letter
	JNE skip_set_mismatch

	MOV mismatch, DL					; otherwise set flag to 1
	MOV color, 00000100b					; change color
	JMP end_compareSentencesLoop				; if mismatch detected, can immediately jump to end
	
skip_set_mismatch:
	INC SI							; increment pointers
	INC DI
	INC DI
	DEC CX							; decrement counter
	DEC CX
	CMP CX, 0						; comparison complete?
	JNE compareSentencesLoop

nothingToCompare:

	MOV DL, 0						; if no mismatch detected, set mismatch to 0
	MOV mismatch, DL
	MOV color, 00000111b					; set default color

end_compareSentencesLoop:

	CMP DI, uSenEndPos					; has the user reached the end of the sentence?
	JNE skip_terminate

	MOV DL, 0
	CMP mismatch, DL					; has the user made any typing errors?
	JNE skip_terminate

	MOV DL, 1						; if neither is the case, set done to 1
	MOV done, DL

skip_terminate:

	POP DI SI DX CX BX AX

RET
compareSentences ENDP

;==========================================================================================================================================================;

updateTimer PROC
	; This PROC is responsible for updating the timer accumulator correctly.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI
	
	MOV AH, 00h
	INT 1Ah

	MOV currentTicks, DX					; current system ticks

	MOV BX, DX						; temporarily store the current tick count in BX

	MOV DX, prevTicks					; DX now contains previous system ticks

	MOV prevTicks, BX					; update prevTicks

	SUB currentTicks, DX					; (current - prev) = difference

	MOV DX, currentTicks					; move difference to DX

	MOV deltaTicks, DX					; deltaTicks contains the difference between currentTicks and prevTicks

	MOV AL, mismatch
	CMP AL, 1
	JNE skip_doubleRate

	ADD deltaTicks, DX					; double it if user screwed up

skip_doubleRate:

	MOV DX, deltaTicks					; move the possibly-doubled value back into DX

	ADD totalTicks, DX					; totalTicks now hold the number to be convert into seconds

	CALL convertTicksToSeconds

	POP DI SI DX CX BX AX

RET
updateTimer ENDP

;==========================================================================================================================================================;

convertTicksToSeconds PROC
	; This PROC converts the contents of "totalTicks" into seconds.
	; All registers are preserved.

	PUSH AX BX DX

	MOV AX, totalTicks					; current tick count

	MOV BX, 55						; multiplier

	MUL BX							; result in DX:AX

	MOV BX, 100						; divisor

	DIV BX							; DX contains the remainder, AX contains the quotient

	MOV seconds, AX						; seconds contains the quotient

	POP DX BX AX

RET
convertTicksToSeconds ENDP

;==========================================================================================================================================================;

printTimer PROC
	; This PROC prints the value in seconds at location DI by calling the appropriate PROCs.	
	; All registers are preserved.

	PUSH AX DI

	MOV AX, seconds

	CALL timer_intToNumeral

	MOV DI, 3*160+140					; location to print timer

	CALL timer_printNumber

	POP DI AX

RET
printTimer ENDP

;==========================================================================================================================================================;

timer_intToNumeral PROC
	; This PROC converts a number into a printable form and stores it in numString.
	; All registers are preserved.

	; assumes: 
	; 	AX contains the int to be converted to numeral
	; alters:
	; 	numString will contain converted scan code

	PUSH AX BX CX DX SI DI	

	MOV BX, 10						; divisor
	
	MOV CX, 10						; set counter to ten since the numString is of size ten

	LEA SI, numString					; set SI to starting position in numString

	MOV DX, 0						; clear DX

timer_clear_intString:						; clear numString
	MOV [SI], DL
	INC SI
	DEC CX
	CMP CX, 0						; clear?
	JE timer_pIntConvertLoop				; if so, jump
	JMP timer_clear_intString				; otherwise, continue

timer_pIntConvertLoop:
	LEA SI, numString					; reset SI to starting position of numString
	INC SI
	MOV DS:[SI], BYTE PTR '.'				; place a period in the appropriate spot
	DEC SI

timer_intConvertLoop:	
	CMP DS:[SI], BYTE PTR '.'				; check whether the period would get overridden
	JE skip_execution					; if so, skip that character

	MOV DX, 0						; clear DX
	DIV BX							; DX contains remainder
								; AX contains quotient
	ADD DL, '0'						; DL contains converted number

	MOV [SI], DL						; place converted number into numString

skip_execution:	
	INC SI							; advance position
	
	CMP AX, 0						; conversion complete?
	JA timer_intConvertLoop					; if not, repeat

	POP DI SI DX CX BX AX

RET
timer_intToNumeral ENDP

;==========================================================================================================================================================;

timer_printNumber PROC
	; This PROC is used to print the contents of numString.
	; It WILL alter DI.
	; All other registers are preserved.

	PUSH AX BX CX DX SI DI

	LEA SI, numString					; attain starting location in numString

	MOV CX, 10						; set counter		

	MOV AH, 00010111b					; set color

timer_printNumberLoop:
	
	MOV AL, DS:[SI]						; place character into AL

	MOV ES:[DI], AX						; place onto screen

	INC SI							; acquire next character
	DEC DI							; move to next screen position
	DEC DI

	DEC CX
	CMP CX, 0						; printing done?
	JE timer_endPrintNumberLoop				; if so, jump
	JMP timer_printNumberLoop				; otherwise, continue

timer_endPrintNumberLoop:

	POP DI SI DX CX BX AX

RET
timer_printNumber ENDP

;==========================================================================================================================================================;

printUserSentence PROC
	; This PROC is responsible for printing the user's sentence.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI

	MOV SI, 0
	MOV DI, 0

	LEA SI, uSen						; get starting location in uSen

	ADD DI, uSenLocation					; get location to print uSen

	MOV CX, 78

printUserSentenceLoop:
	MOV DX, [SI]						; print character
	MOV DH, color						; print color
	MOV ES:[DI], DX
	INC SI							; increment pointers
	INC SI
	INC DI
	INC DI
	DEC CX							; decrement counter
	CMP CX, 0						; printing done?
	JNE printUserSentenceLoop				; if not, repeat

	POP DI SI DX CX BX AX

RET
printUserSentence ENDP

;==========================================================================================================================================================;

terminate PROC
	; This PROC simply terminates the program by setting the appropriate variable.
	; It is called when the ESC key is pressed.
	; All registers are preserved.

	PUSH AX

	MOV AL, 1
	MOV done, AL

	POP AX

RET
terminate ENDP

;==========================================================================================================================================================;

createRandomNumber PROC
	; This PROC is responsible for creating the random number that is used to select one of 10 random sentences.
	; All registers are preserved.

	PUSH AX BX CX DX

	MOV AX, 0						; set everything to zero

	MOV BX, 0

	MOV CX, 0

	MOV DX, 0

	MOV AH, 00h						; get the system ticks
	INT 1Ah	

	MOV AX, DX

	MOV DX, 0

	MOV AH, 0						; preserve only the lower byte from DX in AH

	MOV BX, 10

	DIV BX							; divide by 10

	MOV randomNum, DX					; random number (0 to 9) is placed in randomNum

	POP DX CX BX AX

RET
createRandomNumber ENDP

;==========================================================================================================================================================;

selectSentence PROC
	; This PROC is responsible for selecting a random sentence by utilizing randomNum.
	; All registers are preserved.

	PUSH AX BX DX SI

	MOV BX, randomNum					; get the random number

	LEA SI, sen1						; acquire the address of the first sentence

	MOV AX, 78						; move the length of the sentences into AX

	MUL BX							; multiply the length by the random number

	ADD bSenPos, SI						; get the address of the first sentence in the base sentence position

	ADD bSenPos, AX						; add the result to the base sentence position to shift to the random sentence

	POP SI DX BX AX

RET
selectSentence ENDP

;==========================================================================================================================================================;

printBaseSentence PROC
	; This PROC is responsible for printing the randomly selected sentence.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI

	MOV SI, 0
	MOV DI, 0

	ADD SI, bSenPos						; get the base sentence position

	MOV bSenStartPos, 0
	ADD bSenStartPos, SI					; getting the starting position of the base sentence for future use

	ADD DI, bSenLocation					; get the screen location to print the sentence

	MOV CX, bSenLength					; set the counter to the length of the sentence.

printBaseSentenceLoop:
	MOV DL, [SI]						; place one character
	MOV DH, 00000010b					; place corresponding color
	MOV ES:[DI], DX
	INC SI							; increment pointers
	INC DI
	INC DI
	DEC CX							; decrement counter
	CMP CX, 0						; printing complete?
	JNE printBaseSentenceLoop				; if not, repeat

	POP DI SI DX CX BX AX

RET
printBaseSentence ENDP

;==========================================================================================================================================================;

getSentenceLength PROC
	; This PROC is responsible for setting the values of several length variables.
	; The reasoning is that a string of spaces going from the last position to the first non-space char in the base sentence is
	; filler and should not be typed by the user.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI
	
	MOV SI, 0
	ADD SI, bSenPos						; get base sentence position
	ADD SI, 77						; get last position in base sentence

	MOV BX, 78						; set the counter to the max number of positions in a sentence

	MOV AL, ' '						; get the character to compare to
	MOV AH, 0

senLengthLoop:
	CMP [SI], AL						; is it a space?
	JNE end_senLengthLoop					; if not, jump to end
	DEC SI
	DEC BX							; otherwise decrease length representation
	CMP BX, 0						; compare length representation to 0 since length cannot be less than 0
	JE end_senLengthLoop					; if equal, end
	JMP senLengthLoop					; otherwise, repeat

end_senLengthLoop:
	MOV bSenLength, BX					; set the base sentence length

	ADD uSenEndPos, BX					; add the appropriate offset to users sentence to get the end position
	ADD uSenEndPos, BX					; must be added twice since user sentence is in WORDs

	POP DI SI DX CX BX AX

RET
getSentenceLength ENDP

;==========================================================================================================================================================;

clearScreen PROC
	; This PROC prints clears the screen.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI

	CLD							; clear direction flag
	MOV CX, 2000						; set counter
	MOV DI, 0						; clear DI
	MOV AL, ' '						; move the space char into AX
	MOV AH, 00000111b					; set the color

clearScreenLoop:	
	MOV ES:[DI], AX						; clear the screen
	INC DI
	INC DI
	DEC CX
	CMP CX, 0						; screen reset?
	JE end_clearScreenLoop					; if yes, done
	JMP clearScreenLoop					; otherwise, continue

end_clearScreenLoop:

	POP DI SI DX CX BX AX

RET
clearScreen ENDP

;==========================================================================================================================================================;

intToNumeral PROC
	; This PROC converts a number into a printable form and stores it in numString.
	; All registers are preserved.
	; This PROC is NOT part of the assignment.

	PUSH AX BX CX DX SI DI

	; assumes: 
	; 	AH contains the int to be converted to numeral
	; alters:
	; 	intString will contain converted scan code

	;MOV AL, AH					; move the character into AL for conversion

	;MOV AH, 0					; clear AH

	MOV BX, 10					; divisor
	
	MOV CX, 10					; set counter to ten since the numString is of size ten

	LEA SI, numString				; set SI to starting position in numString

	MOV DX, 0					; clear DX

clear_intString:					; clear numString
	MOV [SI], DL
	INC SI
	DEC CX
	CMP CX, 0					; clear?
	JE pIntConvertLoop				; if so, jump
	JMP clear_intString				; otherwise, continue

pIntConvertLoop:
	LEA SI, numString				; reset SI to starting position of numString

intConvertLoop:	
	MOV DX, 0					; clear DX
	DIV BX						; DX contains remainder
							; AX contains quotient
	ADD DL, '0'					; DL contains converted number

	MOV [SI], DL					; place converted number into numString
		
	INC SI						; advance position
	
	CMP AX, 0					; conversion complete?
	JA intConvertLoop				; if not, repeat

	POP DI SI DX CX BX AX

RET
IntToNumeral ENDP

;==========================================================================================================================================================;

printNumber PROC
	; This PROC is used to print the contents of numString.
	; It WILL alter DI.
	; All other registers are preserved.
	; This PROC is NOT part of the assignment.

	PUSH AX BX CX DX SI DI

	LEA SI, numString				; attain starting location in numString

	MOV CX, 10					

	MOV AH, 00100100b				; set color

printNumberLoop:
	
	MOV AL, DS:[SI]					; place character into AL

	MOV ES:[DI], AX					; place onto screen

	INC SI						; acquire next character
	DEC DI						; move to next screen position
	DEC DI

	DEC CX
	CMP CX, 0					; printing done?
	JE endPrintNumberLoop				; if so, jump
	JMP printNumberLoop				; otherwise, continue

endPrintNumberLoop:

	POP DI SI DX CX BX AX

RET
printNumber ENDP

;==========================================================================================================================================================;

MyCode ENDS

END mainProc