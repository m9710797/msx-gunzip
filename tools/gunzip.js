if (process.argv.length < 3) {
	console.log("Usage: node " + process.argv[1] + " FILE.GZ");
	process.exit(1);
}

var fs = require('fs');

function main() {
	var filename = process.argv[2];
	
	var gunzip = new Gunzip(fs.readFileSync(filename));
	var inflate = gunzip.process();
	fs.writeFileSync(filename + ".inflated", inflate.getOutput());
}

function Gunzip(buffer) {
	this.buffer = buffer;
	this.position = 0;
}

Gunzip.prototype.readByte = function() {
	if (this.position >= this.buffer.length)
		throw new Error("Buffer exceeded.");
	return this.buffer[this.position++];
}

Gunzip.prototype.readWord = function() {
	return this.readByte() | this.readByte() << 8;
}

Gunzip.prototype.readDoubleWord = function() {
	return this.readWord() | this.readWord() << 16;
}

Gunzip.prototype.process = function() {
	if (this.readByte() != 31)
		throw new Error("Not a GZIP file.");
	if (this.readByte() != 139)
		throw new Error("Not a GZIP file.");
	if (this.readByte() != 8)
		throw new Error("Not compressed with DEFLATE.");
	var flags = this.readByte();
	var mtime = this.readDoubleWord();
	var xfl = this.readByte();
	var os = this.readByte();
	
	var FHCRC = 1 << 1;
	var FEXTRA = 1 << 2;
	var FNAME = 1 << 3;
	var FCOMMENT = 1 << 4;
	if (flags & FEXTRA) {
		var xlen = this.readWord();
		for (var i = 0; i < xlen; i++)
			this.readByte();
	}
	if (flags & FNAME)
		while (this.readByte()) {}
	if (flags & FCOMMENT)
		while (this.readByte()) {}
	if (flags & FHCRC)
		var hcrc16 = this.readWord();
	
	var inflate = new Inflate(this);
	
	inflate.process();
	
	return inflate;
}

function Inflate(gzip) {
	this.gzip = gzip;
	this.output = [];
	this.byte = 0;
	this.bitCounter = 0;
}

Inflate.prototype.read = function() {
	if (this.bitCounter == 0)
		this.byte = this.gzip.readByte();

	var bit = (this.byte >> this.bitCounter) & 1;
	this.bitCounter = (this.bitCounter + 1) & 7;
	return bit;
}

Inflate.prototype.readBits = function(length) {
	var value = 0;
	for (var i = 0; i < length; i++) {
		value |= this.read() << i;
	}
	return value;
}

Inflate.prototype.skipBitsToByteBoundary = function() {
	this.bitCounter = 0;
}

Inflate.prototype.write = function(symbols) {
	for (var i = 0; i < arguments.length; i++)
		this.output.push(arguments[i]);
}

Inflate.prototype.getOutput = function() {
	return new Buffer(this.output);
}

Inflate.prototype.process = function() {
	finalBlock = 0;
	while (!finalBlock) {
		finalBlock = this.read();
		var btype = this.readBits(2);
		//console.log("Block type: " + ("0" + btype).substr(-2));
		if (btype == 0)
			this.processUncompressedBlock();
		else if (btype == 1)
			this.processFixedCompressedBlock();
		else if (btype == 2)
			this.processDynamicCompressedBlock();
		else
			throw new Error("Invalid block type.");
	}
}

Inflate.prototype.processUncompressedBlock = function() {
	this.skipBitsToByteBoundary();
	var len = this.gzip.readWord();
	var nlen = this.gzip.readWord();
	if (len != (nlen ^ 0xFFFF))
		throw new Error("Invalid len/nlen: " + len.toString(16) + " / " + nlen.toString(16));
	for (var i = 0; i < len; i++)
		this.write(this.gzip.readByte());
}

Inflate.prototype.processFixedCompressedBlock = function() {
	this.processCompressedBlock(Alphabet.createFixedLiteralsAlphabet(),
			Alphabet.createFixedDistanceAlphabet());
}

