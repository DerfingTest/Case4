class Employee:
    def __init__(self, name):
        self.name = name

    def arrive_at_work(self):
        print(f"Сотрудник {self.name} прибыл на работу в 8 утра")

    def report(self):
        print(f"Сотрудник {self.name} отчитался о проделанной работе")


class Chief(Employee):
    def report(self):
        super().report()
        print(f"Сотрудник {self.name} также отчитался о работе всего отдела")

    def delegate_task(self):
        print(f"Сотрудник {self.name} делегировал задачу подчиненному")


def main():
    employee = Employee("Федор Михайлович")
    chief = Chief("Виктор Сергеевич")

    print("--- Прибытие на работу: унаследованный метод ---")
    employee.arrive_at_work()
    chief.arrive_at_work()

    print("\n--- Отчеты: базовый и переопределенный методы ---")
    employee.report()
    chief.report()

    print("\n--- Метод производного класса ---")
    chief.delegate_task()


if __name__ == "__main__":
    main()
