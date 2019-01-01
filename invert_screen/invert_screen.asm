MyStack SEGMENT STACK

	DW 256 DUP(?)

MyStack ENDS


MyData SEGMENT

	msg DB "AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz123456789123456789123456789?", 0

MyData ENDS


MyCode SEGMENT

	ASSUME CS:MyCode, DS:MyData

mainProg PROC
	
	MOV AX, MyData			; setting up data segment
	MOV DS, AX
	MOV AX, 0B800h			; setting up screen
	MOV ES, AX

	LEA SI, msg			; gets position of first character in msg and puts it in SI
	MOV DI, 12*160+0		; sets the pointer DI so that it can refer to the 12th row and column 0
	MOV AH, 01110100b		; sets the color of the text to red on white

displayloop:

	MOV AL, DS:[SI]			; gets the next char of msg
	MOV ES:[DI], AX			; puts the char and color on screen
	INC SI				; sets to next char
	INC DI				; advance screen position
	INC DI
	CMP [SI], BYTE PTR 0		; terminating character found?
	JNE displayloop			; if not then repeat
	
	MOV CX, 40			; since there are 80 chars on in a row and each swap takes care of two, countdown from 40
	MOV SI, 0			; set SI to position of first char
	MOV DI, 158			; set DI to position of opposing char

	PUSH SI DI			; save SI and DI for later use

invertRowLoop:

	MOV AX, ES:[SI]			; get first char
	MOV BX, ES:[DI]			; get opposing char

	CMP AL, 'A'			; test AX for alphabetical letter
	JL testBX
	CMP AL, 'Z'
	JG testAXlower
	JMP changeColorAX

testAXlower:
	CMP AL, 'a'
	JL testBX
	CMP AL, 'z'
	JG testBX	

changeColorAX:				; if AX contains an alphabetical letter: change color to blue on white
	MOV AH, 01110001b

testBX:					; test BX for alphabetical letter
	CMP BL, 'A'
	JL continue
	CMP BL, 'Z'
	JG testBXlower
	JMP changeColorBX

testBXlower:
	CMP BL, 'a'
	JL continue
	CMP BL, 'z'
	JG continue

changeColorBX:				; if BX contains an alphabetical letter: change color to blue on white
	MOV BH, 01110001b

continue:
	MOV ES:[SI], BX			; place opposing char into first char's location				
	MOV ES:[DI], AX			; place first char into opposing char's location

	INC SI				; advance to next position in row with respect to starting position
	INC SI

	DEC DI				; advance to next position in row with respect to end position
	DEC DI

	DEC CX				; decrement counter for the loop
	CMP CX, 0			; check whether the row has been inverted entirely
	JE shiftToNextRow		; condition met
	JMP invertRowLoop		; condition failed

shiftToNextRow:
	POP DI SI			; restore DI and SI to original values: the end and starting positions in the row
	MOV CX, 40			; restore the counter
	ADD SI, 160			; advance to starting position in the next row
	ADD DI, 160			; advance to ending position in the next row
	PUSH SI DI			; backup new SI and DI values
	CMP SI, 4000			; check whether all rows have been inverted
	JNE invertRowLoop		; condition failed: repeat inversion loop
	
	MOV	AH, 4Ch			; release memory for the program and return control to DOS
	INT	21h


mainProg ENDP

MyCode ENDS

END mainProg