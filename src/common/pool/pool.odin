package pool

Pool :: struct($T: typeid, $Size: int) {
	data: [Size]T,
	taken: [Size]bool,
}

add :: proc(pool: ^Pool($T, $Size)) -> ^T {
	available_index: Maybe(int) = nil
	for taken, index in pool.taken {
		if !taken {
			available_index = index
			break
		}
	}

	assert(available_index != nil)

	if available_index != nil {
		pool.taken[available_index.(int)] = true
		return &pool.data[available_index.(int)]
	} else {
		pool.taken[Size - 1] = true
		return &pool.data[Size - 1]
	}
}

remove :: proc(pool: ^Pool($T, $Size), index: int) {
	assert(index < Size)

	if index < Size {
		pool.taken[index] = false
	}
}

Pool_Iterator :: struct($T: typeid, $Size: int) {
	pool: ^Pool(T, Size),
	index: int,
}

make_pool_iterator :: proc "contextless" (pool: ^Pool($T, $Size)) -> Pool_Iterator(T, Size) {
	return { pool = pool, index = 0 }
}

iterate_pool :: proc "contextless" (iterator: ^Pool_Iterator($T, $Size)) -> (value: ^T, index: int, condition: bool) {
	for iterator.index < Size && !iterator.pool.taken[iterator.index] {
		iterator.index += 1
	}

	index = iterator.index
	condition = index < Size

	if condition {
		value = &iterator.pool.data[index]
		iterator.index += 1
	}

	return
}