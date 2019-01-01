MyStack SEGMENT STACK

	DW 4096 DUP(?)

MyStack ENDS


MyData SEGMENT

	tLeft DW (?)					; tLeft = 218
	tRight DW (?)					; tRight = 191
	hWall DW (?)					; hWall = 196
	vWall DW (?)					; vWall = 179
	bLeft DW (?)					; bLeft = 192
	bRight DW (?)					; bRight = 217
	
	done DB (?)					; this is the terminating condition

	previousAlt DB (?)				; used to represent the state of the left-alt key

	startingChar DW (?)				; stores the original char - the basis for all conversions

	boxColor DB (?)					; stores the current color of the box

	numString DB 10 DUP (?)				; contains the strings that are printed into the box

	bWidth EQU 11					; width of the box is 11 rows 
	bHeight DW (?)					; used to contain height in terms of number of rows
	bRows DW (?)					; used to contain rows in terms of 160
	bLocation DW (?)				; used to contain the upper left corner of the box
	screenContent DW 2000 DUP (?)			; used to backup the screen

MyData ENDS


MyCode SEGMENT

	ASSUME CS:MyCode, DS:MyData

;==========================================================================================================================================================;

mainProc PROC
	; This PROC is responsible for general setup and for the primary loop that runs the program.
	
	MOV AX, MyData					; setting up data segment
	MOV DS, AX

	MOV AX, 0B800h					; setting up screen
	MOV ES, AX
	
	MOV AX, 6*160+2*30				; setting up starting location
	LEA SI, bLocation
	MOV [SI], AX

	MOV AX, 8					; setting up the number of initial rows between top and bottom
	LEA SI, bHeight
	MOV [SI], AX

	MOV AX, 8*160					; setting up the precise screen location for number of rows (makes code elsewhere easier)
	LEA SI, bRows
	MOV [SI], AX

	MOV AH, boxColor				; setting up the starting char and corresponding color
	MOV AL, 128
	LEA SI, startingChar
	MOV [SI], AX

	MOV AL, 0					; making sure done (the ending condition) is equal to 0
	LEA SI, done
	MOV [SI], AL

	MOV AL, 0					; setting up the variable that will stop strobe light color change
	LEA SI, previousAlt
	MOV [SI], AL

	MOV AL, 00010111b				; setting up the color variable (starts as blue on white)
	LEA SI, boxColor
	MOV [SI], AL
	
	MOV AX, 0001011111011010b			; setting up the characters used for the box
	LEA SI, tLeft
	MOV [SI], AX

	MOV AX, 0001011110111111b
	LEA SI, tRight
	MOV [SI], AX

	MOV AX, 0001011111000100b
	LEA SI, hWall
	MOV [SI], AX

	MOV AX, 0001011110110011b
	LEA SI, vWall
	MOV [SI], AX

	MOV AX, 0001011111000000b
	LEA SI, bLeft
	MOV [SI], AX

	MOV AX, 0001011111011001b
	LEA SI, bRight
	MOV [SI], AX
	
	MOV AX, 0					; clearing registers and indexes
	MOV BX, 0
	MOV CX, 0
	MOV DX, 0
	MOV SI, 0
	MOV DI, 0

							; general setup complete - beginning primary program loop

	CALL saveScreen

	CALL drawBox

	CALL fillBox

	CALL setBoxColor

mainLoop:
	MOV AH, 12h					; left-alt down?
	INT 16h
	TEST AX, 0000001000000000b			
	JNZ mainCall_changeBoxColor			; if yes, change color

	JMP mainContinue

mainCall_changeBoxColor:

	LEA SI, previousAlt				; get previousAlt state
	MOV BL, [SI]
	MOV AL, 1

	CMP AL, BL					; compare to check if alt is still down
	JE evaluateAlt

	CALL changeBoxColor

	CALL drawScreen

	CALL drawBox

	CALL fillBox

	CALL setBoxColor

evaluateAlt:
	MOV AH, 12h					; left-alt up?
	INT 16h
	TEST AX, 0000001000000000b	
	JNZ evaluateAlt					; if not, keep looping
	JMP altUp					; otherwise, set previousAlt to 0, as in up

