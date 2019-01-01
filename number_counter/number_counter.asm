MyStack SEGMENT STACK

	DW 4096 DUP (?)

MyStack ENDS


MyData SEGMENT

	numString DB 10 DUP (?)					; NOT part of the program - used in testing code

	done DB (?)						; terminating condition

	EOF DB (?)						; End Of File

	EOB DB (?)						; End Of Buffer

	inFileName DB 128 DUP (0)				; name of the input file taken from the PSP

	outFileName DB "output.dat", 0				; output file name

	handle DW (?)						; contains the reference number for the current File Control Block

	buffer DB 128 DUP (' ')					; this will contain a block of 128 chars at a time to be processed

	bPtr DW (?)						; used to access a character in buffer

	prev_bPtr DW (?)					; used to account for the scenario where a number is cut in half when the buffer ends

	numBytesRead DW (?)					; number of bytes read by readFile

	numBytesProcessed DW (?)				; number of bytes successfully processed - used by setFilePointer

	counterList DW 10 DUP (0)				; keeps track of how many numbers are in each category

	outBuffer DB 10 DUP (5 DUP (' '), 13, 10)		; this will contain the formatted number of numbers < n*100 to be printed

	errorOpeningFileMsg DB "Error: File could not be opened.$"

	errorReadingFileMsg DB "Error: File could not be read.$"

MyData ENDS


MyCode SEGMENT

	ASSUME CS:MyCode, DS:MyData

;==========================================================================================================================================================;

mainProc PROC

	; general setup

	MOV AX, MyData						; setting up data segment
	MOV DS, AX

	CALL getFileName					; acquiring input file name

	MOV AX, 0B800h						; setting up screen segment
	MOV ES, AX

	MOV AX, 0

	MOV done, AL
	MOV EOF, AL
	MOV EOB, AL

	MOV numBytesProcessed, AX

	MOV AX, 0
	MOV BX, 0
	MOV CX, 0
	MOV DX, 0
	MOV SI, 0
	MOV DI, 0

								; general setup complete - beginning executions

	CALL clearScreen

	CALL setMsgLocation
	
	CALL openFile

	MOV DL, done						; check whether an error was encountered in openFile - terminate if so
	CMP DL, 1
	JE end_main

	CALL processFile

	MOV DL, done						; check whether en error was encountered in readFile - terminate if so
	CMP DL, 1
	JE end_main

	CALL closeFile

	CALL counterListToNumerals

	CALL createFile

	CALL outputToFile

	CALL closeFile

end_main:
	MOV AH, 4Ch						; release memory for the program and return control to DOS
	INT 21h

mainProc ENDP

;==========================================================================================================================================================;

openFile PROC
	; This PROC is responsible for opening the file and printing and error message if an error is encountered.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI

	LEA DX, inFileName					; get file name
	MOV AL, 0
	MOV AH, 3Dh						; open file
	INT 21h
	JC errorOpeningFile					; if error print message and terminate
	MOV handle, AX
	JMP end_openFile

errorOpeningFile:
	LEA DX, errorOpeningFileMsg
	MOV AH, 09h
	INT 21h

	MOV DL, 1						; set terminating condition
	MOV done, DL		

end_openFile:

	POP DI SI DX CX BX AX

RET
openFile ENDP

;==========================================================================================================================================================;

setFilePointer PROC
	; This PROC is responsible for setting the location in the file for the next readFile execution.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI

	MOV AL, 0
	MOV BX, handle						; get file reference number
	MOV CX, 0
	MOV DX, numBytesProcessed				; the value that determines the starting point of the next readFile execution

	MOV AH, 42h
	INT 21h

	POP DI SI DX CX BX AX

RET
setFilePointer ENDP

;==========================================================================================================================================================;

processFile PROC
	; This PROC is responsible for calling the appropriate PROCs to categorize and store the numbers in the file.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI

processFileLoop:
	CALL setFilePointer	

	CALL readFile

	CMP done, 1						; if a read error is encountered, terminate the loop
	JE terminate_processFileLoop

	CMP EOF, 1						; if the End Of File is encountered, terminate the loop
	JE terminate_processFileLoop

	CALL evaluateBuffer					; otherwise, evaluate the current buffer contents

	JMP processFileLoop

terminate_processFileLoop:

	POP DI SI DX CX BX AX

RET
processFile ENDP

;==========================================================================================================================================================;

