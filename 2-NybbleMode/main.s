.cpu _45gs02				
#import "../_include/m65macros.s"

.const COLOR_RAM = $ff80000
.const NUM_ROWS=26
.const ROW_SIZE = 24
.const LOGICAL_ROW_SIZE = ROW_SIZE * 2


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
		
		//Unmap C65 Roms $d030 by clearing bits 3-7
		lda #%11111000
		trb $d030

		//Disable IRQ raster interrupts
		//because C65 uses raster interrupts in the ROM
		lda #$00
		sta $d01a

		//Change VIC2 stuff here to save having to disable hot registers
		lda #%00000111
		trb $d016

		cli


		//Now setup VIC4
		lda #%10100000		//Clear bit7=40 column, bit5=disable extended attribute
		trb $d031

		lda #%00000101		//Set bit2=FCM for chars >$ff,  bit0=16 bit char indices
		sta $d054

		//Set logical row width
		//bytes per screen row (16 bit value in $d058-$d059)
		lda #<LOGICAL_ROW_SIZE
		sta $d058
		lda #>LOGICAL_ROW_SIZE
		sta $d059

		//Set number of chars per row
		lda #ROW_SIZE
		sta $d05e
		//Set number of rows
		lda #$1a
		sta $d07b 

		//Relocate screen RAM using $d060-$d063
		lda #<SCREEN_BASE 
		sta $d060 
		lda #>SCREEN_BASE 
		sta $d061
		lda #$00
		sta $d062
		sta $d063

		lda #$00
		sta $d020
		lda #$05
		sta $d021

		//Move top border
		lda #$58
		sta $d048
		lda #$00
		sta $d049

		//Move bottom border
		lda #$f8
		sta $d04a
		lda #$01
		sta $d04b

		//Move Text Y Chargen position 
		lda #$58
		sta $d04e
		lda #$00
		sta $d04f	

		jsr CopyPalette
		jsr CopyColors

	loop:
		//wait for raster
		lda #$fe
		cmp $d012 
		bne *-3 
		lda #$ff 
		cmp $d012 
		bne *-3 

		jsr RRBSprites
		jmp loop
}


RRBSprites: {
		jsr ClearRRBSprites

		jsr MoveBall

		jsr DrawRRBSprites

		rts
}

ClearRRBSprites: {
		RunDMAJob(Job)
		rts 
	Job:
		DMAHeader($00, $00)
		DMAStep(0,0,LOGICAL_ROW_SIZE,0)
		DMAFillJob($00, SCREEN_BASE + 42, NUM_ROWS, false)		
}

BallX:
	.word $0000
BallY:
	.byte $00

MoveBall: {
	// rts
		inc BallY

		inc BallX + 0
		bne !+
		lda BallX + 1
		eor #$01 
		sta BallX + 1
	!:
		rts
}




DrawRRBSprites: {
		//pick a row

		//Set ypos fine
		lda BallY
		and #$07
		eor #$07
		asl 
		asl 
		asl 
		asl 
		asl
		sta ypos

		//Work out how many rows to draw
		ldz #$03
		stz rowsToDraw
		ldz #$06
		stz charToDraw


		lda BallY 
		lsr 
		lsr 
		lsr 
		tax 

	!:
		ldz rowsToDraw:#$02
	!loop:
		//grab row from ypos coarse
		cpx #[ROW_SIZE + 2]
		bcs !Exit+

		lda RRBRowTableLo, x
		sta ScreenVector + 0
		lda RRBRowTableHi, x
		sta ScreenVector + 1

		//Position X sprite
		ldy #$00
		lda BallX+0
		sta (ScreenVector), y
		iny
		lda BallX+1
		ora ypos:#$ff
		sta (ScreenVector), y
		iny

		//Draw sprite
		lda charToDraw:#$07
		sta (ScreenVector), y
		iny
		lda #$02 
		sta (ScreenVector), y
		iny
		
		inc charToDraw
		inx 

		dez 
		bne !loop-

	!Exit:
		rts
}


CopyPalette: {
		//Bit pairs = CurrPalette, TextPalette, SpritePalette, AltPalette
		lda #%00000110 //Edit=%00, Text = %00, Sprite = %01, Alt = %10
		sta $d070 

		ldx #$00
	!:
		lda Palette + $000, x 
		sta $d100, x //red
		lda Palette + $100, x 
		sta $d200, x //green
		lda Palette + $200, x 
		sta $d300, x //blue
		inx 
		bne !-
		rts
}


Palette:
	.import binary "./assets/sprites/sprite_palred.bin"
	.import binary "./assets/sprites/sprite_palgrn.bin"
	.import binary "./assets/sprites/sprite_palblu.bin"


CopyColors: {
		RunDMAJob(Job)
		rts 
	Job:
		DMAHeader($00, COLOR_RAM>>20)
		DMACopyJob(COLORS, COLOR_RAM, LOGICAL_ROW_SIZE * NUM_ROWS, false, false)
}


RRBRowTableLo:
	.fill NUM_ROWS, <[SCREEN_BASE + i * LOGICAL_ROW_SIZE + 40]
RRBRowTableHi:
	.fill NUM_ROWS, >[SCREEN_BASE + i * LOGICAL_ROW_SIZE + 40]

* = $4000
SCREEN_BASE: {
	.for(var r=0; r<NUM_ROWS; r++) {
		.for(var c=0; c<20; c++) {
			.if(mod(r,2)==0) {
				.if(random() < 0.1) {
					.byte $04,$02
				} else {
					.byte $01,$02
				}
			} else {
				.byte $02,$02
			}
		}

		//GOTOX position
		.byte $00,$00
		//Character (blank to start)
		.byte $00,$02

		//GOTOX position
		.byte $40,$01
		//Character (blank to start)
		.byte $00,$02		
	}
	// .fill 40, 0
}


COLORS: {
	.for(var r=0; r<NUM_ROWS; r++) {
		.for(var c=0; c<20; c++) {
			.byte $08,$00		//Byte0Bit3 = enable NCM mode
		}
		//GOTOX marker - Byte0bit4=GOTOXMarker, Byte0Bit7=Transparency
		.byte $90,$00
		.byte $08,$00 //Byte0Bit3 = enable NCM mode

		//GOTOX marker - Byte0bit4=GOTOXMarker, Byte0Bit7=Transparency
		.byte $90,$00
		.byte $08,$00	//Byte0Bit3 = enable NCM mode				
	}
}


* = $8000 "Sprites"  //Index = $0200
	.import binary "./assets/sprites/sprites.bin"
	.fill 64,0