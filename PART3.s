.section .vectors, "ax"
B _start            // reset vector
B SERVICE_UND       // undefined instruction vector
B SERVICE_SVC       // software interrupt vector
B SERVICE_ABT_INST  // aborted prefetch vector
B SERVICE_ABT_DATA  // aborted data vector
.word 0             // unused vector
B SERVICE_IRQ       // IRQ interrupt vector
B SERVICE_FIQ       // FIQ interrupt vector	
.text
.global _start
.equ PB_ADDR, 0xFF200050
.equ PB_INT, 0xFF200058
.EQU PB_EDGE, 0xFF20005C
.equ LED_ADDR, 0xFF200000
.equ SW_ADDR, 0xFF200040
.equ HEX_ADDR, 0xFF200020
.equ HEX_ADDR2, 0xFF200030
.equ LOAD_ADDR, 0xFFFEC600
.equ CONT_ADDR, 0xFFFEC608
.equ INT_ADDR, 0xFFFEC60C
PB_int_flag: .word 0x0
tim_int_flag:.word 0x0
_start:
    /* Set up stack pointers for IRQ and SVC processor modes */
    MOV R1, #0b11010010      // interrupts masked, MODE = IRQ
    MSR CPSR_c, R1           // change to IRQ mode
    LDR SP, =0xFFFFFFFF - 3  // set IRQ stack to A9 onchip memory
    /* Change to SVC (supervisor) mode with interrupts disabled */
    MOV R1, #0b11010011      // interrupts masked, MODE = SVC
    MSR CPSR, R1             // change to supervisor mode
    LDR SP, =0x3FFFFFFF - 3  // set SVC stack to top of DDR3 memory
    BL  CONFIG_GIC               // configure the ARM GIC\
	//GOTTA PASS IN AN ARGUMENT IN A1 FOR WHICH ONES TO ENABLE
	MOV A1, #0B1111
	BL enable_PB_INT_ASM
	LDR A1, =20000000  // LOAD VALUE TO COUNT DOWN FROM AT A FREQ OF 200 MHZ
	MOV A2, #0B111 // I = 1, A = 1, E = 1 
	BL ARM_TIM_config_ASM
	
    // To DO: write to the pushbutton KEY interrupt mask register
    // Or, you can call enable_PB_INT_ASM subroutine from previous task
    // to enable interrupt for ARM A9 private timer, use ARM_TIM_config_ASM subroutine
    LDR R0, =0xFF200050      // pushbutton KEY base address
    MOV R1, #0xF             // set interrupt mask bits
    STR R1, [R0, #0x8]       // interrupt mask register (base + 8)
    // enable IRQ interrupts in the processor
    MOV R0, #0b01010011      // IRQ unmasked, MODE = SVC
    MSR CPSR_c, R0
	
IDLE:
	MOV V1, #0 // SECONDS COUNTER
	MOV V2, #0 // 10SECONDS COUNTER
	MOV V3, #0 // MIN COUNTER
	MOV V4, #0 // 10 MIN COUNTER
	MOV V5, #0 // HOUR COUNTER

// INITIALIZE THE HEX DISPLAY
	MOV A3 , #0 //COUNTER
	MOV V6, #0 // INITIALIZE A ZERO TERM
	MOV A1, #0B111111
	MOV A2, #0
	BL HEX_write_ASM
		PB_START:
			LDR A1, PB_int_flag 
			AND A1, #0B0001 //IF PRESSED, A1==1, IF NOT , A1 == 0
			CMP A1, #1
				BNE PB_START //IF PB0 != 1, WAIT FOR START
				STREQ V6, PB_int_flag 
				BEQ LOOP //IF PB0 == 1
				
LOOP:
	PB_STOP:
	//RESET
		LDR A1, PB_int_flag 
		AND A1, #0B0100 // CHECK PB2'S EDGECAP, IF == 0B0100, THEN THIS BUTTON WAS PUSHED
		CMP A1, #4
			BEQ IDLE
	//START
		LDR A1, PB_int_flag 
		AND A1, #0B0001 // CHECK PB0'S EDGECAP
		CMP A1, #1 //IF PRESSED, A1==1, IF NOT , A1 == 0
			BEQ PB_START
	//STOP	
		LDR A1, PB_int_flag 
		AND A1, #0B0010 // CHECK PB1'S EDGECAP
		CMP A1, #2 // IF PB1 IS PRESSED
			BEQ PB_STOP //THEN LOOP IN HERE
	

		// HOUR
		CMP V5, #10
		
		// IF HOUR LESS THAN 10
			MOVLT A1, #0B100000 // TURN ON HEX 5, PARAMETER A1
			MOVLT A2, V5		// COUNTER VALUE, PARAMETER A2
			BLLT HEX_write_ASM // WRITE THE COUNTER VALUE ON HEX 5
		// IF HOUR == 10, RESET
		CMP V5, #10// REWRITE SINCE THE PREVIOUS FUNCTION CALL CHANGES THE CPSR
			MOVEQ V5, #0 // RESET HOUR COUNTER
			MOVEQ A1, #0B100000 // TURN ON HEX 5, PARAMETER A1
			MOVEQ A2, V5		// COUNTER VALUE, PARAMETER A2
			BLEQ HEX_write_ASM // WRITE THE COUNTER VALUE ON HEX 5
		// 10 MIN
		CMP V4, #6
		
		// IF 10 MINUTE LESS THAN 10
			MOVLT A1, #0B010000 // TURN ON HEX 4, PARAMETER A1
			MOVLT A2, V4		// COUNTER VALUE, PARAMETER A2
			BLLT HEX_write_ASM // WRITE THE COUNTER VALUE ON HEX 4
		// IF 10 MINUTE == 6, RESET
		CMP V4, #6// REWRITE SINCE THE PREVIOUS FUNCTION CALL CHANGES THE CPSR
			MOVEQ V4, #0 // RESET 10 MIN COUNTER
			ADDEQ V5, #1 //INCREMENT HOUR COUNTER
			MOVEQ A1, #0B010000 // TURN ON HEX 4, PARAMETER A1
			MOVEQ A2, V4		// COUNTER VALUE, PARAMETER A2
			BLEQ HEX_write_ASM // WRITE THE COUNTER VALUE ON HEX 4
	
		//MIN	
		CMP V3, #10
		
		// IF MINUTE LESS THAN 10
			MOVLT A1, #0B001000 // TURN ON HEX 3, PARAMETER A1
			MOVLT A2, V3		// COUNTER VALUE, PARAMETER A2
			BLLT HEX_write_ASM // WRITE THE COUNTER VALUE ON HEX 3
		// IF MINUTE == 10, RESET
		CMP V3, #10 // REWRITE SINCE THE PREVIOUS FUNCTION CALL CHANGES THE CPSR
			MOVEQ V3, #0 // RESET MIN COUNTER
			ADDEQ V4, #1 //INCREMENT 10 MIN COUNTER
			MOVEQ A1, #0B001000 // TURN ON HEX 3, PARAMETER A1
			MOVEQ A2, V3 		// COUNTER VALUE, PARAMETER A2
			BLEQ HEX_write_ASM // WRITE THE COUNTER VALUE ON HEX 3
		//10 SEC
		
		CMP V2, #6
		
		// IF 10 SECONDS LESS THAN 10
			MOVLT A1, #0B000100 // TURN ON HEX 2, PARAMETER A1
			MOVLT A2, V2		// COUNTER VALUE, PARAMETER A2
			BLLT HEX_write_ASM // WRITE THE COUNTER VALUE ON HEX 2
		// IF 10 SECONDS == 6, RESET
		CMP V2, #6// REWRITE SINCE THE PREVIOUS FUNCTION CALL CHANGES THE CPSR
			MOVEQ V2, #0 // RESET 10 SEC COUNTER
			ADDEQ V3, #1 //INCREMENT MIN COUNTER
			MOVEQ A1, #0B000100 // TURN ON HEX 2, PARAMETER A1
			MOVEQ A2, V2 		// COUNTER VALUE, PARAMETER A2
			BLEQ HEX_write_ASM // WRITE THE COUNTER VALUE ON HEX 2
		//SEC	
		CMP V1, #10 
		
		// IF SECONDS LESS THAN 10
			MOVLT A1, #0B000010 // TURN ON HEX 1, PARAMETER A1
			MOVLT A2, V1 		// COUNTER VALUE, PARAMETER A2
			BLLT HEX_write_ASM // WRITE THE COUNTER VALUE ON HEX 1
		// IF SECONDS == 10, RESET
		CMP V1, #10 // REWRITE SINCE THE PREVIOUS FUNCTION CALL CHANGES THE CPSR
			MOVEQ V1, #0 // RESET SEC COUNTER
			ADDEQ V2, #1 //INCREMENT 10 SEC COUNTER
			MOVEQ A1, #0B000010 // TURN ON HEX 1, PARAMETER A1
			MOVEQ A2, V1 		// COUNTER VALUE, PARAMETER A2
			BLEQ HEX_write_ASM // WRITE THE COUNTER VALUE ON HEX 1
	CMP A3, #10 // WHEN COUNTER REACHES 10
	MOVEQ A3, #0 // RESTART
	ADDEQ V1, #1
	WAIT:
	LDR A4, tim_int_flag // IF INTERRUPT OCCURED, THEN 1	
	CMP A4, #1
		BNE WAIT // LOOP UNTIL TIME INTERRUPT OCCURS
		MOVEQ A1, #0B000001 // HEX 0
		MOVEQ A2, A3 // DISPLAY COUNTER
		ADDEQ A3, #1 // INCREMENT COUNTER
		STREQ V6, tim_int_flag //RESET TIM INT FLAG
		BLEQ HEX_write_ASM // WRITE ON HEX
	
    B LOOP // This is where you write your objective task
	/*--- Undefined instructions --------------------------------------*/
SERVICE_UND:
    B SERVICE_UND
/*--- Software interrupts ----------------------------------------*/
SERVICE_SVC:
    B SERVICE_SVC
/*--- Aborted data reads ------------------------------------------*/
SERVICE_ABT_DATA:
    B SERVICE_ABT_DATA
/*--- Aborted instruction fetch -----------------------------------*/
SERVICE_ABT_INST:
    B SERVICE_ABT_INST
/*--- IRQ ---------------------------------------------------------*/
SERVICE_IRQ:
    PUSH {R0-R7, LR}
/* Read the ICCIAR from the CPU Interface */
    LDR R4, =0xFFFEC100
    LDR R5, [R4, #0x0C] // read from ICCIAR
/* To Do: Check which interrupt has occurred (check interrupt IDs)
   Then call the corresponding ISR
   If the ID is not recognized, branch to UNEXPECTED
   See the assembly example provided in the De1-SoC Computer_Manual on page 46 */
TIMER_CHECK:
	CMP R5, #29
		BLEQ ARM_TIM_ISR
		BEQ EXIT_IRQ
Pushbutton_check:
    CMP R5, #73
		BLEQ KEY_ISR
		BEQ EXIT_IRQ

UNEXPECTED:
    BNE UNEXPECTED     // if not recognized, stop here
	BL KEY_ISR

EXIT_IRQ:
/* Write to the End of Interrupt Register (ICCEOIR) */
    STR R5, [R4, #0x10] // write to ICCEOIR
    POP {R0-R7, LR}
SUBS PC, LR, #4
/*--- FIQ ---------------------------------------------------------*/
SERVICE_FIQ:
    B SERVICE_FIQ
CONFIG_GIC:
    PUSH {LR}
/* To configure the FPGA KEYS interrupt (ID 73):
* 1. set the target to cpu0 in the ICDIPTRn register
* 2. enable the interrupt in the ICDISERn register */
/* CONFIG_INTERRUPT (int_ID (R0), CPU_target (R1)); */
/* To Do: you can configure different interrupts
   by passing their IDs to R0 and repeating the next 3 lines */
    MOV R0, #73            // KEY port (Interrupt ID = 73)
    MOV R1, #1             // this field is a bit-mask; bit 0 targets cpu0
    BL CONFIG_INTERRUPT
	
	MOV R0, #29            // ARM A9 private timer (Interrupt ID = 29)
    MOV R1, #1             // this field is a bit-mask; bit 0 targets cpu0
    BL CONFIG_INTERRUPT

/* configure the GIC CPU Interface */
    LDR R0, =0xFFFEC100    // base address of CPU Interface
/* Set Interrupt Priority Mask Register (ICCPMR) */
    LDR R1, =0xFFFF        // enable interrupts of all priorities levels
    STR R1, [R0, #0x04]
/* Set the enable bit in the CPU Interface Control Register (ICCICR).
* This allows interrupts to be forwarded to the CPU(s) */
    MOV R1, #1
    STR R1, [R0]
/* Set the enable bit in the Distributor Control Register (ICDDCR).
* This enables forwarding of interrupts to the CPU Interface(s) */
    LDR R0, =0xFFFED000
    STR R1, [R0]
    POP {PC}

/*
* Configure registers in the GIC for an individual Interrupt ID
* We configure only the Interrupt Set Enable Registers (ICDISERn) and
* Interrupt Processor Target Registers (ICDIPTRn). The default (reset)
* values are used for other registers in the GIC
* Arguments: R0 = Interrupt ID, N
* R1 = CPU target
*/
CONFIG_INTERRUPT:
    PUSH {R4-R5, LR}
/* Configure Interrupt Set-Enable Registers (ICDISERn).
* reg_offset = (integer_div(N / 32) * 4
* value = 1 << (N mod 32) */
    LSR R4, R0, #3    // calculate reg_offset
    BIC R4, R4, #3    // R4 = reg_offset
    LDR R2, =0xFFFED100
    ADD R4, R2, R4    // R4 = address of ICDISER
    AND R2, R0, #0x1F // N mod 32
    MOV R5, #1        // enable
    LSL R2, R5, R2    // R2 = value
/* Using the register address in R4 and the value in R2 set the
* correct bit in the GIC register */
    LDR R3, [R4]      // read current register value
    ORR R3, R3, R2    // set the enable bit
    STR R3, [R4]      // store the new register value
/* Configure Interrupt Processor Targets Register (ICDIPTRn)
* reg_offset = integer_div(N / 4) * 4
* index = N mod 4 */
    BIC R4, R0, #3    // R4 = reg_offset
    LDR R2, =0xFFFED800
    ADD R4, R2, R4    // R4 = word address of ICDIPTR
    AND R2, R0, #0x3  // N mod 4
    ADD R4, R2, R4    // R4 = byte address in ICDIPTR
/* Using register address in R4 and the value in R2 write to
* (only) the appropriate byte */
    STRB R1, [R4]
    POP {R4-R5, PC}
KEY_ISR:
    LDR R0, =0xFF200050    // base address of pushbutton KEY port
    LDR R1, [R0, #0xC]     // read edge capture register
	STR R1, PB_int_flag    // WRITE EDGE CAPTURE BUTTONS TO PB_INT_FLAG ADDRESS
    MOV R2, #0xF
    STR R2, [R0, #0xC]     // clear the interrupt
   
END_KEY_ISR:
//	PUSH {LR}
//	MOV A1, #0B1111
//	BL PB_clear_edgecp_ASM
//	POP {LR}
	BX LR
ARM_TIM_ISR:
	PUSH {LR}
	BL ARM_TIM_read_INT_ASM // READ THE INT STATUS AND RETURN IN A1
	STR A1, tim_int_flag// WRITE INT STATUS INTO TIM_INT_FLAG
	BL ARM_TIM_clear_INT_ASM
	POP {LR}
	BX LR
	
	
	
	
	
	
	
	
	
	
	
	
	
	
ARM_TIM_clear_INT_ASM:
	
	PUSH {V1, V2}
	LDR V1 , =INT_ADDR
	MOV V2, #0X1
	STR V2, [V1] //RESET F
	POP {V1, V2}
	BX LR	
	
ARM_TIM_read_INT_ASM:

	PUSH {V1}
	LDR V1 , =INT_ADDR
	LDR A1, [V1] //LOAD THE STATUS OF F INTO A1
	// RETURN INTO A1
	POP {V1}
	BX LR	
	
enable_PB_INT_ASM:
			// PASS ARGUMENT IN A1
	PUSH {V1,V2}
	LDR V1, =PB_INT
	LDR V2, [V1]   // STATUS OF THE INTERRUPT MASK FOR THE PUSH BUTTON
	ORR V2, A1 
	STR V2, [V1]   // STORE THE CHOSEN INDICES IN ORDER TO ENABLE THE CORRECT PUSH BUTTONS
	POP {V1,V2}
	BX LR
	
ARM_TIM_config_ASM:

	PUSH {V1, V2}
	LDR V1, =LOAD_ADDR //LOAD ADDR
	LDR V2, =CONT_ADDR // CONTROL ADDR
	STR A1, [V1]	//STORE LOAD PARAMETER IN LOAD ADDR
	STR A2, [V2]    //STORE CONTROL PARAMETER IN CONTROL ADDR    
	POP {V1, V2}
	BX LR
PB_clear_edgecp_ASM:

	PUSH {V1,A1,LR}
	BL read_PB_edgecp_ASM
	LDR V1, =PB_EDGE
	STR A1, [V1]
	//TEST
	//BL read_PB_edgecp_ASM
	POP {V1,A1, LR}
	BX LR
read_PB_edgecp_ASM:
	
	PUSH {V1}
	LDR V1, =PB_EDGE //ADDRESS OF THE PUSH BUTTON
	LDR A1,[V1]	// READ THE DATA AT THAT ADDRESS
	//RETURN IN A1
	POP {V1}
	BX LR
disable_PB_INT_ASM:
	
	PUSH {V1,V2}
	LDR V1, =PB_INT
	LDR V2, [V1]   // STATUS OF THE INTERRUPT MASK FOR THE PUSH BUTTON
	EOR A2, #0B1111 // NOT GATE, FLIP THE BITS OF A2
	AND V2, A2		// STORE IN V2 THE BITS THAT DETERMINE WHICH PBS HAVE THE INT MASK OFF AND ON
	STR V2, [V1]   // STORE THE CHOSEN INDICES IN ORDER TO ENABLE THE CORRECT PUSH BUTTONS
	POP {V1,V2}
	BX LR
HEX_clear_ASM:
	PUSH {V1-V5}
	LDR V1, =HEX_ADDR //ADDRESS OF THE SEVEN SEGMENT DISPLAY OF HEX0 TO HEX3 
	LDR V2, =HEX_ADDR2 //ADDRESS OF THE SEVEN SEGMENT DISPLAY OF HEX4 AND HEX5
	LDR V3,[V1]       //7-SEGMENT DISPLAY STATUS FOR FIRST 4
	LDR V4,[V2]		  //7-SEGMENT DISPLAY STATUS FOR LAST 2
	
	//THE ANDS ARE USED TO CHECK WHETHER OR NOT THAT SPECIFIT DISPLAY IS COMMANDED TO TURN OFF
	AND V5, A1, #0B000001       
	CMP V5,  #0B000001 		// IF INDEX 0
		ANDEQ V3, #0XFFFFFF00 // TURN OFF HEX0
	AND V5, A1, #0B000010
	CMP V5,  #0B000010 		// IF INDEX 1
		ANDEQ V3, #0XFFFF00FF // TURN OFF HEX1
	AND V5, A1, #0B000100		
	CMP V5,  #0B000100		// IF INDEX 2
		ANDEQ V3, #0XFF00FFFF // TURN OFF HEX2
	AND V5, A1, #0B001000
	CMP V5,  #0B001000 		// IF INDEX 3
		ANDEQ V3, #0X00FFFFFF // TURN OFF HEX3
	AND V5, A1, #0B010000
	CMP V5,  #0B010000		// IF INDEX 4
		ANDEQ V4, #0XFF00 // TURN OFF HEX4
	AND V5, A1, #0B100000		
	CMP V5,  #0B100000		// IF INDEX 5
		ANDEQ V4, #0X00FF // TURN OFF HEX5
//	MOV V3, #0XFFFFFFFF
//	MOV V4, #0X00FFFFFF
	STR V3, [V1] //STORE THE RESULT OF HEX0-3 INTO THE ADDRESS OF THE SEVEN SEGMENT DISPLAY OF HEX0 TO HEX3
	STR V4, [V2] //STORE THE RESULT OF HEX4-5 INTO THE ADDRESS OF THE SEVEN SEGMENT DISPLAY OF HEX4, HEX5
	POP {V1-V5}
	BX LR
HEX_flood_ASM:
	PUSH {V1-V5}
	LDR V1, =HEX_ADDR //ADDRESS OF THE SEVEN SEGMENT DISPLAY OF HEX0 TO HEX3 
	LDR V2, =HEX_ADDR2 //ADDRESS OF THE SEVEN SEGMENT DISPLAY OF HEX4 AND HEX5
	LDR V3,[V1]       //7-SEGMENT DISPLAY STATUS FOR FIRST 4
	LDR V4,[V2]		  //7-SEGMENT DISPLAY STATUS FOR LAST 2
	
	//THE ANDS ARE USED TO CHECK WHETHER OR NOT THAT SPECIFIT DISPLAY IS COMMANDED TO TURN ON
	AND V5, A1, #0B000001       
	CMP V5,  #0B000001 		// IF INDEX 0
		ORREQ V3, #0X000000FF // TURN ON HEX0
	AND V5, A1, #0B000010
	CMP V5,  #0B000010 		// IF INDEX 1
		ORREQ V3, #0X0000FF00 // TURN ON HEX1
	AND V5, A1, #0B000100		
	CMP V5,  #0B000100		// IF INDEX 2
		ORREQ V3, #0X00FF0000 // TURN ON HEX2
	AND V5, A1, #0B001000
	CMP V5,  #0B001000 		// IF INDEX 3
		ORREQ V3, #0XFF000000 // TURN ON HEX3
	AND V5, A1, #0B010000
	CMP V5,  #0B010000		// IF INDEX 4
		ORREQ V4, #0X00FF // TURN ON HEX4
	AND V5, A1, #0B100000		
	CMP V5,  #0B100000		// IF INDEX 5
		ORREQ V4, #0XFF00 // TURN ON HEX5
//	MOV V3, #0XFFFFFFFF
//	MOV V4, #0X00FFFFFF
	STR V3, [V1] //STORE THE RESULT OF HEX0-3 INTO THE ADDRESS OF THE SEVEN SEGMENT DISPLAY OF HEX0 TO HEX3
	STR V4, [V2] //STORE THE RESULT OF HEX4-5 INTO THE ADDRESS OF THE SEVEN SEGMENT DISPLAY OF HEX4, HEX5
	POP {V1-V5}
	BX LR
HEX_write_ASM:
	PUSH {V1-V6,LR}
	BL HEX_clear_ASM // START OFF BY CLEARING THE DISPLAY IN WHICH WE ARE GOING TO WRITE IN (IN ORDER TO OVERWRITE)
	LDR V1, =HEX_ADDR //ADDRESS OF THE SEVEN SEGMENT DISPLAY OF HEX0 TO HEX3 
	LDR V2, =HEX_ADDR2 //ADDRESS OF THE SEVEN SEGMENT DISPLAY OF HEX4 AND HEX5
	LDR V3,[V1]       //7-SEGMENT DISPLAY STATUS FOR FIRST 4
	LDR V4,[V2]		  //7-SEGMENT DISPLAY STATUS FOR LAST 2
	
	//ENCODE THE VALUE OF A2 FROM INTEGER TO SEVEN-SEGMENT DISPLAY CODE
	
	CMP A2, #0
		MOVEQ V6, #0X3F
	CMP A2, #1
		MOVEQ V6, #0X06
	CMP A2, #2
		MOVEQ V6, #0X5B
	CMP A2, #3
		MOVEQ V6, #0X4F
	CMP A2, #4
		MOVEQ V6, #0X66
	CMP A2, #5
		MOVEQ V6, #0X6D
	CMP A2, #6
		MOVEQ V6, #0X7D
	CMP A2, #7
		MOVEQ V6, #0X07
	CMP A2, #8
		MOVEQ V6, #0XFF
	CMP A2, #9
		MOVEQ V6, #0X67
	CMP A2, #10
		MOVEQ V6, #0X77
	CMP A2, #11
		MOVEQ V6, #0XFF
	CMP A2, #12
		MOVEQ V6, #0X39
	CMP A2, #13
		MOVEQ V6, #0X3F
	CMP A2, #14
		MOVEQ V6, #0X79
	CMP A2, #15
		MOVEQ V6, #0X71
	
	//THE ANDS ARE USED TO CHECK WHETHER OR NOT THAT SPECIFIT DISPLAY IS COMMANDED TO TURN ON
	// THE ORRS ARE USED TO ADD ONTO WHAT WAS ON THE DISPLAYS PREVIOUSLY
	AND V5, A1, #0B000001       
	CMP V5,  #0B000001 		// IF INDEX 0
		ORREQ V3, V6 		// DISPLAY A2 ON HEX0 
	AND V5, A1, #0B000010
	CMP V5,  #0B000010 		// IF INDEX 1
		ORREQ V3, V6, LSL#8 // DISPLAY A2 ON HEX1
	AND V5, A1, #0B000100		
	CMP V5,  #0B000100		// IF INDEX 2
		ORREQ V3, V6, LSL#16 // DISPLAY A2 ON HEX2
	AND V5, A1, #0B001000
	CMP V5,  #0B001000 		// IF INDEX 3
		ORREQ V3, V6, LSL#24 // DISPLAY A2 ON HEX3
	AND V5, A1, #0B010000
	CMP V5,  #0B010000		// IF INDEX 4
		ORREQ V4, V6 		// DISPLAY A2 ON HEX4
	AND V5, A1, #0B100000		
	CMP V5,  #0B100000		// IF INDEX 5
		ORREQ V4, V6, LSL#8 // DISPLAY A2 ON HEX5
//	MOV V3, #0XFFFFFFFF
//	MOV V4, #0X00FFFFFF
	STR V3, [V1] //STORE THE RESULT OF HEX0-3 INTO THE ADDRESS OF THE SEVEN SEGMENT DISPLAY OF HEX0 TO HEX3
	STR V4, [V2] //STORE THE RESULT OF HEX4-5 INTO THE ADDRESS OF THE SEVEN SEGMENT DISPLAY OF HEX4, HEX5
	POP {V1-V6,LR}
	BX LR