.cpu _45gs02				
#import "../_include/m65macros.s"

.const COLOR_RAM = $ff80000
.const ROW_SIZE = 40
.const LOGICAL_ROW_SIZE = ROW_SIZE * 2
.const BITMAP_DATA = $10000


* = $02 "Basepage" virtual
	ScreenVector: .word $0000
	MapVector:	.dword $00000000

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

		

	loop:
		//wait for raster
		lda #$fe
		cmp $d012 
		bne *-3 
		lda #$ff 
		cmp $d012 
		bne *-3 

		inc $d020
			jsr DrawLine
		dec $d020

		jmp loop
}


DrawLine: {
		RunDMAJob(job)
		rts

	job:
		DMAHeader(0,0)
		//Enable line draw
		.byte $8f, %10000001  //Bit 7 = Enable
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
		.byte $8b, 255 //Slope (LSB) for line drawing
		.byte $8c, 255 //Slope (MSB) for line drawing
		.byte $8d, 255 //Slope accumulator initial fraction (LSB) for line drawing
		.byte $8e, 255 //Slope accumulator initial fraction (MSB) for line drawing


		//End job option list 
		.byte $00

		.byte $03 		//Fill and last request
		.word $0064   	//size of copy/fill

		.word $0001 	//source address or source byte
		.byte $00		//source sub bank + additional params

		.word $0000 	//dest address  
		.byte $01		//dest sub bank + additional params	

		.word $0000     //needed for chaining (unused bytes)	





}

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
