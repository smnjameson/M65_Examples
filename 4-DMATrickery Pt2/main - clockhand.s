.cpu _45gs02				
#import "../_include/m65macros.s"

.const COLOR_RAM = $ff80000
.const ROW_SIZE = 40
.const LOGICAL_ROW_SIZE = ROW_SIZE * 2
.const BITMAP_DATA = $10000


* = $02 "Basepage" virtual
	ScreenVector: .word $0000
	MapVector:	.dword $00000000
	ZP_CENTER: .dword $00000000

BasicUpstart65(Entry)
* = $2016 "Basic Entry"

Entry: {
		sei 
		lda #$35
		sta $01

		enable40Mhz()
		enableVIC4Registers()
		disableC65ROM()

		//Disable CIA interrupts
		lda #$7f
		sta $dc0d
		sta $dd0d

		//Disable IRQ raster interrupts
		//because C65 uses raster interrupts in the ROM
		lda #$00
		sta $d01a


		lda #%00000111
		trb $d016

		cli


		//Now setup VIC4

		lda #%00000101		//Set bit2=FCM for chars >$ff,  bit0=16 bit char indices
		sta $d054

		//40 column
		lda #$80
		trb $d031

		lda #$00
		sta $d020
		lda #$0b
		sta $d021


		jsr InitScreenAndColor
		
		jsr ClearBitmap

		
		lda #$00
		sta ZP_CENTER + 0
		sta ZP_CENTER + 3
		lda #$52
		sta ZP_CENTER + 1
		lda #$01
		sta ZP_CENTER + 2


			ldz #$00
			ldx #$00
		!:
			lda StartAddrLo, x 
			sta ZP_CENTER + 0
			lda StartAddrHi, x 
			sta ZP_CENTER + 1
			lda #$05
			sta ((ZP_CENTER)), z
			inx 
			bne !-

	loop:
		//wait for raster
		lda #$fe
		cmp $d012 
		bne *-3 
		lda #$ff 
		cmp $d012 
		bne *-3 

		inc $d020
			jsr ClearBitmap
			jsr UpdateLine
			jsr DrawLine

			lda #$02
			ldz #$00
			sta ((ZP_CENTER)), z

	


		dec $d020

		jmp loop
}

LineAngle:
	.byte $00
UpdateLine: {
	// AccValues
	// StartAddrLo
	// StartAddrHi
	// Slopes	
	ldx LineAngle
	lda AccLSBValues, x 
	sta DrawLine.AccLSBValue	
	lda AccValues, x 
	sta DrawLine.AccValue
	lda StartAddrLo, x 
	sta DrawLine.StartAddr + 0
	lda StartAddrHi, x 
	sta DrawLine.StartAddr + 1
	lda Slopes, x 
	sta DrawLine.Slope
	lda Lengths, x 
	sta DrawLine.Length

	inc LineAngle
	rts
}



DrawLine: {
		RunDMAJob(job)
		rts

	job:
		DMAHeader(0,0)
		//Enable line draw
		.label Slope = * + 1
		.byte $8f, %10000000  //Bit 7 = Enable, Bit6=enable y slope, bit 5=neg slope
		//X column bytes
		//To move from char-column0-byte7 to char-column1-byte0
		//we need to add 16 * 64 - 8 (rows * bytesPerChar - charWidth) 
		.byte $87, <[16 * 64 - 8]
		.byte $88, >[16 * 64 - 8]
		//Y Row bytes
		//To move from char-column0-row7 to char-column0-row8
		//we need to add nothing additional to other rows (size of a row in bytes) 
		.byte $89, 0
		.byte $8a, 0
		//Slope data
		.label AccLSBValue = * + 1
		.byte $8b, 0 //Slope (LSB) for line drawing
		.label AccValue = * + 1
		.byte $8c, 255 //Slope (MSB) for line drawing
		.byte $8d, 0 //Slope accumulator initial fraction (LSB) for line drawing
		.byte $8e, 128 //Slope accumulator initial fraction (MSB) for line drawing


		//End job option list 
		.byte $00

		.byte $03		//fill and last request
		.label Length = *
		.word $0020   	//size of copy/fill
		// .word getLength(111, 64)   	//size of copy/fill

		.word $0001 	//source address or source byte
		.byte $00		//source sub bank + additional params

		// .word $5200 	//dest address  
		.label StartAddr = *
		.word getEndPoint(159, 64) 	//dest address  
		.byte $01		//dest sub bank + additional params	

		.word $0000     //needed for chaining (unused bytes)	
}


//Screen memory position = floor(x/8) * (1024) + mod(x,8) + (y * 8)
.label BASE_POINT = $10000	//(160,64)  = floor(160/8) * (1024) + mod(160,8) + (64*8)
								//			= 20 * 1024 + 0 + 512
								//			= 20,992 = $5200
