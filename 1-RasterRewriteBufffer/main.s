.cpu _45gs02				
#import "../_include/m65macros.s"

.const COLOR_RAM = $ff80000
.const ROW_SIZE = 46
.const LOGICAL_ROW_SIZE = ROW_SIZE * 2

.const GOTOX = $10
.const TRANSPARENT = $80


* = $02 "Basepage" virtual
	ScreenVector: .word $0000

BasicUpstart65(Entry)
* = $2016 "Basic Entry"

Entry: {
		sei 
		lda #$35
		sta $01

		enable40Mhz()
		enableVIC4Registers()

		//Disable CIA interrupts
		lda #$7f
		sta $dc0d
		sta $dd0d

		//Disable C65 rom protection using
		//hypervisor trap (see mega65 manual)
		lda #$70
		sta $d640
		eom

		//Disable IRQ raster interrupts
		//because C65 uses raster interrupts in the ROM
		lda #$00
		sta $d01a

		//Unmap C65 Roms $d030 by clearing bits 3-7
		lda #%11111000
		trb $d030

		cli



		//Set to 40 columns by disabling H640 (bit 7) of $d031
		lda #$80
		trb $d031

		lda #$05    //Enable 16 bit char numbers (bit0) and 
		sta $d054   //full color for chars>$ff (bit2)

		//Set logical row width
		//bytes per screen row (16 bit value in $d058-$d059)
		lda #<LOGICAL_ROW_SIZE
		sta $d058
		lda #>LOGICAL_ROW_SIZE
		sta $d059

		//Set number of chars per row
		lda #ROW_SIZE
		sta $d05e


		//Relocate screen RAM using $d060-$d063
		lda #<SCREEN_BASE 
		sta $d060 
		lda #>SCREEN_BASE 
		sta $d061
		lda #$00
		sta $d062
		sta $d063

		jsr CopyColors

	MainLoop:
		//Crappy animation of GOTOX values
	!:
		lda $d011
		bpl !-

		//do stuff
		inc SinusIndex


		ldx SinusIndex
		ldy #$00

	!Loop:
		lda ScreenOffsets, y
		iny
		sta ScreenVector + 0

		lda ScreenOffsets, y 
		iny
		sta ScreenVector + 1

		ldz #$00
		lda Sinus, x 
		sta (ScreenVector), z

		ldz #$04
		eor #$ff 
		sta (ScreenVector), z


		txa 
		clc 
		adc #$04
		tax
		
		cpy #$32
		bne !Loop-


	!:
		lda $d011
		bmi !-

		jmp MainLoop

}


CopyColors: {
		RunDMAJob(Job)
		rts 
	Job:
		DMAHeader($00, COLOR_RAM>>20)
		DMACopyJob(COLORS, COLOR_RAM, LOGICAL_ROW_SIZE * 25, false, false)
}


SinusIndex:
	.byte $00
Sinus:
	.fill 256, sin(i/256 * PI * 2) * 127 + 127

ScreenOffsets:
	.for(var r=0; r<25; r++) {
		.word SCREEN_BASE + r*LOGICAL_ROW_SIZE + 80
	}



* = $4000
SCREEN_BASE:
	//Build each row in a loop
	.for(var r=0; r<25; r++) {
		.fill 40, [i, 0]  //0 1 2 3 4 5 6 7 8 9 10 11
		//Because GOTOX flag set in color ram, no draw!!!, 
		//instead set XPosition to 100
		.byte $64, 0 
		.byte 15, 0

		.byte $64, 0 
		.byte 15, 0

		//Set final GOTOX to 320 to ensure raster ends on far right of screen
		.byte 64, 1	

		//Draw final char offscreen
		.byte 0,0
	}



COLORS:
	.for(var r=0; r<25; r++) {
		.fill 40, [0, 0] //layer 1

		//Set bit 4 of color ram byte 0 to enable gotox flag
		//set bit 7 additionally to enable transparency

		.byte [GOTOX | TRANSPARENT], $00 
		.byte 0, 7 //standard 16 colors are in bits 0-3 of byte 1 in 16 bit char mode

		.byte [GOTOX | TRANSPARENT], $00 
		.byte 0, 7 //standard 16 colors are in bits 0-3 of byte 1 in 16 bit char mode

		
		//Final GOTOX to ensure whole row is drawn
		.byte [GOTOX], $00 //Set bit 4 of color ram byte 0 to enable gotox flag
		.byte 0,0
	}



// Think of render buffer as a list of instructions per line:
// where each screen location and color ram location defines the instruction
// with xpos incrementing by 8 after each char unless a GOTOX has relocated it
// 
// xpos=0, char=0, color=black
// xpos=8, char=1, color=black
// xpos=16, char=2, color=blacK
// ....
// xpos=312, char=39, color=black
// 
// GOTOX - [$10, $00] -> jump to new x position
// xpos=100, char=15, color=yellow, 

// GOTOX - [$10, $00] -> Jump to x position = 320
// xpos=320, char=0, color=black