mainContinue:
	MOV AH, 11h					; check for keyboard input
	INT 16h
	JNZ mainCall_processInput			; if yes, process input

	JMP mainLoop

mainCall_processInput:
	CALL processInput

	LEA SI, DONE					; check whether ending condition is met
	MOV AL, [SI]
	CMP AL, 1
	JE finishIt					; if yes, terminate

	CALL drawScreen

	CALL drawBox

	CALL fillBox

	CALL setBoxColor

	JMP mainLoop

altUp:
	LEA SI, previousAlt				; set current state of alt to 0, as in up
	MOV AL, 0
	MOV [SI], AL
	JMP mainLoop					; continue loop

finishIt:
	MOV	AH, 4Ch					; release memory for the program and return control to DOS
	INT	21h

mainProc ENDP

;==========================================================================================================================================================;

clarity PROC
	; This PROC just prints garbage on to the left most column and top most row - used this to count things easier.
	; All registers are preserved.
	; This PROC is NOT part of the assignment.

	PUSH AX BX CX DX SI DI

	MOV DI, 0
	MOV AX, WORD PTR 0200h + 'A'

vClarityLoop:
	MOV ES:[DI], AX
	ADD AX, 1
	ADD DI, 160
	CMP DI, 4000
	JNE vClarityLoop
	JMP resetClarity

resetClarity:
	MOV AX, WORD PTR 0200h + 'A'
	MOV DI, 0

hClarityLoop:
	MOV ES:[DI], AX
	ADD AX, 1
	INC DI
	INC DI
	CMP DI, 160
	JNE hClarityLoop

	POP DI SI DX CX BX AX

RET
clarity ENDP

;==========================================================================================================================================================;

saveScreen PROC
	; This PROC saves what is currently printed on the screen.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI

	CLD						; clear direction flag
	MOV CX, 2000					; fill counter
	LEA DI, screenContent				; attain starting position in screenContent
	MOV SI, 0					; clear SI

saveScreenLoop:
	MOV AX, ES:[SI]					; store char in AX
	MOV [DI], AX					; store AX in screenContent
	INC SI						; advance pointers
	INC SI
	INC DI
	INC DI
	DEC CX
	CMP CX, 0					; screen content saved?
	JE saveScreenDone				; if yes, done
	JMP saveScreenLoop				; otherwise, continue

saveScreenDone:
	
	POP SI DI DX CX BX AX

RET
saveScreen ENDP

;==========================================================================================================================================================;

drawScreen PROC
	; This PROC prints what was store by saveScreen.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI

	CLD						; clear direction flag
	MOV CX, 2000					; set counter
	LEA SI, screenContent				; set pointer to starting position in screenContent
	MOV DI, 0					; clear DI

drawScreenLoop:	
	LODSW						; store content from screenContent in AX
	STOSW						; place content in AX onto screen
	DEC CX
	CMP CX, 0					; screen reset?
	JE drawScreenLoopDone				; if yes, done
	JMP drawScreenLoop				; otherwise, continue

drawScreenLoopDone:

	POP DI SI DX CX BX AX				; SI AND DI WERE IN THE WRONG ORDER BEFORE!!!

RET
drawScreen ENDP

;==========================================================================================================================================================;

processInput PROC
	; This PROC evaluates the keys hit by the user and calls corresponding PROCs.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI

	LEA SI, previousAlt				; since a different key is being processed, alt MUST be up 
	MOV AL, 0					; does NOT work
	MOV [SI], AL

	MOV AH, 10h					; extract key from buffer
	INT 16h

evaluateInputLoop:
	CMP AH, 48h					; up-arrow?
	JE scrollUp

	CMP AH, 50h					; down-arrow?
	JE scrollDown

	CMP AL, 'w'
	JE moveUp

	CMP AL, 'a'
	JE moveLeft

	CMP AL, 's'
	JE moveDown

	CMP AL, 'd'
	JE moveRight

	CMP AH, 8Dh					; ctrl + up-arrow?
	JE expand

	CMP AH, 91h					; ctrl + down-arrow?
	JE contract

	CMP AL, 1Bh					; esc?
	JE terminate

	JMP continue					; if no correct key combination is hit, skip

