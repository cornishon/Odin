Any :: struct #ordered {
	data:      rawptr,
	type_info: ^Type_Info,
}

String :: struct #ordered {
	data: ^byte,
	len:  int,
};

Slice :: struct #ordered {
	data: rawptr,
	len:  int,
	cap:  int,
};

Dynamic_Array :: struct #ordered {
	data:      rawptr,
	len:       int,
	cap:       int,
	allocator: Allocator,
};

Dynamic_Map :: struct #ordered {
	hashes:  [dynamic]int,
	entries: Dynamic_Array,
};