readFile PROC
	; This PROC is responsible for reading the file contents and determining whether the End Of File has been attained.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI

	MOV BX, handle						; acquire file reference number
	MOV CX, 128						; number of bytes to be read
	LEA DX, buffer						; where the read content is stored - processed later
	MOV AH, 3Fh						; read file
	INT 21h
	JC errorReadingFile					; if read error, print message and terminate
	MOV bPtr, 0						; reset the buffer pointer
	MOV numBytesRead, AX					; acquire the number of bytes read
	ADD numBytesProcessed, AX				; accumulate the total number of successfully read bytes
	CMP numBytesRead, 0					; if numBytesRead = 0, then the End Of File has been reached
	JNE end_readFile

	MOV AL, 1						; set End Of File if it has been reached
	MOV EOF, AL
	JMP end_readFile

errorReadingFile:
	LEA DX, errorReadingFileMsg
	MOV AH, 09h
	INT 21h

	MOV DL, 1						; set terminating condition
	MOV done, DL

end_readFile:

	POP DI SI DX CX BX AX

RET
readFile ENDP

;==========================================================================================================================================================;

setMsgLocation PROC
	; This PROC sets the location of the error messages.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI

	MOV BH, 0
	MOV DH, 3						; cursor row
	MOV DL, 0						; cursor column

	MOV AH, 02h	
	INT 10h

	POP DI SI DX CX BX AX

RET
setMsgLocation ENDP

;==========================================================================================================================================================;

printBufferV2 PROC
	; This PROC is TESTING CODE.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI

	LEA SI, buffer
	MOV CX, numBytesRead

printBufferV2Loop:
	MOV AL, [SI]
	MOV AH, 00000111b
	MOV ES:[DI], AX
	INC SI
	INC DI
	INC DI
	DEC CX
	CMP CX, 0
	JNE printBufferV2Loop
	

	POP DI SI DX CX BX AX

RET
printBufferV2 ENDP

;==========================================================================================================================================================;

evaluateBuffer PROC
	; This PROC is responsible for correctly evaluating the contents of the buffer by calling the appropriate PROCs.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI

	MOV AX, 0						; clear AX

	MOV EOB, AL						; clear End Of Buffer

	LEA SI, buffer						; acquire starting location in buffer

	MOV CL, [SI]

evaluateBufferLoop:						; begin evaluating
	CALL skipWhiteSpace

	CMP EOB, 1						; if End Of Buffer = 1, skip to end
	JE skipToEnd

	CALL getNextNumeral

	CMP EOF, 1						; if End Of File = 1, categorize the last number and terminate
	JE skipToCategorize

	CMP EOB, 1						; if End Of Buffer = 1, skip to end
	JE skipToEnd

skipToCategorize:
	CALL categorize

skipToEnd:
	CMP EOF, 1						; if EOF = 1, terminate loop
	JE end_evaluateBufferLoop

	CMP EOB, 1						; if EOB != 1, continue looping
	JNE evaluateBufferLoop

end_evaluateBufferLoop:

	POP DI SI DX CX BX AX

RET
evaluateBuffer ENDP

;==========================================================================================================================================================;

skipWhiteSpace PROC
	; This PROC is responsible for skipping all non-digit characters until the first instance of a digit.
	; CL contains the current character from the buffer to be compared - it is set by getNextByte.
	; All other registers are preserved.

	PUSH BX DX SI DI

skipWhiteSpaceLoop:
	CMP EOB, 1						; if End Of Buffer reached, terminate loop
	JE end_skipWhiteSpaceLoop
	CMP CL, '0'						; if character is not a digit, skip it and get next digit
	JL p_skipWhiteSpaceLoop
	CMP CL, '9'
	JG p_skipWhiteSpaceLoop
	JMP end_skipWhiteSpaceLoop

p_skipWhiteSpaceLoop:
	CALL getNextByte					; acquiring next digit
	JMP skipWhiteSpaceLoop

end_skipWhiteSpaceLoop:

	MOV AX, 0

	POP DI SI DX BX

RET
skipWhiteSpace ENDP

;==========================================================================================================================================================;

getNextNumeral PROC
	; This PROC is responsible for storing and converting consecutive digits.
	; CL is used to get the next character from the current buffer.
	; Upon exit, AX contains the converted digit to be catagorized.
	; All other registers are preserved.

	PUSH BX DX SI DI

	MOV AX, bPtr						; acquire the location of the first instance of a digit
	MOV prev_bPtr, AX					; store it for the scenario where a number is cut in half

	MOV AX, 0						; clear AX (the accumulator)
	MOV BX, 10						; set the multiplier