scrollUp:						; calling corresponding PROCs
	CALL boxScrollUp

	JMP continue	

scrollDown:
	CALL boxScrollDown

	JMP continue

moveUp:
	CALL boxMoveUp

	JMP continue

moveLeft:
	CALL boxMoveLeft

	JMP continue

moveDown:
	CALL boxMoveDown

	JMP continue

moveRight:
	CALL boxMoveRight

	JMP continue

expand:
	CALL boxExpand

	JMP continue

contract:
	CALL boxContract

	JMP continue

terminate:
	CALL boxTerminate

continue:

	POP DI SI DX CX BX AX

RET
processInput ENDP

;==========================================================================================================================================================;

boxScrollUp PROC

	PUSH AX BX CX DX SI DI

	MOV AX, 0					; clear AX
	LEA SI, startingChar				; get startingChar
	MOV AX, [SI]					; store in AX
	DEC AX						; decrement the char
	MOV AH, 0					; clear higher byte to prevent accidental changes to AH
	MOV [SI], AX					; store new value in startingChar

	POP DI SI DX CX BX AX

RET
boxScrollUp ENDP

;==========================================================================================================================================================;

boxScrollDown PROC

	PUSH AX BX CX DX SI DI

	MOV AX, 0					; clear AX
	LEA SI, startingChar				; get startingChar
	MOV AX, [SI]					; store in AX
	INC AX						; increment the char
	MOV AH, 0					; clear higher byte to prevent accidental changes to AH
	MOV [SI], AX					; store new value in startingChar

	POP DI SI DX CX BX AX

RET
boxScrollDown ENDP

;==========================================================================================================================================================;

boxMoveUp PROC

	PUSH AX BX CX DX SI DI

	LEA SI, bLocation				; get upper left corner of box
	MOV AX, [SI]					; store in AX
	CMP AX, 160					; room to move up?
	JL skipMoveUp					; if no, jump
	SUB AX, 160					; otherwise, move up
	MOV [SI], AX

skipMoveUp:

	POP DI SI DX CX BX AX

RET
boxMoveUp ENDP

;==========================================================================================================================================================;

boxMoveLeft PROC

	PUSH AX BX CX DX SI DI

	LEA SI, bLocation				; get upper left corner of box
	MOV AX, [SI]					; AX contains bLocation
	MOV BX, 160					; divisor
	DIV BX						; AX has quotient
	MOV DX, 0					; clear remainder
	MOV BX, 160					; multiplier
	MUL BX						; AX has n*160 (so the number of rows)
	MOV BX, [SI]					; BX contains bLocation
	CMP BX, AX					; bLocation at leftmost column?
	JE skipMoveLeft					; if so no room to move left, so skip
	SUB BX, 2					; if not, move to left
	MOV [SI], BX

skipMoveLeft:

	POP DI SI DX CX BX AX

RET
boxMoveLeft ENDP

;==========================================================================================================================================================;

boxMoveDown PROC

	PUSH AX BX CX DX SI DI

	LEA SI, bLocation				; get upper left corner location
	MOV AX, [SI]					; store in AX
	ADD AX, bRows					; add the number of rows in the middle
	ADD AX, 160					; adding the bottom row (border in this case)
	CMP AX, 23*160+158				; room to move down?
	JG skipMoveDown					; if not, jump
	SUB AX, bRows					; otherwise, move down
	MOV [SI], AX

skipMoveDown:

	POP DI SI DX CX BX AX

RET
boxMoveDown ENDP

;==========================================================================================================================================================;

boxMoveRight PROC

	PUSH AX BX CX DX SI DI

	LEA SI, bLocation				; get upper left corner of box
	MOV AX, [SI]					; AX contains bLocation
	MOV BX, 160					; divisor
	DIV BX						; AX has quotient
	MOV DX, 0					; clear remainder
	MOV BX, 160					; multiplier
	MUL BX						; AX has n*160 (so the number of rows)
	ADD AX, 158					; points AX to the right most column in the row
	MOV BX, [SI]					; BX contains bLocation
	ADD BX, 24					; BX contains location of the right most column in the box (11 columns + border column)
	CMP BX, AX					; BX at right most column?
	JE skipMoveRight				; if so, skip
	SUB BX, 24					; remove shift
	ADD BX, 2					; if not, move to right
	MOV [SI], BX

