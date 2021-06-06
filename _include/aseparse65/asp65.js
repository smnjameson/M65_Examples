const Aseprite = require('ase-parser');
const fs = require('fs');
const path = require('path');

//Define parameters
const yargs = require('yargs/yargs')
const { hideBin } = require('yargs/helpers')
const argv = yargs(hideBin(process.argv))
	.command('parse', 'Convert an image to tilemaps', () => {}, (argv) => {
		runTileMapper(argv)
	})
	.command('sprites', 'Convert an image to spritemaps', () => {}, (argv) => {
		runSpriteMapper(argv)
	})			
    .option('input', {
        alias: 'i',
        description: 'The path to the Aseprite file - eg: ./images/myimage.aseprite',
        type: 'string',
    })
    .option('nodedupe', {
        alias: 'n',
        description: 'Turn off remove duplicate chars when getting map data',
        type: 'boolean',
    })    
    .option('base', {
        alias: 'b',
        description: 'Memory location of TILE_BASE or SPRITE_BASE - eg: 0x7000',
        type: 'number',
    })  
    .option('output', {
        alias: 'o',
        description: 'Folder to output files to - eg: ./output',
        type: 'string',
    })  
 	.option('spriteheight', {
        alias: 's',
        description: 'Height of sprites (in chars, eg 48px = 6chars) in spritemapper output - eg: 6',
        type: 'number',
    })  
 	.option('spritepad', {
        alias: 'd',
        description: 'adds sprite padding',
        type: 'boolean',
    })  
 	.option('preserve', {
        alias: 'p',
        description: 'Preserves palette information  and does NOT reorder and recalculate',
        type: 'boolean',
    })       
    .help()
    .alias('help', 'h')
    .argv;




function getAseFile(path) {
	//Try to load the file
	let buff, aseFile
	try {
		buff = fs.readFileSync(path);
		aseFile = new Aseprite(buff, 'output.aseprite');
		aseFile.parse();
	} catch(e) {
		console.log(e);
		process.exit(1);
	}
	if(aseFile.colorDepth !== 8) {
		console.log("asp65 currently does not support 32 bit color aseprite files. Please use indexed color");
		process.exit(1);
	}	
	return aseFile;
}


function setOutputPath(path) {
	let outputPath = path || "./"
	if(!fs.existsSync(outputPath)) {
		fs.mkdirSync(outputPath);
	}
	return outputPath;
}


function createBlankTile() {
	return {
		data: new Array(128).fill(0),
		str: new Array(128).fill(0).join(","),
		pal: [],
		slice: 0
	};
}


function getPaletteDataFromASE(aseFile) {
	let palette = [];
	for(var c=0; c<aseFile.palette.colors.length; c++) {
		let pal = {
			red: aseFile.palette.colors[c].red,
			green: aseFile.palette.colors[c].green,
			blue: aseFile.palette.colors[c].blue,
			alpha: aseFile.palette.colors[c].alpha,
			useCount: 0,
			originalIndex: palette.length
		};
		palette.push(pal); 
	}
	console.log("Palette size: " + palette.length+" colors");
	return palette;	
}


function getCols(data) {
	var cols = []
	for(var j=0; j<data.length; j++) {
		if(cols.indexOf(data[j]) === -1 && data[j] !== 0) {
			cols.push(data[j])
		}
	}
	return cols
}	



function findBestMatch(cols, p) {
	let cnt = new Array(16).fill(0)

	//Find matches in each palette slice
	for(var i=0; i<16; i++) {
		for(var j=0; j<cols.length; j++) {
			if(p[i].indexOf(cols[j]) >-1) cnt[i]++
		}
		//If not enough room in palette ignore
		if((cols.length - cnt[i]+ p[i].length) > 16) {
			cnt[i] = -1
		}
	}	

	var most = -1
	for(var i=0; i<16; i++) {
		if(cnt[i] > -1) {
			if(most === -1 || (cnt[i] > cnt[most])) {
				most = i
			}
		}
	}

	if(most !== -1) {
		for(var i=0; i<cols.length; i++) {
			if(p[most].indexOf(cols[i]) === -1) {
				p[most].push(cols[i])
			} 
		}
	} else {
		//IF MOST === -1 NOT ENOUGH PALETTE ROOM	
		console.log("ERROR PALETTE TO SMALL")
	}
	return most
}


