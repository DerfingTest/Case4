def sum_negative_between_min_max(numbers):
    """Складывает отрицательные числа, стоящие между минимумом и максимумом."""
    min_index = numbers.index(min(numbers))
    max_index = numbers.index(max(numbers))

    left_index = min(min_index, max_index)
    right_index = max(min_index, max_index)

    return sum(number for number in numbers[left_index + 1 : right_index] if number < 0)


def main():
    size = int(input("Введите количество элементов N: "))
    if size <= 0:
        raise ValueError("Количество элементов должно быть положительным")

    numbers = []
    for index in range(size):
        numbers.append(int(input(f"A[{index}] = ")))

    result = sum_negative_between_min_max(numbers)
    print(f"Результат: сумма отрицательных элементов между min и max: {result}")


if __name__ == "__main__":
    main()