skipMoveRight:

	POP DI SI DX CX BX AX

RET
boxMoveRight ENDP

;==========================================================================================================================================================;

boxExpand PROC

	PUSH AX BX CX DX SI DI

	LEA SI, bLocation				; get upper left corner of box
	MOV AX, [SI]					; store in AX
	ADD AX, bRows					; at the number of rows
	ADD AX, 160					; adding the bottom row (border in this case) onto the rows in the middle
	CMP AX, 23*160+158				; is there room to expand down?
	JG skipExpandDown				; if not, skip

	LEA SI, bHeight					; otherwise, get number of rows
	MOV AX, [SI]					; store in AX
	ADD AX, 1					; add 1 to AX because lower border row
	MOV [SI], AX					; store back in variable

	LEA SI, bRows					; get number of rows in terms of 160
	MOV AX, [SI]					; store in AX
	ADD AX, 160					; add 160 to AX because lower border row
	MOV [SI], AX					; store back in variable

	JMP skipExpandUp

skipExpandDown:
	MOV AX, [SI]					; reset AX to upper left corner of box
	CMP AX, 160					; room to expand up?
	JL skipExpandUp					; if not, skip

	CALL boxMoveUp					; otherwise, expand up

	CALL boxExpand
	

skipExpandUp:

	POP DI SI DX CX BX AX

RET
boxExpand ENDP

;==========================================================================================================================================================;

boxContract PROC


	PUSH AX BX CX DX SI DI

	LEA SI, bHeight					; get number of rows
	MOV AX, [SI]					; store in AX
	CMP AX, 5					; less than 4 rows?
	JL skipContract					; if so, skip
	SUB AX, 1					; otherwise, reduce AX by 1
	MOV [SI], AX					; store back in variable

	LEA SI, bRows					; get number of rows in terms of 160
	MOV AX, [SI]					; store in AX
	SUB AX, 160					; reduce by 160
	MOV [SI], AX					; store back in variable

skipContract:

	POP DI SI DX CX BX AX

RET
boxContract ENDP

;==========================================================================================================================================================;

boxTerminate PROC

	PUSH AX BX CX DX SI DI

	MOV AL, 1					; acquire terminating condition
	LEA SI, done					; set SI to terminating variable
	MOV [SI], AL					; store terminating condition in variable

	POP DI SI DX CX BX AX

RET
boxTerminate ENDP

;==========================================================================================================================================================;

printScanCode PROC
	; Takes user input and prints scan code.
	; After calling intToNumeral, numString contains the converted scan code, which is then placed onto the screen at 160*20+40.
	; This PROC is NOT part of the assignment.

	PUSH AX BX CX DX SI DI

noKeyReady:						; waiting for input
	MOV AH, 11h
	INT 16h
	JZ noKeyReady

	MOV AH, 10h
	INT 16h
	
	CALL intToNumeral				; call conversion PROC

	MOV DI, 160*20+40				; location to print number

	LEA SI, numString				; set SI to storing variable

	MOV CX, 10					

	MOV AH, 00100100b				; set color

printScanCodeLoop:					; printing loop
	
	MOV AL, DS:[SI]

	MOV ES:[DI], AX

	INC SI
	DEC DI
	DEC DI

	DEC CX
	CMP CX, 0
	JE endPrintScanCodeLoop
	JMP printScanCodeLoop

endPrintScanCodeLoop:

	POP DI SI DX CX BX AX	

RET
printScanCode ENDP

;==========================================================================================================================================================;

drawBox PROC
	; This PROC is responsible for drawing the box.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI
	
	MOV DI, bLocation				; attain upper left corner of box
	
	MOV AX, tLeft					; store top left character in AX
	MOV ES:[DI], AX					; set into top left corner
	MOV AX, hWall					; acquire horizontal wall character
	MOV CX, bWidth					; acquire box width

topLoop:
	INC DI						; more to next character location
	INC DI
	MOV ES:[DI], AX					; store character in appropriate location
	DEC CX
	CMP CX, 0					; row complete?
	JE tRightCorner					; if so, jump
	JMP topLoop					; otherwise, continue