.label CENTERX = 160
.label CENTERY = 64
.label CENTER_POINT = getAddr(CENTERX, CENTERY) + BASE_POINT

.function getEndPoint(angle, length) {
	.var rad = (angle/256) * PI*2 + PI/2
	.return [getAddr( round(sin(rad) * length) + CENTERX, round(cos(rad) * length) * -1 + CENTERY) + BASE_POINT]
}
.function getAddr(x,y) {
	.return floor(x/8) * (1024) + mod(x,8) + (y * 8)
}
.function getLength(angle, length) {
	.var rad = (angle/256) * PI*2 + PI/2
	.return max(abs(round(sin(rad) * length)), abs(round(cos(rad) * length)))
}

/*
Treating East as 0 degrees
	ANGLE		   SLOPE    	ACC-DIR		START AT
	
	0-31  	     = slope x+ 	0-255 		center    
	32-63 	     = slope y+ 	255-0 		center
	64-95	     = slope y- 	0-255		center

	96-127	     = slope x- 	255-0		end 
	128-159	     = slope x+ 	0-255		end 
	160-191		 = slope y+     255-0		end
	192-223		 = slope y-     0-255		end

	224-255		 = slope x-	 	255-0		center

*/

AccLSBValues:
	.fill 32, 0
	.fill 32, 255
	.fill 32, 0
	.fill 32, 255
	.fill 32, 0
	.fill 32, 255
	.fill 32, 0
	.fill 32, 255
AccValues:
	.fill 32, i * $08 //$00-$f8
	.fill 32, (31-i) * $08 + $07 //$ff-$07
	.fill 32, i * $08 //$00-$f8
	.fill 32, (31-i) * $08 + $07 //$ff-$07
	.fill 32, i * $08 //$00-$f8
	.fill 32, (31-i) * $08 + $07 //$ff-$07
	.fill 32, i * $08 //$00-$f8
	.fill 32, (31-i) * $08 + $07 //$ff-$07

StartAddrLo:
	.fill 32, <[CENTER_POINT]
	.fill 32, <[CENTER_POINT]
	.fill 32, <[CENTER_POINT]
	.fill 32, <getEndPoint(i + 96, 32)
	.fill 32, <getEndPoint(i + 128, 32)
	.fill 32, <getEndPoint(i + 160, 32)
	.fill 32, <getEndPoint(i + 192, 32)
	.fill 32, <[CENTER_POINT]
StartAddrHi:
	.fill 32, >[CENTER_POINT]
	.fill 32, >[CENTER_POINT]
	.fill 32, >[CENTER_POINT]
	.fill 32, >getEndPoint(i + 96, 32)
	.fill 32, >getEndPoint(i + 128, 32)
	.fill 32, >getEndPoint(i + 160, 32)
	.fill 32, >getEndPoint(i + 192, 32)
	.fill 32, >[CENTER_POINT]
Slopes:
	.fill 32, %10000000
	.fill 32, %11000000
	.fill 32, %11100000
	.fill 32, %10100000
	.fill 32, %10000000
	.fill 32, %11000000
	.fill 32, %11100000
	.fill 32, %10100000
Lengths:
	.fill 256, getLength(i, 32)




InitScreenAndColor: {
		//Set screen up with relevant chars
		//Relocate screen RAM using $d060-$d063
		lda #<SCREEN_BASE 
		sta $d060 
		lda #>SCREEN_BASE 
		sta $d061
		lda #$00
		sta $d062
		sta $d063

		lda #<LOGICAL_ROW_SIZE
		sta $d058
		lda #>LOGICAL_ROW_SIZE
		sta $d059

		//Set number of chars per row
		lda #ROW_SIZE
		sta $d05e

		jsr ClearColorRam
		rts
}

ClearColorRam: {
		RunDMAJob(job)
		rts 
	job:
		DMAHeader(0,$ff)
		DMAFillJob(0,COLOR_RAM,1000*2,false)
}

ClearBitmap: {
		RunDMAJob(job)
		rts 
	job:
		DMAHeader(0,0)
		DMAFillJob(0, BITMAP_DATA, 320*128, false)
}


* = $7f00
	.fill 256, [mod(i,15) + 1]

* = $8000 "Screen"
SCREEN_BASE: {
	.for(var r=0; r<9; r++){
		.for(var c=0;c<40;c++){
			.byte 32,0
		}	
	}
	.for(var r=0; r<16; r++){
		.for(var c=0;c<40;c++){
			.var char = r + c * 16
			.byte [<char], [>char] + 4 //Chars start at $10000  = $0400 index
		}	
	}
}
