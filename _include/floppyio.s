* = * "Floppy IO code"

.macro FLOPPY_LOAD(addr, fname) {
		bra !+
	FileName:
		.text fname
		.byte $00
	!:
		lda #<addr				
		ldx #>addr
		ldy #[[addr & $ff0000] >> 16]
		jsr FLOPPYIO.SetLoadAddress
		ldx #<FileName
		ldy #>FileName
		jsr FLOPPYIO.LoadFile
}



FLOPPYIO: {
	.align $10 //Keep these vars bytes from crossing a page
	
	.const BASEPAGE = >*
	FileNamePtr:		.word $0000
	BufferPtr:			.word $0000
	NextTrack:			.byte $00
	NextSector:			.byte $00
	PotentialTrack:		.byte $00
	PotentialSector:	.byte $00
	SectorHalf:			.byte $00



	SetLoadAddress: {
			sta DMACopyToDest + 0
			stx DMACopyToDest + 1
			sty DMACopyToDest + 2
			rts
	}

	LoadFile: {
		  	lda #BASEPAGE
	  		tab 

			stx <[FileNamePtr + 0]
			sty <[FileNamePtr + 1]

			//First get directory listing track/sector
			ldx #40
			ldy #0
			jsr ReadSector
			bcs !FileNotFoundError+
		!:

			//Read first directory
			jsr CopyToBuffer 
		  	ldx $0200 //track
		  	ldy $0201 //sector

		!NextDirectoryPage:
			jsr FetchNext
			jsr CopyToBuffer

	  		//Get first entry  pointer to next track/sector
	  		ldy #$00 
	  		ldx #$00 //Store For beginning of entry
	  	!LoopEntry:
	  		lda (<BufferPtr), y
	  		beq !+	//Dont store next track if 0
	  		sta <NextTrack
	  	!:
	  		iny

	  		lda (<BufferPtr), y
	  		beq !+ //Dont store next sector if 0
	  		sta <NextSector
	  	!:
	  		iny

	  		//FileType 
	  		lda (<BufferPtr), y
	  		iny

	  		//Get this entries track/sector info
	  		lda (<BufferPtr), y
	  		beq !FileNotFoundError+ //Track 00 implies no file here
	  		sta <PotentialTrack
	  		iny

	  		lda (<BufferPtr), y
	  		sta <PotentialSector
	  		iny
	  		

	  		ldz #$00
	  	!FilenameLoop:
			lda (<BufferPtr), y
			cmp #$a0
			beq !FileFound+
			cmp (<FileNamePtr), z 
			bne !NextEntry+
			iny
			inz 
			cpz #$10
			bne !FilenameLoop-

		!FileFound:
			txa 
			clc 
			adc #$1e 
			tay 

			//If a match set track/sector
			lda <PotentialTrack
			sta <NextTrack
			lda <PotentialSector
			sta <NextSector

			jmp FetchFile

	  	!NextEntry:
	  		//advance $20 bytes to next entry
	  		txa 
	  		clc
	  		adc #$20 
	  		tax 
	  		tay
	  		bcc !LoopEntry-

	  		//If crossing page is it still in the sector buffer?
	  		jsr AdvanceSectorPointer //Returns 0 if we need to fetch next sector buffer
	  		bne !LoopEntry-

	  		//Otherwise we need to fetch new sector buffer
	  		ldx <NextTrack
	  		ldy <NextSector
	  		jmp !NextDirectoryPage-

		!FileNotFoundError:
			//Fall through into Floppy error below
	}
	FloppyError:
	FloppyExit:
			lda #$00
			sta $d080
			rts		
	


	FetchFile: {
		!LoopFetchNext:
			ldx <NextTrack
			ldy <NextSector
			jsr FetchNext
			jsr CopyToBuffer
			
		!LoopFileRead:	
			ldy #$00
			lda (<BufferPtr), y 
			sta <NextTrack
			tax 
			iny 

			lda (<BufferPtr), y 
			sta <NextSector
			taz
			dez
			iny 

			lda #$fe
			cpx #$00
			bne !+
			tza 
		!:
			sta DMACopyToDestLength
			jsr CopyFileToPosition	

			lda <NextTrack
			beq !done+


			//Increase dest
			clc
			lda DMACopyToDest + 0
			adc #$fe
			sta DMACopyToDest + 0
			bcc !+
			inc DMACopyToDest + 1
			bne !+
			inc DMACopyToDest + 2
		!:
			

			jsr AdvanceSectorPointer //Returns 0 if we need to fetch next sector buffer
	  		bne !LoopFileRead-

	  		//Otherwise we need to fetch new sector buffer
	  		jmp !LoopFetchNext-

		!done:
			bra FloppyExit
	}


	CopyFileToPosition: {
			lda #$02
			clc
			adc <SectorHalf
			sta DMACopyToDestSource + 1
			
			// Execute DMA job
			lda #$00
			sta $d702
			sta $d704
			lda #>DMACopyToDestination
			sta $d701
			lda #<DMACopyToDestination
			sta $d705
			rts	
	}


	AdvanceSectorPointer: {
			inc <[BufferPtr + 1]
	  		lda <SectorHalf
	  		eor #$01
	  		sta <SectorHalf
	  		rts
	}

	FetchNext: {
			jsr ReadSector
			bcc !+
			// abort if the sector read failed
		  	pla 
		  	pla	//break out of the parent method 
		!:
			rts 
	}


	ReadSector: {	 
	  	  	// motor and LED on
		  	lda #$60
		  	sta $d080
		  	// Wait for motor spin up
		  	lda #$20
		  	sta $d081
	  	
		  	//(tracks begin at 0 not 1)
		  	dex 
			stx $d084 //Track

			//Convert sector
			tya 
			lsr //Carry indicates we need second half of sector
			tay
			//(sectors begin at 1, not 0)
			iny
			sty $d085 //Sector			
			lda #$00
			sta $d086 //side - always 0
			adc #$00  //Apply carry to select sector
			sta <SectorHalf


		  	// Read sector
 		  	lda #$41
		  	sta $d081
	  		//WaitForBusy
	  	!:
		  	lda $d082
		  	bmi !-

	  		//Check for read error
		  	lda $d082
		  	and #$18
		  	beq !+

		  	// abort if the sector read failed
		  	sec
		  !:
		  	rts
	}


	CopyToBuffer: {
	  		jsr CopySector
	  		ldx #$00
	  		stx <[BufferPtr + 0]
	  		lda #$02
	  		//Carry is always already clear here
	  		adc <SectorHalf
	  		sta <[BufferPtr + 1]
	  		rts
	}

	CopySector: {
			//Set pointer to buffer
			//Select FDC buffer
			lda #$80
			trb $d689

			// Execute DMA job
			lda #$00
			sta $d702
			sta $d704
			lda #>DMACopyBuffer
			sta $d701
			lda #<DMACopyBuffer
			sta $d705
			rts	
	}

	//DMA Job to copy from buffer at $200-$3FF to destination
	DMACopyToDestination:
        .byte $0A  // Request format is F018A
        .byte $80,$00 // Source is $00
        .byte $81,$00 // Destination is $00
        .byte $00  // No more options
        // F018A DMA list
        .byte $00 // copy + last request in chain
    DMACopyToDestLength:
        .word $00fe // size of copy
    DMACopyToDestSource:    
        .word $0202 // starting at
        .byte $00   // of bank
	DMACopyToDest:	
        .word $0800 // destination addr
        .byte $00   // of bank
        // .word $0000 // modulo (unused)


    //DMA Job to copy 512 bytes from sector buffer
    //at $FFD6C00 to temp buffer at $200-$3ff
	DMACopyBuffer:
        .byte $0A  // Request format is F018A
        .byte $80,$FF // Source MB is $FFxxxxx
        .byte $81,$00 // Destination MB is $00xxxxx
        .byte $00  // No more options
        //F018A DMA list
        .byte $00 // copy + last request in chain
        .word $0200 // size of copy
        .word $6C00 // starting at
        .byte $0D   // of bank
        .word $0200 // destination addr
        .byte $00   // of bank
        // .word $0000 // modulo (unused)



}