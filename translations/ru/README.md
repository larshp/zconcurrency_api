![ABAP 7.00+](https://img.shields.io/badge/ABAP-7.00%2B-brightgreen)

**ВНИМАНИЕ**: Проект все еще разрабатывается и API может меняться.
## `ABAP Concurrency API`
API для параллельных вычислений, основанное на SPTA Framework.

## Что это такое?
`ABAP Concurrency API` - это несколько классов, предназначенных для реализации параллельных вычислений.

## Зачем это нужно?
Реализация параллельных вычислений в ABAP обычно включает следующие шаги:
1. Создание RFC ФМ-а
2. **Реализация** внутри него **бизнес-логики**
3. Асинхронный вызов RFC ФМ-а в цикле
4. Ожидание выполнения и **получение результатов работы**

Если посмотреть на получившийся список, то можно заметить, что по большому счету нас интересует только шаги **`2`** и **`4`**.
Все остальное - это рутинная работа, которая каждый раз занимает время и, потенциально, может быть источником ошибок.

Чтобы не создавать RFC ФМ каждый раз когда необходимо выполнить параллельную обработку, можно использовать SPTA Framework, который нам предоставил вендор.  
SPTA Framework это хороший инструмент, но интерфейс взаимодействия с ним оставляет желать лучшего. Из-за этого, разработчику приходится прикладывать не малые усилия, для того, чтобы реализовать сам процесс распараллеливания.  

Кроме того, написать чистый код, используя непосредственно SPTA Framework тоже не самая простая задача. Нужно быть настоящим ниндзя, чтобы избежать использования глобальных переменных. В конечном итоге, код может получится запутанным и тяжело поддерживаемым.

`ABAP Concurrency API` позволяет избежать этих проблем. С ним вы можете позволить себе мыслить более абстрактно.
Вам не нужно акцентировать внимание на распараллеливании. Вместо этого, вы можете уделить больше времени бизнес-логике вашего приложения.  

## Установка
Есть два простых способа установить `ABAP Concurrency API`:

1. [abapGit](http://www.abapgit.org).
2. [SAPlink](https://gist.github.com/victorizbitskiy/bcbd9ea7ac4ef7a06e58c01b06b4cce0)

## Использование
Рассмотрим простую задачу:  

*Необходимо найти квадраты чисел от **`1`** до **`10`***.

Квадрат каждого из чисел будем искать в отдельной задаче/процессе.  
Пример оторван от реального мира, но его достаточно для того, чтобы понять как работать с API.

Для начала создадим необходимые нам 3 класса: *Контекст*, *Задача* и *Результат*. 
1. **lcl_contex**, объект этого класса будет инкапсулировать параметры задачи.
Использование этого класса не обязательно. Можно обойтись и без него, передав параметры задачи непосредственно в ее конструктор.
Однако, использование отдельного класса, на мой взгляд, предпочтительнее.

```abap
CLASS lcl_context DEFINITION FINAL.
  PUBLIC SECTION.
    INTERFACES: if_serializable_object.

    TYPES: BEGIN OF ty_params,
             param TYPE i,
           END OF ty_params.

    METHODS: constructor IMPORTING is_params TYPE ty_params,
             get RETURNING VALUE(rs_params) TYPE ty_params.

  PRIVATE SECTION.
    DATA: ms_params TYPE ty_params.
ENDCLASS.

CLASS lcl_context IMPLEMENTATION.
  METHOD constructor.
    ms_params = is_params.
  ENDMETHOD.

  METHOD get.
    rs_params = ms_params.
  ENDMETHOD.
ENDCLASS.
```
2. **lcl_task**, описывает объект *Задача*. Содержит бизнес-логику (в нашем случае возведение числа в степень 2).
   Обратите внимание, что класс **lcl_task** наследуется от класса **zcl_capi_abstract_task** и переопределяет метод **zif_capi_callable~call**.

```abap
CLASS lcl_task DEFINITION INHERITING FROM zcl_capi_abstract_task FINAL.
  PUBLIC SECTION.

    METHODS: constructor IMPORTING io_context TYPE REF TO lcl_context,
             zif_capi_callable~call REDEFINITION.

  PRIVATE SECTION.
    DATA: mo_context TYPE REF TO lcl_context.
    DATA: mv_res TYPE i.
ENDCLASS.

CLASS lcl_task IMPLEMENTATION.
  METHOD constructor.
    super->constructor( ).
    mo_context = io_context.
  ENDMETHOD.

  METHOD zif_capi_callable~call.
    DATA: ls_params TYPE lcl_context=>ty_params.

    ls_params = mo_context->get( ).
    mv_res = ls_params-param ** 2.

    ro_result = new lcl_result( iv_param  = ls_params-param
                                iv_result = mv_res ).
  ENDMETHOD.
ENDCLASS.
```
3. **lcl_result** описывает *Результат* выполнения задачи. 
Этот класс должен реализовывать интерфейс **if_serializable_object**. В остальном вы можете описать его произвольным образом.

```abap
CLASS lcl_result DEFINITION FINAL.
  PUBLIC SECTION.
    INTERFACES: if_serializable_object.

    METHODS: constructor IMPORTING iv_param  TYPE i
                                   iv_result TYPE i,
             get RETURNING VALUE(rv_result) TYPE string.

  PRIVATE SECTION.
    DATA: mv_param TYPE i.
    DATA: mv_result TYPE i.
ENDCLASS.

CLASS lcl_result IMPLEMENTATION.
  METHOD constructor.
    mv_param = iv_param.
    mv_result = iv_result.
  ENDMETHOD.

  METHOD get.
    rv_result = |{ mv_param } -> { mv_result }|.
  ENDMETHOD.
ENDCLASS.
```
**Внимание:**  
Объекты классов **lcl_task** и **lcl_result** сериализуются/десериализуются в процессе выполнения, поэтому избегайте использования статичных атрибутов.
Статичные атрибуты принадлежат классу, а не объекту. Их содержимое при сериализации/десериализации будет утеряно.

Итак, объекты *Контекст*, *Задача* и *Результат* описаны. 
Теперь посмотрим пример их применения:

```abap
    DATA: lo_result TYPE REF TO lcl_result.

*   Create collection of tasks
    DATA(lo_tasks) = NEW zcl_capi_collection( ).

    DO 10 TIMES.
      DATA(lo_task) = NEW lcl_task(
                                    NEW lcl_context(
                                                     VALUE lcl_context=>ty_params( param = sy-index )
                                                     )
                                    ).
      lo_tasks->zif_capi_collection~add( lo_task ).
    ENDDO.

    DATA(lo_message_handler) = NEW zcl_capi_message_handler( ).
    DATA(lo_executor) = NEW zcl_capi_executor_service( iv_server_group             = 'parallel_generators'
                                                       iv_max_no_of_tasks          = 5
                                                       iv_no_resubmission_on_error = abap_false
                                                       io_capi_message_handler     = lo_message_handler ).
                                                       
    DATA(lo_results) = lo_executor->zif_capi_executor_service~invoke_all( lo_tasks ).
    DATA(lo_results_iterator) = lo_results->get_iterator( ).

    WHILE lo_results_iterator->has_next( ).
      lo_result ?= lo_results_iterator->next( ).
      DATA(lv_result) = lo_result->get( ).
      WRITE: / lv_result.
    ENDWHILE.

```
1. Сначала создаем *Коллекцию задач* **lo_tasks**
2. Далее, создаем *Задачу* **lo_task** и добавляем ее в *Коллекцию задач* **lo_tasks**
3. Создаем *Обработчик сообщений* **lo_message_handler**
4. Теперь мы подошли к наиболее важной части API - к понятию "сервиса-исполнителя". Сервис-исполнитель асинхронно выполняет переданные в него задачи.  
   Создаем объект **lo_executor** класса **zcl_capi_executor_service**. Конструктор класса имеет 4 параметра:

| Имя параметра               | Описание                                                     |
| :-------------------------- | :----------------------------------------------------------- |
| iv_server_group             | группа серверов (tcode: RZ12)                                |
| iv_max_no_of_tasks          | максимальное количество одновременно работающих задач        |
| iv_no_resubmission_on_error | флаг, "**true**"- не запускать повторно задачу при возникновении ошибке |
| io_capi_message_handler     | объект, который будет содержать сообщения об ошибках (если они произошли) |
  
  Объект lo_executor имеет только один интерфейсный метод **invoke_all()**, который принимает на вход *Коллекцию задач* и возвращает *Коллекцию результатов* **lo_results**  (подход заимствован из **java.util.concurrent.***).

5. У *Коллекции результатов* **lo_results** есть итератор, используя который мы легко получаем *Результаты работы* **lo_result** и вызываем у них метод **get( )**.  

В итоге, нам не пришлось создавать RFC ФМ, описывать процесс распараллеливания и т.д.
Все что мы сделали, это описали что собой представляют *Задача* и *Результат*.

**Результат работы:**

![result](https://github.com/victorizbitskiy/zconcurrency_api/blob/main/docs/img/result.png)

Рассмотренный пример использования `ABAP Concurrency API` можно найти в отчете **ZCONCURRENCY_API_EXAMPLE**.

# UML диаграмма классов
![UML Class Diagram](https://github.com/victorizbitskiy/zconcurrency_api/blob/main/docs/img/UML%20Class%20Diagram.png)

# Лицензия
[Unlicense License](https://github.com/victorizbitskiy/zconcurrency_api/blob/main/LICENSE)