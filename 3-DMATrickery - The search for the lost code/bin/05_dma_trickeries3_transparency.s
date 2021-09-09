//1h54
.cpu _45gs02
#import "../_include/m65macros.s"

.const COLOR_RAM = $ff80000
.const SCREEN_RAM = $0800

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

	    cli


	    //Now setup VIC4
	    lda #%10100000    //Clear bit7=40 columns, bit5=disable extended attributes
	    trb $d031


	    //DMA jobs!!
	    jsr ClearScreenAndColor
        jsr CopyScreenDMA
        jsr CopyTransparentData

	Loop:
	    //Wait for raster = $ff once per frame
	    lda	#$fe 
	    cmp $d012
	    bne *-3
	    lda #$ff
	    cmp $d012
	    bne *-3

        inc $d020
        //Checker Scale
        //inc CopyScreenScaled.ScaleFactor + 0
	    //jsr CopyScreenScaled


        
        dec $d020

	    jmp Loop
}

CopyTransparentData: {
	    lda #<TransparentData
	    sta SourceLo
	    lda #>TransparentData
	    sta SourceHi
	    lda #<SCREEN_RAM
	    sta DestLo
	    lda #>SCREEN_RAM
	    sta DestHi

	    ldx #$07
	!:
        RunDMAJob(job)

        lda DestLo
        clc
        adc #$28
        sta DestLo
        lda DestHi
        adc #$00
        sta DestHi

        lda SourceLo
        clc
        adc #$08
        sta SourceLo
        lda SourceHi
        adc #$00
        sta SourceHi

        dex
        bpl !-
        rts
    job:
        DMAHeader(0,0)
        DMAEnableTransparency($20)
       .label SourceLo = * + 4
       .label SourceHi = * + 5
       .label DestLo   = * + 7
       .label DestHi   = * + 8
        DMACopyJob(TransparentData, $0800,8,false,false)
}
CopyScreenDMA: {
        RunDMAJob(job)
        rts
    job:
        DMAHeader(0,0)
        DMACopyJob(ScreenData, $0800,1000,false,false)
}
CopyScreenScaledDMA: {
	   lda #$00
	   sta RowCounter + 0 //Frac
	   sta RowCounter + 1 //Integer

       lda #<SCREEN_RAM
       sta DestLo
       lda #>SCREEN_RAM
       sta DestHi

	   ldx #$00
	!:
	   ldy RowCounter + 1
	   lda RowsLo, y
	   sta SourceLo
	   lda RowsHi, y
	   sta SourceHi

	   lda ScaleFactor + 0
	   sta SourceFracStep
	   lda ScaleFactor + 1
	   sta SourceStep

	   RunDMAJob(job)
	   
	   //Increment source data row
	   lda RowCounter +  0
	   clc
       adc ScaleFactor + 0
       sta RowCounter  + 0
       lda RowCounter  + 1
       adc ScaleFactor + 1
       sta RowCounter  + 1

	   //Increment destination row
	   lda DestLo +  0
	   clc
	   adc #$28
       sta DestLo  + 0
       lda DestLo  + 1
       adc #$00
       sta DestLo  + 1

       inx
	   cpx #$19
	   bne !-

	   rts
	job:
	   DMAHeader(0,0)
 
       .label SourceFracStep = * + 1
       .label SourceStep     = * + 3
       .label DestFracStep   = * + 5
       .label DestStep       = * + 7
       DMAStep($01,$00,$01,$00)

       .label SourceLo = * + 4
       .label SourceHi = * + 5
       .label DestLo   = * + 7
       .label DestHi   = * + 8
	   DMACopyJob(ScreenData, $0800, 40, false, false)
    
    ScaleFactor:
        .byte $01,$00
    RowCounter:
        .byte 0,0
	RowsHi:
	    .fill 25, >[ScreenData + 40 * i]
	RowsLo:
	    .fill 25, <[ScreenData + 40 * i]
}
    
ClearScreenAndColor:{
        RunDMAJob(job)
        rts       
        //$0 - $FFFFF bank 0
        //$100000 - $1FFFFF bank 1
    job:
        //DMAHeader($00, $ff)
        DMAHeader($00, COLOR_RAM >> 20)
        DMAFillJob($00, COLOR_RAM, 1000, true)
        DMAHeader($00, SCREEN_RAM >> 20)
        DMAFillJob($20, COLOR_RAM, 1000, false)
}

ScreenData: {
	.var char = 160
	.for(var r=0; r<25; r++) {
		.for(var c=0; c<40; c++) {
			 .byte char
			 .eval char = char ^ 128
		}
		.eval char = char ^ 128
	}
}

TransparentData:
//    .byte $20,$20,$a0,$a0,$a0,$a0,$20,$20
//    .byte $20,$a0,$a0,$a0,$a0,$a0,$a0,$20 
//    .byte $a0,$a0,$a0,$a0,$a0,$a0,$a0,$a0    
//    .byte $a0,$a0,$a0,$a0,$a0,$a0,$a0,$a0    
//    .byte $a0,$a0,$a0,$a0,$a0,$a0,$a0,$a0    
//    .byte $a0,$a0,$a0,$a0,$a0,$a0,$a0,$a0
//    .byte $20,$a0,$a0,$a0,$a0,$a0,$a0,$20
//    .byte $20,$20,$a0,$a0,$a0,$a0,$20,$20        

    .byte $20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$20,$20,$a0,$a0,$20,$20,$20 
    .byte $20,$20,$a0,$a0,$a0,$a0,$20,$20    
    .byte $20,$20,$a0,$a0,$a0,$a0,$20,$20    
    .byte $20,$20,$a0,$a0,$a0,$a0,$20,$20    
    .byte $20,$20,$a0,$a0,$a0,$a0,$20,$20    
    .byte $20,$20,$20,$a0,$a0,$20,$20,$20 
    .byte $20,$20,$20,$20,$20,$20,$20,$20

// Scroll Left - first iteration
//ShiftScreenDMA: {
//	    RunDMAJob(job)
//	    rts
//	job:
//        DMAHeader(0,0)
//        DMACopyJob($0801, $0800,999, false, false)
//}

// Scroll Left - Second iteration
ShiftScreenDMA: {
	    RunDMAJob(job)
	    rts
	job:
        DMAHeader(0,0)
        DMAStep(40,0,1,0)
        DMACopyJob($0800, TempColumn, 25, true, false)        
        
        DMAHeader(0,0)
        DMAStep(1,0,1,0)
        DMACopyJob($0801, $0800, 999, true, false)

        DMAHeader(0,0)
        DMAStep(1,0,40,0)
        DMACopyJob(TempColumn, $0827, 25, false, false)        

    TempColumn:
        .fill 25, 0
}