Inflate.prototype.processDynamicCompressedBlock = function() {
	var hlit = this.readBits(5) + 257;
	var hdist = this.readBits(5) + 1;
	var hclen = this.readBits(4) + 4;
	
	var headerCodeOrder = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15];
	var headerCodeLengths = createArray(headerCodeOrder.length, 0);
	for (var i = 0; i < hclen; i++) {
		headerCodeLengths[headerCodeOrder[i]] = this.readBits(3);
	}
	var headerCodeAlphabet = new Alphabet(headerCodeLengths);
	
	// FIXME This is not handled:
	//  13. The literal/length and distance code bit lengths are read as a
	//      single stream of lengths.  It is possible (and advantageous) for
	//      a repeat code (16, 17, or 18) to go across the boundary between
	//      the two sets of lengths.
	// FIXME? One distance code of zero bits means that there are no
	//        distance codes used at all (the data is all literals).
	var literalsAlphabet = this.readHeaderAlphabet(hlit, headerCodeAlphabet);
	var distanceAlphabet = this.readHeaderAlphabet(hdist, headerCodeAlphabet);
	
	this.processCompressedBlock(literalsAlphabet, distanceAlphabet);
}

Inflate.prototype.readHeaderAlphabet = function(size, headerCodeAlphabet) {
	var codeLengths = createArray(size, 0);
	for (var i = 0; i < size; i++) {
		var symbol = headerCodeAlphabet.getSymbol(this);
		if (symbol < 16) {
			codeLengths[i] = symbol;
		} else if (symbol == 16) {
			var value = codeLengths[i - 1];
			var repeatCount = this.readBits(2) + 3;
			for (var j = 0; j < repeatCount; j++)
				codeLengths[i + j] = value;
			i += j - 1;
		} else if (symbol == 17) {
			var repeatCount = this.readBits(3) + 3;
			for (var j = 0; j < repeatCount; j++)
				codeLengths[i + j] = 0;
			i += j - 1;
		} else if (symbol == 18) {
			var repeatCount = this.readBits(7) + 11;
			for (var j = 0; j < repeatCount; j++)
				codeLengths[i + j] = 0;
			i += j - 1;
		}
	}
	return new Alphabet(codeLengths);
}

Inflate.prototype.processCompressedBlock = function(literalsAlphabet, distanceAlphabet) {
	while (true) {
		var symbol = literalsAlphabet.getSymbol(this);
		if (symbol < 256) {
			this.write(symbol);
		} else if (symbol == 256) {
			break;
		} else if (symbol < 265) {
			this.copy(symbol - 257 + 3, this.readDistance(distanceAlphabet));
		} else if (symbol < 269) {
			this.copy((symbol - 265 << 1 | this.readBits(1)) + 11, this.readDistance(distanceAlphabet));
		} else if (symbol < 273) {
			this.copy((symbol - 269 << 2 | this.readBits(2)) + 19, this.readDistance(distanceAlphabet));
		} else if (symbol < 277) {
			this.copy((symbol - 273 << 3 | this.readBits(3)) + 35, this.readDistance(distanceAlphabet));
		} else if (symbol < 281) {
			this.copy((symbol - 277 << 4 | this.readBits(4)) + 67, this.readDistance(distanceAlphabet));
		} else if (symbol < 285) {
			this.copy((symbol - 281 << 5 | this.readBits(5)) + 131, this.readDistance(distanceAlphabet));
		} else if (symbol == 285) {
			this.copy(258);
		} else {
			throw new Error("Unrecognised symbol: " + symbol);
		}
	}
}

Inflate.prototype.readDistance = function(distanceAlphabet) {
	var distance = distanceAlphabet.getSymbol(this);
	if (distance < 4) {
		return distance + 1;
	} else if (distance < 6) {
		return (distance - 4 << 1 | this.readBits(1)) + 5;
	} else if (distance < 8) {
		return (distance - 6 << 2 | this.readBits(2)) + 9;
	} else if (distance < 10) {
		return (distance - 8 << 3 | this.readBits(3)) + 17;
	} else if (distance < 12) {
		return (distance - 10 << 4 | this.readBits(4)) + 33;
	} else if (distance < 14) {
		return (distance - 12 << 5 | this.readBits(5)) + 65;
	} else if (distance < 16) {
		return (distance - 14 << 6 | this.readBits(6)) + 129;
	} else if (distance < 18) {
		return (distance - 16 << 7 | this.readBits(7)) + 257;
	} else if (distance < 20) {
		return (distance - 18 << 8 | this.readBits(8)) + 513;
	} else if (distance < 22) {
		return (distance - 20 << 9 | this.readBits(9)) + 1025;
	} else if (distance < 24) {
		return (distance - 22 << 10 | this.readBits(10)) + 2049;
	} else if (distance < 26) {
		return (distance - 24 << 11 | this.readBits(11)) + 4097;
	} else if (distance < 28) {
		return (distance - 26 << 12 | this.readBits(12)) + 8193;
	} else if (distance < 30) {
		return (distance - 28 << 13 | this.readBits(13)) + 16385;
	} else {
		throw new Error("Unrecognised distance: " + distance);
	}
}