tRightCorner:
	MOV AX, tRight					; acquire top right character
	INC DI						; advance to next position
	INC DI
	MOV ES:[DI], AX					; place character
	
	MOV AX, vWall					; acquire vertical wall character
	MOV CX, bHeight					; acquire number of rows

rightWallLoop:
	ADD DI, 160					; advance to next position
	MOV ES:[DI], AX					; place character
	DEC CX
	CMP CX, 0					; finished column?
	JE bRightCorner					; if so, jump
	JMP rightWallLoop				; otherwise, continue

bRightCorner:
	MOV AX, bRight					; acquire bottom right character
	ADD DI, 160					; advance to next position
	MOV ES:[DI], AX					; place character
	
	MOV AX, hWall					; acquire horizontal wall character
	MOV CX, bWidth					; acquire width

bottomLoop:
	DEC DI						; decrement to next position
	DEC DI
	MOV ES:[DI], AX					; place character
	DEC CX
	CMP CX, 0					; row done?
	JE bLeftCorner					; if so, jump
	JMP bottomLoop					; otherwise, continue

bLeftCorner:
	MOV AX, bLeft					; acquire bottom left character
	DEC DI						; decrement to next position
	DEC DI
	MOV ES:[DI], AX					; place character
	
	MOV AX, vWall					; acquire vertical wall character
	MOV CX, bHeight					; acquire number of rows

leftWallLoop:
	SUB DI, 160					; substract to next position
	MOV ES:[DI], AX					; set character
	DEC CX
	CMP CX, 0					; column done?
	JE boxDone					; if so, jump
	JMP leftWallLoop				; otherwise, continue
boxDone:
	
	POP DI SI DX CX BX AX

RET
drawBox ENDP

;==========================================================================================================================================================;

fillBox PROC
	; This PROC is responsible for filling the box with the appropriate contents.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI

	MOV AX, bLocation				; attain top left corner of box
	ADD AX, 22					; attain right most printable position
	MOV DI, 0					; clear pointer
	ADD DI, AX					; DI contains right most printable position

	MOV AX, startingChar				; AX contains the startingChar
	MOV AH, boxColor				; set the color

	MOV DX, bHeight					; acquire number of rows
	ADD DX, 1					; increase by one since otherwise not all rows would be filled

	MOV BX, ' '					; fill BX with a space (used to override previous characters)	

fillBoxRowLoop:	
	DEC DX
	CMP DX, 0					; all rows filled?
	JE fillBoxEnd					; if so, jump

	ADD DI, 160					; jump to next row

	MOV ES:[DI], BX					; override any characters that were previous in this spot

	SUB DI, 2					; sub by 2 for aesthetic reasons (equal spacing from right and left border)

	MOV ES:[DI], AX					; place startingChar
	MOV AH, AL					; move character into AH for intToNumeral and hexToNumeral
	MOV AL, 0					; clear AL

	SUB DI, 2					; shift to the left

	MOV ES:[DI], BX					; override any characters that were previously in this spot

	SUB DI, 2					; shift to the left

	MOV ES:[DI], BX					; override any characters that were previously in this spot

	SUB DI, 2					; shift to the left

	CALL intToNumeral				; convert the ASCII number into printable form
	
	CALL printNumber				; print the character

	MOV ES:[DI], BX					; override any characters that were previously in this spot

	SUB DI, 2					; shift to the left

	CALL hexToNumeral				; convert the ASCII number into hex and then into printable form

	CALL printNumber				; print the character
	
	ADD DI, 22					; reset the shift
	MOV AL, AH					; place the character back into AL
	MOV AH, boxColor				; place the color back into AH
	INC AL						; increment the character

	JMP fillBoxRowLoop

fillBoxEnd:

	POP SI DI DX CX BX AX

RET
fillBox ENDP

;==========================================================================================================================================================;

intToNumeral PROC
	; This PROC converts a number into a printable form and stores it in numString.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI

	; assumes: 
	; 	AH contains the int to be converted to numeral
	; alters:
	; 	intString will contain converted scan code

	MOV AL, AH					; move the character into AL for conversion

	MOV AH, 0					; clear AH

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

