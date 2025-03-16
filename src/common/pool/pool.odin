package pool

Pool :: struct($T: typeid, $Size: int) {
	data: [Size]T,
	taken: [Size]bool,
}

add :: proc(pool: ^Pool($T, $Size)) -> ^T {
	value, ok := add_safe(pool)
	assert(ok)
	return value
}

add_safe :: proc(pool: ^Pool($T, $Size)) -> (^T, bool) {
	available_index: Maybe(int) = nil
	for taken, index in pool.taken {
		if !taken {
			available_index = index
			break
		}
	}

	if available_index != nil {
		pool.taken[available_index.(int)] = true
		return &pool.data[available_index.(int)], true
	} else {
		return nil, false
	}
}

remove :: proc(pool: ^Pool($T, $Size), index: int) {
	assert(index < Size)

	if index < Size {
		pool.taken[index] = false
	}
}

available :: proc "contextless" (pool: Pool($T, $Size)) -> int {
	count := 0
	for i in 0..<Size {
		if !pool.taken[i] do count += 1
	}
	return count
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