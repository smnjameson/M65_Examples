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

		lda #$ff
		sta $d020
		lda #$ff
		sta $d021


		jsr SetPalette
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

		lda #$01
		sta $d020
			jsr ClearBitmap
		lda #$80
		sta $d020
			jsr UpdateLine
		lda #$ff
		sta $d020

		jmp loop
}


SetPalette: {
		lda #%00000000
		sta $d070

		ldx #$00
	!:
		txa 
		neg
		and #$0f
		asl 
		asl 
		asl 
		asl 
		sta RestA 
		txa 
		neg
		lsr 
		lsr 
		lsr
		lsr 
		ora RestA:#$BEEF
		sta $d100, x

		asl
		sta $d200, x
		asl
		sta $d300, x
		neg
		inx
		bne !-
		rts

}

.label LINECOUNT = 127
UpdateLine: {
			//X1
			ldx #$00
			ldy #$00
		Loop1:

			lda dx1, x 
			bmi !n+
		!p:
			lda x1 + 0, y
			clc 
			adc dx1, x 
			sta x1 + 0, y
			bcc !+
			pha
			lda x1 + 1, y
			adc #$00
			sta x1 + 1, y
			pla
		!:
			cmp #$3c 
			bne !done+
			lda x1 + 1, y
			beq !done+
			lda dx1, x 
			neg
			sta dx1, x  
			bra !done+
		!n:
			lda x1 + 0, y
			clc 
			adc dx1, x 
			sta x1 + 0, y
			bcs !+
			pha
			lda x1 + 1, y
			sbc #$00
			sta x1 + 1, y
			pla
		!:
			cmp #$00
			bne !done+
			lda x1 + 1, y
			bne !done+
			lda dx1, x 
			neg
			sta dx1, x  
		!done:


			//X2
			lda dx2, x 
			bmi !n+
		!p:
			lda x2 + 0, y
			clc 
			adc dx2, x 
			sta x2 + 0, y
			bcc !+
			pha
			lda x2 + 1, y
			adc #$00
			sta x2 + 1, y
			pla
		!:
			cmp #$3c 
			bne !done+
			lda x2 + 1, y
			beq !done+
			lda dx2, x 
			neg
			sta dx2, x  
			bra !done+
		!n:
			lda x2 + 0, y
			clc 
			adc dx2, x 
			sta x2 + 0, y
			bcs !+
			pha
			lda x2 + 1, y
			sbc #$00
			sta x2 + 1, y
			pla
		!:
			cmp #$00
			bne !done+
			lda x2 + 1, y
			bne !done+
			lda dx2, x 
			neg
			sta dx2, x  
		!done:


			//y1
			lda dy1, x  
			bmi !n+
		!p:
			lda y1 + 0, y
			clc 
			adc dy1, x 
			sta y1 + 0, y
			cmp #$7c 
			bne !done+
			lda dy1, x 
			neg
			sta dy1, x  
			bra !done+
		!n:
			lda y1 + 0, y
			clc 
			adc dy1, x 
			sta y1 + 0, y
			cmp #$00 
			bne !done+
			lda dy1, x 
			neg
			sta dy1, x  
		!done:

			//y2
			lda dy2, x  
			bmi !n+
		!p:
			lda y2 + 0, y
			clc 
			adc dy2, x 
			sta y2 + 0, y
			cmp #$7c
			bne !done+
			lda dy2, x 
			neg
			sta dy2, x  
			bra !done+
		!n:
			lda y2 +0, y
			clc 
			adc dy2, x 
			sta y2 + 0, y
			cmp #$00 
			bne !done+
			lda dy2, x 
			neg
			sta dy2, x  
		!done:


			ldx #[LINECOUNT - 1]
			ldy #[LINECOUNT * 2 - 2]
		Loop2:
			//Copy
			lda x1 + 0, y
			sta DrawLineFast.x1 +0
			lda x1 + 1, y
			sta DrawLineFast.x1 +1
			lda y1 + 0, y
			sta DrawLineFast.y1 +0
			lda y1 + 1, y
			sta DrawLineFast.y1 +1
			lda x2 + 0, y
			sta DrawLineFast.x2 +0
			lda x2 + 1, y
			sta DrawLineFast.x2 +1
			lda y2 + 0, y
			sta DrawLineFast.y2 +0
			lda y2 + 1, y
			sta DrawLineFast.y2 +1

			txa 
			asl 
			clc 
			adc #$01
			sta DrawLineFast.color
			jsr DrawLineFast
			
			dex 
			dey
			dey
			cpx #$ff 
			lbne Loop2


			// inc Counter
			// lda Counter
			// and #$01
			// bne !skip+

			ldx #[LINECOUNT - 2]
			ldy #[LINECOUNT * 2 - 4]
		!:
			lda x1 + 0, y
			sta x1 + 2, y
			lda x1 + 1, y
			sta x1 + 3, y
			lda x2 + 0, y
			sta x2 + 2, y
			lda x2 + 1, y
			sta x2 + 3, y
			lda y1 + 0, y
			sta y1 + 2, y
			lda y1 + 1, y
			sta y1 + 3, y
			lda y2 + 0, y
			sta y2 + 2, y
			lda y2 + 1, y
			sta y2 + 3, y

			lda dx1 + 0, x 
			sta dx1 + 1, x
			lda dx2 + 0, x 
			sta dx2 + 1, x
			lda dy1 + 0, x 
			sta dy1 + 1, x
			lda dy2 + 0, x 
			sta dy2 + 1, x

			dey 
			dey
			dex 
			bpl !-

		!skip:
			rts



			* = * "x1"
	x1:
		.fill LINECOUNT, [$20,$00]
	x2:
		.fill LINECOUNT, [$20,$01]

	y1:
		.fill LINECOUNT, [$20,$00]
	y2:
		.fill LINECOUNT, [$60,$00]

	dx1:
		.fill LINECOUNT, $01
	dx2:
		.fill LINECOUNT, $fe
	dy1:
		.fill LINECOUNT, $02
	dy2:
		.fill LINECOUNT, $ff

	Counter:
		.byte $00
}