hexToNumeral PROC
	; This PROC converts a number into hex and then into a printable form and stores it in numString.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI

	; assumes: 
	; 	AH contains the number to be converted to numeral
	; alters:
	; 	numString will contain converted scan code		

	MOV AL, AH					; move the character into AL for conversion

	MOV AH, 0					; clear AH

	MOV BX, 16					; divisor
	
	MOV CX, 10					; set counter to ten since the numString is of size ten

	LEA SI, numString				; set SI to starting position in numString

	MOV DX, 0					; clear DX

clear_hexString:					; clear numString
	MOV [SI], DL
	INC SI
	DEC CX
	CMP CX, 0					; clear?
	JE pHexConvertLoop				; if so, jump
	JMP clear_hexString				; otherwise, continue

pHexConvertLoop:
	LEA SI, numString				;reset SI to starting position of numString
	MOV CX, 2

hexConvertLoop:
	MOV DX, 0					; clear DX			
	DIV BX						; DX contains remainder
							; AX contains quotient
	CMP DL, 10					; DL contains converted number - check whether it is greater or equal to ten
	JGE setHexChar					; if so, jump to hex conversion
	JMP skipSetHexChar				; otherwise, skip

setHexChar:
	ADD DL, 7					; set to correct hex character by adding 7 (what was the good way of doing this??)

skipSetHexChar:	
	ADD DL, '0'					; DL now contains converted number
	
	MOV [SI], DL					; place into numString
	
	INC SI						; advance position
	DEC CX	


	CMP CX, 0					; conversion complete?
	JNE hexConvertLoop				; if not, repeat
	
	POP DI SI DX CX BX AX

RET
hexToNumeral ENDP

;==========================================================================================================================================================;

printNumber PROC
	; This PROC is used to print the contents of numString.
	; It WILL alter DI.
	; All other registers are preserved.

	PUSH AX BX CX DX SI

	LEA SI, numString				; attain starting location in numString

	MOV CX, 3					; since converted numbers are never greater than three digits, print three digits

	MOV AH, boxColor				; set color

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

	POP SI DX CX BX AX

RET
printNumber ENDP

;==========================================================================================================================================================;

setBoxColor PROC
	; This PROC is responsible for changing the color of the box and its contents.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI
	
	MOV DX, bHeight					; attain number of rows
	ADD DX, 3					; add three to cover whole box (acts as counter for loop)
	MOV AX, bLocation				; move position of upper left corner of box into AX
	MOV DI, 0					; clear DI
	ADD DI, AX					; DI has the location of the top left corner of the box
	ADD DI, 1					; DI now points to the color byte of the char in the top left of the box
	MOV AH, boxColor				; set color

colorRowLoop:
	DEC DX
	CMP DX, 0					; coloring done?
	JE endColor					; if so, jump

	MOV CX, 13					; otherwise, set counter to box width + 2 for the sides

colorColumnLoop:
	MOV ES:[DI], AH					; place color on screen
	INC DI						; advance position
	INC DI
	DEC CX
	CMP CX, 0					; row done?
	JE resetColorRowLoop				; if so, jump
	JMP colorColumnLoop				; otherwise, continue

resetColorRowLoop:
	SUB DI, 26					; reset DI to starting position
	ADD DI, 160					; move to next row
	JMP colorRowLoop

endColor:

	POP DI SI DX CX BX AX

RET
setBoxColor ENDP

;==========================================================================================================================================================;

changeBoxColor PROC
	; This proc is responsible for changing the color of the box once for each depression of the alt-key.
	; It relies on validation within mainLoop to correctly change the color.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI

	LEA SI, previousAlt				; set previousAlt state to 1 which means depressed
	MOV AL, 1
	MOV [SI], AL

	LEA SI, boxColor				; switches through colors
	MOV AH, [SI]
	ADD AH, 10h
	AND AH, 01111111b				; gets rid of blinking bit
	MOV [SI], AH

	POP DI SI DX CX BX AX

RET
changeBoxColor ENDP

;==========================================================================================================================================================;

MyCode ENDS

END mainProc