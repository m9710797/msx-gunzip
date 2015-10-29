var crctable = [];

for (var n = 0; n < 256; n++) {
	var c = n;
	for (var k = 0; k < 8; k++)
		c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
	crctable.push(c);
}

var splittable = [[], [], [], []];

for (var i = 0; i < crctable.length; i++) {
	splittable[0].push(crctable[i] & 0xFF);
	splittable[1].push((crctable[i] >> 8) & 0xFF);
	splittable[2].push((crctable[i] >> 16) & 0xFF);
	splittable[3].push((crctable[i] >> 24) & 0xFF);
}

console.log("\tdb " + splittable[0].join(", "));
console.log("\tdb " + splittable[1].join(", "));
console.log("\tdb " + splittable[2].join(", "));
console.log("\tdb " + splittable[3].join(", "));
