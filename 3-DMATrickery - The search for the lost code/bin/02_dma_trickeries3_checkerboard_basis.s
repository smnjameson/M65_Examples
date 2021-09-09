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


	Loop:
	    //Wait for raster = $ff once per frame
	    lda	#$fe 
	    cmp $d012
	    bne *-3
	    lda #$ff
	    cmp $d012
	    bne *-3

        inc $d020
	    jsr CopyScreenDMA
        dec $d020

	    jmp Loop
}

CopyScreenDMA: {
	   RunDMAJob(job)
	   rts
	job:
	   DMAHeader(0,0)
	   //DMAStep($00,$80,$01,$00) // checkerboard size x2
       //DMAStep($00,$40,$01,$00) // checkerboard size x4

	   DMACopyJob(ScreenData, $0800, 1000, false, false)
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