function nswap(a) {
	return (((a & 0xf) << 4) | ((a>>4)&0xf))
}




function getTilesFromCels(cels, palette, chars, dedupe) {
	let w = cels.w + cels.xpos;
	let h = cels.h + cels.ypos;

	let mapdata = []

	var tilewidth = 16; //TODO

	let totalCount = 0
	let dedupedCount = 0
	for(var y=0; y< h; y+=8) {
		for(var x=0; x< w; x+=tilewidth) {
			let char = {
				data: [],
				str: "",
				pal: [],
				slice: 0
			}	

			//Get tile
			for(var yy=0; yy<8; yy++) {
				for(var xx=0; xx<tilewidth; xx++) {
					if(((y+yy) < cels.ypos) || ((x+xx) < cels.xpos)) {
						char.data.push( 0 )
					} else {
						let idx = ((y + yy - cels.ypos) * cels.w) + ((x + xx - cels.xpos))
						char.data.push( cels.rawCelData[idx] )
						if(cels.rawCelData[idx]) palette[cels.rawCelData[idx]].useCount++;
					}

				}
			}


			char.str = char.data.join(",") 
		
			//Check for dupes
			let found = -1
			if(dedupe) {
				for(var i=0; i<chars.length; i++) {
					if(char.str === chars[i].str){
						found = i;	
						break;
					} 
				}
				if(found === -1) {
					found = chars.length
					chars.push(char)
					dedupedCount++
				} 
			} else {
					found = chars.length
					chars.push(char)
			}
			mapdata.push( found )

			totalCount++

		}
	}

	return {
		mapdata, totalCount, dedupedCount
	}
}


function generatePalettesFromChars(chars, palette, preserve) {
		//Create palette list
		let p = new Array()
		for(let i=0; i<16; i++) p.push([0])

		// Sort palettes
		for(let i=0; i<chars.length; i++) {
			let char = chars[i]
			let cols = getCols(char.data)
			char.pal = cols
			if(cols.length && !preserve) {
				if(char.data.length === 128) {
					char.slice = findBestMatch(cols, p) //4bit
				} else {
					char.slice = -1
				}
			} else if(cols.length) {
				char.slice = (cols[0] & 0xf0) >> 4
				// console.log(char.data)
			}
		}

		for(var i=0; i<16; i++) {
			while(p[i].length < 16) {
				p[i].push(0)
			}
		}

		///////////////////////////////////////////
		//GENERATE palettes
		///////////////////////////////////////////
		let pal = {r:[],g:[],b:[]}

		for(var s=0; s<16; s++) {
			for(var i=0; i<16; i++){


				let col = p[s][i]

				if(preserve) {
					col = i + s * 16
					// console.log(col)
				}

				let red = (palette[col] && palette[col].red) || 0
				let grn = (palette[col] && palette[col].green) || 0
				let blu = (palette[col] && palette[col].blue) || 0

				pal.r.push(nswap(red))
				pal.g.push(nswap(grn))
				pal.b.push(nswap(blu))
			}
		}

		return {pal, p}
}


function getCharDataFromChars(chars, p, preserve) {
	let charcols = [];
	let chardata = [];

	for(let i=0; i<chars.length; i++) {
		let c = chars[i]
		charcols.push((c.slice << 4) + 0x0f)

		let toggle = 0;
		let data = 0
		for(var j=0;j<c.data.length;j++) {	

			let val = p[c.slice].indexOf(c.data[j])
			if(preserve) {
				val = (c.data[j] & 0x0f)	
			}
			if(val <0) val = 0
			data = data + val
			toggle++
			if(toggle===2) {
				toggle=0
				data = nswap(data)
				chardata.push(data)
				data=0
			} else {
				data = data << 4
			}
		}
	}
	return {charcols, chardata};
}