.const BITMAP_ROWS = 16 
.const BITMAP_BASE = $10000
DrawLineFast: {

		//Calculate deltax/deltay and absolute versions
		//DeltaX
		sec 
		lda x2 + 0
		sbc x1 + 0
		sta x + 0
		sta ax + 0
		lda x2 + 1
		sbc x1 + 1
		sta x + 1
		sta ax + 1
		bpl !+
		//Absolute if negative
		eor #$ff
		sta ax + 1
		lda ax + 0
		neg 
		sta ax + 0
	!:

		//DeltaY
		sec 
		lda y2 + 0
		sbc y1 + 0
		sta y + 0
		sta ay + 0
		lda y2 + 1
		sbc y1 + 1
		sta y + 1
		sta ay + 1
		bpl !+
		//Absolute if negative
		eor #$ff
		sta ay + 1
		lda ay + 0
		neg 
		sta ay + 0
	!:

		//Which slope
		lda ax + 1
		cmp ay + 1
		bcc !slopeY+
		bne !slopeX+
		lda ax + 0
		cmp ay + 0	
		bcc !slopeY+
	!slopeX: //AX >= AY
		lda #%10000000 //Enable slopeX
		sta SlopeType
		//Calculate which start point (negative = x2,y2)
		sec 
		lda x + 0
		sbc y + 0
		lda x + 1
		sbc y + 1
		sta TempVal
		lda ax + 0
		sta GradientDenom + 0
		sta l3 + 0	//length
		lda ax + 1
		sta GradientDenom + 1
		sta l3 + 1	//length
		lda ay + 0
		sta GradientNum + 0
		lda ay + 1
		sta GradientNum + 1
		bra !slopeDone+
	!slopeY: //AY > AX
		lda #%11000000 //Enable slopeY
		sta SlopeType
		//Calculate which start point (negative = x2,y2)
		sec 
		lda y + 0
		sbc x + 0
		lda y + 1
		sbc x + 1
		sta TempVal	
		lda ay + 0
		sta GradientDenom + 0
		sta l3 + 0	//length
		lda ay + 1
		sta GradientDenom + 1
		sta l3 + 1	//length
		lda ax + 0
		sta GradientNum + 0
		lda ax + 1
		sta GradientNum + 1			
	!slopeDone:

		//Quick sign(x * y) and set bit 5 in SlopeType
		lda x + 1
		eor y + 1
		and #$80
		lsr 
		lsr 
		ora SlopeType
		sta SlopeType 

		//Get start point address
		lda TempVal
		bmi !x2+
	!x1:
		lda x1 + 0
		sta x3 + 0
		lda x1 + 1
		sta x3 + 1
		lda y1 + 0
		sta y3 + 0
		lda y1 + 1
		sta y3 + 1
		bra !x3+
	!x2:
		lda x2 + 0
		sta x3 + 0
		lda x2 + 1
		sta x3 + 1
		lda y2 + 0
		sta y3 + 0
		lda y2 + 1
		sta y3 + 1	
	!x3:

	!getStartAddr:
		//floor(x/8) * (BITMAP_ROWS * 64) + mod(x,8) + (y * 8)

		//(BITMAP_ROWS * 64)
		lda #<[BITMAP_ROWS * 64]
		sta $d770	
		lda #>[BITMAP_ROWS * 64]
		sta $d771
		lda #$00	
		sta $d772	
		sta $d773

		//floor(x/8)
		lda x3 + 1
		lsr 
		lda x3 + 0
		ror 
		lsr
		lsr 	
		sta $d774
		lda #$00	
		sta $d775	
		sta $d776	
		sta $d777	

		//floor(x/8) * (BITMAP_ROWS * 64)
		lda $d778
		sta StartAddr + 0
		lda $d779
		sta StartAddr + 1

		//+ mod(x,8)
		lda x3 + 0
		and #$07
		clc 
		adc StartAddr + 0
		sta StartAddr + 0
		bcc !+
		inc StartAddr + 1
	!:
		//+ (y * 8)
		lda y3 + 0
		sta TempVal + 0
		lda y3 + 1
		sta TempVal + 1
		asw TempVal
		asw TempVal
		asw TempVal
		clc
		lda TempVal + 0
		adc StartAddr + 0
		sta StartAddr + 0
		lda TempVal + 1
		adc StartAddr + 1
		sta StartAddr + 1

		//Calculate slope value
		//GradientNum
		lda GradientNum + 0
		sta $d770	
		lda GradientNum + 1
		sta $d771
		lda #$00
		sta $d772	
		sta $d773

		//GradientDenom
		lda GradientDenom + 0
		sta $d774
		lda GradientDenom + 1
		adc #$00
		sta $d775
		lda #$00	
		sta $d776	
		sta $d777	


		lda $d76a //lsb
		sta SlopeLSB
		lda $d76b //msb
		sta SlopeMSB
		lda $d76c 
		beq !+
		lda #$ff
		sta SlopeLSB
		sta SlopeMSB
	!:



	!run:
		RunDMAJob(job)
		rts



	job:
		DMAHeader(0,0)
		//Enable line draw
		.label SlopeType = * + 1
		.byte $8f, %11100000  //Bit 7 = Enable, Bit6=enable y slope, bit 5=neg slope
		//X column bytes
		.byte $87, <[16 * 64 - 8]
		.byte $88, >[16 * 64 - 8]
		//Y Row bytes
		.byte $89, 0
		.byte $8a, 0
		//Slope data
		.label SlopeLSB = * + 1
		.byte $8b, 0 //Slope (LSB) for line drawing
		.label SlopeMSB = * + 1
		.byte $8c, 85 //Slope (MSB) for line drawing
		.byte $8d, 0 //Slope accumulator initial fraction (LSB) for line drawing
		.byte $8e, 128 //Slope accumulator initial fraction (MSB) for line drawing


		//End job option list 
		.byte $00
		.byte $03		//fill and last request
		.label l3 = *
		.word $0040   	//size of copy/fill
		.label color = *
		.word $0001 	//source address or source byte
		.byte $00		//source sub bank + additional params

		.label StartAddr = *
		.word $0000 	//dest address  
		.byte $01		//dest sub bank + additional params	
		.word $0000     //needed for chaining (unused bytes)




	GradientNum:
		.word $0000
	GradientDenom:
		.word $0000
	TempVal:
		.byte $00,$00
	x:
		.word $0000
	y: 
		.word $0000	
	ax:
		.word $0000	
	ay:
		.word $0000	
	x1:
		.word $0000
	x2:
		.word $0000
	x3:
		.word $0000
	y1:
		.word $0000
	y2:
		.word $0000
	y3:
		.word $0000
}
/*
	LINE FORMULA
	============

	var x = x2 - x1      
	var y = y2 - y1      
	var ax = abs(x)     
	var ay = abs(y)      

	if(ax > ay) {
		ATTRslope is x            
		var start = x - y  
		var denominator = ax
		var numerator = ay
	} else { 
		ATTRslope is y 			  
		var start = y - x  
		var denominator = ay
		var numerator = ax       
	}

	ATTRslopeIsNegative = sign(x * y)    

	if(start > 0) {
		ATTRstartLine @ (x1,y1)    
	} else {
		ATTRstartLine @ (x2,y2)	   
	}
	
	ATTRaccSlope = numerator / denominator   [min(ax,ay) / max(ax,ay)]

   



    ALTERNATE LINE FORMULA
    ======================
   	var x = x2 - x1      
	var y = y2 - y1      
	var ax = abs(x)     
	var ay = abs(y)

	if(ax > ay) {
		ATTRslope is x   
		var denominator = ax
		var numerator = ay		             
	} else { 
		ATTRslope is y 	
		var denominator = ay
		var numerator = ax  		        
	}

	ATTRslopeIsXNegative = x<0 
	ATTRslopeIsYNegative = y<0 

	ATTRstartLine @ (x1,y1) 
	
	ATTRaccSlope = numerator / denominator
*/

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