convertNumeralLoop:
	MUL BX							; begin conversion
	SUB CL, '0'
	MOV CH, 0
	ADD AX, CX						; AX contains the integer
	
	CALL getNextByte					; acquire the next byte

	CMP EOB, 1						; check whether the End Of Buffer has been reached
	JE p_endGetNextNumeral
	CMP CL, '0'						; check whether the character is a digit - if not terminate the loop
	JL endGetNextNumeral
	CMP CL, '9'
	JG endGetNextNumeral

	JMP convertNumeralLoop

p_endGetNextNumeral:						; on exit AX has the int to be categorized
	CMP numBytesRead, 128					; if the End Of Buffer is reached while converting consecutive digits and
	JE continue						; numBytesRead is NOT equal to 128, then the file has been read fully
								; and the digit can be converted - otherwise the next readFile execution must
								; start a the first digit of the number that is possible cut in half

	PUSH AX

	MOV AX, 1						; if numBytesRead < 128 - End Of File has been reached
	MOV EOF, AL

	POP AX

	JMP endGetNextNumeral	

continue:
	MOV AX, 128						; acquire the starting position for the next readFile execution
	SUB AX, prev_bPtr					; (the position of the first digit of the possibly cut number)
	SUB numBytesProcessed, AX				; store the position in numBytesProcessed - setFilePointer will now
								; set the correct location
endGetNextNumeral:	

	MOV CX, 0						; reset CX

	POP DI SI DX BX

RET
getNextNumeral ENDP

;==========================================================================================================================================================;

getNextByte PROC
	; This PROC is responsible for getting the next byte in the current buffer and setting End Of Buffer when appropriate.
	; The character is stored in CL.
	; All other registers are preserved.

	PUSH AX BX DX SI DI

	INC bPtr						; acquire next character location

	LEA SI, buffer

	ADD SI, bPtr

	MOV CL, [SI]						; store the character in CL

	MOV AX, bPtr

	CMP AX, numBytesRead					; if AX = numBytesRead then the End Of Buffer has been reached
	JNE skip_setEOB

	MOV DL, 1
	MOV EOB, DL						; set End Of Buffer

skip_setEOB:

	POP DI SI DX BX AX

RET
getNextByte ENDP

;==========================================================================================================================================================;

categorize PROC
	; This PROC is responsible for correctly categorizing the integer stored in AX.
	; Upon exit, AX is cleared.
	; All other registers are preserved.	

	PUSH BX CX DX SI DI

	LEA DI, counterList					; acquire starting location in counterList

	MOV BX, 100						; set the divisor

	DEC AX							; decrement to allow for correct categorization of value equal to N*100

	CMP AX, 0						; if AX is less than 0, set to 0
	JNL skip_setToZero

	MOV AX, 0

skip_setToZero:

	DIV BX							; AX contains quotient which is also the offset for counterList

	MOV DX, 0						; clear DX

	ADD DI, AX						; add the offset to counterList

	ADD DI, AX

	MOV CX, 10						; acquire the number of executions

	SUB CX, AX

	MOV BX, 1						; set the value to add to counterList

recordLoop:
	ADD [DI], BX						; increment the correct positions in counterList
	INC DI
	INC DI
	DEC CX
	CMP CX, 0						; if incrementation is complete, terminate loop
	JNE recordLoop

	MOV AX, 0						; clear AX

	POP DI SI DX CX BX

RET
categorize ENDP

;==========================================================================================================================================================;

counterListToNumerals PROC
	; This PROC converts the contents of counterList into a printable form and stores it in outBuffer.
	; All registers are preserved.

	; assumes: 
	; 	counterList contains the ints to be converted to numerals
	; alters:
	; 	outBuffer will contain converted ints

	PUSH AX BX CX DX SI DI	

	MOV BX, 10						; divisor
	
	MOV CX, 10						; counter = 10 since 10 numbers in counterList

	LEA SI, counterList					; set SI to starting position in counterList

	LEA DI, outBuffer					; set DI to starting position in outBuffer

	MOV AX, [SI]						; AX contains the number to be converted

counterListToNumeralsLoop:

	ADD DI, 4						; shift to the last position for a number in outBuffer to enable forwards printing