function runSpriteMapper(argv) {
	let spriteHeight = argv.spriteheight || 2
	let aseFile = getAseFile(argv.input)
	let outputPath = setOutputPath(argv.output)

	let chars = []
	let palette = getPaletteDataFromASE(aseFile)

	let cels = aseFile.frames[0].cels[0]
	let layer = aseFile.layers[0]
	
	let spritebase = parseInt(argv.base) || 0
	console.log("____________________________________");
	console.log("____ Sprite Generation          ____");
	console.log("____________________________________");
	console.log("\\____ Dimensions "+aseFile.width + " x "+aseFile.height);
	console.log(" \\___ Processing cels @"+cels.xpos+","+cels.ypos);

	let aw = aseFile.width;
	let ah = aseFile.height;
	let cw = cels.w + cels.xpos;
	let ch = cels.h + cels.ypos;

	let tiledata = getTilesFromCels(cels, palette, chars, false)


	//palettes
	let genPalettes = generatePalettesFromChars(chars, palette, argv.preserve)
	let pal = genPalettes.pal  //RGB palette for binary
	let p = genPalettes.p      //Internal palette structure, required for getCharDataFromChars
	fs.writeFileSync( path.resolve(outputPath,"sprite_palred.bin"), Buffer.from(pal.r))
	fs.writeFileSync( path.resolve(outputPath,"sprite_palgrn.bin"), Buffer.from(pal.g))
	fs.writeFileSync( path.resolve(outputPath,"sprite_palblu.bin"), Buffer.from(pal.b))


	//reorder sprites
	//Create sprite index and RLE packed sprite list
	
	let nChars = []
	let spriteIndex = []
	let spriteData = []

	let h = Math.ceil(ch/(8*spriteHeight))
	let w = Math.ceil(cw/16)
	for(var y=0; y<h; y++) {
		for(var x=0; x<w; x++) {
			let c = x + y * w * spriteHeight;
			if(argv.spritepad) {
				nChars = [ createBlankTile()]
			} else {
				nChars = []
			}
			for(var s=0; s<spriteHeight; s++) {
				nChars.push(chars[c + w * s])
			}

			let cd = getCharDataFromChars(nChars, p, argv.preserve).chardata
			let rle = rleData(cd)

			spriteIndex.push( 	(spriteData.length + spritebase) & 0xff,
								((spriteData.length + spritebase) >> 8) & 0xff,
								((spriteData.length + spritebase) >> 16) & 0xff,
								0,0,0,0,0 );

			// console.log("Sprite index " + (spriteData.length + spritebase))
			spriteData = spriteData.concat(rle)
		}
	}


	fs.writeFileSync( path.resolve(outputPath,"sprite_index.bin"), Buffer.from(spriteIndex))
	fs.writeFileSync( path.resolve(outputPath,"sprites.bin"), Buffer.from(spriteData))
	// console.log(ccData.chardata.length,cw,ch)
}

function rleData(buf) {
	return buf;

    let out = []
    let char = -1
    let count = 0   
 
    for(var i=0; i<buf.length; i++) {
        //Flush
        if(buf[i] !== char || count === 62 || i === buf.length-1) {
            if(char !== -1) {
                if(count === 1) {
                    out.push(char)
                } else if(count > 1 && char !== 0) {
                    out.push(count + 128)
                    out.push(char)
                } else if(count > 1 && char === 0) {
                    out.push(count + 192)
                }
            }
            count = 0;
            char = buf[i]
        }
        count++;
    }
    out.push(255)

    return out 
}