Inflate.prototype.copy = function(length, distance) {
	var start = this.output.length - distance;
	for (var i = 0; i < length; i++)
		this.write(this.output[start + i]);
}

/**
 * @param codeLengths Array of code lengths for each symbol
 */
function Alphabet(codeLengths) {
	this.codes = [];
	this.tree = [];
	
	// count the number of codes for each code length
	var maxBits = Math.max.apply(Math, codeLengths);
	var bitLengthCount = createArray(maxBits + 1, 0);
	for (var i = 0; i < codeLengths.length; i++) {
		if (codeLengths[i] > 0)
			bitLengthCount[codeLengths[i]]++;
	}
	
	// find the numerical value of the smallest code for each code length
	var code = 0;
	var nextCode = [0];
	for (var bits = 1; bits <= bitLengthCount.length; bits++) {
		code = (code + bitLengthCount[bits - 1]) << 1;
		if (bitLengthCount[bits] > 0 && code >= (1 << bits))
			throw new Error("Code exceeds bit length: " + code.toString(2) + ", length: " + bits);
		nextCode[bits] = code;
	}
	
	// assign numerical values to all codes
	for (var i = 0; i < codeLengths.length; i++) {
		if (codeLengths[i] != 0) {
			this.codes[i] = new Code(i, codeLengths[i], nextCode[codeLengths[i]]++);
			this.addTreeEntry(this.codes[i]);
		}
	}
}

Alphabet.prototype.addTreeEntry = function(code) {
	var tree = this.tree;
	for (var i = code.codeLength - 1; i >= 0; i--) {
		var bit = (code.code >> i) & 1;
		if (i > 0) {
			if (!(tree instanceof Array))
				throw new Error("Huffman tree conflict: " + code + " / " + tree);
			if (tree[bit] === undefined)
				tree[bit] = [];
			else if (!(tree[bit] instanceof Array))
				throw new Error("Huffman tree conflict: " + code + " / " + tree[bit]);
			tree = tree[bit];
		} else {
			if (tree[bit] !== undefined)
				throw new Error("Huffman tree conflict: " + code + " / " + tree[bit]);
			tree[bit] = code;
		}
	}
}

Alphabet.prototype.getCode = function(symbol) {
	return this.codes[symbol];
}

Alphabet.prototype.getSymbol = function(inflate) {
	var tree = this.tree;
	while (tree instanceof Array) {
		tree = tree[inflate.read()];
	}
	if (!(tree instanceof Code)) {
		throw new Error("Unrecognised symbol.");
	}
	return tree.symbol;
}

Alphabet.prototype.toString = function() {
	var codes = this.codes.filter(function(code) { return code !== undefined });
	return codes.join("\n");
}

Alphabet.createFixedLiteralsAlphabet = function() {
	var codeLengths = [];
	for (var i = 0; i < 144; i++)
		codeLengths.push(8);
	for (var i = 144; i < 256; i++)
		codeLengths.push(9);
	for (var i = 256; i < 280; i++)
		codeLengths.push(7);
	for (var i = 280; i < 288; i++)
		codeLengths.push(8);
	return new Alphabet(codeLengths);
}

Alphabet.createFixedDistanceAlphabet = function() {
	var codeLengths = [];
	for (var i = 0; i < 30; i++)
		codeLengths.push(5);
	return new Alphabet(codeLengths);
}

function Code(symbol, length, code) {
	if (code >= (1 << length))
		throw new Error("Code exceeds bit length: " + code.toString(2) + ", length: " + length);
	
	this.symbol = symbol;
	this.codeLength = length;
	this.code = code;
}

Code.prototype.toString = function() {
	return ("    " + this.symbol).substr(-5) + ": " +
		("000000000000000" + this.code.toString(2)).substr(-this.codeLength);
}

function createArray(size, initialValue) {
	var array = new Array(size);
	for (var i = 0; i < size; i++)
		array[i] = initialValue;
	return array;
}

main();