counterList_intConvertLoop:	
	MOV DX, 0						; clear DX
	DIV BX							; DX contains remainder
								; AX contains quotient
	ADD DL, '0'						; DL contains converted number

	MOV [DI], DL						; place converted number into outBuffer
	DEC DI							; set next number location in outBuffer

	CMP AX, 0						; if the conversion is complete, terminate - otherwise, repeat
	JA counterList_intConvertLoop

	DEC CX
	CMP CX, 0						; decrement the counter each time a number is fully converted and stored
	JNE p_counterListToNumeralsLoop				; if the conversion process is not complete, prepare next execution
	JMP end_counterListToNumeralsLoop			; otherwise, end the loop

p_counterListToNumeralsLoop:
	PUSH AX BX DX

	MOV AX, 10						; reset the location in outBuffer
	SUB AX, CX
	MOV BX, 7
	MUL BX
		
	LEA DI, outBuffer
	ADD DI, AX						; AX now contains the first position of one of the number locations in outBuffer

	POP DX BX AX

	INC SI							; acquire the next digit in counterList
	INC SI
	MOV AX, [SI]						; store it in AX
	JMP counterListToNumeralsLoop				; execute the conversion process again

end_counterListToNumeralsLoop:

	POP DI SI DX CX BX AX

RET
counterListToNumerals ENDP

;==========================================================================================================================================================;

print_outBuffer PROC
	; This PROC is used to print the contents of outBuffer.
	; This PROC is TESTING CODE.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI

	LEA SI, outBuffer					; attain starting location in outBuffer

	MOV CX, 70						; set counter		

	MOV AH, 00010010b					; set color

	MOV DI, 8*160						; set screen location

print_outBufferLoop:
	
	MOV AL, DS:[SI]						; place character into AL

	MOV ES:[DI], AX						; place onto screen

	INC SI							; acquire next character
	INC DI							; move to next screen position
	INC DI

	DEC CX
	CMP CX, 0						; printing done?
	JE end_print_outBufferLoop				; if so, jump
	JMP print_outBufferLoop					; otherwise, continue

end_print_outBufferLoop:

	POP DI SI DX CX BX AX

RET
print_outBuffer ENDP

;==========================================================================================================================================================;

outputToFile PROC
	; This PROC is responsible for printing the contents of outBuffer to a file.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI

	MOV BX, handle						; acquire file reference number

	LEA DX, outBuffer					; attain starting location in outBuffer

	MOV CX, 70						; number of characters to print

	MOV AH, 40h						; print to file
	INT 21h

	POP DI SI DX CX BX AX

RET
outputToFile ENDP

;==========================================================================================================================================================;

createFile PROC
	; This PROC is responsible for creating a the file to which to print the contents of outBuffer.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI

	LEA DX, outFileName					; acquire output file name
	MOV CL, 0						; set file attribute
	MOV AH, 3Ch						; create the file
	INT 21h
	MOV handle, AX						; acquire file handle

	POP DI SI DX CX BX AX

RET
createFile ENDP

;==========================================================================================================================================================;

closeFile PROC
	; This PROC is responsible for closing the currently open file.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI

	MOV BX, handle						; acquire file reference number
	MOV AH, 3Eh						; close the file
	INT 21h
	
	POP DI SI DX CX BX AX

RET
closeFile ENDP

;==========================================================================================================================================================;

getFileName PROC
	; This PROC is responsible for getting the input file name from the PSP.
	; All registers are preserved.

	PUSH AX BX CX DX SI DI

	MOV SI, 80h						; set SI to the correct offset

	LEA DI, inFileName					; acquire the starting position of the variable to store the file name in

	INC SI							; advance to the first possible file name character

getFileNameLoop:
	CMP ES:[SI], BYTE PTR ' '				; if space, skip
	JE skipSpace

	CMP ES:[SI], BYTE PTR 13				; if carriage return, end of file name found - terminate the loop
	JE end_getFileNameLoop

	MOV AL, ES:[SI]						; otherwise store the character
	MOV DS:[DI], AL

	INC DI							; advance to next position in the variable

skipSpace:
	INC SI							; advance to next character in the PSP

	JMP getFileNameLoop

end_getFileNameLoop:
	
	POP DI SI DX CX BX AX

RET
getFileName ENDP

;==========================================================================================================================================================;

clearScreen PROC
	; This PROC clears the screen.
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
	; This PROC is TESTING CODE.

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
	; This PROC is TESTING CODE.

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