function runTileMapper(argv) {
		let aseFile = getAseFile(argv.input)
		let outputPath = setOutputPath(argv.output)
 
		//Output file details
		console.log("Layer count : " + aseFile.layers.length)

		let chars = [createBlankTile()]
		let layers = []
		let palette = getPaletteDataFromASE(aseFile)
		let mapdata = new Array(aseFile.layers.length)
		let mapdimensions = new Array(aseFile.layers.length)


		//Tile details
		let tw=1
		let th=2
		let tilebase = parseInt(argv.base) || 0

		//Process layers into chars and tiles
		console.log("\nPROCESSING "+aseFile.frames[0].cels.length+" cel arrays")

		for (var lyr = 0; lyr < aseFile.frames[0].cels.length; lyr++) {
			mapdata[lyr] = []

			let layer = aseFile.layers[lyr]
			let cels = aseFile.frames[0].cels[lyr]


			let w = cels.w + cels.xpos;
			let h = cels.h + cels.ypos;

			let tilewidth = 16;
			mapdimensions[lyr] = [(w/tilewidth), (h/8)]

			console.log("____________________________________");
			console.log("\\____ Layer #"+lyr+" - " + layer.name);
			console.log("   \\___ Dimensions "+w+" x " + h);
			console.log("    \\__ Map "+(w/tilewidth / tw)+" x " + (h/8 / th));
			console.log("     \\_ Processing cels @"+cels.xpos+","+cels.ypos+"   tile width: "+tilewidth)

			let tiledata = getTilesFromCels(cels, palette, chars, !argv.nodedupe)

			mapdata[lyr] = tiledata.mapdata
			// console.log("      \\___ Offset char  = " + offset)
			console.log("       \\__ Total char count = " + tiledata.totalCount)
			console.log("        \\_ Deduped char count = " + tiledata.dedupedCount + "\n\n")
		}

		
		let genPalettes = generatePalettesFromChars(chars, palette, argv.preserve)
		let pal = genPalettes.pal  //RGB palette for binary
		let p = genPalettes.p      //Internal palette structure, required for getCharDataFromChars

		fs.writeFileSync( path.resolve(outputPath,"palred.bin"), Buffer.from(pal.r))
		fs.writeFileSync( path.resolve(outputPath,"palgrn.bin"), Buffer.from(pal.g))
		fs.writeFileSync( path.resolve(outputPath,"palblu.bin"), Buffer.from(pal.b))


		////////////////////////////////////
		// GENERATE TILESETS 
		////////////////////////////////////
		let ccData = getCharDataFromChars(chars, p, argv.preserve)
		var chardata = ccData.chardata
		var charcols = ccData.charcols


		/////////////////////////////////////////////////////////////////////
		//If tw or th are more than 1 then start to form tiles//
		/////////////////////////////////////////////////////////////////////
		var maptiles = []
		// if(tw >1 || th > 1) {
		console.log("____________________________________");	
		console.log("\\____ Tile generation @ "+tw+"x"+th);
		let count = 0

		for (var lyr = 0; lyr < aseFile.frames[0].cels.length; lyr++) {
			if(mapdata[lyr]) {
				let data = []
				
				for(var y=0; y<mapdimensions[lyr][1]; y+=ty) {
					for(var x=0; x<mapdimensions[lyr][0]; x+=tw) {
						count++
						let i = y * mapdimensions[lyr][0] + x 

						let tile = {
							data:[],
							str:""
						}

						for(var ty=0; ty<th; ty++) {
							for(var tx=0; tx<tw; tx++) {
								let off = ty * mapdimensions[lyr][0] + tx 
								off = i + off

								// console.log(mapdata[lyr][off], charcols[mapdata[lyr][off]])
								tile.data.push(	mapdata[lyr][off] & 0xff , 
												( (mapdata[lyr][off] >> 8) & 0x0f) + 
												  (charcols[mapdata[lyr][off]] & 0xf0) )
							}
						}

						tile.str = tile.data.join(",")

						var found = -1
						for(var j=0; j<maptiles.length; j++) {
							if(maptiles[j].str === tile.str) {
								found = j
								break
							}
						}
						if(found===-1) {
							found = maptiles.length
							maptiles.push(tile)
							
						} 
						data.push(found)
					}
				}

				mapdata[lyr] = []
				for(var i=0; i<data.length; i++) {
					data[i] = data[i] * (tw*th*2) + (tilebase & 0xffff)
					mapdata[lyr].push(data[i] & 0xff, data[i] >> 8)
				}

			}
		}
		console.log("   \\__ Total tile count = " + count)
		console.log("    \\_ Deduped tile count = " + maptiles.length)	


		maptiles = maptiles.map(a => a.data)
		maptiles = maptiles.join(",").split(",")
		fs.writeFileSync( path.resolve(outputPath,"tiles.bin"), Buffer.from(maptiles))
		fs.writeFileSync( path.resolve(outputPath,"chars.bin"), Buffer.from(chardata))


		let cData= []
		for (var lyr = 0; lyr < aseFile.frames[0].cels.length; lyr++) {
			
			if(mapdata[lyr]) {
				cData = cData.concat(mapdata[lyr])
				fs.writeFileSync( path.resolve(outputPath,"map_"+aseFile.layers[lyr].name+".bin"), Buffer.from(mapdata[lyr]))
			}
			
		}
		fs.writeFileSync( path.resolve(outputPath,"map_all.bin"), Buffer.from(cData))
}







